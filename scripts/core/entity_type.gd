class_name EntityType
extends RefCounted

const DEFAULT_COLOR: Color = Color("3498db")
const NAME_KEYS: Array[String] = ["type.character", "type.event", "type.place", "type.faction", "type.item"]

var id: String = ""
var name: String = ""
var name_key: String = ""
var color: Color = DEFAULT_COLOR
var fields: Array[FieldDef] = []
var bg_color: String = ""
var bg_color2: String = ""
var bg_image: String = ""

static func create(type_name: String, type_color: Color) -> EntityType:
	var entity_type: EntityType = EntityType.new()
	entity_type.id = UuidUtil.generate_v4()
	entity_type.name = type_name.strip_edges()
	entity_type.color = type_color
	return entity_type

func display_name() -> String:
	if name_key != "":
		return TranslationServer.translate(name_key)
	return name

func to_dict() -> Dictionary:
	var field_entries: Array[Dictionary] = []
	for field: FieldDef in fields:
		field_entries.append(field.to_dict())
	var result: Dictionary = {
		"id": id,
		"name": name,
		"color": color.to_html(false),
		"fields": field_entries,
		"bg_color": bg_color,
		"bg_color2": bg_color2,
		"bg_image": bg_image,
	}
	if name_key != "":
		result["name_key"] = name_key
	return result

static func from_dict(value: Variant) -> EntityType:
	if not (value is Dictionary):
		return null
	var data: Dictionary = value as Dictionary
	var type_id: String = str(data.get("id", "")).strip_edges()
	if type_id == "":
		return null

	var entity_type: EntityType = EntityType.new()
	entity_type.id = type_id
	entity_type.name = str(data.get("name", "")).strip_edges()
	var raw_key: String = str(data.get("name_key", "")).strip_edges()
	if NAME_KEYS.has(raw_key):
		entity_type.name_key = raw_key

	var color_hex: String = str(data.get("color", "")).strip_edges().trim_prefix("#")
	entity_type.color = Color(color_hex) if Color.html_is_valid(color_hex) else DEFAULT_COLOR

	entity_type.bg_color = NoteBackground.sanitize_hex(data.get("bg_color", ""))
	entity_type.bg_color2 = NoteBackground.sanitize_hex(data.get("bg_color2", ""))
	entity_type.bg_image = str(data.get("bg_image", "")).strip_edges()

	var raw_fields: Variant = data.get("fields", [])
	if raw_fields is Array:
		var seen_keys: Dictionary = {}
		for raw_field: Variant in (raw_fields as Array):
			var field: FieldDef = FieldDef.from_dict(raw_field)
			if field == null or seen_keys.has(field.key):
				continue
			seen_keys[field.key] = true
			entity_type.fields.append(field)
	return entity_type

func active_fields() -> Array[FieldDef]:
	var result: Array[FieldDef] = []
	for field: FieldDef in fields:
		if not field.removed:
			result.append(field)
	return result

func find_field(field_key: String) -> FieldDef:
	for field: FieldDef in fields:
		if field.key == field_key:
			return field
	return null
