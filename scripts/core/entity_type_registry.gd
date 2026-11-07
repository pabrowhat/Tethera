class_name EntityTypeRegistry
extends RefCounted

signal changed

const DEFAULT_TYPES_PATH: String = "res://data/default_types.json"
const NEW_TYPE_COLORS: Array[Color] = [
	Color("3498db"), Color("2ecc71"), Color("f1c40f"), Color("e74c3c"),
	Color("9b59b6"), Color("1abc9c"), Color("e67e22"), Color("e84393"),
]

var _types: Array[EntityType] = []

func get_all() -> Array[EntityType]:
	var result: Array[EntityType] = []
	result.assign(_types)
	return result

func count() -> int:
	return _types.size()

func find(type_id: String) -> EntityType:
	if type_id == "":
		return null
	for entity_type: EntityType in _types:
		if entity_type.id == type_id:
			return entity_type
	return null

func find_by_name(type_name: String) -> EntityType:
	var wanted: String = type_name.strip_edges().to_lower()
	if wanted == "":
		return null
	for entity_type: EntityType in _types:
		if entity_type.display_name().to_lower() == wanted:
			return entity_type
	return null

func add_type(entity_type: EntityType) -> bool:
	if entity_type == null or entity_type.id == "" or find(entity_type.id) != null:
		return false
	_types.append(entity_type)
	changed.emit()
	return true

func has_name(type_name: String, except_id: String = "") -> bool:
	var wanted: String = type_name.strip_edges().to_lower()
	for entity_type: EntityType in _types:
		if entity_type.id != except_id and entity_type.display_name().to_lower() == wanted:
			return true
	return false

func suggest_color() -> Color:
	return NEW_TYPE_COLORS[_types.size() % NEW_TYPE_COLORS.size()]

func create(type_name: String, type_color: Color) -> EntityType:
	if type_name.strip_edges() == "":
		return null
	var entity_type: EntityType = EntityType.create(type_name, type_color)
	_types.append(entity_type)
	changed.emit()
	return entity_type

func rename(type_id: String, type_name: String) -> bool:
	var entity_type: EntityType = find(type_id)
	var clean: String = type_name.strip_edges()
	if entity_type == null or clean == "" or entity_type.display_name() == clean:
		return false
	entity_type.name = clean
	entity_type.name_key = ""
	changed.emit()
	return true

func set_color(type_id: String, type_color: Color) -> bool:
	var entity_type: EntityType = find(type_id)
	if entity_type == null or entity_type.color.is_equal_approx(type_color):
		return false
	entity_type.color = type_color
	changed.emit()
	return true

func set_background(type_id: String, color_hex: String, color2_hex: String, image: String) -> bool:
	var entity_type: EntityType = find(type_id)
	if entity_type == null:
		return false
	var clean_hex: String = NoteBackground.sanitize_hex(color_hex)
	var clean_hex2: String = NoteBackground.sanitize_hex(color2_hex)
	if entity_type.bg_color == clean_hex and entity_type.bg_color2 == clean_hex2 and entity_type.bg_image == image:
		return false
	entity_type.bg_color = clean_hex
	entity_type.bg_color2 = clean_hex2
	entity_type.bg_image = image
	changed.emit()
	return true

func remove(type_id: String) -> bool:
	var entity_type: EntityType = find(type_id)
	if entity_type == null:
		return false
	_types.erase(entity_type)
	changed.emit()
	return true

func add_field(type_id: String, field_label: String, field_kind: FieldDef.Kind) -> FieldDef:
	var entity_type: EntityType = find(type_id)
	var clean: String = field_label.strip_edges()
	if entity_type == null or clean == "":
		return null

	var wanted: String = clean.to_lower()
	var revivable: FieldDef = null
	for field: FieldDef in entity_type.fields:
		if field.label.to_lower() != wanted:
			continue
		if not field.removed:
			return null
		if field.kind == field_kind and revivable == null:
			revivable = field

	if revivable != null:
		revivable.removed = false
		revivable.label = clean
		changed.emit()
		return revivable

	var created: FieldDef = FieldDef.create(clean, field_kind)
	entity_type.fields.append(created)
	changed.emit()
	return created

func remove_field(type_id: String, field_key: String) -> bool:
	var entity_type: EntityType = find(type_id)
	if entity_type == null:
		return false
	var field: FieldDef = entity_type.find_field(field_key)
	if field == null or field.removed:
		return false
	field.removed = true
	changed.emit()
	return true

func to_array() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entity_type: EntityType in _types:
		result.append(entity_type.to_dict())
	return result

func load_array(value: Variant) -> void:
	_types.clear()
	if value is Array:
		var seen_ids: Dictionary = {}
		for entry: Variant in (value as Array):
			var entity_type: EntityType = EntityType.from_dict(entry)
			if entity_type == null or seen_ids.has(entity_type.id):
				continue
			seen_ids[entity_type.id] = true
			_types.append(entity_type)
	changed.emit()

func migrate_default_names() -> bool:
	var key_of_name: Dictionary = {}
	var resource: Resource = load(DEFAULT_TYPES_PATH)
	if resource is JSON and (resource as JSON).data is Array:
		for entry: Variant in ((resource as JSON).data as Array):
			if entry is Dictionary:
				key_of_name[str((entry as Dictionary).get("name", ""))] = str((entry as Dictionary).get("name_key", ""))
	var migrated: bool = false
	for entity_type: EntityType in _types:
		var wanted_key: String = str(key_of_name.get(entity_type.name, ""))
		if entity_type.name_key == "" and wanted_key != "":
			entity_type.name_key = wanted_key
			migrated = true
	return migrated

func seed_defaults() -> void:
	_types.clear()
	var resource: Resource = load(DEFAULT_TYPES_PATH)
	if resource is JSON and (resource as JSON).data is Array:
		for entry: Variant in ((resource as JSON).data as Array):
			if not (entry is Dictionary):
				continue
			var data: Dictionary = (entry as Dictionary).duplicate()
			data["id"] = UuidUtil.generate_v4()
			var entity_type: EntityType = EntityType.from_dict(data)
			if entity_type != null:
				_types.append(entity_type)
	changed.emit()
