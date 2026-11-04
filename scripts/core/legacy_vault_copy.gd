class_name LegacyVaultCopy
extends RefCounted

const SOURCE_DIR: String = "user://vault/"
const FOLDERS: Array[String] = [VaultStorage.NOTES_FOLDER, VaultStorage.IMAGES_FOLDER]
const FILES: Array[String] = [VaultStorage.TYPES_FILE, VaultStorage.CONNECTIONS_FILE, VaultStorage.DECOR_FILE, VaultStorage.CANVAS_FILE]

const REASON_COPY_FAILED: String = "vault.error.copy_failed"

static func has_data(source: String = SOURCE_DIR) -> bool:
	for folder: String in FOLDERS:
		if not _files_in(source + folder).is_empty():
			return true
	for file_name: String in FILES:
		if FileAccess.file_exists(source + file_name):
			return true
	return false

static func copy_into(world_root: String, source: String = SOURCE_DIR) -> Dictionary:
	var copied: int = 0
	for folder: String in FOLDERS:
		var names: PackedStringArray = _files_in(source + folder)
		if names.is_empty():
			continue
		if not DirAccess.dir_exists_absolute(world_root + folder) and DirAccess.make_dir_recursive_absolute(world_root + folder) != OK:
			return _failed(copied, folder)
		for file_name: String in names:
			if not _copy_checked(source + folder + file_name, world_root + folder + file_name):
				return _failed(copied, folder + file_name)
			copied += 1
	for file_name: String in FILES:
		if not FileAccess.file_exists(source + file_name):
			continue
		if not _copy_checked(source + file_name, world_root + file_name):
			return _failed(copied, file_name)
		copied += 1
	return {"ok": true, "copied": copied, "reason": "", "file": ""}

static func _files_in(dir_path: String) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return names
	for file_name: String in dir.get_files():
		if not dir.is_link(file_name):
			names.append(file_name)
	return names

static func _copy_checked(from: String, to: String) -> bool:
	if FileAccess.file_exists(to) or DirAccess.dir_exists_absolute(to):
		return false
	var expected: int = _length(from)
	if expected < 0 or DirAccess.copy_absolute(from, to) != OK:
		return false
	return _length(to) == expected

static func _length(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return -1
	var length: int = file.get_length()
	file.close()
	return length

static func _failed(copied: int, file_name: String) -> Dictionary:
	push_error("Copy of the old vault stopped at " + file_name)
	return {"ok": false, "copied": copied, "reason": REASON_COPY_FAILED, "file": file_name}
