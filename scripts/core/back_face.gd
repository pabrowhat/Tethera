class_name BackFace
extends RefCounted

const MAX_VALUE_CHARS: int = 40
const MAX_FIELD_ROWS: int = 6

static var _tag_re: RegEx = null
static var _wiki_re: RegEx = null
static var _lead_re: RegEx = null
static var _symbols_re: RegEx = null
static var _word_re: RegEx = null

static func outgoing_ids(content: String, ids_by_title: Dictionary, own_id: String) -> Array[String]:
	var ids: Array[String] = []
	for title: String in WikiLink.titles_in(content):
		var target: String = str(ids_by_title.get(LinkReconciler.title_key(title), ""))
		if target != "" and target != own_id and not ids.has(target):
			ids.append(target)
	return ids

static func type_block(entity_type: EntityType, values: Dictionary) -> Dictionary:
	if entity_type == null:
		return {}
	var rows: Array[Dictionary] = []
	for field: FieldDef in entity_type.fields:
		if field.removed:
			continue
		var shown: String = format_value(values.get(field.key, null))
		if shown != "":
			rows.append({"label": field.label, "value": shown})
	var more: int = maxi(rows.size() - MAX_FIELD_ROWS, 0)
	return {"name": entity_type.display_name(), "color": entity_type.color, "fields": rows.slice(0, MAX_FIELD_ROWS), "more": more}

static func format_value(value: Variant) -> String:
	var text: String = ""
	if value is String:
		text = (value as String).strip_edges()
	elif value is int or value is float:
		var number: float = float(value)
		text = str(int(number)) if is_equal_approx(number, roundf(number)) else String.num(number)
	elif value is Array:
		var parts: PackedStringArray = PackedStringArray()
		for entry: Variant in value as Array:
			if str(entry).strip_edges() != "":
				parts.append(str(entry).strip_edges())
		text = ", ".join(parts)
	text = text.replace("\n", " ")
	if text.length() > MAX_VALUE_CHARS:
		return text.substr(0, MAX_VALUE_CHARS - 1).rstrip(" ") + "…"
	return text

static func word_count(content: String) -> int:
	_ensure_regex()
	var plain: String = content
	var pictures: Array[Dictionary] = NoteImages.find_inline(content)
	for index: int in range(pictures.size() - 1, -1, -1):
		var start: int = int(pictures[index]["start"])
		plain = plain.substr(0, start) + " " + plain.substr(int(pictures[index]["end"]))
	plain = _wiki_re.sub(plain, "$1", true)
	plain = _tag_re.sub(plain, " ", true)
	var lines: PackedStringArray = plain.split("\n")
	for index: int in lines.size():
		lines[index] = _lead_re.sub(lines[index], "")
	plain = _symbols_re.sub("\n".join(lines), " ", true)
	var count: int = 0
	for word: String in plain.split(" ", false):
		if _word_re.search(word) != null:
			count += 1
	return count

static func _ensure_regex() -> void:
	if _tag_re != null:
		return
	_tag_re = RegEx.create_from_string("\\[/?[A-Za-z_][A-Za-z0-9_]*(?:[= ][^\\[\\]\\n]*)?\\]")
	_wiki_re = RegEx.create_from_string("\\[\\[([^\\[\\]|\\n]*)(?:\\|[^\\[\\]\\n]*)?\\]\\]")
	_lead_re = RegEx.create_from_string("^[ \\t]*(?:#{1,6}|[-*+](?:[ \\t]+\\[[ xX]\\])?|[0-9]+\\.|>)[ \\t]+")
	_symbols_re = RegEx.create_from_string("[*_~`|#>\\[\\]()\\s]+")
	_word_re = RegEx.create_from_string("[\\p{L}\\p{N}]")
