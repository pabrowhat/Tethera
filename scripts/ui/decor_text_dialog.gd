class_name DecorTextDialog
extends ModalDialog

signal applied(text: String, color_hex: String, font_size: int, align: String)

const SWATCH_SHADER: Shader = preload("res://shaders/color_swatch.gdshader")
const DIALOG_WIDTH: float = 460.0
const TEXT_HEIGHT: float = 160.0
const FONT_SIZE: int = 13
const ALIGN_ICON_WIDTH: int = 16
const ALIGN_BUTTON_WIDTH: float = 44.0
const ALIGN_ICONS: Dictionary = {
	DecorItem.ALIGN_LEFT: preload("res://assets/icons/align-left.svg"),
	DecorItem.ALIGN_CENTER: preload("res://assets/icons/align-center.svg"),
	DecorItem.ALIGN_RIGHT: preload("res://assets/icons/align-right.svg"),
}
const ALIGN_TOOLTIPS: Dictionary = {
	DecorItem.ALIGN_LEFT: "format.align_left",
	DecorItem.ALIGN_CENTER: "format.align_center",
	DecorItem.ALIGN_RIGHT: "format.align_right",
}

var _edit: TextEdit = null
var _count_label: Label = null
var _size_spin: SpinBox = null
var _color_bar: ColorBar = null
var _theme_button: Button = null
var _color_hex: String = ""
var _align: String = DecorItem.ALIGN_LEFT
var _align_buttons: Dictionary = {}

func _init() -> void:
	super()
	dismiss_on_backdrop = false
	_set_card_width(DIALOG_WIDTH)
	_body.add_child(_make_label("decor.text.title", 15, TITLE_COLOR))

	_edit = TextEdit.new()
	_edit.custom_minimum_size = Vector2(0.0, TEXT_HEIGHT)
	_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_edit.placeholder_text = "decor.text.placeholder"
	_edit.text_changed.connect(_on_text_changed)
	_body.add_child(_edit)
	_count_label = _make_label("", 12, MUTED_COLOR)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_body.add_child(_count_label)

	var size_row: HBoxContainer = HBoxContainer.new()
	size_row.add_theme_constant_override("separation", 10)
	_body.add_child(size_row)
	var size_label: Label = _make_label("decor.text.size", FONT_SIZE, TEXT_COLOR)
	size_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_row.add_child(size_label)
	_size_spin = SpinBox.new()
	_size_spin.min_value = DecorItem.TEXT_MIN_FONT_SIZE
	_size_spin.max_value = DecorItem.TEXT_MAX_FONT_SIZE
	_size_spin.step = 1.0
	_size_spin.rounded = true
	size_row.add_child(_size_spin)

	var align_row: HBoxContainer = HBoxContainer.new()
	align_row.add_theme_constant_override("separation", 6)
	_body.add_child(align_row)
	var align_label: Label = _make_label("decor.text.align", FONT_SIZE, TEXT_COLOR)
	align_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	align_row.add_child(align_label)
	for choice: String in ALIGN_ICONS:
		var align_button: Button = _make_button("", false)
		align_button.icon = ALIGN_ICONS[choice] as Texture2D
		align_button.custom_minimum_size = Vector2(ALIGN_BUTTON_WIDTH, 34.0)
		align_button.expand_icon = true
		for icon_color: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color"]:
			ThemeColors.bind_override(align_button, StringName(icon_color), TITLE_COLOR)
		align_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		align_button.add_theme_constant_override("icon_max_width", ALIGN_ICON_WIDTH)
		align_button.tooltip_text = ALIGN_TOOLTIPS[choice] as String
		align_button.toggle_mode = true
		_style_toggle(align_button)
		align_button.pressed.connect(_on_align_pressed.bind(choice))
		align_row.add_child(align_button)
		_align_buttons[choice] = align_button

	_body.add_child(_make_label("decor.text.color", FONT_SIZE, TEXT_COLOR))
	_color_bar = ColorBar.new()
	_color_bar.setup(SWATCH_SHADER)
	_color_bar.set_eyedropper_visible(false)
	_color_bar.color_picked.connect(_on_color_picked)
	_color_bar.color_previewed.connect(_on_color_picked)
	_color_bar.color_committed.connect(_on_color_picked)
	_body.add_child(_color_bar)

	_theme_button = _make_button("decor.text.theme_color", false)
	_theme_button.toggle_mode = true
	_theme_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_style_toggle(_theme_button)
	_theme_button.pressed.connect(_on_theme_color_pressed)
	_body.add_child(_theme_button)

	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	footer.alignment = BoxContainer.ALIGNMENT_END
	_body.add_child(footer)
	var cancel_button: Button = _make_button("settings.cancel", false)
	cancel_button.pressed.connect(cancel)
	footer.add_child(cancel_button)
	var save_button: Button = _make_button("settings.save", true)
	save_button.pressed.connect(_save)
	footer.add_child(save_button)

func open_for(content: String, color_hex: String, font_size: int, align: String) -> void:
	_edit.text = DecorItem.clip_text(content)
	_size_spin.set_value_no_signal(float(font_size))
	_size_spin.get_line_edit().text = str(font_size)
	_color_hex = color_hex
	_align = DecorItem.align_or_default(align)
	_refresh_color_state()
	_refresh_align_state()
	_update_count()
	open()
	_focus_edit.call_deferred()

func _focus_edit() -> void:
	if is_open():
		_edit.grab_focus()
		_edit.set_caret_line(_edit.get_line_count() - 1)
		_edit.set_caret_column(_edit.get_line(_edit.get_line_count() - 1).length())

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _count_label != null:
		_update_count()

func _input(event: InputEvent) -> void:
	if is_open() and event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and not key.is_echo() and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER) and PlatformKeys.is_primary(key):
			get_viewport().set_input_as_handled()
			_save()
			return
	super(event)

func _on_text_changed() -> void:
	if _edit.text.length() > DecorItem.MAX_TEXT_LENGTH:
		_edit.text = DecorItem.clip_text(_edit.text)
		_edit.set_caret_line(_edit.get_line_count() - 1)
		_edit.set_caret_column(_edit.get_line(_edit.get_line_count() - 1).length())
	_update_count()

func _update_count() -> void:
	_count_label.text = tr("decor.text.count") % [_edit.text.length(), DecorItem.MAX_TEXT_LENGTH]

func _on_color_picked(color: Color) -> void:
	_color_hex = color.to_html(false)
	_refresh_color_state()

func _on_align_pressed(choice: String) -> void:
	_align = choice
	_refresh_align_state()

func _refresh_align_state() -> void:
	for choice: String in _align_buttons:
		(_align_buttons[choice] as Button).set_pressed_no_signal(choice == _align)

func _on_theme_color_pressed() -> void:
	_color_hex = ""
	_refresh_color_state()

func _refresh_color_state() -> void:
	_theme_button.set_pressed_no_signal(_color_hex == "")
	if _color_hex == "":
		_color_bar.clear_active()
		return
	_color_bar.set_active_color(Color(_color_hex))

func _save() -> void:
	if not is_open():
		return
	_size_spin.apply()
	applied.emit(_edit.text, _color_hex, int(_size_spin.value), _align)
	close()
