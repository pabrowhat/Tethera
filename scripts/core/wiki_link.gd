class_name WikiLink
extends RefCounted

const SEPARATOR: String = "|"
const ESCAPE: String = "\\"

static var _link_re: RegEx = null

static func separator_index(inner: String) -> int:
	var i: int = 0
	while i < inner.length():
		var c: String = inner[i]
		if c == ESCAPE and i + 1 < inner.length() and _is_escapable(inner[i + 1]):
			i += 2
			continue
		if c == SEPARATOR:
			return i
		i += 1
	return -1

static func split(inner: String) -> Dictionary:
	var at: int = separator_index(inner)
	if at < 0:
		return {"title": unescape(inner), "alias": "", "has_alias": false, "alias_raw": ""}
	var raw_alias: String = inner.substr(at + 1)
	return {"title": unescape(inner.substr(0, at)), "alias": unescape(raw_alias), "has_alias": true, "alias_raw": raw_alias}

static func is_note_link(inner: String) -> bool:
	return String(split(inner)["title"]).strip_edges() != ""

static func display_text(inner: String) -> String:
	var link: Dictionary = split(inner)
	var alias: String = link["alias"]
	return alias if alias.strip_edges() != "" else str(link["title"])

static func unescape(text: String) -> String:
	var result: String = ""
	var i: int = 0
	while i < text.length():
		if text[i] == ESCAPE and i + 1 < text.length() and _is_escapable(text[i + 1]):
			result += text[i + 1]
			i += 2
		else:
			result += text[i]
			i += 1
	return result

static func escape(text: String) -> String:
	return text.replace(ESCAPE, ESCAPE + ESCAPE).replace(SEPARATOR, ESCAPE + SEPARATOR)

static func replace_title(text: String, old_title: String, new_title: String) -> String:
	_ensure_regex()
	var wanted: String = old_title.strip_edges().to_lower()
	var result: String = ""
	var cursor: int = 0
	for found: RegExMatch in _link_re.search_all(text):
		var link: Dictionary = split(found.get_string(1))
		if str(link["title"]).strip_edges().to_lower() != wanted:
			continue
		result += text.substr(cursor, found.get_start() - cursor)
		result += "[[" + escape(new_title)
		if bool(link["has_alias"]):
			result += SEPARATOR + str(link["alias_raw"])
		result += "]]"
		cursor = found.get_end()
	return result + text.substr(cursor)

static func titles_in(text: String) -> Array[String]:
	_ensure_regex()
	var titles: Array[String] = []
	for found: RegExMatch in _link_re.search_all(text):
		var inner: String = found.get_string(1)
		if not is_note_link(inner):
			continue
		titles.append(str(split(inner)["title"]))
	return titles

static func unlink_title(text: String, title: String) -> String:
	_ensure_regex()
	var wanted: String = title.strip_edges().to_lower()
	var result: String = ""
	var cursor: int = 0
	for found: RegExMatch in _link_re.search_all(text):
		var inner: String = found.get_string(1)
		if not is_note_link(inner):
			continue
		if str(split(inner)["title"]).strip_edges().to_lower() != wanted:
			continue
		result += text.substr(cursor, found.get_start() - cursor)
		result += display_text(inner)
		cursor = found.get_end()
	return result + text.substr(cursor)

static func _ensure_regex() -> void:
	if _link_re == null:
		_link_re = RegEx.create_from_string("\\[\\[([^\\[\\]\\n]+)\\]\\]")

static func _is_escapable(c: String) -> bool:
	return c == SEPARATOR or c == ESCAPE
