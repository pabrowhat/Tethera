class_name CommandPalette
extends ModalDialog

const PALETTE_WIDTH: float = 520.0
const LIST_HEIGHT: float = 320.0
const ROW_HEIGHT: float = 30.0
const ROW_TEXT_COLOR: Color = Color(0.88, 0.89, 0.94, 1.0)
const ROW_HINT_COLOR: Color = Color(0.6, 0.63, 0.74, 1.0)
const ROW_DISABLED_COLOR: Color = Color(0.45, 0.47, 0.58, 1.0)

var _source: Callable = Callable()
var _runner: Callable = Callable()

var _entries: Array[Dictionary] = []
var _shown: Array[Dictionary] = []
var _rows: Array[Button] = []
var _selected: int = -1
var _search: LineEdit = null
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _row_style: StyleBoxFlat = null
var _row_active_style: StyleBoxFlat = null
var _previous_focus: Control = null

func _init() -> void:
	super()
	_set_card_width(PALETTE_WIDTH)

	_row_style = UiStyle.box(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 5, 0.0, 0.0)
	_row_style.set_border_width_all(0)
	_row_active_style = UiStyle.box(UiStyle.ACCENT, UiStyle.ACCENT, 5, 0.0, 0.0)
	_row_active_style.set_border_width_all(0)

	_search = LineEdit.new()
	_search.placeholder_text = "palette.placeholder"
	_search.add_theme_font_size_override("font_size", 14)
	_search.text_changed.connect(_on_query_changed)
	_body.add_child(_search)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(0.0, LIST_HEIGHT)
	_body.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_list)

func setup(source: Callable, runner: Callable) -> void:
	_source = source
	_runner = runner

func open_palette() -> void:
	if is_open():
		return
	_previous_focus = get_viewport().gui_get_focus_owner()
	_entries.clear()
	if _source.is_valid():
		for entry: Variant in (_source.call() as Array):
			_entries.append(entry as Dictionary)
	_search.text = ""
	_refresh_list()
	open()
	_search.grab_focus()

func close() -> void:
	var was_open: bool = is_open()
	super()
	if was_open and is_instance_valid(_previous_focus) and _previous_focus.is_inside_tree():
		_previous_focus.grab_focus()
	_previous_focus = null

func _on_query_changed(_new_text: String) -> void:
	_refresh_list()

func _refresh_list() -> void:
	var query: String = _search.text.strip_edges()
	_shown.clear()
	if query == "":
		_shown.append_array(_entries)
	else:
		var items: Array[Dictionary] = []
		var by_id: Dictionary = {}
		for entry: Dictionary in _entries:
			var key: String = str(entry["id"])
			items.append({"id": key, "title": str(entry["text"])})
			by_id[key] = entry
		for match_item: Dictionary in FuzzyMatcher.rank(query, items, items.size()):
			_shown.append(by_id[str(match_item["id"])] as Dictionary)

	for row: Node in _list.get_children():
		_list.remove_child(row)
		row.queue_free()
	_rows.clear()

	if _shown.is_empty():
		_list.add_child(_make_label("palette.empty", 13, MUTED_COLOR))
		_selected = -1
		return

	for index: int in _shown.size():
		var row: Button = _make_row(_shown[index], index)
		_rows.append(row)
		_list.add_child(row)
	_selected = _next_enabled(-1, 1)
	_refresh_selection()

func _make_row(entry: Dictionary, index: int) -> Button:
	var reason: String = str(entry.get("reason", ""))
	var disabled: bool = reason != ""
	var row: Button = Button.new()
	row.focus_mode = Control.FOCUS_NONE
	row.disabled = disabled
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
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
	label.text = str(entry["text"])
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", ROW_DISABLED_COLOR if disabled else ROW_TEXT_COLOR)
	box.add_child(label)

	var side_text: String = reason if disabled else str(entry.get("hint", ""))
	if side_text != "":
		var side: Label = Label.new()
		side.text = side_text
		side.mouse_filter = Control.MOUSE_FILTER_IGNORE
		side.add_theme_font_size_override("font_size", 12)
		side.add_theme_color_override("font_color", ROW_DISABLED_COLOR if disabled else ROW_HINT_COLOR)
		box.add_child(side)

	row.mouse_entered.connect(_on_row_hovered.bind(index))
	row.pressed.connect(_run.bind(index))
	return row

func _next_enabled(from: int, step: int) -> int:
	var count: int = _shown.size()
	if count == 0:
		return -1
	var index: int = from
	for _attempt: int in count:
		index = posmod(index + step, count)
		if str(_shown[index].get("reason", "")) == "":
			return index
	return -1

func _refresh_selection() -> void:
	for index: int in _rows.size():
		var style: StyleBoxFlat = _row_active_style if index == _selected else _row_style
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			_rows[index].add_theme_stylebox_override(state, style)
	if _selected >= 0 and _selected < _rows.size():
		_scroll.ensure_control_visible(_rows[_selected])

func _on_row_hovered(index: int) -> void:
	if index < 0 or index >= _shown.size() or str(_shown[index].get("reason", "")) != "":
		return
	_selected = index
	_refresh_selection()

func _run(index: int) -> void:
	if index < 0 or index >= _shown.size():
		return
	var entry: Dictionary = _shown[index]
	if str(entry.get("reason", "")) != "":
		return
	var command_id: int = int(entry["id"])
	close()
	if _runner.is_valid():
		_runner.call_deferred(command_id)

func _input(event: InputEvent) -> void:
	if not is_open() or not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if key.pressed:
		var is_k: bool = key.keycode == KEY_K or key.physical_keycode == KEY_K
		if is_k and PlatformKeys.is_primary(key):
			if not key.is_echo():
				cancel()
			get_viewport().set_input_as_handled()
			return
		match key.keycode:
			KEY_DOWN:
				_selected = _next_enabled(_selected, 1)
				_refresh_selection()
				get_viewport().set_input_as_handled()
				return
			KEY_UP:
				_selected = _next_enabled(_selected, -1)
				_refresh_selection()
				get_viewport().set_input_as_handled()
				return
			KEY_ENTER, KEY_KP_ENTER:
				if not key.is_echo():
					_run(_selected)
				get_viewport().set_input_as_handled()
				return
	super(event)
