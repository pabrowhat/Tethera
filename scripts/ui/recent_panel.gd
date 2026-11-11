class_name RecentPanel
extends Control

signal note_chosen(card_id: String)

const PANEL_WIDTH: float = 300.0
const LIST_MAX_HEIGHT: float = 360.0
const ROW_HEIGHT: float = 28.0
const SCREEN_MARGIN: float = 8.0
const ANCHOR_GAP: float = 4.0
const FADE_DURATION: float = 0.12
const TEXT_COLOR: StringName = &"text.primary"
const DIM_COLOR: StringName = &"text.muted"

var _panel: PanelContainer = null
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _row_style: StyleBoxFlat = null
var _row_hover_style: StyleBoxFlat = null
var _tween: Tween = null
var _is_open: bool = false
var _anchor: Rect2 = Rect2()
var _source: Callable = Callable()
var _now_source: Callable = Callable()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

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

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)

	set_process_input(false)

func setup(source: Callable, now_source: Callable) -> void:
	_source = source
	_now_source = now_source

func _exit_tree() -> void:
	_is_open = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		close()

func is_open() -> bool:
	return _is_open

func is_point_over_panel(global_pos: Vector2) -> bool:
	return _is_open and Rect2(_panel.global_position, _panel.size).has_point(global_pos)

func open_below(anchor: Rect2) -> void:
	if _is_open:
		return
	_anchor = anchor
	_is_open = true
	_rebuild()
	_kill_tween()
	_panel.visible = true
	_place()
	_place.call_deferred()
	_panel.modulate.a = 0.0
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_panel, "modulate:a", 1.0, FADE_DURATION)
	UiMotion.settle(_tween)
	set_process_input(true)

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	set_process_input(false)
	_kill_tween()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(_panel, "modulate:a", 0.0, FADE_DURATION)
	_tween.tween_callback(func() -> void: _panel.visible = false)
	UiMotion.settle(_tween)

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

func _rebuild() -> void:
	for row: Node in _list.get_children():
		_list.remove_child(row)
		row.queue_free()

	var entries: Array = _source.call() if _source.is_valid() else []
	if entries.is_empty():
		var empty: Label = Label.new()
		empty.text = "recent.empty"
		empty.add_theme_font_size_override("font_size", 13)
		ThemeColors.bind_override(empty, &"font_color", DIM_COLOR)
		_list.add_child(empty)
		return

	var now: int = int(_now_source.call()) if _now_source.is_valid() else 0
	for entry: Variant in entries:
		var data: Dictionary = entry as Dictionary
		_add_row(str(data["id"]), str(data["title"]), RecentNotes.relative_time(int(data["modified"]), now))

func _add_row(card_id: String, title: String, time_text: String) -> void:
	var row: Button = Button.new()
	row.focus_mode = Control.FOCUS_NONE
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	for state: String in ["normal", "pressed", "disabled", "focus"]:
		row.add_theme_stylebox_override(state, _row_style)
	for state: String in ["hover", "hover_pressed"]:
		row.add_theme_stylebox_override(state, _row_hover_style)
	row.pressed.connect(_on_row_pressed.bind(card_id))

	var content: HBoxContainer = HBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 8.0
	content.offset_right = -8.0
	row.add_child(content)

	var name_label: Label = Label.new()
	name_label.text = title
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.add_theme_font_size_override("font_size", 13)
	ThemeColors.bind_override(name_label, &"font_color", TEXT_COLOR)
	content.add_child(name_label)

	var time_label: Label = Label.new()
	time_label.text = time_text
	time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_label.add_theme_font_size_override("font_size", 12)
	ThemeColors.bind_override(time_label, &"font_color", DIM_COLOR)
	content.add_child(time_label)

	_list.add_child(row)

func _on_row_pressed(card_id: String) -> void:
	close()
	note_chosen.emit(card_id)

func _place() -> void:
	if not _panel.visible:
		return
	var content: Vector2 = _list.get_combined_minimum_size()
	_scroll.custom_minimum_size = Vector2(0.0, minf(content.y, LIST_MAX_HEIGHT))
	_panel.size = Vector2.ZERO
	var panel_size: Vector2 = _panel.get_combined_minimum_size()
	_panel.size = panel_size

	var anchor: Rect2 = _anchor
	var bounds: Vector2 = get_viewport_rect().size
	var x: float = clampf(anchor.position.x, SCREEN_MARGIN, maxf(bounds.x - panel_size.x - SCREEN_MARGIN, SCREEN_MARGIN))
	var y: float = clampf(anchor.end.y + ANCHOR_GAP, SCREEN_MARGIN, maxf(bounds.y - panel_size.y - SCREEN_MARGIN, SCREEN_MARGIN))
	_panel.global_position = Vector2(x, y)

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
