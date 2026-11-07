class_name StartScreen
extends ColorRect

signal open_requested(world_id: String)
signal rename_requested(world_id: String)
signal delete_requested(world_id: String)
signal create_requested
signal import_requested
signal settings_requested
signal about_requested
signal quit_requested

const BACKGROUND: StringName = &"start.background"
const CONTENT_WIDTH: float = 640.0
const LIST_HEIGHT: float = 320.0
const ROW_HEIGHT: float = 48.0
const DAMAGED_ALPHA: float = 0.45
const BACKDROP_SHADER: Shader = preload("res://shaders/start_backdrop.gdshader")

var input_blocked: Callable = Callable()

var _worlds: Array[Dictionary] = []
var _last_id: String = ""
var _selected_id: String = ""
var _is_open: bool = false
var _row_group: ButtonGroup = null
var _rows_box: VBoxContainer = null
var _scroll: ScrollContainer = null
var _empty_label: Label = null
var _open_button: Button = null
var _error_label: Label = null
var _row_by_id: Dictionary = {}
var _backdrop: ColorRect = null
var _backdrop_material: ShaderMaterial = null
var _usable_count: int = 0
var _frame_shown: bool = false

func _init() -> void:
	ThemeColors.bind(self, &"color", BACKGROUND)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_backdrop = ColorRect.new()
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop_material: ShaderMaterial = ShaderMaterial.new()
	backdrop_material.shader = BACKDROP_SHADER
	_backdrop_material = backdrop_material
	_backdrop.material = backdrop_material
	_backdrop.resized.connect(_on_backdrop_resized)
	add_child(_backdrop)
	ThemeColors.watch(_apply_theme_colors)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size = Vector2(CONTENT_WIDTH, 0.0)
	column.add_theme_constant_override("separation", 14)
	center.add_child(column)

	column.add_child(_make_label(ProjectSettings.get_setting("application/config/name", "Tethera"), 34, ModalDialog.TITLE_COLOR))
	column.add_child(_make_label("start.subtitle", 14, ModalDialog.MUTED_COLOR))
	column.add_child(_make_label("start.worlds", 13, ModalDialog.TEXT_COLOR))

	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(0.0, LIST_HEIGHT)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override("separation", 4)
	_scroll.add_child(_rows_box)
	_empty_label = _make_label("worlds.empty_list", 13, ModalDialog.MUTED_COLOR, true)
	column.add_child(_empty_label)

	_error_label = _make_label("", 12, ModalDialog.WARNING_COLOR, true)
	_error_label.visible = false
	column.add_child(_error_label)

	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	column.add_child(footer)
	_open_button = _make_button("start.open", true)
	_open_button.pressed.connect(_request_open)
	footer.add_child(_open_button)
	var create_button: Button = _make_button("start.create", false)
	create_button.pressed.connect(func() -> void: create_requested.emit())
	footer.add_child(create_button)
	var import_button: Button = _make_button("start.import", false)
	import_button.pressed.connect(func() -> void: import_requested.emit())
	footer.add_child(import_button)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var settings_button: Button = _make_button("start.settings", false)
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	footer.add_child(settings_button)
	var about_button: Button = _make_button("start.about", false)
	about_button.pressed.connect(func() -> void: about_requested.emit())
	footer.add_child(about_button)
	var quit_button: Button = _make_button("start.quit", false)
	quit_button.pressed.connect(func() -> void: quit_requested.emit())
	footer.add_child(quit_button)

	set_process_input(false)

func _apply_theme_colors() -> void:
	_backdrop_material.set_shader_parameter("base_color", ThemeColors.color(&"start.base"))
	_backdrop_material.set_shader_parameter("glow_a", ThemeColors.color(&"start.glow_a"))
	_backdrop_material.set_shader_parameter("glow_b", ThemeColors.color(&"start.glow_b"))
	_backdrop_material.set_shader_parameter("star_color", ThemeColors.color(&"start.star"))
	_backdrop_material.set_shader_parameter("vignette_color", ThemeColors.color(&"start.vignette"))

func _on_backdrop_resized() -> void:
	(_backdrop.material as ShaderMaterial).set_shader_parameter("rect_size", _backdrop.size)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _rows_box != null and _is_open:
		_rebuild_rows()

func is_open() -> bool:
	return _is_open

func show_worlds(worlds: Array[Dictionary], last_id: String) -> void:
	_worlds = worlds
	_last_id = last_id
	_selected_id = ""
	_frame_shown = false
	if _is_usable(last_id):
		_selected_id = last_id
	else:
		for world: Dictionary in worlds:
			if bool(world["ok"]):
				_selected_id = str(world["id"])
				break
	_rebuild_rows()
	show_error("")
	_is_open = true
	visible = true
	set_process_input(true)

func refresh(worlds: Array[Dictionary], last_id: String) -> void:
	var keep: String = _selected_id
	var keep_frame: bool = _frame_shown
	show_worlds(worlds, last_id)
	if keep != "" and _is_usable(keep):
		_frame_shown = keep_frame
		_select(keep)

func close() -> void:
	_is_open = false
	visible = false
	set_process_input(false)

func show_error(text: String) -> void:
	_error_label.text = text
	_error_label.visible = text != ""

func _is_usable(world_id: String) -> bool:
	for world: Dictionary in _worlds:
		if str(world["id"]) == world_id:
			return bool(world["ok"])
	return false

func _rebuild_rows() -> void:
	for child: Node in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()
	_row_by_id.clear()
	_row_group = ButtonGroup.new()
	var now: int = int(Time.get_unix_time_from_system())
	_usable_count = 0
	for world: Dictionary in _worlds:
		if bool(world["ok"]):
			_usable_count += 1
	for world: Dictionary in _worlds:
		_rows_box.add_child(_make_row(world, now))
	_empty_label.visible = _worlds.is_empty()
	_update_buttons()

func _make_row(world: Dictionary, now: int) -> HBoxContainer:
	var world_id: String = str(world["id"])
	var usable: bool = bool(world["ok"])
	var row: Button = Button.new()
	row.toggle_mode = true
	row.button_group = _row_group
	row.focus_mode = Control.FOCUS_NONE
	row.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_stylebox_override("normal", UiStyle.box(UiStyle.BG_NORMAL, UiStyle.BG_NORMAL, 6, 12.0, 6.0))
	row.add_theme_stylebox_override("hover", UiStyle.box(UiStyle.BG_HOVER, UiStyle.BG_HOVER, 6, 12.0, 6.0))
	row.add_theme_stylebox_override("pressed", UiStyle.box(UiStyle.ACCENT_TINT, UiStyle.ACCENT, 6, 12.0, 6.0))
	row.add_theme_stylebox_override("hover_pressed", UiStyle.box(UiStyle.ACCENT_TINT, UiStyle.ACCENT, 6, 12.0, 6.0))
	row.add_theme_stylebox_override("disabled", UiStyle.box(UiStyle.BG_NORMAL, UiStyle.BG_NORMAL, 6, 12.0, 6.0))

	var line: HBoxContainer = HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	line.offset_left = 12.0
	line.offset_right = -12.0
	line.add_theme_constant_override("separation", 12)
	row.add_child(line)

	var shown_name: String = str(world["name"]) if str(world["name"]) != "" else world_id.substr(0, 8)
	var name_label: Label = _make_label(shown_name, 14, ModalDialog.TITLE_COLOR)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	line.add_child(name_label)

	if not usable:
		line.add_child(_make_label("worlds.damaged", 12, ModalDialog.WARNING_COLOR))
	elif world_id == _last_id:
		line.add_child(_make_label("start.last_world", 12, UiStyle.ACCENT))

	var meta: String = tr("worlds.notes") % int(world.get("notes", 0))
	var modified: int = int(world.get("modified", 0))
	if modified > 0:
		meta += "   " + RecentNotes.relative_time(modified, now)
	line.add_child(_make_label(meta, 12, ModalDialog.MUTED_COLOR))

	for label: Node in line.get_children():
		(label as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE

	var entry: HBoxContainer = HBoxContainer.new()
	entry.add_theme_constant_override("separation", 6)
	entry.add_child(row)
	if usable:
		row.set_pressed_no_signal(_frame_shown and world_id == _selected_id)
		row.pressed.connect(_pick_with_mouse.bind(world_id))
		row.gui_input.connect(_on_row_input.bind(world_id))
		_row_by_id[world_id] = row
		var rename_button: Button = _make_button("worlds.rename", false)
		rename_button.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
		rename_button.pressed.connect(func() -> void: rename_requested.emit(world_id))
		entry.add_child(rename_button)
		if _usable_count > 1:
			var delete_button: Button = _make_button("worlds.delete", false)
			delete_button.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
			delete_button.pressed.connect(func() -> void: delete_requested.emit(world_id))
			entry.add_child(delete_button)
	else:
		row.disabled = true
		row.modulate.a = DAMAGED_ALPHA
		var damaged_delete: Button = _make_button("worlds.delete", false)
		damaged_delete.custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
		damaged_delete.pressed.connect(func() -> void: delete_requested.emit(world_id))
		entry.add_child(damaged_delete)
	return entry

func _pick_with_mouse(world_id: String) -> void:
	_frame_shown = true
	_select(world_id)

func _select(world_id: String) -> void:
	_selected_id = world_id
	show_error("")
	for other_id: String in _row_by_id:
		(_row_by_id[other_id] as Button).set_pressed_no_signal(_frame_shown and other_id == world_id)
	var row: Button = _row_by_id.get(world_id) as Button
	if row != null:
		_scroll.ensure_control_visible(row)
	_update_buttons()

func _on_row_input(event: InputEvent, world_id: String) -> void:
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT and click.double_click:
			_select(world_id)
			_request_open()

func _update_buttons() -> void:
	_open_button.disabled = _selected_id == "" or not _is_usable(_selected_id)

func _request_open() -> void:
	if not _open_button.disabled:
		open_requested.emit(_selected_id)

func _move_selection(step: int) -> void:
	var usable_ids: Array[String] = []
	for world: Dictionary in _worlds:
		if bool(world["ok"]):
			usable_ids.append(str(world["id"]))
	if usable_ids.is_empty():
		return
	var index: int = usable_ids.find(_selected_id)
	_frame_shown = true
	index = clampi(index + step if index >= 0 else 0, 0, usable_ids.size() - 1)
	_select(usable_ids[index])

func _input(event: InputEvent) -> void:
	if not _is_open or not (event is InputEventKey):
		return
	if input_blocked.is_valid() and bool(input_blocked.call()):
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed:
		return
	match key.keycode:
		KEY_DOWN:
			_move_selection(1)
		KEY_UP:
			_move_selection(-1)
		KEY_TAB:
			_move_selection(-1 if key.shift_pressed else 1)
		KEY_ENTER, KEY_KP_ENTER:
			if not key.is_echo():
				_request_open()
		KEY_ESCAPE:
			pass
		_:
			return
	get_viewport().set_input_as_handled()

func _make_label(text: String, font_size: int, text_color: StringName, wrap: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	ThemeColors.bind_override(label, &"font_color", text_color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _make_button(text: String, primary: bool) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, 36.0)
	button.add_theme_font_size_override("font_size", 13)
	if primary:
		ThemeColors.bind_override(button, &"font_color", &"text.on_accent")
		ThemeColors.bind_override(button, &"font_hover_color", &"text.on_accent")
		ThemeColors.bind_override(button, &"font_pressed_color", &"text.on_accent")
		ThemeColors.bind_override(button, &"font_disabled_color", &"text.disabled")
		button.add_theme_stylebox_override("normal", UiStyle.box(UiStyle.ACCENT_SOFT, UiStyle.ACCENT_SOFT, 6, 16.0, 8.0))
		button.add_theme_stylebox_override("hover", UiStyle.box(UiStyle.ACCENT, UiStyle.ACCENT, 6, 16.0, 8.0))
		button.add_theme_stylebox_override("pressed", UiStyle.box(UiStyle.ACCENT, UiStyle.ACCENT, 6, 16.0, 8.0))
		button.add_theme_stylebox_override("disabled", UiStyle.box(UiStyle.BG_NORMAL, UiStyle.BG_NORMAL, 6, 16.0, 8.0))
	else:
		ThemeColors.bind_override(button, &"font_color", ModalDialog.TEXT_COLOR)
		button.add_theme_stylebox_override("normal", UiStyle.box(UiStyle.BG_NORMAL, UiStyle.BG_NORMAL, 6, 16.0, 8.0))
		button.add_theme_stylebox_override("hover", UiStyle.box(UiStyle.BG_HOVER, UiStyle.BG_HOVER, 6, 16.0, 8.0))
	return button
