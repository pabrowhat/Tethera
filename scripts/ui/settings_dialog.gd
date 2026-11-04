class_name SettingsDialog
extends ModalDialog

signal saved
signal vault_change_requested(path: String)

const ICON_CHECK: Texture2D = preload("res://assets/icons/check.svg")
const ICON_CHEVRON: Texture2D = preload("res://assets/icons/chevron-down.svg")
const SWATCH_SHADER: Shader = preload("res://shaders/color_swatch.gdshader")
const DIALOG_WIDTH: float = 460.0
const ROW_HEIGHT: float = 30.0
const CHECK_SIZE: float = 16.0
const FONT_SIZE: int = 13
const HINT_SIZE: int = 12
const SWATCH_GAP: int = 8
const SLIDER_STEP: float = 0.1
const PROMPT_WIDTH: float = 380.0
const LANGUAGE_BUTTON_WIDTH: float = 170.0

var _reduce_motion: bool = false
var _show_grid: bool = true
var _export_linked: bool = false
var _note_color: Color = Color(Preferences.DEFAULT_NOTE_COLOR_HEX)
var _language: String = Localization.AUTO

var _boxes: Dictionary = {}
var _language_button: DropdownButton = null
var _line_slider: HSlider = null
var _line_value: Label = null
var _swatch_row: HFlowContainer = null
var _swatches: Array[ColorRect] = []
var _advanced_body: VBoxContainer = null
var _advanced_arrow: TextureRect = null
var _backups_spin: SpinBox = null
var _vault_dir: String = ""
var _vault_label: Label = null
var _folder_dialog_open: bool = false

var _prompt: ColorRect = null
var _prompt_title: Label = null
var _prompt_message: Label = null
var _prompt_buttons: HBoxContainer = null

var _row_style: StyleBoxFlat = UiStyle.box(Color(0.0, 0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 0.0), 5, 0.0, 0.0)
var _row_hover_style: StyleBoxFlat = UiStyle.box(UiStyle.BG_HOVER, UiStyle.BG_HOVER, 5, 0.0, 0.0)
var _box_off_style: StyleBoxFlat = UiStyle.box(UiStyle.BG_NORMAL, UiStyle.BORDER, 4, 0.0, 0.0)
var _box_on_style: StyleBoxFlat = UiStyle.box(UiStyle.ACCENT, UiStyle.ACCENT, 4, 0.0, 0.0)

func _init() -> void:
	super()
	_row_style.set_border_width_all(0)
	_row_hover_style.set_border_width_all(0)
	dismiss_on_backdrop = false
	_set_card_width(DIALOG_WIDTH)
	_build()
	_build_prompt()

func _build() -> void:
	_body.add_child(_make_label("settings.title", 15, TITLE_COLOR))

	_add_toggle(&"reduce_motion", "settings.reduce_motion", "settings.reduce_motion.hint", _on_reduce_motion_pressed)
	_add_toggle(&"show_grid", "settings.show_grid", "", _on_show_grid_pressed)
	_build_line_width()
	_build_note_color()
	_build_language()
	_build_advanced()

	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	_body.add_child(footer)
	var reset_button: Button = _make_button("settings.reset", false)
	reset_button.pressed.connect(_on_reset_pressed)
	footer.add_child(reset_button)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var cancel_button: Button = _make_button("settings.cancel", false)
	cancel_button.pressed.connect(_on_cancel_requested)
	footer.add_child(cancel_button)
	var save_button: Button = _make_button("settings.save", true)
	save_button.pressed.connect(_on_save_pressed)
	footer.add_child(save_button)

func _build_prompt() -> void:
	_prompt = ColorRect.new()
	_prompt.color = Color(0.03, 0.03, 0.05, 0.7)
	_prompt.mouse_filter = Control.MOUSE_FILTER_STOP
	_prompt.visible = false
	_prompt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_prompt)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_child(center)

	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(PROMPT_WIDTH, 0.0)
	panel.add_theme_stylebox_override("panel", UiStyle.box(PopupList.PANEL_BG, UiStyle.BORDER, 10, 18.0, 16.0))
	center.add_child(panel)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	_prompt_title = _make_label("", 15, TITLE_COLOR)
	box.add_child(_prompt_title)
	_prompt_message = _make_label("", FONT_SIZE, TEXT_COLOR, true)
	box.add_child(_prompt_message)
	_prompt_buttons = HBoxContainer.new()
	_prompt_buttons.add_theme_constant_override("separation", 10)
	_prompt_buttons.alignment = BoxContainer.ALIGNMENT_END
	box.add_child(_prompt_buttons)

func _build_line_width() -> void:
	var head: HBoxContainer = HBoxContainer.new()
	_body.add_child(head)
	var caption: Label = _make_label("settings.line_width", FONT_SIZE, TEXT_COLOR)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(caption)
	_line_value = _make_label("", FONT_SIZE, MUTED_COLOR)
	head.add_child(_line_value)

	_line_slider = HSlider.new()
	_line_slider.min_value = Preferences.LINE_WIDTH_MIN
	_line_slider.max_value = Preferences.LINE_WIDTH_MAX
	_line_slider.step = SLIDER_STEP
	_line_slider.focus_mode = Control.FOCUS_NONE
	_line_slider.custom_minimum_size = Vector2(0.0, 22.0)
	_line_slider.value_changed.connect(_on_line_width_changed)
	_body.add_child(_line_slider)

func _build_note_color() -> void:
	_body.add_child(_make_label("settings.default_color", FONT_SIZE, TEXT_COLOR))
	_body.add_child(_make_label("settings.default_color.hint", HINT_SIZE, MUTED_COLOR, true))
	_swatch_row = HFlowContainer.new()
	_swatch_row.add_theme_constant_override("h_separation", SWATCH_GAP)
	_swatch_row.add_theme_constant_override("v_separation", SWATCH_GAP)
	_body.add_child(_swatch_row)

func _build_language() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_body.add_child(row)
	var caption: Label = _make_label("settings.language", FONT_SIZE, TEXT_COLOR)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(caption)
	_language_button = DropdownButton.new()
	_language_button.custom_minimum_size = Vector2(LANGUAGE_BUTTON_WIDTH, 32.0)
	_fill_language_list()
	_language_button.item_selected.connect(_on_language_selected)
	row.add_child(_language_button)
	_body.add_child(_make_label("settings.language.hint", HINT_SIZE, MUTED_COLOR, true))

func _build_advanced() -> void:
	var header: Button = _make_row_button()
	header.pressed.connect(_toggle_advanced)
	var content: HBoxContainer = _make_row_content(header)
	_advanced_arrow = TextureRect.new()
	_advanced_arrow.texture = ICON_CHEVRON
	_advanced_arrow.custom_minimum_size = Vector2(CHECK_SIZE, CHECK_SIZE)
	_advanced_arrow.pivot_offset = Vector2(CHECK_SIZE, CHECK_SIZE) * 0.5
	_advanced_arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_advanced_arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_advanced_arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_advanced_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_advanced_arrow)
	var title: Label = _make_label("settings.advanced", FONT_SIZE, UiStyle.ACCENT)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(title)
	_body.add_child(header)

	_advanced_body = VBoxContainer.new()
	_advanced_body.add_theme_constant_override("separation", 10)
	_body.add_child(_advanced_body)

	var backups_row: HBoxContainer = HBoxContainer.new()
	backups_row.add_theme_constant_override("separation", 10)
	_advanced_body.add_child(backups_row)
	var backups_label: Label = _make_label("settings.backups", FONT_SIZE, TEXT_COLOR)
	backups_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	backups_row.add_child(backups_label)
	_backups_spin = SpinBox.new()
	_backups_spin.min_value = Preferences.BACKUPS_MIN
	_backups_spin.max_value = Preferences.BACKUPS_MAX
	_backups_spin.step = 1.0
	_backups_spin.rounded = true
	backups_row.add_child(_backups_spin)
	_advanced_body.add_child(_make_label("settings.backups.hint", HINT_SIZE, MUTED_COLOR, true))

	_add_toggle(&"export_linked", "settings.export_include_linked", "", _on_export_linked_pressed, _advanced_body)
	_build_vault_row()

func _build_vault_row() -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_advanced_body.add_child(row)
	var caption: Label = _make_label("settings.vault_dir", FONT_SIZE, TEXT_COLOR)
	row.add_child(caption)
	_vault_label = _make_label("", HINT_SIZE, MUTED_COLOR)
	_vault_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vault_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_vault_label.clip_text = true
	_vault_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_vault_label)
	var choose_button: Button = _make_button("settings.vault_dir.choose", false)
	choose_button.pressed.connect(_open_vault_picker)
	row.add_child(choose_button)
	_advanced_body.add_child(_make_label("settings.vault_dir.hint", HINT_SIZE, MUTED_COLOR, true))

func _show_vault_dir() -> void:
	_vault_label.text = _vault_dir
	_vault_label.tooltip_text = _vault_dir

func _open_vault_picker() -> void:
	if _folder_dialog_open:
		return
	_folder_dialog_open = true
	DisplayServer.file_dialog_show(
		tr("settings.vault_dir.dialog_title"),
		_vault_dir,
		"",
		false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_DIR,
		PackedStringArray(),
		_on_vault_picked
	)

func _on_vault_picked(status: bool, selected_paths: PackedStringArray, _filter_index: int) -> void:
	_folder_dialog_open = false
	if status and not selected_paths.is_empty():
		_vault_dir = selected_paths[0].replace("\\", "/")
		_show_vault_dir()

func _vault_changed() -> bool:
	return _same_dir_key(_vault_dir) != _same_dir_key(WorldRegistry.saved_vault_dir())

func _same_dir_key(path: String) -> String:
	return path.strip_edges().replace("\\", "/").trim_suffix("/").to_lower()


func open_with_current() -> void:
	_hide_prompt()
	var stored: Dictionary = {}
	for key: String in Preferences.defaults():
		stored[key] = Preferences.get_pref(key)
	_load_form(stored)
	_vault_dir = WorldRegistry.saved_vault_dir()
	_show_vault_dir()
	_set_advanced_open(false)
	open()

func _load_form(values: Dictionary) -> void:
	_reduce_motion = bool(values[Preferences.KEY_REDUCE_MOTION])
	_show_grid = bool(values[Preferences.KEY_SHOW_GRID])
	_export_linked = bool(values[Preferences.KEY_EXPORT_INCLUDE_LINKED])
	_note_color = Color(str(values[Preferences.KEY_DEFAULT_NOTE_COLOR]))
	_language = str(values[Preferences.KEY_LANGUAGE])
	_language_button.select_id(Localization.CHOICES.find(_language))

	_line_slider.set_value_no_signal(float(values[Preferences.KEY_LINE_WIDTH_SCALE]))
	_update_line_value()
	var backups: int = int(values[Preferences.KEY_BACKUPS_KEPT])
	_backups_spin.set_value_no_signal(float(backups))
	_backups_spin.get_line_edit().text = str(backups)
	_refresh_toggles()
	_rebuild_swatches()


func _current_values() -> Dictionary:
	if _backups_spin.get_line_edit().has_focus():
		_backups_spin.apply()
	return {
		Preferences.KEY_REDUCE_MOTION: _reduce_motion,
		Preferences.KEY_SHOW_GRID: _show_grid,
		Preferences.KEY_LINE_WIDTH_SCALE: snappedf(_line_slider.value, SLIDER_STEP),
		Preferences.KEY_DEFAULT_NOTE_COLOR: _note_color.to_html(false),
		Preferences.KEY_BACKUPS_KEPT: int(_backups_spin.value),
		Preferences.KEY_EXPORT_INCLUDE_LINKED: _export_linked,
		Preferences.KEY_LANGUAGE: _language,
	}

func has_unsaved_changes() -> bool:
	if not is_open():
		return false
	if _vault_changed():
		return true
	var current: Dictionary = _current_values()
	for key: String in current:
		var shown: Variant = Preferences.sanitize(key, current[key])
		var stored: Variant = Preferences.get_pref(key)
		if shown is float and stored is float:
			if not is_equal_approx(shown as float, stored as float):
				return true
		elif shown != stored:
			return true
	return false

func request_leave(after: Callable = Callable()) -> void:
	if not is_open():
		_run(after)
		return
	if not has_unsaved_changes():
		cancel()
		_run(after)
		return
	_show_prompt(tr("settings.unsaved.title"), tr("settings.unsaved.message"), [
		{"text": tr("settings.cancel"), "primary": false, "action": Callable()},
		{"text": tr("settings.unsaved.discard"), "primary": false, "action": _discard.bind(after)},
		{"text": tr("settings.save"), "primary": true, "action": _save_and_leave.bind(after)},
	])

func _discard(after: Callable) -> void:
	cancel()
	_run(after)

func _save_and_leave(after: Callable) -> void:
	_on_save_pressed(after)

func _run(action: Callable) -> void:
	if action.is_valid():
		action.call()

func _on_cancel_requested() -> void:
	if _prompt.visible:
		_hide_prompt()
	else:
		request_leave()

func _on_reset_pressed() -> void:
	_show_prompt(tr("settings.reset.title"), tr("settings.reset.message"), [
		{"text": tr("settings.cancel"), "primary": false, "action": Callable()},
		{"text": tr("settings.reset.confirm"), "primary": true, "action": _load_form.bind(Preferences.defaults())},
	])

func _show_prompt(title: String, message: String, options: Array[Dictionary]) -> void:
	_prompt_title.text = title
	_prompt_message.text = message
	for child: Node in _prompt_buttons.get_children():
		_prompt_buttons.remove_child(child)
		child.queue_free()
	for option: Dictionary in options:
		var button: Button = _make_button(str(option["text"]), bool(option["primary"]))
		button.pressed.connect(_on_prompt_answered.bind(option["action"] as Callable))
		_prompt_buttons.add_child(button)
	_prompt.visible = true

func _on_prompt_answered(action: Callable) -> void:
	_hide_prompt()
	_run(action)

func _hide_prompt() -> void:
	_prompt.visible = false


func _add_toggle(key: StringName, text: String, hint: String, on_press: Callable, parent: Control = null) -> void:
	var target: Control = parent if parent != null else _body
	var row: Button = _make_row_button()
	row.pressed.connect(on_press)
	var content: HBoxContainer = _make_row_content(row)
	var box: PanelContainer = _make_checkbox()
	content.add_child(box)
	var label: Label = _make_label(text, FONT_SIZE, TEXT_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)
	target.add_child(row)
	_boxes[key] = box
	if hint != "":
		target.add_child(_make_label(hint, HINT_SIZE, MUTED_COLOR, true))

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
	return box

func _set_checked(key: StringName, checked: bool) -> void:
	var box: PanelContainer = _boxes[key]
	(box.get_child(0) as TextureRect).visible = checked
	box.add_theme_stylebox_override("panel", _box_on_style if checked else _box_off_style)

func _refresh_toggles() -> void:
	_set_checked(&"reduce_motion", _reduce_motion)
	_set_checked(&"show_grid", _show_grid)
	_set_checked(&"export_linked", _export_linked)


func _color_choices() -> Array[Color]:
	var choices: Array[Color] = []
	choices.append_array(SidebarEditor.COLOR_PALETTE)
	for slot: int in PaletteStore.SLOT_COUNT:
		var saved_color: Variant = PaletteStore.instance().get_slot(slot)
		if saved_color != null and not _has_color(choices, saved_color as Color):
			choices.append(saved_color as Color)
	if not _has_color(choices, _note_color):
		choices.append(_note_color)
	return choices

func _has_color(colors: Array[Color], wanted: Color) -> bool:
	for color: Color in colors:
		if color.is_equal_approx(wanted):
			return true
	return false

func _rebuild_swatches() -> void:
	for child: Node in _swatch_row.get_children():
		_swatch_row.remove_child(child)
		child.queue_free()
	_swatches = SwatchPalette.build(_swatch_row, _color_choices(), SWATCH_SHADER, _on_color_picked)
	SwatchPalette.set_active(_swatches, _note_color)

func _on_color_picked(color: Color) -> void:
	_note_color = color
	SwatchPalette.set_active(_swatches, _note_color)


func _on_reduce_motion_pressed() -> void:
	_reduce_motion = not _reduce_motion
	_refresh_toggles()

func _on_show_grid_pressed() -> void:
	_show_grid = not _show_grid
	_refresh_toggles()

func _on_export_linked_pressed() -> void:
	_export_linked = not _export_linked
	_refresh_toggles()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _language_button != null:
		_fill_language_list()

func _fill_language_list() -> void:
	_language_button.clear()
	for index: int in Localization.CHOICES.size():
		_language_button.add_item(tr("settings.language." + Localization.CHOICES[index]), index)
	_language_button.select_id(Localization.CHOICES.find(_language))

func _on_language_selected(id: int) -> void:
	_language = Localization.CHOICES[id]

func _on_line_width_changed(_value: float) -> void:
	_update_line_value()

func _update_line_value() -> void:
	_line_value.text = tr("settings.line_width.value") % snappedf(_line_slider.value, SLIDER_STEP)

func _toggle_advanced() -> void:
	_set_advanced_open(not _advanced_body.visible)

func _set_advanced_open(open_section: bool) -> void:
	_advanced_body.visible = open_section
	_advanced_arrow.rotation = 0.0 if open_section else -PI / 2.0

func _on_save_pressed(after: Callable = Callable()) -> void:
	if not _vault_changed():
		_finish_save(false, after)
		return
	var status: String = WorldRegistry.vault_dir_status(_vault_dir)
	if status != "" and status != WorldRegistry.VAULT_MISSING:
		_show_prompt(tr("settings.vault.confirm.title"), tr(status), [
			{"text": tr("worlds.name.ok"), "primary": true, "action": Callable()},
		])
		return
	_show_prompt(tr("settings.vault.confirm.title"), tr("settings.vault.confirm.message") % _vault_dir, [
		{"text": tr("settings.cancel"), "primary": false, "action": Callable()},
		{"text": tr("settings.vault.confirm.action"), "primary": true, "action": _after_vault_confirmed.bind(status, after)},
	])

func _after_vault_confirmed(status: String, after: Callable) -> void:
	if status != WorldRegistry.VAULT_MISSING:
		_finish_save(true, after)
		return
	_show_prompt(tr("settings.vault.create.title"), tr("settings.vault.create.message") % _vault_dir, [
		{"text": tr("settings.cancel"), "primary": false, "action": Callable()},
		{"text": tr("settings.vault.create.action"), "primary": true, "action": _create_vault_and_save.bind(after)},
	])

func _create_vault_and_save(after: Callable) -> void:
	var reason: String = WorldRegistry.create_vault_dir(_vault_dir)
	if reason != "":
		_show_prompt(tr("settings.vault.confirm.title"), tr(reason), [
			{"text": tr("worlds.name.ok"), "primary": true, "action": Callable()},
		])
		return
	_finish_save(true, after)

func _finish_save(vault_changed: bool, after: Callable) -> void:
	Preferences.save(_current_values())
	_hide_prompt()
	close()
	saved.emit()
	if vault_changed:
		vault_change_requested.emit(_vault_dir)
	_run(after)
