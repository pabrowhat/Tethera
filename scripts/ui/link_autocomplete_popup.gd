class_name LinkAutocompletePopup
extends PanelContainer

signal item_chosen(card_id: String, title: String)

@export var popup_width: float = 240.0
@export var open_duration: float = 0.12
@export var max_height: float = 260.0

const SCREEN_MARGIN: float = 8.0
const ANCHOR_GAP: float = 4.0

var _list: VBoxContainer = null
var _scroll: ScrollContainer = null
var _items: Array[Dictionary] = []
var _buttons: Array[Button] = []
var _selected_index: int = 0
var _anchor_pos: Vector2 = Vector2.ZERO
var _line_height: float = 20.0
var _open_tween: Tween = null

var _panel_style: StyleBoxFlat = null
var _row_style: StyleBoxFlat = null
var _row_selected_style: StyleBoxFlat = null

func _init() -> void:
	top_level = true
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(popup_width, 0.0)

	_panel_style = StyleBoxFlat.new()
	ThemeColors.bind(_panel_style, &"bg_color", &"surface.raised")
	ThemeColors.bind(_panel_style, &"border_color", &"accent")
	_panel_style.set_border_width_all(1)
	_panel_style.set_corner_radius_all(6)
	_panel_style.set_content_margin_all(4.0)
	add_theme_stylebox_override("panel", _panel_style)

	_row_style = StyleBoxFlat.new()
	ThemeColors.bind(_row_style, &"bg_color", UiStyle.CLEAR)
	_row_style.set_corner_radius_all(4)
	_row_style.set_content_margin_all(6.0)

	_row_selected_style = StyleBoxFlat.new()
	ThemeColors.bind(_row_selected_style, &"bg_color", &"accent")
	_row_selected_style.set_corner_radius_all(4)
	_row_selected_style.set_content_margin_all(6.0)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)

func set_popup_width(width: float) -> void:
	popup_width = width
	custom_minimum_size.x = width

func is_open() -> bool:
	return visible

func has_items() -> bool:
	return not _items.is_empty()

func open_at(caret_global: Vector2, line_height: float) -> void:
	_anchor_pos = caret_global
	_line_height = line_height
	if visible:
		_reposition()
		return

	visible = true
	_reposition()
	modulate.a = 0.0
	scale = Vector2(0.92, 0.92)

	if _open_tween and _open_tween.is_valid():
		_open_tween.kill()
	_open_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(self, "scale", Vector2.ONE, open_duration)
	_open_tween.tween_property(self, "modulate:a", 1.0, open_duration)

func move_anchor(caret_global: Vector2, line_height: float) -> void:
	_anchor_pos = caret_global
	_line_height = line_height
	if visible:
		_reposition()

func update_results(items: Array[Dictionary]) -> void:
	_items = items
	_selected_index = 0
	_scroll.scroll_vertical = 0

	for btn: Button in _buttons:
		_list.remove_child(btn)
		btn.queue_free()
	_buttons.clear()

	if _items.is_empty():
		var empty_label: Button = _make_row(tr("link.autocomplete.empty"))
		empty_label.disabled = true
		_list.add_child(empty_label)
		_buttons.append(empty_label)
	else:
		for i: int in _items.size():
			var item: Dictionary = _items[i]
			var btn: Button = _make_row(str(item["title"]))
			var index: int = i
			btn.pressed.connect(func() -> void:
				_selected_index = index
				confirm()
			)
			btn.mouse_entered.connect(func() -> void: _set_selected(index))
			_list.add_child(btn)
			_buttons.append(btn)

	_refresh_selection_style()
	if visible:
		_reposition()

func move_selection(direction: int) -> void:
	if _items.is_empty():
		return
	var count: int = _items.size()
	_set_selected((_selected_index + direction + count) % count)

func confirm() -> bool:
	if _items.is_empty():
		return false
	var item: Dictionary = _items[_selected_index]
	item_chosen.emit(str(item["id"]), str(item["title"]))
	return true

func close() -> void:
	if _open_tween and _open_tween.is_valid():
		_open_tween.kill()
	visible = false
	_items = []

func _make_row(text: String) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.focus_mode = Control.FOCUS_NONE
	btn.clip_text = true
	btn.add_theme_stylebox_override("normal", _row_style)
	btn.add_theme_stylebox_override("hover", _row_style)
	btn.add_theme_stylebox_override("pressed", _row_selected_style)
	btn.add_theme_stylebox_override("disabled", _row_style)
	return btn

func _set_selected(index: int) -> void:
	if index == _selected_index:
		return
	_selected_index = index
	_refresh_selection_style()
	if index >= 0 and index < _buttons.size():
		_scroll.ensure_control_visible(_buttons[index])

func _refresh_selection_style() -> void:
	if _items.is_empty():
		return
	for i: int in _buttons.size():
		var style: StyleBoxFlat = _row_selected_style if i == _selected_index else _row_style
		_buttons[i].add_theme_stylebox_override("normal", style)
		_buttons[i].add_theme_stylebox_override("hover", style)
		var selected: bool = i == _selected_index
		ThemeColors.bind_override(_buttons[i], &"font_color", &"text.on_accent" if selected else &"text.primary")
		ThemeColors.bind_override(_buttons[i], &"font_hover_color", &"text.on_accent" if selected else &"text.strong")

func _reposition() -> void:
	_scroll.custom_minimum_size.y = minf(_list.get_combined_minimum_size().y, max_height)
	reset_size()
	var popup_size: Vector2 = get_combined_minimum_size()
	size = popup_size

	var viewport_size: Vector2 = get_viewport_rect().size
	var pos: Vector2 = _anchor_pos + Vector2(0.0, _line_height + ANCHOR_GAP)
	var flipped: bool = false

	if pos.y + popup_size.y > viewport_size.y - SCREEN_MARGIN:
		pos.y = _anchor_pos.y - popup_size.y - ANCHOR_GAP
		flipped = true

	pos.x = clampf(pos.x, SCREEN_MARGIN, maxf(SCREEN_MARGIN, viewport_size.x - popup_size.x - SCREEN_MARGIN))
	pos.y = maxf(SCREEN_MARGIN, pos.y)

	position = pos
	pivot_offset = Vector2(0.0, popup_size.y if flipped else 0.0)
