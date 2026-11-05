class_name VaultStorage
extends RefCounted

const IMAGE_REF_PREFIX: String = "user://vault/images/"
const NOTES_FOLDER: String = "notes/"
const IMAGES_FOLDER: String = "images/"
const TRASH_FOLDER: String = "trash/"
const BACKUPS_FOLDER: String = "backups/"
const CONNECTIONS_FILE: String = "connections.json"
const TYPES_FILE: String = "types.json"
const DECOR_FILE: String = "decor.json"
const CANVAS_FILE: String = "canvas.json"
const BACKUP_PREFIX: String = "vault_"
const MAX_BACKUPS: int = 10
const DAILY_PREFIX: String = "daily_"
const MAX_DAILY_SNAPSHOTS: int = 7
const TRASH_DAYS: int = 30
const SECONDS_PER_DAY: int = 86400
const MAX_IMAGE_BASE_LENGTH: int = 80
const TEMP_SUFFIX: String = ".tmp"
const CORRUPT_SUFFIX: String = ".corrupt"

enum NoteState { OK, UNREADABLE, CORRUPT }
enum SnapshotResult { TAKEN, ALREADY_TAKEN, NOTHING_TO_SAVE, FAILED }

var last_corrupt: PackedStringArray = PackedStringArray()
var last_unreadable: PackedStringArray = PackedStringArray()

var root: String = ""
var notes_dir: String = ""
var images_dir: String = ""
var connections_path: String = ""
var types_path: String = ""
var decor_path: String = ""
var canvas_path: String = ""
var backups_dir: String = ""
var trash_dir: String = ""
var trash_notes_dir: String = ""
var trash_images_dir: String = ""
var trash_files_dir: String = ""
var trash_decor_dir: String = ""

func _init(world_root: String) -> void:
	root = world_root.replace("\\", "/") if OS.get_name() == "Windows" else world_root
	if not root.ends_with("/"):
		root += "/"
	notes_dir = root + NOTES_FOLDER
	images_dir = root + IMAGES_FOLDER
	connections_path = root + CONNECTIONS_FILE
	types_path = root + TYPES_FILE
	decor_path = root + DECOR_FILE
	canvas_path = root + CANVAS_FILE
	backups_dir = root + BACKUPS_FOLDER
	trash_dir = root + TRASH_FOLDER
	trash_notes_dir = trash_dir + "notes/"
	trash_images_dir = trash_dir + "images/"
	trash_files_dir = trash_dir + "files/"
	trash_decor_dir = trash_dir + "decor/"

func ensure_directories() -> void:
	if not DirAccess.dir_exists_absolute(notes_dir):
		DirAccess.make_dir_recursive_absolute(notes_dir)
	if not DirAccess.dir_exists_absolute(images_dir):
		DirAccess.make_dir_recursive_absolute(images_dir)
	if not DirAccess.dir_exists_absolute(trash_decor_dir):
		DirAccess.make_dir_recursive_absolute(trash_decor_dir)

func save_note(id: String, title: String, content: String, pos: Vector2, color_hex: String = "313549", image_path: String = "", extra: Dictionary = {}) -> bool:
	ensure_directories()
	var file_path: String = notes_dir + id + ".md"
	var metadata: Dictionary = {
		"id": id,
		"title": title,
		"pos_x": pos.x,
		"pos_y": pos.y,
		"color": color_hex,
		"image": image_path
	}
	metadata.merge(extra, false)

	var file_content: String = "---\n" + JSON.stringify(metadata, "\t") + "\n---\n" + content
	return _write_text_atomic(file_path, file_content)

func _write_text_atomic(path: String, text: String) -> bool:
	var temp_path: String = path + TEMP_SUFFIX
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write file: " + temp_path)
		return false
	var written: bool = file.store_string(text)
	file.close()
	if not written:
		push_error("Failed to write file: " + temp_path)
		return false
	if DirAccess.rename_absolute(temp_path, path) != OK:
		push_error("Failed to replace file: " + path)
		return false
	return true

func load_all_notes() -> Array[Dictionary]:
	ensure_directories()
	last_corrupt = PackedStringArray()
	last_unreadable = PackedStringArray()
	_recover_temp_notes()

	var notes: Array[Dictionary] = []
	for file_name: String in _list_notes():
		var loaded: Dictionary = _read_note(notes_dir + file_name)
		match int(loaded["state"]):
			NoteState.OK:
				notes.append(loaded["note"] as Dictionary)
			NoteState.UNREADABLE:
				last_unreadable.append(file_name)
				push_warning("Note file could not be opened: " + notes_dir + file_name)
			NoteState.CORRUPT:
				var new_name: String = _mark_corrupt(file_name)
				last_corrupt.append(new_name if new_name != "" else file_name)
				push_warning("Damaged note file %s renamed to %s" % [file_name, new_name])
	return notes

func _recover_temp_notes() -> void:
	var dir: DirAccess = DirAccess.open(notes_dir)
	if not dir:
		return
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".md" + TEMP_SUFFIX):
			continue
		var note_name: String = file_name.trim_suffix(TEMP_SUFFIX)
		if FileAccess.file_exists(notes_dir + note_name):
			continue
		if int(_read_note(notes_dir + file_name)["state"]) == NoteState.OK:
			DirAccess.rename_absolute(notes_dir + file_name, notes_dir + note_name)

func _mark_corrupt(file_name: String) -> String:
	var target: String = file_name + CORRUPT_SUFFIX
	var counter: int = 2
	while FileAccess.file_exists(notes_dir + target):
		target = "%s.%d%s" % [file_name, counter, CORRUPT_SUFFIX]
		counter += 1
	if DirAccess.rename_absolute(notes_dir + file_name, notes_dir + target) != OK:
		return ""
	return target

func _parse_note_file(path: String) -> Dictionary:
	var loaded: Dictionary = _read_note(path, false)
	return loaded["note"] if int(loaded["state"]) == NoteState.OK else {}

func _read_note(path: String, check_id: bool = true) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {"state": NoteState.UNREADABLE, "note": {}}

	var text: String = file.get_as_text().replace("\r\n", "\n")
	file.close()

	if not text.begins_with("---\n"):
		return {"state": NoteState.CORRUPT, "note": {}}

	var end_meta: int = text.find("\n---\n", 4)
	if end_meta == -1:
		return {"state": NoteState.CORRUPT, "note": {}}

	var json_str: String = text.substr(4, end_meta - 4)
	var content_body: String = text.substr(end_meta + 5)

	var parsed: Variant = JSON.parse_string(json_str)
	if not (parsed is Dictionary):
		return {"state": NoteState.CORRUPT, "note": {}}

	var meta: Dictionary = parsed as Dictionary
	var note_id: String = str(meta.get("id", ""))
	var file_id: String = path.get_file().trim_suffix(TEMP_SUFFIX).trim_suffix(".md")
	if check_id and (not ProjectBundle.is_safe_id(note_id) or note_id != file_id):
		return {"state": NoteState.CORRUPT, "note": {}}

	var file_time: int = int(FileAccess.get_modified_time(path))
	return {"state": NoteState.OK, "note": _note_from_meta(meta, file_time, content_body)}

func _note_from_meta(meta: Dictionary, file_time: int, content_body: String) -> Dictionary:
	return {
		"id": str(meta.get("id", "")),
		"title": str(meta.get("title", TranslationServer.translate("note.title_fallback"))),
		"pos": Vector2(float(meta.get("pos_x", 0.0)), float(meta.get("pos_y", 0.0))),
		"color": str(meta.get("color", "313549")),
		"image": str(meta.get("image", "")),
		"status": str(meta.get("status", "")),
		"created": int(meta.get("created", file_time)),
		"modified": int(meta.get("modified", file_time)),
		"flipped": bool(meta.get("flipped", false)),
		"type": str(meta.get("type", "")),
		"fields": FieldDef.sanitize_values(meta.get("fields", {})),
		"color_overridden": bool(meta.get("color_overridden", false)),
		"bg_color": NoteBackground.sanitize_hex(meta.get("bg_color", "")),
		"bg_color2": NoteBackground.sanitize_hex(meta.get("bg_color2", "")),
		"bg_image": str(meta.get("bg_image", "")),
		"content": content_body
	}

func delete_note(id: String) -> void:
	_move_to_trash(notes_dir + id + ".md", trash_notes_dir)

var last_refusal: String = ""
var last_refusal_reason: String = ""

func copy_image_to_vault(source_path: String, max_side: int = ImageGuard.MAX_SIDE, max_bytes: int = ImageGuard.MAX_FILE_BYTES) -> String:
	last_refusal = ""
	last_refusal_reason = ""
	var checked: Dictionary = ImageGuard.inspect_file(source_path, max_side, max_bytes)
	if not bool(checked["ok"]):
		last_refusal = ImageGuard.describe(checked, source_path)
		last_refusal_reason = str(checked["reason"])
		return ""
	return store_image_bytes(source_path.get_file(), checked["bytes"] as PackedByteArray, max_side, max_bytes)

static func hashed_image_name(file_name: String, bytes: PackedByteArray) -> String:
	var hasher: HashingContext = HashingContext.new()
	hasher.start(HashingContext.HASH_SHA1)
	hasher.update(bytes)
	var digest: String = hasher.finish().hex_encode().substr(0, 16)

	var safe_name: String = file_name.get_file().validate_filename()
	for unsafe: String in [" ", "(", ")", "[", "]", ","]:
		safe_name = safe_name.replace(unsafe, "_")
	var extension: String = safe_name.get_extension()
	var base: String = safe_name.get_basename().strip_edges()
	if base == "":
		base = "image"
	if base.length() > MAX_IMAGE_BASE_LENGTH:
		base = base.substr(0, MAX_IMAGE_BASE_LENGTH)
	safe_name = base + ("." + extension if extension != "" else "")

	if safe_name.begins_with(digest + "_"):
		return safe_name
	return digest + "_" + safe_name

func store_image_bytes(file_name: String, bytes: PackedByteArray, max_side: int = ImageGuard.MAX_SIDE, max_bytes: int = ImageGuard.MAX_FILE_BYTES) -> String:
	last_refusal = ""
	last_refusal_reason = ""
	if bytes.is_empty():
		return ""
	var checked: Dictionary = ImageGuard.inspect(bytes, file_name.get_extension(), max_side, max_bytes)
	if not bool(checked["ok"]):
		last_refusal = ImageGuard.describe(checked, file_name)
		last_refusal_reason = str(checked["reason"])
		return ""
	ensure_directories()

	var stored_name: String = hashed_image_name(file_name, bytes)
	var reference: String = IMAGE_REF_PREFIX + stored_name
	var target_path: String = images_dir + stored_name
	if FileAccess.file_exists(target_path):
		return reference

	var temp_path: String = target_path + TEMP_SUFFIX
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to write image file: " + temp_path)
		return ""
	var written: bool = file.store_buffer(bytes)
	file.close()
	if not written or DirAccess.rename_absolute(temp_path, target_path) != OK:
		push_error("Failed to write image file: " + target_path)
		return ""
	return reference

func list_images() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(images_dir)
	if not dir:
		return names
	for file_name: String in dir.get_files():
		if ProjectBundle.IMAGE_EXTENSIONS.has(file_name.get_extension().to_lower()):
			names.append(file_name)
	return names

func delete_image(file_name: String) -> bool:
	if file_name != file_name.get_file() or not FileAccess.file_exists(images_dir + file_name):
		return false
	return _move_to_trash(images_dir + file_name, trash_images_dir)

func backup_image_refs() -> Dictionary:
	var refs: Dictionary = {}
	_collect_image_refs(trash_notes_dir, refs)
	for trashed: String in DirAccess.get_files_at(trash_decor_dir):
		if trashed.ends_with(".json"):
			_collect_decor_image_refs(trash_decor_dir + trashed, refs)
	var backups: DirAccess = DirAccess.open(backups_dir)
	if not backups:
		return refs
	for folder: String in backups.get_directories():
		if folder.begins_with(BACKUP_PREFIX) or folder.begins_with(DAILY_PREFIX):
			_collect_image_refs(backups_dir + folder + "/notes/", refs)
			_collect_type_image_refs(backups_dir + folder + "/types.json", refs)
			_collect_decor_image_refs(backups_dir + folder + "/decor.json", refs)
			_collect_canvas_image_ref(backups_dir + folder + "/canvas.json", refs)
	return refs

func _collect_canvas_image_ref(path: String, refs: Dictionary) -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		var picture: String = str((parsed as Dictionary).get("image", ""))
		if picture != "":
			refs[picture.get_file().to_lower()] = true

func _collect_type_image_refs(types_path: String, refs: Dictionary) -> void:
	if not FileAccess.file_exists(types_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(types_path))
	if not (parsed is Array):
		return
	for entry: Variant in (parsed as Array):
		if entry is Dictionary:
			var picture: String = str((entry as Dictionary).get("bg_image", ""))
			if picture != "":
				refs[picture.get_file().to_lower()] = true

func _collect_decor_image_refs(path: String, refs: Dictionary) -> void:
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var entries: Array = []
	if parsed is Array:
		entries = parsed as Array
	elif parsed is Dictionary:
		entries = [parsed]
	for entry: Variant in entries:
		if entry is Dictionary:
			var picture: String = str((entry as Dictionary).get("image", ""))
			if picture != "":
				refs[picture.get_file().to_lower()] = true

func _collect_image_refs(notes_dir: String, refs: Dictionary) -> void:
	var dir: DirAccess = DirAccess.open(notes_dir)
	if not dir:
		return
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".md"):
			continue
		for picture: String in NoteImages.used_paths(_parse_note_file(notes_dir + file_name)):
			refs[picture.get_file().to_lower()] = true


func _move_to_trash(path: String, trash_dir: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	if not DirAccess.dir_exists_absolute(trash_dir) and DirAccess.make_dir_recursive_absolute(trash_dir) != OK:
		push_error("Failed to create the trash folder: " + trash_dir)
		return false
	var stamp: int = int(Time.get_unix_time_from_system())
	var target: String = trash_dir + "%d_%s" % [stamp, path.get_file()]
	var counter: int = 2
	while FileAccess.file_exists(target):
		target = trash_dir + "%d_%d-%s" % [stamp, counter, path.get_file()]
		counter += 1
	if DirAccess.rename_absolute(path, target) != OK:
		push_error("Failed to move %s to the trash" % path)
		return false
	return true

func list_trashed_notes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for file_name: String in DirAccess.get_files_at(trash_notes_dir):
		var stamp: String = file_name.get_slice("_", 0)
		if not file_name.ends_with(".md") or not stamp.is_valid_int():
			continue
		var loaded: Dictionary = _read_note(trash_notes_dir + file_name, false)
		if int(loaded["state"]) != NoteState.OK:
			continue
		var note: Dictionary = loaded["note"]
		note["trash_file"] = file_name
		note["deleted_at"] = stamp.to_int()
		result.append(note)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["deleted_at"]) > int(b["deleted_at"]))
	return result

func restore_trashed_note(trash_file: String, new_id: String, note: Dictionary) -> bool:
	var source: String = trash_notes_dir + trash_file
	var target: String = notes_dir + new_id + ".md"
	if trash_file != trash_file.get_file() or not ProjectBundle.is_safe_id(new_id) 			or not FileAccess.file_exists(source) or FileAccess.file_exists(target):
		return false
	ensure_directories()
	if DirAccess.rename_absolute(source, target) != OK:
		return false
	for picture: String in NoteImages.used_paths(note):
		_restore_trashed_picture(picture.get_file())
	return true

func _restore_trashed_picture(file_name: String) -> void:
	if file_name == "" or FileAccess.file_exists(images_dir + file_name):
		return
	for trashed: String in DirAccess.get_files_at(trash_images_dir):
		var stamp: String = trashed.get_slice("_", 0)
		if not stamp.is_valid_int():
			continue
		var rest: String = trashed.substr(stamp.length() + 1)
		var dash: int = rest.find("-")
		var matches: bool = rest == file_name or (dash > 0 and rest.substr(0, dash).is_valid_int() and rest.substr(dash + 1) == file_name)
		if matches:
			DirAccess.rename_absolute(trash_images_dir + trashed, images_dir + file_name)
			return

func trash_file_count() -> int:
	var count: int = 0
	for trash_dir: String in [trash_notes_dir, trash_images_dir, trash_files_dir, trash_decor_dir]:
		if DirAccess.dir_exists_absolute(trash_dir):
			count += DirAccess.get_files_at(trash_dir).size()
	return count

func empty_trash() -> int:
	var removed: int = 0
	for trash_dir: String in [trash_notes_dir, trash_images_dir, trash_files_dir, trash_decor_dir]:
		for file_name: String in DirAccess.get_files_at(trash_dir):
			if DirAccess.remove_absolute(trash_dir + file_name) == OK:
				removed += 1
	return removed

func purge_trash(now: int) -> int:
	var removed: int = 0
	var limit: int = now - TRASH_DAYS * SECONDS_PER_DAY
	for trash_dir: String in [trash_notes_dir, trash_images_dir, trash_files_dir, trash_decor_dir]:
		var dir: DirAccess = DirAccess.open(trash_dir)
		if not dir:
			continue
		for file_name: String in dir.get_files():
			var stamp: String = file_name.get_slice("_", 0)
			if stamp.is_valid_int() and stamp.to_int() < limit:
				if DirAccess.remove_absolute(trash_dir + file_name) == OK:
					removed += 1
	return removed

func backup_vault(keep: int = MAX_BACKUPS) -> String:
	ensure_directories()
	if keep <= 0:
		_prune_backups(BACKUP_PREFIX, 0)
		return ""
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var backup_dir: String = backups_dir + BACKUP_PREFIX + stamp + "/"
	if not _backup_into(backup_dir):
		return ""
	_prune_backups(BACKUP_PREFIX, keep)
	return backup_dir

func take_daily_snapshot(day: String) -> SnapshotResult:
	ensure_directories()
	var snapshot_dir: String = backups_dir + DAILY_PREFIX + day + "/"
	if DirAccess.dir_exists_absolute(snapshot_dir):
		return SnapshotResult.ALREADY_TAKEN
	if _list_notes().is_empty():
		return SnapshotResult.NOTHING_TO_SAVE
	if not _backup_into(snapshot_dir):
		_remove_dir_recursive(snapshot_dir)
		return SnapshotResult.FAILED
	_prune_backups(DAILY_PREFIX, MAX_DAILY_SNAPSHOTS)
	return SnapshotResult.TAKEN

func _backup_into(backup_dir: String) -> bool:
	var notes_target: String = backup_dir + "notes/"
	if DirAccess.make_dir_recursive_absolute(notes_target) != OK:
		return false
	var copied: bool = true
	for file_name: String in _list_notes():
		copied = DirAccess.copy_absolute(notes_dir + file_name, notes_target + file_name) == OK and copied
	if FileAccess.file_exists(connections_path):
		copied = DirAccess.copy_absolute(connections_path, backup_dir + "connections.json") == OK and copied
	if FileAccess.file_exists(types_path):
		copied = DirAccess.copy_absolute(types_path, backup_dir + "types.json") == OK and copied
	if FileAccess.file_exists(decor_path):
		copied = DirAccess.copy_absolute(decor_path, backup_dir + "decor.json") == OK and copied
	if FileAccess.file_exists(canvas_path):
		copied = DirAccess.copy_absolute(canvas_path, backup_dir + "canvas.json") == OK and copied
	return copied

func clear_vault() -> void:
	for file_name: String in _list_notes():
		_move_to_trash(notes_dir + file_name, trash_notes_dir)
	_move_to_trash(types_path, trash_files_dir)
	_move_to_trash(connections_path, trash_files_dir)
	_move_to_trash(decor_path, trash_files_dir)
	_move_to_trash(canvas_path, trash_files_dir)
	var no_links: Array[Dictionary] = []
	save_connections(no_links)

func _list_notes() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(notes_dir)
	if not dir:
		return names
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".md"):
			names.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	return names

func _prune_backups(prefix: String, keep: int) -> void:
	var dir: DirAccess = DirAccess.open(backups_dir)
	if not dir:
		return
	var folders: PackedStringArray = PackedStringArray()
	for folder: String in dir.get_directories():
		if folder.begins_with(prefix):
			folders.append(folder)
	folders.sort()
	while folders.size() > keep:
		_remove_dir_recursive(backups_dir + folders[0] + "/")
		folders.remove_at(0)

func _remove_dir_recursive(path: String) -> void:
	if not path.begins_with(root) or path.length() <= root.length() or path.contains(".."):
		push_error("Refused to remove a folder outside the world: " + path)
		return
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return
	for sub: String in dir.get_directories():
		if dir.is_link(sub):
			continue
		_remove_dir_recursive(path + sub + "/")
	for file_name: String in dir.get_files():
		DirAccess.remove_absolute(path + file_name)
	DirAccess.remove_absolute(path)

func save_connections(connections: Array[Dictionary]) -> bool:
	ensure_directories()
	return _write_text_atomic(connections_path, JSON.stringify(connections, "\t"))

func save_decor(items: Array[Dictionary]) -> bool:
	ensure_directories()
	return _write_text_atomic(decor_path, JSON.stringify(items, "\t"))

func load_decor() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not FileAccess.file_exists(decor_path):
		return result
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(decor_path))
	if parsed is Array:
		for item: Variant in (parsed as Array):
			if item is Dictionary:
				result.append(item as Dictionary)
	return result

func save_canvas_background(background: CanvasBackground) -> bool:
	ensure_directories()
	return _write_text_atomic(canvas_path, JSON.stringify(background.to_dict(), "\t"))

func load_canvas_background() -> CanvasBackground:
	if not FileAccess.file_exists(canvas_path):
		return CanvasBackground.new()
	return CanvasBackground.from_dict(JSON.parse_string(FileAccess.get_file_as_string(canvas_path)))

func trash_decor(item: Dictionary) -> bool:
	if not DirAccess.dir_exists_absolute(trash_decor_dir) and DirAccess.make_dir_recursive_absolute(trash_decor_dir) != OK:
		return false
	var stamp: int = int(Time.get_unix_time_from_system())
	var base: String = str(item.get("id", "decor"))
	var target: String = trash_decor_dir + "%d_%s.json" % [stamp, base]
	var counter: int = 2
	while FileAccess.file_exists(target):
		target = trash_decor_dir + "%d_%d-%s.json" % [stamp, counter, base]
		counter += 1
	return _write_text_atomic(target, JSON.stringify(item, "\t"))

func save_types(types: Array[Dictionary]) -> bool:
	ensure_directories()
	return _write_text_atomic(types_path, JSON.stringify(types, "\t"))

func load_types() -> Dictionary:
	if not FileAccess.file_exists(types_path):
		return {"exists": false, "types": []}

	var file: FileAccess = FileAccess.open(types_path, FileAccess.READ)
	if not file:
		return {"exists": true, "types": []}

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Array:
		return {"exists": true, "types": parsed}
	return {"exists": true, "types": []}

func load_connections() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not FileAccess.file_exists(connections_path):
		return result

	var file: FileAccess = FileAccess.open(connections_path, FileAccess.READ)
	if not file:
		return result

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if parsed is Array:
		for item: Variant in (parsed as Array):
			if item is Dictionary:
				result.append(item as Dictionary)
	return result
