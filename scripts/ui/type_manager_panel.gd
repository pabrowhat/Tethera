class_name TypeManagerPanel
extends VBoxContainer

signal close_requested
signal create_requested(type_name: String)
signal rename_requested(type_id: String, type_name: String)
signal recolor_requested(type_id: String, color: Color)
signal delete_requested(type_id: String)
signal background_color_requested(type_id: String, color: Color)
signal background_color2_requested(type_id: String, color: Color)
signal background_gradient_clear_requested(type_id: String)
signal background_image_requested(type_id: String, source_path: String)
signal background_clear_requested(type_id: String)
signal field_add_requested(type_id: String, field_label: String, kind: int)
signal field_remove_requested(type_id: String, field_key: String)

const ICON_X: Texture2D = preload("res://assets/icons/x.svg")
const ICON_PLUS: Texture2D = preload("res://assets/icons/plus.svg")
const CAPTION_COLOR: Color = Color(0.7, 0.72, 0.8)
const DIM_COLOR: Color = Color(0.55, 0.58, 0.7)
const BODY_BG: Color = Color(0.0705882, 0.0745098, 0.105882, 1.0)
const KIND_KEYS: Array[String] = ["type.field.kind.text", "type.field.kind.number", "type.field.kind.date", "type.field.kind.list"]

var _registry: EntityTypeRegistry = null
var _count_of: Callable = Callable()
var _palette: Array[Color] = []
var _swatch_shader: Shader = null

var _expanded_id: String = ""
var _last_field_kind: int = FieldDef.Kind.TEXT
var _rebuild_queued: bool = false

var _new_input: LineEdit = null
var _list: VBoxContainer = null

func _init() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var header: HBoxContainer = HBoxContainer.new()
	add_child(header)

	var title: Label = Label.new()
	title.text = "type.manager.title"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", Color.WHITE)
	header.add_child(title)

	var close_button: Button = Button.new()
	close_button.custom_minimum_size = Vector2(36.0, 36.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.icon = ICON_X
	close_button.expand_icon = true
	close_button.add_theme_constant_override("icon_max_width", 16)
	close_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_button.tooltip_text = "type.manager.close"
	close_button.pressed.connect(close_requested.emit)
	header.add_child(close_button)

	var create_row: HBoxContainer = HBoxContainer.new()
	create_row.add_theme_constant_override("separation", 6)
	add_child(create_row)

	_new_input = LineEdit.new()
	_new_input.placeholder_text = "type.create.placeholder"
	_new_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_new_input.text_submitted.connect(_on_create_submitted)
	create_row.add_child(_new_input)
	create_row.add_child(_make_icon_button(ICON_PLUS, "type.create.button", _on_create_pressed))

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)

func setup(registry: EntityTypeRegistry, count_of: Callable, palette: Array[Color], swatch_shader: Shader) -> void:
	_registry = registry
	_count_of = count_of
	_palette = palette
	_swatch_shader = swatch_shader
	_registry.changed.connect(refresh)
	refresh()

func expand(type_id: String) -> void:
	_expanded_id = type_id
	refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _registry != null and _list != null:
		refresh()

func refresh() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _rebuild() -> void:
	_rebuild_queued = false
	if _registry == null:
		return

	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()

	var types: Array[EntityType] = _registry.get_all()
	if _registry.find(_expanded_id) == null:
		_expanded_id = ""
	if types.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "type.manager.empty"
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.add_theme_font_size_override("font_size", 12)
		empty_label.add_theme_color_override("font_color", DIM_COLOR)
		_list.add_child(empty_label)
		return

	for entity_type: EntityType in types:
		_list.add_child(_make_type_block(entity_type))

func _make_type_block(entity_type: EntityType) -> VBoxContainer:
	var block: VBoxContainer = VBoxContainer.new()
	block.add_theme_constant_override("separation", 4)
	block.add_child(_make_type_header(entity_type))
	if entity_type.id == _expanded_id:
		block.add_child(_make_type_body(entity_type))
	return block

func _make_type_header(entity_type: EntityType) -> Button:
	var type_id: String = entity_type.id
	var count: int = int(_count_of.call(type_id)) if _count_of.is_valid() else 0

	var button: Button = Button.new()
	button.text = entity_type.name if entity_type.name != "" else "—"
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.clip_text = true
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.tooltip_text = "%s: %d" % [tr("type.notes_count"), count]
	button.add_theme_stylebox_override("normal", _make_header_style(entity_type.color, UiStyle.BG_NORMAL))
	button.add_theme_stylebox_override("hover", _make_header_style(entity_type.color, UiStyle.BG_HOVER))
	button.add_theme_stylebox_override("pressed", _make_header_style(entity_type.color, UiStyle.BG_HOVER))
	button.pressed.connect(_on_header_pressed.bind(type_id))

	var count_label: Label = Label.new()
	count_label.text = str(count)
	count_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	count_label.offset_right = -10.0
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.add_theme_font_size_override("font_size", 12)
	count_label.add_theme_color_override("font_color", DIM_COLOR)
	button.add_child(count_label)
	return button

func _make_type_body(entity_type: EntityType) -> PanelContainer:
	var type_id: String = entity_type.id

	var body: PanelContainer = PanelContainer.new()
	body.add_theme_stylebox_override("panel", UiStyle.box(BODY_BG, UiStyle.BORDER, 6, 10.0, 10.0))

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	body.add_child(box)

	var name_input: LineEdit = LineEdit.new()
	name_input.text = entity_type.name
	name_input.text_submitted.connect(_on_name_committed.bind(type_id, name_input))
	name_input.focus_exited.connect(_on_name_focus_lost.bind(type_id, name_input))
	box.add_child(name_input)

	var color_bar: ColorBar = ColorBar.new()
	color_bar.setup(_palette, _swatch_shader)
	color_bar.set_eyedropper_visible(false)
	color_bar.set_active_color(entity_type.color)
	color_bar.color_picked.connect(_on_color_chosen.bind(type_id))
	color_bar.color_committed.connect(_on_color_chosen.bind(type_id))
	box.add_child(color_bar)

	var background: NoteBackgroundSection = NoteBackgroundSection.new("background.title_type")
	background.setup(_swatch_shader)
	background.show_state(entity_type.bg_color, entity_type.bg_color2, entity_type.bg_image)
	background.color_chosen.connect(func(color: Color) -> void: background_color_requested.emit(type_id, color))
	background.color2_chosen.connect(func(color: Color) -> void: background_color2_requested.emit(type_id, color))
	background.gradient_cleared.connect(func() -> void: background_gradient_clear_requested.emit(type_id))
	background.image_chosen.connect(func(source_path: String) -> void: background_image_requested.emit(type_id, source_path))
	background.cleared.connect(func() -> void: background_clear_requested.emit(type_id))
	box.add_child(background)

	var active: Array[FieldDef] = entity_type.active_fields()
	if active.is_empty():
		var none_label: Label = Label.new()
		none_label.text = "type.field.none"
		none_label.add_theme_font_size_override("font_size", 12)
		none_label.add_theme_color_override("font_color", DIM_COLOR)
		box.add_child(none_label)
	for field: FieldDef in active:
		box.add_child(_make_field_row(type_id, field))

	box.add_child(_make_add_field_row(type_id))

	var delete_button: Button = Button.new()
	delete_button.text = "type.delete.button"
	delete_button.focus_mode = Control.FOCUS_NONE
	UiStyle.apply_danger_text(delete_button)
	delete_button.pressed.connect(func() -> void: delete_requested.emit(type_id))
	box.add_child(delete_button)
	return body

func _make_field_row(type_id: String, field: FieldDef) -> HBoxContainer:
	var field_key: String = field.key

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var label: Label = Label.new()
	label.text = field.label
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", 13)
	row.add_child(label)

	var kind_label: Label = Label.new()
	kind_label.text = tr(KIND_KEYS[int(field.kind)])
	kind_label.add_theme_font_size_override("font_size", 12)
	kind_label.add_theme_color_override("font_color", DIM_COLOR)
	row.add_child(kind_label)

	row.add_child(_make_icon_button(ICON_X, "type.field.remove", func() -> void: field_remove_requested.emit(type_id, field_key)))
	return row

func _make_add_field_row(type_id: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var label_input: LineEdit = LineEdit.new()
	label_input.placeholder_text = "type.field.label_placeholder"
	label_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label_input)

	var kind_picker: DropdownButton = DropdownButton.new()
	kind_picker.custom_minimum_size = Vector2(96.0, 32.0)
	for index: int in KIND_KEYS.size():
		kind_picker.add_item(tr(KIND_KEYS[index]), index)
	kind_picker.select_id(_last_field_kind)
	row.add_child(kind_picker)

	var submit: Callable = _submit_field.bind(type_id, label_input, kind_picker)
	label_input.text_submitted.connect(func(_text: String) -> void: submit.call())
	row.add_child(_make_icon_button(ICON_PLUS, "type.field.add", submit))
	return row

func _make_icon_button(icon: Texture2D, tooltip: String, on_pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(32.0, 32.0)
	button.focus_mode = Control.FOCUS_NONE
	button.icon = icon
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 14)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.tooltip_text = tooltip
	button.pressed.connect(on_pressed)
	return button

func _make_header_style(accent: Color, background: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = accent
	style.border_width_left = 5
	style.set_corner_radius_all(6)
	style.content_margin_left = 12.0
	style.content_margin_right = 36.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _on_create_pressed() -> void:
	_on_create_submitted(_new_input.text)

func _on_create_submitted(text: String) -> void:
	var clean: String = text.strip_edges()
	if clean == "":
		return
	_new_input.clear()
	create_requested.emit(clean)

func _on_header_pressed(type_id: String) -> void:
	_expanded_id = "" if _expanded_id == type_id else type_id
	refresh()

func _on_name_committed(text: String, type_id: String, edit: LineEdit) -> void:
	_commit_name(text, type_id, edit)

func _on_name_focus_lost(type_id: String, edit: LineEdit) -> void:
	if is_instance_valid(edit):
		_commit_name(edit.text, type_id, edit)

func _commit_name(text: String, type_id: String, edit: LineEdit) -> void:
	var entity_type: EntityType = _registry.find(type_id)
	if entity_type == null:
		return
	var clean: String = text.strip_edges()
	if clean == "":
		edit.text = entity_type.name
	elif clean != entity_type.name:
		rename_requested.emit(type_id, clean)

func _on_color_chosen(color: Color, type_id: String) -> void:
	recolor_requested.emit(type_id, color)

func _submit_field(type_id: String, label_input: LineEdit, kind_picker: DropdownButton) -> void:
	_last_field_kind = kind_picker.get_selected_id()
	var clean: String = label_input.text.strip_edges()
	if clean == "":
		return
	field_add_requested.emit(type_id, clean, _last_field_kind)
