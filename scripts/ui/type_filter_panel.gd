class_name TypeFilterPanel
extends Button

signal type_toggled(type_id: String)
signal show_all_requested
signal hide_all_requested

const ICON_CHEVRON: Texture2D = preload("res://assets/icons/chevron-down.svg")
const ICON_CHECK: Texture2D = preload("res://assets/icons/check.svg")
const PANEL_WIDTH: float = 260.0
const LIST_MAX_HEIGHT: float = 300.0
const ROW_HEIGHT: float = 28.0
const SWATCH_SIZE: int = 10
const ICON_SIZE: float = 14.0
const SCREEN_MARGIN: float = 8.0
const ANCHOR_GAP: float = 4.0
const FADE_DURATION: float = 0.12
const OFF_ALPHA: float = 0.4
const NO_TYPE_COLOR: StringName = &"type.none"
const TEXT_COLOR: StringName = &"text.primary"
const ACTIVE_COLOR: StringName = &"accent.text"

var _panel: PanelContainer = null
var _search: LineEdit = null
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _row_style: StyleBoxFlat = null
var _row_hover_style: StyleBoxFlat = null
var _tween: Tween = null
var _is_open: bool = false

var _rows: Dictionary = {}
var _contents: Dictionary = {}
var _checks: Dictionary = {}
var _labels: Dictionary = {}

func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(110.0, 36.0)
	icon = ICON_CHEVRON
	icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	expand_icon = true
	add_theme_constant_override("icon_max_width", 16)
	add_theme_font_size_override("font_size", 13)
	ThemeColors.bind_override(self, &"font_color", TEXT_COLOR)
	pressed.connect(_toggle_panel)

	_row_style = UiStyle.box(UiStyle.CLEAR, UiStyle.CLEAR, 5, 0.0, 0.0)
	_row_style.set_border_width_all(0)
	_row_hover_style = UiStyle.box(UiStyle.BG_HOVER, UiStyle.BG_HOVER, 5, 0.0, 0.0)
	_row_hover_style.set_border_width_all(0)

	_panel = PanelContainer.new()
	_panel.top_level = true
	_panel.visible = false
	_panel.z_index = 100
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	var panel_style: StyleBoxFlat = UiStyle.box(PopupList.PANEL_BG, UiStyle.BORDER, 8, 8.0, 8.0)
	ThemeColors.bind(panel_style, &"shadow_color", &"shadow")
	panel_style.shadow_size = 12
	panel_style.shadow_offset = Vector2(0.0, 4.0)
	_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(_panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_panel.add_child(column)

	var actions: HBoxContainer = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	column.add_child(actions)
	actions.add_child(_make_action_button("filter.show_all", show_all_requested))
	actions.add_child(_make_action_button("filter.hide_all", hide_all_requested))

	_search = LineEdit.new()
	_search.placeholder_text = "filter.search"
	_search.clear_button_enabled = true
	_search.add_theme_font_size_override("font_size", 13)
	_search.text_changed.connect(_on_search_changed)
	column.add_child(_search)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)

	set_process_input(false)
	ThemeColors.watch(_on_theme_changed)

func _on_theme_changed() -> void:
	if _last_filter != null:
		rebuild(_last_types, _last_filter)

func _exit_tree() -> void:
	_is_open = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		close()
	elif what == NOTIFICATION_TRANSLATION_CHANGED and _last_filter != null:
		rebuild(_last_types, _last_filter)

var _last_types: Array[EntityType] = []
var _last_filter: TypeFilter = null

func is_open() -> bool:
	return _is_open

func is_point_over_panel(global_pos: Vector2) -> bool:
	return _is_open and Rect2(_panel.global_position, _panel.size).has_point(global_pos)

func rebuild(types: Array[EntityType], filter: TypeFilter) -> void:
	_last_types = types
	_last_filter = filter
	for row: Button in _rows.values():
		_list.remove_child(row)
		row.queue_free()
	_rows.clear()
	_contents.clear()
	_checks.clear()
	_labels.clear()

	for entity_type: EntityType in types:
		_add_row(entity_type.id, entity_type.name, entity_type.color)
	_add_row("", tr("filter.no_type"), ThemeColors.color(NO_TYPE_COLOR))
	_apply_search()
	refresh_states(filter)

func refresh_states(filter: TypeFilter) -> void:
	var shown: int = 0
	for type_id: String in _rows:
		var is_on: bool = filter.is_shown(type_id)
		shown += 1 if is_on else 0
		(_checks[type_id] as TextureRect).visible = is_on
		(_contents[type_id] as HBoxContainer).modulate.a = 1.0 if is_on else OFF_ALPHA

	text = tr("filter.button") % [shown, _rows.size()]
	ThemeColors.bind_override(self, &"font_color", TEXT_COLOR if shown == _rows.size() else ACTIVE_COLOR)

func open() -> void:
	if _is_open:
		return
	_is_open = true
	_kill_tween()
	_panel.visible = true
	_place()
	_place.call_deferred()
	_panel.modulate.a = 0.0
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_panel, "modulate:a", 1.0, FADE_DURATION)
	set_process_input(true)
	_search.grab_focus()

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	set_process_input(false)
	_search.release_focus()
	_search.clear()
	_apply_search()
	_kill_tween()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(_panel, "modulate:a", 0.0, FADE_DURATION)
	_tween.tween_callback(func() -> void: _panel.visible = false)

func _toggle_panel() -> void:
	if _is_open:
		close()
	else:
		open()

func _input(event: InputEvent) -> void:
	if not _is_open:
		return

	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if not click.pressed or click.button_index == MOUSE_BUTTON_WHEEL_UP or click.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			return
		if is_point_over_panel(click.global_position):
			return
		close()
		if get_global_rect().has_point(click.global_position):
			get_viewport().set_input_as_handled()

func _on_search_changed(_new_text: String) -> void:
	_apply_search()
	_place()
	_place.call_deferred()

func _apply_search() -> void:
	var query: String = _search.text.strip_edges()
	for type_id: String in _rows:
		(_rows[type_id] as Button).visible = FuzzyMatcher.score(query, (_labels[type_id] as Label).text) >= 0

func _place() -> void:
	if not _panel.visible:
		return
	var content: Vector2 = _list.get_combined_minimum_size()
	_scroll.custom_minimum_size = Vector2(0.0, minf(content.y, LIST_MAX_HEIGHT))
	_panel.size = Vector2.ZERO
	var panel_size: Vector2 = _panel.get_combined_minimum_size()
	_panel.size = panel_size

	var anchor: Rect2 = get_global_rect()
	var bounds: Vector2 = get_viewport_rect().size
	var x: float = clampf(anchor.position.x, SCREEN_MARGIN, maxf(bounds.x - panel_size.x - SCREEN_MARGIN, SCREEN_MARGIN))
	var y: float = clampf(anchor.end.y + ANCHOR_GAP, SCREEN_MARGIN, maxf(bounds.y - panel_size.y - SCREEN_MARGIN, SCREEN_MARGIN))
	_panel.global_position = Vector2(x, y)

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

func _make_action_button(label: String, requested: Signal) -> Button:
	var button: Button = Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, 28.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(func() -> void: requested.emit())
	return button

func _add_row(type_id: String, label: String, color: Color) -> void:
	var row: Button = Button.new()
	row.focus_mode = Control.FOCUS_NONE
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	for state: String in ["normal", "pressed", "disabled", "focus"]:
		row.add_theme_stylebox_override(state, _row_style)
	for state: String in ["hover", "hover_pressed"]:
		row.add_theme_stylebox_override(state, _row_hover_style)
	row.pressed.connect(type_toggled.emit.bind(type_id))

	var content: HBoxContainer = HBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 8.0
	content.offset_right = -8.0
	row.add_child(content)

	var swatch: RoundedShape = RoundedShape.new()
	swatch.set_style(color, color, 0.0)
	swatch.custom_minimum_size = Vector2(SWATCH_SIZE, SWATCH_SIZE)
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(swatch)

	var name_label: Label = Label.new()
	name_label.text = label
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 13)
	ThemeColors.bind_override(name_label, &"font_color", TEXT_COLOR)
	content.add_child(name_label)

	var check: TextureRect = TextureRect.new()
	check.texture = ICON_CHECK
	ThemeColors.bind(check, &"modulate", TEXT_COLOR)
	check.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	check.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	check.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(check)

	_list.add_child(row)
	_rows[type_id] = row
	_contents[type_id] = content
	_checks[type_id] = check
	_labels[type_id] = name_label
