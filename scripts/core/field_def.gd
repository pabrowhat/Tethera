class_name FieldDef
extends RefCounted

enum Kind { TEXT, NUMBER, DATE, LIST }

const KIND_NAMES: Array[String] = ["text", "number", "date", "list"]

var key: String = ""
var label: String = ""
var kind: Kind = Kind.TEXT
var removed: bool = false

static func create(field_label: String, field_kind: Kind) -> FieldDef:
	var field: FieldDef = FieldDef.new()
	field.key = UuidUtil.generate_v4()
	field.label = field_label.strip_edges()
	field.kind = field_kind
	return field

static func kind_to_string(value: Kind) -> String:
	return KIND_NAMES[int(value)]

static func kind_from_string(name: String) -> int:
	return KIND_NAMES.find(name)

func to_dict() -> Dictionary:
	return {
		"key": key,
		"label": label,
		"kind": kind_to_string(kind),
		"removed": removed,
	}

static func from_dict(value: Variant) -> FieldDef:
	if not (value is Dictionary):
		return null
	var data: Dictionary = value as Dictionary
	var field_key: String = str(data.get("key", "")).strip_edges()
	var kind_index: int = kind_from_string(str(data.get("kind", "")))
	if field_key == "" or kind_index < 0:
		return null

	var field: FieldDef = FieldDef.new()
	field.key = field_key
	field.label = str(data.get("label", "")).strip_edges()
	field.kind = kind_index as Kind
	field.removed = bool(data.get("removed", false))
	return field

static func is_valid_date(text: String) -> bool:
	var parts: PackedStringArray = text.split("-")
	if parts.size() != 3:
		return false
	if parts[0].length() != 4 or parts[1].length() != 2 or parts[2].length() != 2:
		return false
	for part: String in parts:
		if not part.is_valid_int():
			return false

	var year: int = parts[0].to_int()
	var month: int = parts[1].to_int()
	var day: int = parts[2].to_int()
	if month < 1 or month > 12 or day < 1:
		return false
	return day <= _days_in_month(year, month)

static func _days_in_month(year: int, month: int) -> int:
	match month:
		2:
			var leap: bool = (year % 4 == 0 and year % 100 != 0) or year % 400 == 0
			return 29 if leap else 28
		4, 6, 9, 11:
			return 30
	return 31

static func sanitize_values(value: Variant) -> Dictionary:
	var result: Dictionary = {}
	if not (value is Dictionary):
		return result
	var source: Dictionary = value as Dictionary
	for raw_key: Variant in source:
		var field_key: String = str(raw_key)
		var item: Variant = source[raw_key]
		if item is String:
			result[field_key] = item
		elif item is int or item is float:
			var number: float = float(item)
			if is_finite(number):
				result[field_key] = number
		elif item is Array:
			var items: Array[String] = []
			for entry: Variant in (item as Array):
				if entry is String:
					items.append(entry)
			result[field_key] = items
	return result
