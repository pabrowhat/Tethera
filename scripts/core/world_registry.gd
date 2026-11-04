class_name WorldRegistry
extends RefCounted

enum VaultState { NOT_SET, MISSING, READY }

const SETTINGS_SECTION: String = "worlds"
const KEY_VAULT_DIR: String = "vault_dir"
const KEY_LAST_WORLD: String = "last_world"

const WORLD_FILE: String = "world.json"
const FORMAT: int = 1
const MAX_WORLD_FILE_BYTES: int = 64 * 1024
const MAX_NAME_LENGTH: int = 200
const MAX_NEW_NAME_LENGTH: int = 80
const WORLD_FOLDERS: Array[String] = [VaultStorage.NOTES_FOLDER, VaultStorage.IMAGES_FOLDER, VaultStorage.TRASH_FOLDER, VaultStorage.BACKUPS_FOLDER]
const WORLD_TRASH_FOLDER: String = "trash-worlds/"

const REASON_NAME_EMPTY: String = "worlds.name.empty"
const REASON_NAME_TOO_LONG: String = "worlds.name.too_long"
const REASON_NAME_LINE_BREAK: String = "worlds.name.line_break"
const REASON_RENAME_FAILED: String = "worlds.rename.failed"
const REASON_DELETE_LAST: String = "worlds.delete.last"
const REASON_DELETE_DAMAGED: String = "worlds.delete.damaged"
const REASON_DELETE_FAILED: String = "worlds.delete.failed"
const REASON_DELETE_DAMAGED_FAILED: String = "worlds.delete.damaged_failed"

const REASON_NOT_ABSOLUTE: String = "vault.error.not_absolute"
const REASON_PARENT_REF: String = "vault.error.parent_ref"
const REASON_NOT_DIR: String = "vault.error.not_dir"
const REASON_LEGACY_FOLDER: String = "vault.error.legacy_folder"
const REASON_WORLD_FOLDER: String = "vault.error.world_folder"
const REASON_CREATE_FAILED: String = "vault.error.create_failed"
const VAULT_MISSING: String = "missing"

const WORLD_ID_PATTERN: String = "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"

static var _id_re: RegEx = null

var vault_dir: String = ""

func _init() -> void:
	var saved: String = saved_vault_dir()
	if saved != "":
		var checked: Dictionary = check_vault_dir(saved)
		if bool(checked["ok"]):
			vault_dir = str(checked["path"])


static func is_safe_world_id(id: String) -> bool:
	if _id_re == null:
		_id_re = RegEx.create_from_string(WORLD_ID_PATTERN)
	return ProjectBundle.is_safe_id(id) and _id_re.search(id) != null

static func _check_shape(path: String) -> Dictionary:
	var clean: String = path.strip_edges().replace("\\", "/")
	if clean == "" or clean.begins_with("res://") or clean.begins_with("user://") or not clean.is_absolute_path():
		return {"ok": false, "path": "", "reason": REASON_NOT_ABSOLUTE}
	for part: String in clean.split("/"):
		if part == "." or part == "..":
			return {"ok": false, "path": "", "reason": REASON_PARENT_REF}
	if not clean.ends_with("/"):
		clean += "/"
	return {"ok": true, "path": clean, "reason": ""}

static func check_vault_dir(path: String) -> Dictionary:
	var shape: Dictionary = _check_shape(path)
	if not bool(shape["ok"]):
		return shape
	var clean: String = str(shape["path"])
	if not DirAccess.dir_exists_absolute(clean):
		return {"ok": false, "path": "", "reason": REASON_NOT_DIR}
	var legacy: String = ProjectSettings.globalize_path(LegacyVaultCopy.SOURCE_DIR).replace("\\", "/")
	if clean.to_lower().begins_with(legacy.to_lower()):
		return {"ok": false, "path": "", "reason": REASON_LEGACY_FOLDER}
	if _inside_world(clean):
		return {"ok": false, "path": "", "reason": REASON_WORLD_FOLDER}
	return {"ok": true, "path": clean, "reason": ""}

static func _inside_world(path: String) -> bool:
	var current: String = path.trim_suffix("/")
	while current != "":
		if FileAccess.file_exists(current + "/" + WORLD_FILE):
			return true
		var parent: String = current.get_base_dir()
		if parent == current or parent == "" or parent.ends_with(":") or parent == "/":
			break
		current = parent
	return false

static func vault_dir_status(path: String) -> String:
	var shape: Dictionary = _check_shape(path)
	if not bool(shape["ok"]):
		return str(shape["reason"])
	var clean: String = str(shape["path"])
	if not DirAccess.dir_exists_absolute(clean):
		if FileAccess.file_exists(clean.trim_suffix("/")):
			return REASON_NOT_DIR
		return REASON_WORLD_FOLDER if _inside_world(clean) else VAULT_MISSING
	return str(check_vault_dir(clean)["reason"])

static func create_vault_dir(path: String) -> String:
	var shape: Dictionary = _check_shape(path)
	if not bool(shape["ok"]):
		return str(shape["reason"])
	var clean: String = str(shape["path"])
	if not DirAccess.dir_exists_absolute(clean) and DirAccess.make_dir_recursive_absolute(clean) != OK:
		return REASON_CREATE_FAILED
	return str(check_vault_dir(clean)["reason"])


static func saved_vault_dir() -> String:
	return str(AppSettings.get_value(SETTINGS_SECTION, KEY_VAULT_DIR, ""))

func vault_state() -> VaultState:
	if saved_vault_dir() == "":
		return VaultState.NOT_SET
	return VaultState.READY if vault_dir != "" else VaultState.MISSING

func select_vault_dir(path: String) -> bool:
	var checked: Dictionary = check_vault_dir(path)
	if not bool(checked["ok"]):
		return false
	vault_dir = str(checked["path"])
	return true

func remember_vault_dir() -> void:
	if vault_dir != "":
		AppSettings.set_value(SETTINGS_SECTION, KEY_VAULT_DIR, vault_dir)

func create_saved_vault_dir() -> String:
	var reason: String = create_vault_dir(saved_vault_dir())
	if reason != "":
		return reason
	vault_dir = str(check_vault_dir(saved_vault_dir())["path"])
	return ""

func last_world_id() -> String:
	return str(AppSettings.get_value(SETTINGS_SECTION, KEY_LAST_WORLD, ""))

func remember_last(id: String) -> void:
	if is_safe_world_id(id):
		AppSettings.set_value(SETTINGS_SECTION, KEY_LAST_WORLD, id)


func list_worlds(with_stats: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if vault_dir == "":
		return result
	var dir: DirAccess = DirAccess.open(vault_dir)
	if dir == null:
		return result
	for folder: String in dir.get_directories():
		if not is_safe_world_id(folder) or dir.is_link(folder):
			continue
		var root: String = vault_dir + folder + "/"
		var info: Dictionary = read_world_file(root)
		var row: Dictionary = {"id": folder, "name": str(info["name"]), "root": root, "ok": bool(info["ok"])}
		if with_stats:
			row.merge(world_stats(root))
		result.append(row)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var name_a: String = str(a["name"]).to_lower()
		var name_b: String = str(b["name"]).to_lower()
		return name_a < name_b if name_a != name_b else str(a["id"]) < str(b["id"]))
	return result

func world_root(id: String) -> String:
	if vault_dir == "" or not is_safe_world_id(id):
		return ""
	var dir: DirAccess = DirAccess.open(vault_dir)
	if dir == null or not dir.dir_exists(id) or dir.is_link(id):
		return ""
	var root: String = vault_dir + id + "/"
	return root if bool(read_world_file(root)["ok"]) else ""

static func read_world_file(root: String) -> Dictionary:
	var path: String = root + WORLD_FILE
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false, "name": ""}
	if file.get_length() > MAX_WORLD_FILE_BYTES:
		file.close()
		return {"ok": false, "name": ""}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return {"ok": false, "name": ""}
	var data: Dictionary = parsed as Dictionary
	var name_value: Variant = data.get("name", null)
	var format_value: Variant = data.get("format", null)
	if not (name_value is String) or str(name_value).strip_edges() == "":
		return {"ok": false, "name": ""}
	if not (format_value is int or format_value is float) or float(format_value) != float(FORMAT):
		return {"ok": false, "name": str(name_value).strip_edges().left(MAX_NAME_LENGTH)}
	return {"ok": true, "name": str(name_value).strip_edges().left(MAX_NAME_LENGTH)}

static func check_name(world_name: String) -> String:
	if world_name.contains("\n") or world_name.contains("\r"):
		return REASON_NAME_LINE_BREAK
	var clean: String = world_name.strip_edges()
	if clean == "":
		return REASON_NAME_EMPTY
	if clean.length() > MAX_NEW_NAME_LENGTH:
		return REASON_NAME_TOO_LONG
	return ""

func create_world(world_name: String, with_files: bool = true) -> Dictionary:
	var name_problem: String = check_name(world_name)
	if name_problem != "":
		return {"ok": false, "id": "", "root": "", "reason": name_problem}
	if vault_dir == "":
		return {"ok": false, "id": "", "root": "", "reason": REASON_CREATE_FAILED}
	var id: String = ""
	for _attempt: int in 8:
		var candidate: String = UuidUtil.generate_v4()
		if not DirAccess.dir_exists_absolute(vault_dir + candidate):
			id = candidate
			break
	if id == "":
		return {"ok": false, "id": "", "root": "", "reason": REASON_CREATE_FAILED}
	var root: String = vault_dir + id + "/"
	var made: bool = true
	for folder: String in WORLD_FOLDERS:
		made = made and DirAccess.make_dir_recursive_absolute(root + folder) == OK
	made = made and write_world_file(root, world_name)
	if made and with_files:
		var storage: VaultStorage = VaultStorage.new(root)
		var defaults: EntityTypeRegistry = EntityTypeRegistry.new()
		defaults.seed_defaults()
		var no_links: Array[Dictionary] = []
		made = storage.save_connections(no_links) and storage.save_types(defaults.to_array())
	if not made:
		remove_unfinished_world(id)
		return {"ok": false, "id": "", "root": "", "reason": REASON_CREATE_FAILED}
	return {"ok": true, "id": id, "root": root, "reason": ""}

func rename_world(id: String, world_name: String) -> String:
	var name_problem: String = check_name(world_name)
	if name_problem != "":
		return name_problem
	var root: String = world_root(id)
	if root == "":
		return REASON_RENAME_FAILED
	return "" if write_world_file(root, world_name) else REASON_RENAME_FAILED

static func world_stats(root: String) -> Dictionary:
	var notes: int = 0
	var modified: int = 0
	var notes_dir: String = root + VaultStorage.NOTES_FOLDER
	var names: PackedStringArray = DirAccess.get_files_at(notes_dir) if DirAccess.dir_exists_absolute(notes_dir) else PackedStringArray()
	for file_name: String in names:
		if file_name.ends_with(".md"):
			notes += 1
			modified = maxi(modified, int(FileAccess.get_modified_time(notes_dir + file_name)))
	for file_name: String in [WORLD_FILE, VaultStorage.CONNECTIONS_FILE, VaultStorage.TYPES_FILE, VaultStorage.DECOR_FILE, VaultStorage.CANVAS_FILE]:
		if FileAccess.file_exists(root + file_name):
			modified = maxi(modified, int(FileAccess.get_modified_time(root + file_name)))
	return {"notes": notes, "modified": modified}

static func write_world_file(root: String, world_name: String) -> bool:
	var clean_name: String = world_name.strip_edges().left(MAX_NAME_LENGTH)
	if clean_name == "":
		return false
	var path: String = root + WORLD_FILE
	var temp_path: String = path + VaultStorage.TEMP_SUFFIX
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return false
	var written: bool = file.store_string(JSON.stringify({"name": clean_name, "format": FORMAT}, "\t"))
	file.close()
	if not written:
		return false
	return DirAccess.rename_absolute(temp_path, path) == OK


func world_trash_dir() -> String:
	return vault_dir + WORLD_TRASH_FOLDER if vault_dir != "" else ""

func trash_world(id: String, now: int) -> String:
	if vault_dir == "" or not is_safe_world_id(id):
		return REASON_DELETE_FAILED
	var parent: DirAccess = DirAccess.open(vault_dir)
	if parent == null or not parent.dir_exists(id) or parent.is_link(id):
		return REASON_DELETE_FAILED
	if world_root(id) == "":
		return REASON_DELETE_DAMAGED
	var usable: int = 0
	for world: Dictionary in list_worlds():
		if bool(world["ok"]):
			usable += 1
	if usable <= 1:
		return REASON_DELETE_LAST
	var trash_name: String = WORLD_TRASH_FOLDER.trim_suffix("/")
	if parent.dir_exists(trash_name) and parent.is_link(trash_name):
		return REASON_DELETE_FAILED
	var trash: String = world_trash_dir()
	if not DirAccess.dir_exists_absolute(trash) and DirAccess.make_dir_recursive_absolute(trash) != OK:
		return REASON_DELETE_FAILED
	var source: String = vault_dir + id
	var target: String = trash + "%d_%s" % [now, id]
	if not _inside(source, vault_dir) or not _inside(target, trash) or DirAccess.dir_exists_absolute(target) or FileAccess.file_exists(target):
		return REASON_DELETE_FAILED
	if DirAccess.rename_absolute(source, target) != OK:
		return REASON_DELETE_FAILED
	return ""

func delete_damaged_world(id: String) -> String:
	if vault_dir == "" or not is_safe_world_id(id):
		return REASON_DELETE_DAMAGED_FAILED
	var parent: DirAccess = DirAccess.open(vault_dir)
	if parent == null or not parent.dir_exists(id) or parent.is_link(id):
		return REASON_DELETE_DAMAGED_FAILED
	var root: String = vault_dir + id + "/"
	if bool(read_world_file(root)["ok"]):
		return REASON_DELETE_DAMAGED_FAILED
	_remove_tree(root, vault_dir)
	return "" if not DirAccess.dir_exists_absolute(root) else REASON_DELETE_DAMAGED_FAILED

func purge_world_trash(now: int) -> int:
	var trash: String = world_trash_dir()
	if trash == "":
		return 0
	var dir: DirAccess = DirAccess.open(trash)
	if dir == null:
		return 0
	var limit: int = now - VaultStorage.TRASH_DAYS * VaultStorage.SECONDS_PER_DAY
	var removed: int = 0
	for folder: String in dir.get_directories():
		var stamp: String = folder.get_slice("_", 0)
		var id: String = folder.substr(stamp.length() + 1)
		if not stamp.is_valid_int() or not is_safe_world_id(id) or dir.is_link(folder):
			continue
		if stamp.to_int() >= limit:
			continue
		var path: String = trash + folder + "/"
		_remove_tree(path, trash)
		if not DirAccess.dir_exists_absolute(path):
			removed += 1
	return removed

static func _inside(path: String, folder: String) -> bool:
	if folder == "" or not path.begins_with(folder) or path.length() <= folder.length():
		return false
	for part: String in path.substr(folder.length()).split("/"):
		if part == "." or part == "..":
			return false
	return true

func remove_unfinished_world(id: String) -> bool:
	if vault_dir == "" or not is_safe_world_id(id):
		return false
	var parent: DirAccess = DirAccess.open(vault_dir)
	if parent == null or not parent.dir_exists(id) or parent.is_link(id):
		return false
	var root: String = vault_dir + id + "/"
	_remove_tree(root, vault_dir)
	return not DirAccess.dir_exists_absolute(root)

static func _remove_tree(path: String, inside: String) -> void:
	if not _inside(path, inside):
		push_error("Refused to remove a folder outside %s: %s" % [inside, path])
		return
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.include_hidden = true
	for sub: String in dir.get_directories():
		if not dir.is_link(sub):
			_remove_tree(path + sub + "/", inside)
	for file_name: String in dir.get_files():
		DirAccess.remove_absolute(path + file_name)
	DirAccess.remove_absolute(path)
