class_name NoteImages
extends RefCounted

const MARKDOWN_SOURCE: String = "!\\[([^\\[\\]\\n|]*)(?:\\|(\\d+))?\\]\\(([^()\\s]+)\\)"
const LEGACY_SOURCE: String = "\\[img(?:=(\\d+)(?:x\\d+)?|[ \\t]+([^\\]\\n]*))?\\]([^\\[\\]\\n]+)\\[/img\\]"

static var _token_re: RegEx = null
static var _markdown_re: RegEx = null
static var _legacy_re: RegEx = null
static var _width_attr_re: RegEx = null

static func _ensure_regex() -> void:
	if _token_re != null:
		return
	_token_re = RegEx.create_from_string(MARKDOWN_SOURCE + "|" + LEGACY_SOURCE)
	_markdown_re = RegEx.create_from_string("^" + MARKDOWN_SOURCE + "$")
	_legacy_re = RegEx.create_from_string("^" + LEGACY_SOURCE + "$")
	_width_attr_re = RegEx.create_from_string("width=(\\d+)")

static func token_pattern() -> String:
	return MARKDOWN_SOURCE + "|" + LEGACY_SOURCE

static func parse_token(token: String) -> Dictionary:
	_ensure_regex()
	var markdown: RegExMatch = _markdown_re.search(token)
	if markdown != null:
		return {
			"alt": markdown.get_string(1),
			"width": markdown.get_string(2).to_int(),
			"path": markdown.get_string(3),
			"legacy": false,
		}

	var legacy: RegExMatch = _legacy_re.search(token)
	if legacy != null:
		var width: int = legacy.get_string(1).to_int()
		if width <= 0 and legacy.get_string(2) != "":
			var attribute: RegExMatch = _width_attr_re.search(legacy.get_string(2))
			if attribute != null:
				width = attribute.get_string(1).to_int()
		return {
			"alt": "",
			"width": width,
			"path": legacy.get_string(3).strip_edges(),
			"legacy": true,
		}
	return {}

static func find_inline(content: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not content.contains("![") and not content.contains("[img"):
		return result
	_ensure_regex()
	for found: RegExMatch in _token_re.search_all(content):
		var entry: Dictionary = parse_token(found.get_string())
		if entry.is_empty():
			continue
		entry["start"] = found.get_start()
		entry["end"] = found.get_end()
		result.append(entry)
	return result

static func used_paths(note: Dictionary) -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	var cover: String = str(note.get("image", ""))
	if cover != "":
		paths.append(cover)
	var background: String = str(note.get("bg_image", ""))
	if background != "" and not paths.has(background):
		paths.append(background)
	for entry: Dictionary in find_inline(str(note.get("content", ""))):
		var path: String = str(entry["path"])
		if not paths.has(path):
			paths.append(path)
	return paths

static func to_markdown(alt: String, width: int, path: String) -> String:
	var clean_alt: String = alt.replace("[", "").replace("]", "").replace("|", "").replace("\n", " ").strip_edges()
	var size_part: String = "|%d" % width if width > 0 else ""
	return "![%s%s](%s)" % [clean_alt, size_part, path]

static func rewrite_inline(content: String, mapper: Callable) -> String:
	var entries: Array[Dictionary] = find_inline(content)
	if entries.is_empty():
		return content

	var result: String = ""
	var cursor: int = 0
	for entry: Dictionary in entries:
		var start: int = int(entry["start"])
		var end: int = int(entry["end"])
		result += content.substr(cursor, start - cursor)
		var new_path: String = str(mapper.call(str(entry["path"])))
		if new_path == "":
			result += content.substr(start, end - start)
		else:
			result += to_markdown(str(entry["alt"]), int(entry["width"]), new_path)
		cursor = end
	return result + content.substr(cursor)

static func localize_inline(content: String, assets: Dictionary, storage: VaultStorage, stored: Dictionary) -> String:
	return rewrite_inline(content, func(path: String) -> String:
		if not path.begins_with(ProjectBundle.ASSETS_DIR):
			return ""
		var asset_name: String = path.trim_prefix(ProjectBundle.ASSETS_DIR)
		if not stored.has(asset_name):
			stored[asset_name] = ""
			if assets.has(asset_name):
				stored[asset_name] = storage.store_image_bytes(asset_name, assets[asset_name] as PackedByteArray)
		return str(stored[asset_name])
	)

static func localize_asset(asset_name: String, assets: Dictionary, storage: VaultStorage, stored: Dictionary) -> String:
	if asset_name == "" or not assets.has(asset_name):
		return ""
	if not stored.has(asset_name):
		stored[asset_name] = storage.store_image_bytes(asset_name, assets[asset_name] as PackedByteArray)
	return str(stored[asset_name])

static func type_paths(types: Array[Dictionary]) -> PackedStringArray:
	var paths: PackedStringArray = PackedStringArray()
	for entity_type: Dictionary in types:
		var path: String = str(entity_type.get("bg_image", ""))
		if path != "" and not paths.has(path):
			paths.append(path)
	return paths

static func failed_count(stored: Dictionary, refused: Dictionary = {}) -> int:
	var failed: int = 0
	for asset_name: String in stored:
		if str(stored[asset_name]) == "" and not refused.has(asset_name):
			failed += 1
	return failed

static func is_vault_image(path: String) -> bool:
	if not path.begins_with(VaultStorage.IMAGE_REF_PREFIX):
		return false
	var file_name: String = path.substr(VaultStorage.IMAGE_REF_PREFIX.length())
	if file_name == "" or file_name != file_name.get_file() or file_name.begins_with("."):
		return false
	if file_name.contains("\\") or file_name.contains(".."):
		return false
	if file_name.contains("[") or file_name.contains("]"):
		return false
	return ProjectBundle.IMAGE_EXTENSIONS.has(file_name.get_extension().to_lower())
