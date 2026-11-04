class_name AppSettings
extends RefCounted

const SETTINGS_PATH: String = "user://settings.cfg"
const TEMP_SUFFIX: String = ".tmp"

static var _config: ConfigFile = null

static func get_value(section: String, key: String, default_value: Variant) -> Variant:
	_ensure_loaded()
	return _config.get_value(section, key, default_value)

static func has_value(section: String, key: String) -> bool:
	_ensure_loaded()
	return _config.has_section_key(section, key)

static func set_value(section: String, key: String, value: Variant) -> void:
	_ensure_loaded()
	if _config.has_section_key(section, key) and _config.get_value(section, key) == value:
		return
	_config.set_value(section, key, value)
	_save()

static func set_values(section: String, values: Dictionary) -> void:
	_ensure_loaded()
	var changed: bool = false
	for key: String in values:
		if _config.has_section_key(section, key) and _config.get_value(section, key) == values[key]:
			continue
		_config.set_value(section, key, values[key])
		changed = true
	if changed:
		_save()

static func _ensure_loaded() -> void:
	if _config != null:
		return
	_config = ConfigFile.new()
	if not FileAccess.file_exists(SETTINGS_PATH) and FileAccess.file_exists(SETTINGS_PATH + TEMP_SUFFIX):
		_config.load(SETTINGS_PATH + TEMP_SUFFIX)
		return
	_config.load(SETTINGS_PATH)

static func _save() -> void:
	var temp_path: String = SETTINGS_PATH + TEMP_SUFFIX
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write file: " + temp_path)
		return
	var written: bool = file.store_string(_config.encode_to_text())
	file.close()
	if not written:
		push_error("Failed to write file: " + temp_path)
		return
	if DirAccess.rename_absolute(temp_path, SETTINGS_PATH) != OK:
		push_error("Failed to replace file: " + SETTINGS_PATH)
