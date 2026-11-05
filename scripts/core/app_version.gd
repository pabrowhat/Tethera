class_name AppVersion
extends RefCounted

const SETTINGS_SECTION: String = "app"
const KEY_LAST_SEEN: String = "last_seen_version"
const WHATS_NEW_DIR: String = "res://whats_new/"
const VERSION_PATTERN: String = "^\\d+\\.\\d+\\.\\d+$"
const KEY_PATTERN: String = "^[a-z0-9_.]+$"

static func current() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))

static func is_valid_version(version: String) -> bool:
	return RegEx.create_from_string(VERSION_PATTERN).search(version) != null

static func whats_new_path(version: String) -> String:
	if not is_valid_version(version):
		return ""
	return WHATS_NEW_DIR + version + ".md"

static func all_versions() -> PackedStringArray:
	var versions: Array[String] = []
	var dir: DirAccess = DirAccess.open(WHATS_NEW_DIR)
	if dir == null:
		return PackedStringArray()
	for file_name: String in dir.get_files():
		var version: String = file_name.trim_suffix(".remap").get_basename()
		if file_name.get_extension() == "md" and is_valid_version(version) and not versions.has(version):
			versions.append(version)
	versions.sort_custom(func(a: String, b: String) -> bool: return compare_versions(a, b) > 0)
	return PackedStringArray(versions)

static func compare_versions(a: String, b: String) -> int:
	var pa: PackedStringArray = a.split(".")
	var pb: PackedStringArray = b.split(".")
	for i: int in range(mini(pa.size(), pb.size())):
		var diff: int = pa[i].to_int() - pb[i].to_int()
		if diff != 0:
			return diff
	return pa.size() - pb.size()

static func whats_new_keys(version: String) -> PackedStringArray:
	var keys: PackedStringArray = PackedStringArray()
	var path: String = whats_new_path(version)
	if path == "" or not FileAccess.file_exists(path):
		return keys
	var key_re: RegEx = RegEx.create_from_string(KEY_PATTERN)
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var trimmed: String = line.strip_edges()
		if not trimmed.begins_with("- "):
			continue
		var key: String = trimmed.substr(2).strip_edges()
		if key_re.search(key) != null:
			keys.append(key)
	return keys

static func notes_pending() -> bool:
	var version: String = current()
	if version == "":
		return false
	if not AppSettings.has_value(SETTINGS_SECTION, KEY_LAST_SEEN):
		AppSettings.set_value(SETTINGS_SECTION, KEY_LAST_SEEN, version)
		return false
	return str(AppSettings.get_value(SETTINGS_SECTION, KEY_LAST_SEEN, "")) != version

static func mark_seen() -> void:
	AppSettings.set_value(SETTINGS_SECTION, KEY_LAST_SEEN, current())
