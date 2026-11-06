class_name PopupList
extends PanelContainer

signal item_chosen(id: int)
signal closed

const OPEN_DURATION: float = 0.12
const CLOSE_DURATION: float = 0.08
const OPEN_SCALE_Y: float = 0.88
const SCREEN_MARGIN: float = 8.0
const ANCHOR_GAP: float = 4.0
const MAX_HEIGHT: float = 360.0
const ROW_HEIGHT: float = 30.0
const TEXT_COLOR: StringName = &"text.primary"
const HINT_COLOR: StringName = &"text.muted"
const PANEL_BG: StringName = &"surface.panel"
const SUBMENU_MARK: String = ">"
const SUBMENU_GAP: float = 2.0

static var _open_lists: Array[PopupList] = []

static func is_any_open() -> bool:
	return not _open_lists.is_empty()

static func is_point_over_open(global_point: Vector2) -> bool:
	for list: PopupList in _open_lists:
		if is_instance_valid(list) and Rect2(list.global_position, list.size).has_point(global_point):
			return true
	return false

var _items: Array[Dictionary] = []
var _rows: Array[Button] = []
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _tween: Tween = null
var _is_open: bool = false
var _anchor_rect: Rect2 = Rect2()
var _selected_index: int = -1
var _beside: bool = false
var _open_sub: PopupList = null

var _row_style: StyleBoxFlat = null
var _row_active_style: StyleBoxFlat = null

func _init() -> void:
	top_level = true
	visible = false
	z_index = 100
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(false)

	var panel_style: StyleBoxFlat = UiStyle.box(PANEL_BG, UiStyle.BORDER, 8, 4.0, 4.0)
	ThemeColors.bind(panel_style, &"shadow_color", &"shadow")
	panel_style.shadow_size = 12
	panel_style.shadow_offset = Vector2(0.0, 4.0)
	add_theme_stylebox_override("panel", panel_style)

	_row_style = UiStyle.box(UiStyle.CLEAR, UiStyle.CLEAR, 5, 0.0, 0.0)
	_row_style.set_border_width_all(0)
	_row_active_style = UiStyle.box(UiStyle.ACCENT, UiStyle.ACCENT, 5, 0.0, 0.0)
	_row_active_style.set_border_width_all(0)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)

func _exit_tree() -> void:
	_open_lists.erase(self)
	_is_open = false


func clear() -> void:
	_items.clear()
	_open_sub = null
	for child: Node in get_children():
		if child is PopupList:
			remove_child(child)
			child.queue_free()

func add_item(text: String, id: int, hint: String = "") -> void:
	_items.append({"id": id, "text": text, "hint": hint, "disabled": false, "separator": false})

func add_submenu(text: String, id: int) -> PopupList:
	var submenu: PopupList = PopupList.new()
	add_child(submenu)
	submenu.item_chosen.connect(_on_submenu_chosen)
	submenu.closed.connect(_on_submenu_closed.bind(submenu))
	_items.append({"id": id, "text": text, "hint": SUBMENU_MARK, "disabled": false, "separator": false, "submenu": submenu})
	return submenu

func add_separator() -> void:
	_items.append({"id": -1, "text": "", "hint": "", "disabled": false, "separator": true})

func get_item_count() -> int:
	var total: int = 0
	for item: Dictionary in _items:
		if not bool(item["separator"]):
			total += 1
	return total

func set_item_disabled(id: int, disabled: bool) -> void:
	var item: Dictionary = _find_item(id)
	if not item.is_empty():
		item["disabled"] = disabled

func set_item_text(id: int, text: String) -> void:
	var item: Dictionary = _find_item(id)
	if not item.is_empty():
		item["text"] = text

func is_open() -> bool:
	return _is_open

func all_disabled() -> bool:
	for item: Dictionary in _items:
		if not bool(item["separator"]) and not bool(item["disabled"]):
			return false
	return true

func _find_item(id: int) -> Dictionary:
	for item: Dictionary in _items:
		if not bool(item["separator"]) and int(item["id"]) == id:
			return item
	return {}


func open_below(anchor: Rect2, min_width: float = 0.0, highlight_id: int = -1) -> void:
	_beside = false
	_open(anchor, min_width, highlight_id)

func open_at(pos: Vector2, min_width: float = 0.0) -> void:
	_beside = false
	_open(Rect2(pos, Vector2.ZERO), min_width, -1)

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_open_lists.erase(self)
	set_process_input(false)
	if _open_sub != null and _open_sub.is_open():
		_open_sub.close()
	_open_sub = null
	_kill_tween()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, CLOSE_DURATION)
	_tween.tween_property(self, "scale:y", OPEN_SCALE_Y, CLOSE_DURATION)
	_tween.chain().tween_callback(func() -> void: visible = false)
	closed.emit()

func open_beside(row_rect: Rect2, highlight_first: bool) -> void:
	_beside = true
	_open(row_rect, 0.0, -1)
	if not highlight_first:
		_selected_index = -1
		_refresh_selection()

func _open(anchor: Rect2, min_width: float, highlight_id: int) -> void:
	_kill_tween()
	_rebuild()
	_anchor_rect = anchor

	custom_minimum_size = Vector2(min_width, 0.0)
	visible = true
	_place()
	_place.call_deferred()

	_select_initial(highlight_id)

	modulate.a = 0.0
	scale = Vector2(1.0, OPEN_SCALE_Y)
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, OPEN_DURATION)
	_tween.tween_property(self, "scale:y", 1.0, OPEN_DURATION)

	if not _is_open:
		_is_open = true
		_open_lists.append(self)
	set_process_input(true)

func _place() -> void:
	if not visible:
		return
	_fit_rows()
	var content: Vector2 = _list.get_combined_minimum_size()
	_scroll.custom_minimum_size = Vector2(content.x, minf(content.y, MAX_HEIGHT))
	size = Vector2.ZERO
	var popup_size: Vector2 = get_combined_minimum_size()
	size = popup_size

	var bounds: Vector2 = get_viewport_rect().size
	if _beside:
		var right_x: float = _anchor_rect.end.x + SUBMENU_GAP
		var side_x: float = right_x if right_x + popup_size.x <= bounds.x - SCREEN_MARGIN else _anchor_rect.position.x - SUBMENU_GAP - popup_size.x
		var side_y: float = clampf(_anchor_rect.position.y - 4.0, SCREEN_MARGIN, maxf(bounds.y - popup_size.y - SCREEN_MARGIN, SCREEN_MARGIN))
		global_position = Vector2(maxf(side_x, SCREEN_MARGIN), side_y)
		pivot_offset = Vector2.ZERO
		return
	var x: float = clampf(_anchor_rect.position.x, SCREEN_MARGIN, maxf(bounds.x - popup_size.x - SCREEN_MARGIN, SCREEN_MARGIN))
	var gap: float = ANCHOR_GAP if _anchor_rect.size != Vector2.ZERO else 0.0
	var below: float = _anchor_rect.end.y + gap
	var opens_down: bool = below + popup_size.y <= bounds.y - SCREEN_MARGIN or _anchor_rect.position.y - gap - popup_size.y < SCREEN_MARGIN
	var y: float = below if opens_down else _anchor_rect.position.y - gap - popup_size.y
	y = clampf(y, SCREEN_MARGIN, maxf(bounds.y - popup_size.y - SCREEN_MARGIN, SCREEN_MARGIN))
	global_position = Vector2(x, y)
	pivot_offset = Vector2(popup_size.x * 0.5, 0.0 if opens_down else popup_size.y)

func _fit_rows() -> void:
	for row: Button in _rows:
		if row == null or row.get_child_count() == 0 or not (row.get_child(0) is HBoxContainer):
			continue
		var box: HBoxContainer = row.get_child(0) as HBoxContainer
		row.custom_minimum_size = Vector2(box.get_combined_minimum_size().x + 20.0, ROW_HEIGHT)

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _rebuild() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_rows.clear()

	for entry: Dictionary in _items:
		if entry.has("submenu"):
			entry["disabled"] = (entry["submenu"] as PopupList).all_disabled()

	for index: int in _items.size():
		var item: Dictionary = _items[index]
		if bool(item["separator"]):
			_list.add_child(_make_separator())
			_rows.append(null)
			continue
		var row: Button = _make_row(item, index)
		_list.add_child(row)
		_rows.append(row)

func _make_separator() -> Control:
	var holder: MarginContainer = MarginContainer.new()
	holder.add_theme_constant_override("margin_left", 6)
	holder.add_theme_constant_override("margin_right", 6)
	holder.add_theme_constant_override("margin_top", 3)
	holder.add_theme_constant_override("margin_bottom", 3)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line: ColorRect = ColorRect.new()
	ThemeColors.bind(line, &"color", UiStyle.BORDER)
	line.custom_minimum_size = Vector2(0.0, 1.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(line)
	return holder

func _make_row(item: Dictionary, index: int) -> Button:
	var disabled: bool = bool(item["disabled"])
	var row: Button = Button.new()
	row.focus_mode = Control.FOCUS_NONE
	row.disabled = disabled
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		row.add_theme_stylebox_override(state, _row_style)

	var box: HBoxContainer = HBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10.0
	box.offset_right = -10.0
	row.add_child(box)

	var label: Label = Label.new()
	label.text = str(item["text"])
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 13)
	box.add_child(label)

	if str(item["hint"]) != "":
		var hint: Label = Label.new()
		hint.text = str(item["hint"])
		hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hint.add_theme_font_size_override("font_size", 12)
		box.add_child(hint)

	UiStyle.paint_row_text(row, disabled, false, TEXT_COLOR, HINT_COLOR)
	row.custom_minimum_size = Vector2(box.get_combined_minimum_size().x + 20.0, ROW_HEIGHT)
	row.mouse_entered.connect(_on_row_hovered.bind(index))
	row.pressed.connect(_choose.bind(index))
	return row

func _select_initial(highlight_id: int) -> void:
	var found: int = -1
	for index: int in _items.size():
		var item: Dictionary = _items[index]
		if not bool(item["separator"]) and not bool(item["disabled"]) and int(item["id"]) == highlight_id:
			found = index
			break
	_selected_index = found if found >= 0 else _next_enabled(-1, 1)
	_refresh_selection()

func _next_enabled(from: int, step: int) -> int:
	var count: int = _items.size()
	if count == 0:
		return -1
	var index: int = from
	for _attempt: int in count:
		index = posmod(index + step, count)
		var item: Dictionary = _items[index]
		if not bool(item["separator"]) and not bool(item["disabled"]):
			return index
	return -1

func _refresh_selection() -> void:
	for index: int in _rows.size():
		var row: Button = _rows[index]
		if row == null:
			continue
		var active: bool = index == _selected_index
		var style: StyleBoxFlat = _row_active_style if active else _row_style
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			row.add_theme_stylebox_override(state, style)
		UiStyle.paint_row_text(row, bool(_items[index]["disabled"]), active, TEXT_COLOR, HINT_COLOR)
	if _selected_index >= 0 and _selected_index < _rows.size() and _rows[_selected_index] != null:
		_scroll.ensure_control_visible(_rows[_selected_index])

func _on_row_hovered(index: int) -> void:
	var hovered: Dictionary = _items[index]
	if _open_sub != null and hovered.get("submenu") != _open_sub:
		_open_sub.close()
	if bool(hovered["disabled"]):
		return
	_selected_index = index
	_refresh_selection()
	if hovered.has("submenu"):
		_show_submenu(index, false)

func _show_submenu(index: int, highlight_first: bool) -> void:
	var submenu: PopupList = _items[index].get("submenu") as PopupList
	if submenu == null or index >= _rows.size() or _rows[index] == null:
		return
	if submenu.is_open():
		if highlight_first:
			submenu._selected_index = submenu._next_enabled(-1, 1)
			submenu._refresh_selection()
		return
	_open_sub = submenu
	submenu.open_beside(_rows[index].get_global_rect(), highlight_first)

func _on_submenu_chosen(id: int) -> void:
	close()
	item_chosen.emit(id)

func _on_submenu_closed(submenu: PopupList) -> void:
	if _open_sub == submenu:
		_open_sub = null

func _choose(index: int) -> void:
	if index < 0 or index >= _items.size():
		return
	var item: Dictionary = _items[index]
	if bool(item["separator"]) or bool(item["disabled"]):
		return
	if item.has("submenu"):
		_show_submenu(index, true)
		return
	var id: int = int(item["id"])
	close()
	item_chosen.emit(id)


func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	var sub_open: bool = _open_sub != null and _open_sub.is_open()

	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if not key.pressed:
			return
		if sub_open:
			return
		match key.keycode:
			KEY_RIGHT:
				if _selected_index >= 0 and _selected_index < _items.size() and _items[_selected_index].has("submenu") \
						and not bool(_items[_selected_index]["disabled"]):
					_show_submenu(_selected_index, true)
					get_viewport().set_input_as_handled()
			KEY_LEFT:
				if _beside:
					close()
					get_viewport().set_input_as_handled()
			KEY_ESCAPE:
				close()
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_selected_index = _next_enabled(_selected_index, 1)
				_refresh_selection()
				get_viewport().set_input_as_handled()
			KEY_UP:
				_selected_index = _next_enabled(_selected_index, -1)
				_refresh_selection()
				get_viewport().set_input_as_handled()
			KEY_ENTER, KEY_KP_ENTER:
				_choose(_selected_index)
				get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if not button.pressed or button.button_index == MOUSE_BUTTON_WHEEL_UP or button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			return
		if Rect2(global_position, size).has_point(button.global_position):
			return
		if sub_open and Rect2(_open_sub.global_position, _open_sub.size).has_point(button.global_position):
			return
		close()
		if _anchor_rect.size != Vector2.ZERO and _anchor_rect.has_point(button.global_position):
			get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		close()
