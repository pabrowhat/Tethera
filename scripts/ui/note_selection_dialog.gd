class_name NoteSelectionDialog
extends ModalDialog

const ICON_CHECK: Texture2D = preload("res://assets/icons/check.svg")
const DIALOG_WIDTH: float = 480.0
const LIST_MAX_HEIGHT: float = 260.0
const ROW_HEIGHT: float = 30.0
const ROW_GAP: int = 2
const LINKED_GROUP_GAP: int = 10
const LINKED_HEADER_ROOM: float = 64.0
const CHECK_SIZE: float = 16.0
const SUMMARY_LIMIT: int = 4
const FONT_SIZE: int = 13

var _on_action: Callable = Callable()
var _notes: Array[Dictionary] = []
var _connections: Array[Dictionary] = []
var _types: Array[Dictionary] = []
var _type_names: Dictionary = {}
var _existing_titles: Dictionary = {}
var _selected: Dictionary = {}
var _include_linked: bool = false
var _with_project_options: bool = true

var _search: LineEdit = null
var _counter: Label = null
var _types_label: Label = null
var _images_label: Label = null
var _warning: Label = null
var _linked_box: PanelContainer = null
var _scroll: ScrollContainer = null
var _list: VBoxContainer = null
var _linked_group: VBoxContainer = null
var _linked_title: Label = null
var _linked_list: VBoxContainer = null
var _action_buttons: Array[Button] = []
var _action_needs_notes: Array[bool] = []

var _rows: Dictionary = {}
var _boxes: Dictionary = {}
var _marks: Dictionary = {}

var _row_style: StyleBoxFlat = UiStyle.box(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 5, 0.0, 0.0)
var _row_hover_style: StyleBoxFlat = UiStyle.box(UiStyle.BG_HOVER, UiStyle.BG_HOVER, 5, 0.0, 0.0)
var _box_off_style: StyleBoxFlat = UiStyle.box(UiStyle.BG_NORMAL, UiStyle.BORDER, 4, 0.0, 0.0)
var _box_on_style: StyleBoxFlat = UiStyle.box(UiStyle.ACCENT, UiStyle.ACCENT, 4, 0.0, 0.0)
var _box_linked_style: StyleBoxFlat = UiStyle.box(UiStyle.ACCENT_SOFT, UiStyle.ACCENT_SOFT, 4, 0.0, 0.0)

func _init() -> void:
	super()
	_row_style.set_border_width_all(0)
	_row_hover_style.set_border_width_all(0)
	_set_card_width(DIALOG_WIDTH)

func open_for(dialog_title: String, notes: Array[Dictionary], connections: Array[Dictionary], types: Array[Dictionary], \
		preselected: Array[String], existing_titles: Dictionary, actions: Array[Dictionary], on_action: Callable, \
		with_project_options: bool = true, include_linked: bool = false) -> void:
	_on_action = on_action
	_with_project_options = with_project_options
	_notes = notes
	_connections = connections
	_types = types
	_existing_titles = existing_titles
	_include_linked = include_linked and with_project_options
	_selected.clear()
	for id: String in preselected:
		_selected[id] = true
	_type_names.clear()
	for entity_type: Dictionary in types:
		_type_names[str(entity_type.get("id", ""))] = str(entity_type.get("name", ""))

	_build(dialog_title, actions)
	_refresh()
	open()
	_search.grab_focus()

func _build(dialog_title: String, actions: Array[Dictionary]) -> void:
	_clear_body()
	_rows.clear()
	_boxes.clear()
	_marks.clear()
	_action_buttons.clear()
	_action_needs_notes.clear()

	_body.add_child(_make_label(dialog_title, 15, TITLE_COLOR))

	_search = LineEdit.new()
	_search.placeholder_text = "select.search"
	_search.clear_button_enabled = true
	_search.add_theme_font_size_override("font_size", FONT_SIZE)
	_search.text_changed.connect(_on_search_changed)
	_body.add_child(_search)

	var tools: HBoxContainer = HBoxContainer.new()
	tools.add_theme_constant_override("separation", 6)
	_body.add_child(tools)
	var all_button: Button = _make_button("select.all", false)
	all_button.pressed.connect(_set_visible_rows.bind(true))
	tools.add_child(all_button)
	var none_button: Button = _make_button("select.none", false)
	none_button.pressed.connect(_set_visible_rows.bind(false))
	tools.add_child(none_button)
	_counter = _make_label("", FONT_SIZE, MUTED_COLOR)
	_counter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tools.add_child(_counter)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(_scroll)
	var lists: VBoxContainer = VBoxContainer.new()
	lists.add_theme_constant_override("separation", LINKED_GROUP_GAP)
	lists.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(lists)
	_list = _make_row_list()
	lists.add_child(_list)
	for note: Dictionary in _notes:
		_add_row(_list, note)

	_linked_group = VBoxContainer.new()
	_linked_group.add_theme_constant_override("separation", ROW_GAP)
	_linked_group.visible = false
	lists.add_child(_linked_group)
	_linked_title = _make_label("", FONT_SIZE, UiStyle.ACCENT)
	_linked_group.add_child(_linked_title)
	_linked_group.add_child(_make_label("select.linked_group.hint", 12, MUTED_COLOR, true))
	_linked_list = _make_row_list()
	_linked_group.add_child(_linked_list)

	var linked_row: Button = _make_row_button()
	linked_row.pressed.connect(_on_include_linked_pressed)
	var linked_content: HBoxContainer = _make_row_content(linked_row)
	_linked_box = _make_checkbox()
	linked_content.add_child(_linked_box)
	var linked_label: Label = _make_label("select.include_linked", FONT_SIZE, TEXT_COLOR)
	linked_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linked_content.add_child(linked_label)
	linked_row.visible = _with_project_options
	_body.add_child(linked_row)

	_types_label = _make_label("", 12, MUTED_COLOR, true)
	_types_label.visible = _with_project_options
	_body.add_child(_types_label)
	_images_label = _make_label("", 12, MUTED_COLOR, true)
	_images_label.visible = _with_project_options
	_body.add_child(_images_label)
	_warning = _make_label("", 12, WARNING_COLOR, true)
	_body.add_child(_warning)

	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	footer.alignment = BoxContainer.ALIGNMENT_END
	_body.add_child(footer)
	var cancel_button: Button = _make_button("select.cancel", false)
	cancel_button.pressed.connect(cancel)
	footer.add_child(cancel_button)
	for action: Dictionary in actions:
		var button: Button = _make_button(str(action.get("text", "")), bool(action.get("primary", false)))
		button.pressed.connect(_on_action_pressed.bind(int(action.get("id", 0))))
		footer.add_child(button)
		_action_buttons.append(button)
		_action_needs_notes.append(bool(action.get("needs_notes", true)))

func _add_row(list: VBoxContainer, note: Dictionary) -> void:
	var note_id: String = str(note.get("id", ""))
	var row: Button = _make_row_button()
	row.pressed.connect(_on_row_pressed.bind(note_id))
	var content: HBoxContainer = _make_row_content(row)

	var box: PanelContainer = _make_checkbox()
	content.add_child(box)

	var title_label: Label = _make_label(str(note.get("title", "")), FONT_SIZE, TEXT_COLOR)
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title_label)

	var mark: Label = _make_label("", 12, MUTED_COLOR)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(mark)

	list.add_child(row)
	_rows[note_id] = row
	_boxes[note_id] = box
	_marks[note_id] = mark

func _make_row_list() -> VBoxContainer:
	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", ROW_GAP)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return list

func _make_row_button() -> Button:
	var row: Button = Button.new()
	row.focus_mode = Control.FOCUS_NONE
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	for state: String in ["normal", "pressed", "disabled", "focus"]:
		row.add_theme_stylebox_override(state, _row_style)
	for state: String in ["hover", "hover_pressed"]:
		row.add_theme_stylebox_override(state, _row_hover_style)
	return row

func _make_row_content(row: Button) -> HBoxContainer:
	var content: HBoxContainer = HBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 8.0
	content.offset_right = -8.0
	row.add_child(content)
	return content

func _make_checkbox() -> PanelContainer:
	var box: PanelContainer = PanelContainer.new()
	box.custom_minimum_size = Vector2(CHECK_SIZE, CHECK_SIZE)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tick: TextureRect = TextureRect.new()
	tick.texture = ICON_CHECK
	tick.modulate = TITLE_COLOR
	tick.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tick.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tick)
	_set_checked(box, false, false)
	return box

func _set_checked(box: PanelContainer, checked: bool, included: bool) -> void:
	(box.get_child(0) as TextureRect).visible = checked
	if checked:
		box.add_theme_stylebox_override("panel", _box_on_style)
	elif included:
		box.add_theme_stylebox_override("panel", _box_linked_style)
	else:
		box.add_theme_stylebox_override("panel", _box_off_style)


func _selected_ids() -> Array[String]:
	var ids: Array[String] = []
	for note: Dictionary in _notes:
		var note_id: String = str(note.get("id", ""))
		if _selected.has(note_id):
			ids.append(note_id)
	return ids

func _refresh() -> void:
	var picked: Array[String] = _selected_ids()
	var result: Dictionary = ProjectSelection.select(_notes, _connections, _types, picked, _include_linked)
	var linked: Array[String] = result["linked_ids"]
	var result_ids: Array[String] = result["ids"]

	var duplicates: int = 0
	var main_count: int = 0
	var linked_count: int = 0
	for note: Dictionary in _notes:
		var note_id: String = str(note.get("id", ""))
		var is_picked: bool = _selected.has(note_id)
		var is_linked: bool = linked.has(note_id) and not is_picked
		_set_checked(_boxes[note_id] as PanelContainer, is_picked, is_linked)

		var row: Button = _rows[note_id]
		var target: VBoxContainer = _linked_list if is_linked else _list
		if row.get_parent() != target:
			row.reparent(target, false)
		if is_linked:
			target.move_child(row, linked_count)
			linked_count += 1
		else:
			target.move_child(row, main_count)
			main_count += 1

		var mark: Label = _marks[note_id]
		var is_duplicate: bool = _existing_titles.has(str(note.get("title", "")).strip_edges().to_lower())
		if is_duplicate and (is_picked or is_linked):
			duplicates += 1
		if is_duplicate:
			mark.text = "select.row.duplicate"
			mark.add_theme_color_override("font_color", WARNING_COLOR)
		elif is_linked:
			mark.text = "select.row.linked"
			mark.add_theme_color_override("font_color", UiStyle.ACCENT)
		else:
			mark.text = str(_type_names.get(str(note.get("type", "")), ""))
			mark.add_theme_color_override("font_color", MUTED_COLOR)

	_set_checked(_linked_box, _include_linked, false)
	_linked_group.visible = linked_count > 0
	_linked_title.text = tr("select.linked_group") % linked_count
	var row_height: float = ROW_HEIGHT + float(ROW_GAP)
	var list_height: float = float(_notes.size()) * row_height + (LINKED_HEADER_ROOM if linked_count > 0 else 0.0)
	_scroll.custom_minimum_size = Vector2(0.0, clampf(list_height, ROW_HEIGHT, LIST_MAX_HEIGHT))

	var counter_text: String = tr("select.counter") % [picked.size(), _notes.size()]
	if not linked.is_empty():
		counter_text += tr("select.counter.linked") % linked.size()
	_counter.text = counter_text

	var type_names: Array[String] = []
	for entity_type: Dictionary in (result["types"] as Array[Dictionary]):
		type_names.append(str(entity_type.get("name", "")))
	_types_label.text = tr("select.types") % _summarize(type_names) if not type_names.is_empty() else tr("select.types.none")

	var image_names: Array[String] = []
	for image: String in (result["images"] as PackedStringArray):
		image_names.append(image.get_file())
	_images_label.text = tr("select.images") % _summarize(image_names) if not image_names.is_empty() else tr("select.images.none")

	_warning.visible = duplicates > 0
	_warning.text = tr("select.duplicates") % duplicates

	for i: int in _action_buttons.size():
		_action_buttons[i].disabled = _action_needs_notes[i] and result_ids.is_empty()

func _summarize(names: Array[String]) -> String:
	var shown: PackedStringArray = PackedStringArray(names.slice(0, SUMMARY_LIMIT))
	if names.size() <= SUMMARY_LIMIT:
		return ", ".join(shown)
	return "%s, %s" % [", ".join(shown), tr("select.more") % (names.size() - SUMMARY_LIMIT)]


func _on_row_pressed(note_id: String) -> void:
	if _selected.has(note_id):
		_selected.erase(note_id)
	else:
		_selected[note_id] = true
	_refresh()

func _on_include_linked_pressed() -> void:
	_include_linked = not _include_linked
	_refresh()

func _set_visible_rows(on: bool) -> void:
	for note_id: String in _rows:
		if not (_rows[note_id] as Button).visible:
			continue
		if on:
			_selected[note_id] = true
		else:
			_selected.erase(note_id)
	_refresh()

func _on_search_changed(_new_text: String) -> void:
	var query: String = _search.text.strip_edges()
	for note: Dictionary in _notes:
		var note_id: String = str(note.get("id", ""))
		(_rows[note_id] as Button).visible = FuzzyMatcher.score(query, str(note.get("title", ""))) >= 0

func _on_action_pressed(action_id: int) -> void:
	var picked: Array[String] = _selected_ids()
	var include_linked: bool = _include_linked
	close()
	if _on_action.is_valid():
		_on_action.call(action_id, picked, include_linked)
