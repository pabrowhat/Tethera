class_name NoteTypeSection
extends VBoxContainer

signal type_chosen(type_id: String)
signal field_edited(field_key: String, value: Variant)
signal follow_type_color_requested

const ICON_FOLLOW: Texture2D = preload("res://assets/icons/rotate-ccw.svg")
const CAPTION_COLOR: Color = Color(0.7, 0.72, 0.8)
const ERROR_COLOR: Color = Color(0.93, 0.47, 0.44)
const READ_COLOR: Color = Color(0.82, 0.84, 0.9)
const MAX_FIELDS_HEIGHT: float = 190.0
const KIND_PLACEHOLDER_KEYS: Dictionary = {
	FieldDef.Kind.DATE: "type.field.date_hint",
	FieldDef.Kind.LIST: "type.field.list_hint",
}

var _registry: EntityTypeRegistry = null
var _card: GraphCard = null
var _row: HBoxContainer = null
var _read_only: bool = false
var _picker: DropdownButton = null
var _follow_button: Button = null
var _scroll: ScrollContainer = null
var _fields_box: VBoxContainer = null
var _refresh_queued: bool = false

func _init() -> void:
	add_theme_constant_override("separation", 8)

	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 8)
	add_child(_row)

	var caption: Label = Label.new()
	caption.text = "type.section.title"
	caption.add_theme_font_size_override("font_size", 12)
	caption.add_theme_color_override("font_color", CAPTION_COLOR)
	_row.add_child(caption)

	_picker = DropdownButton.new()
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_picker.item_selected.connect(_on_picker_selected)
	_row.add_child(_picker)

	_follow_button = Button.new()
	_follow_button.custom_minimum_size = Vector2(32.0, 32.0)
	_follow_button.focus_mode = Control.FOCUS_NONE
	_follow_button.icon = ICON_FOLLOW
	_follow_button.expand_icon = true
	_follow_button.add_theme_constant_override("icon_max_width", 14)
	_follow_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_follow_button.tooltip_text = "type.color.follow"
	_follow_button.visible = false
	_follow_button.pressed.connect(follow_type_color_requested.emit)
	_row.add_child(_follow_button)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.visible = false
	add_child(_scroll)

	_fields_box = VBoxContainer.new()
	_fields_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fields_box.add_theme_constant_override("separation", 8)
	_scroll.add_child(_fields_box)
	_fields_box.minimum_size_changed.connect(_fit_scroll)

func setup(registry: EntityTypeRegistry) -> void:
	_registry = registry
	_registry.changed.connect(_queue_refresh)

func set_read_only(value: bool) -> void:
	if value == _read_only:
		return
	_read_only = value
	_row.visible = not value
	if is_instance_valid(_card):
		_rebuild()

func show_card(card: GraphCard) -> void:
	_card = card
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _picker != null:
		_queue_refresh()

func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_refresh_now.call_deferred()

func _refresh_now() -> void:
	_refresh_queued = false
	if is_instance_valid(_card):
		_rebuild()

func _rebuild() -> void:
	if _registry == null or not is_instance_valid(_card):
		return

	_picker.clear()
	_picker.add_item(tr("type.none"), 0, "")
	var selected: int = 0
	for entity_type: EntityType in _registry.get_all():
		var index: int = _picker.get_item_count()
		_picker.add_item(entity_type.name if entity_type.name != "" else "—", index, entity_type.id)
		if entity_type.id == _card.entity_type_id:
			selected = index
	_picker.select_id(selected)

	var current: EntityType = _registry.find(_card.entity_type_id)
	_follow_button.visible = current != null and _card.color_overridden

	for child: Node in _fields_box.get_children():
		_fields_box.remove_child(child)
		child.queue_free()
	if current != null:
		for field: FieldDef in current.active_fields():
			if not _read_only:
				_fields_box.add_child(_make_field_row(field))
			else:
				var shown: String = _format_value(field, _card.field_values.get(field.key, null))
				if shown != "":
					_fields_box.add_child(_make_read_line(field, shown))
	_scroll.visible = _fields_box.get_child_count() > 0
	_fit_scroll.call_deferred()

func _fit_scroll() -> void:
	if is_instance_valid(_scroll) and _scroll.visible:
		var wanted: float = minf(_fields_box.get_combined_minimum_size().y, MAX_FIELDS_HEIGHT)
		if not is_equal_approx(_scroll.custom_minimum_size.y, wanted):
			_scroll.custom_minimum_size.y = wanted

func _make_read_line(field: FieldDef, shown: String) -> Label:
	var line: Label = Label.new()
	line.text = tr("type.field.read_line") % [field.label, shown]
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.add_theme_font_size_override("font_size", 13)
	line.add_theme_color_override("font_color", READ_COLOR)
	return line

func _make_field_row(field: FieldDef) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)

	var label: Label = Label.new()
	label.text = field.label
	label.clip_text = true
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", CAPTION_COLOR)
	box.add_child(label)

	var edit: LineEdit = LineEdit.new()
	edit.text = _format_value(field, _card.field_values.get(field.key, null))
	if KIND_PLACEHOLDER_KEYS.has(field.kind):
		edit.placeholder_text = str(KIND_PLACEHOLDER_KEYS[field.kind])
	box.add_child(edit)

	var error: Label = Label.new()
	error.visible = false
	error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	error.add_theme_font_size_override("font_size", 11)
	error.add_theme_color_override("font_color", ERROR_COLOR)
	box.add_child(error)

	edit.text_changed.connect(_on_field_text_changed.bind(field, error))
	edit.focus_exited.connect(_on_field_focus_lost.bind(field, edit))
	return box


static func _format_value(field: FieldDef, value: Variant) -> String:
	if value == null:
		return ""
	if field.kind == FieldDef.Kind.LIST and value is Array:
		var items: PackedStringArray = PackedStringArray()
		for item: Variant in (value as Array):
			items.append(str(item))
		return ", ".join(items)
	return str(value)

static func parse_input(field: FieldDef, text: String) -> Dictionary:
	var clean: String = text.strip_edges()
	if clean == "":
		return {"ok": true, "value": null}

	match field.kind:
		FieldDef.Kind.NUMBER:
			var normalized: String = clean.replace(" ", "").replace("\u00a0", "").replace(",", ".")
			if normalized.is_valid_float() and is_finite(normalized.to_float()):
				return {"ok": true, "value": normalized.to_float()}
			return {"ok": false, "value": null}
		FieldDef.Kind.DATE:
			if FieldDef.is_valid_date(clean):
				return {"ok": true, "value": clean}
			return {"ok": false, "value": null}
		FieldDef.Kind.LIST:
			var items: Array[String] = []
			for part: String in clean.split(","):
				var item: String = part.strip_edges()
				if item != "":
					items.append(item)
			return {"ok": true, "value": items if not items.is_empty() else null}
	return {"ok": true, "value": clean}


func _on_picker_selected(_id: int) -> void:
	type_chosen.emit(str(_picker.get_selected_metadata()))

func _on_field_text_changed(text: String, field: FieldDef, error: Label) -> void:
	var parsed: Dictionary = parse_input(field, text)
	if not bool(parsed["ok"]):
		error.text = "type.field.number_invalid" if field.kind == FieldDef.Kind.NUMBER else "type.field.date_invalid"
		error.visible = true
		return
	error.visible = false
	field_edited.emit(field.key, parsed["value"])

func _on_field_focus_lost(field: FieldDef, edit: LineEdit) -> void:
	if not is_instance_valid(_card) or not is_instance_valid(edit):
		return
	if not bool(parse_input(field, edit.text)["ok"]):
		edit.text = _format_value(field, _card.field_values.get(field.key, null))
