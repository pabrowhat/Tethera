class_name NoteBackgroundSection
extends VBoxContainer

signal color_previewed(color: Color)
signal color_chosen(color: Color)
signal color2_previewed(color: Color)
signal color2_chosen(color: Color)
signal gradient_cleared
signal image_chosen(source_path: String)
signal eyedropper_requested(second: bool)
signal cleared

const CAPTION_COLOR: StringName = &"text.caption"
const HINT_COLOR: StringName = &"text.dim"
const BODY_PALETTE: Array[Color] = [
	Color("1d2338"),
	Color("2b2140"),
	Color("1b3030"),
	Color("33301c"),
	Color("381f26"),
	Color("2a2d34"),
]

static var _expanded: bool = false

var _title_key: String = ""
var _header: Button = null
var _body: VBoxContainer = null
var _color_bar: ColorBar = null
var _color2_bar: ColorBar = null
var _pick_button: Button = null
var _gradient_toggle: CheckButton = null
var _gradient_box: VBoxContainer = null
var _has_gradient: bool = false
var _clear_button: Button = null
var _hint: Label = null
var _image_dialog_open: bool = false

func _init(title_key: String = "background.title") -> void:
	add_theme_constant_override("separation", 6)
	_title_key = title_key

	_header = Button.new()
	_header.flat = true
	_header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header.focus_mode = Control.FOCUS_NONE
	_header.add_theme_font_size_override("font_size", 12)
	ThemeColors.bind_override(_header, &"font_color", CAPTION_COLOR)
	_header.pressed.connect(_on_header_pressed)
	add_child(_header)

func setup(swatch_shader: Shader, with_eyedropper: bool = false) -> void:
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 8)
	add_child(_body)

	_color_bar = ColorBar.new()
	_color_bar.setup(BODY_PALETTE, swatch_shader)
	_color_bar.set_eyedropper_visible(with_eyedropper)
	_color_bar.eyedropper_requested.connect(eyedropper_requested.emit.bind(false))
	_color_bar.color_picked.connect(color_chosen.emit)
	_color_bar.color_previewed.connect(color_previewed.emit)
	_color_bar.color_committed.connect(color_chosen.emit)
	_body.add_child(_color_bar)

	_gradient_toggle = CheckButton.new()
	_gradient_toggle.text = "background.gradient"
	_gradient_toggle.focus_mode = Control.FOCUS_NONE
	_gradient_toggle.add_theme_font_size_override("font_size", 12)
	ThemeColors.bind_override(_gradient_toggle, &"font_color", CAPTION_COLOR)
	_gradient_toggle.toggled.connect(_on_gradient_toggled)
	_body.add_child(_gradient_toggle)

	_gradient_box = VBoxContainer.new()
	_gradient_box.add_theme_constant_override("separation", 6)
	_gradient_box.visible = false
	_body.add_child(_gradient_box)

	var gradient_caption: Label = _make_caption("background.gradient_end", 11, HINT_COLOR)
	_gradient_box.add_child(gradient_caption)

	_color2_bar = ColorBar.new()
	_color2_bar.setup(BODY_PALETTE, swatch_shader)
	_color2_bar.set_eyedropper_visible(with_eyedropper)
	_color2_bar.eyedropper_requested.connect(eyedropper_requested.emit.bind(true))
	_color2_bar.color_picked.connect(color2_chosen.emit)
	_color2_bar.color_previewed.connect(color2_previewed.emit)
	_color2_bar.color_committed.connect(color2_chosen.emit)
	_gradient_box.add_child(_color2_bar)

	var row: HFlowContainer = HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 6)
	_body.add_child(row)

	_pick_button = _make_button("background.pick_image", _on_pick_pressed)
	row.add_child(_pick_button)
	_clear_button = _make_button("background.clear", cleared.emit)
	row.add_child(_clear_button)

	_hint = Label.new()
	_hint.add_theme_font_size_override("font_size", 11)
	ThemeColors.bind_override(_hint, &"font_color", HINT_COLOR)
	_hint.visible = false
	_body.add_child(_hint)
	_sync_fold()

func attach_border_control(control: Control, caption: String) -> void:
	var border_caption: Label = _make_caption(caption, 11, HINT_COLOR)
	_body.add_child(border_caption)
	_body.move_child(border_caption, 0)
	control.reparent(_body, false)
	_body.move_child(control, 1)
	var body_caption: Label = _make_caption("background.body_color", 11, HINT_COLOR)
	_body.add_child(body_caption)
	_body.move_child(body_caption, 2)

func _make_caption(text: String, font_size: int, color: StringName) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	ThemeColors.bind_override(label, &"font_color", color)
	return label

func _make_button(text: String, on_pressed: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.custom_minimum_size = Vector2(0.0, 28.0)
	button.pressed.connect(on_pressed)
	return button

func show_state(color_hex: String, color2_hex: String, image: String, hint: String = "") -> void:
	if color_hex != "":
		_color_bar.set_active_color(Color(color_hex))
	else:
		_color_bar.clear_active()
	if color2_hex != "":
		_color2_bar.set_active_color(Color(color2_hex))
	else:
		_color2_bar.clear_active()
	_pick_button.tooltip_text = image.get_file()
	_has_gradient = color2_hex != ""
	_gradient_toggle.set_pressed_no_signal(_has_gradient)
	_gradient_box.visible = _has_gradient
	_clear_button.disabled = color_hex == "" and color2_hex == "" and image == ""
	_hint.text = hint
	_hint.visible = hint != ""

func _on_gradient_toggled(on: bool) -> void:
	_gradient_box.visible = on
	if not on and _has_gradient:
		gradient_cleared.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _header != null:
		_sync_fold()

func _on_header_pressed() -> void:
	_expanded = not _expanded
	_sync_fold()

func _sync_fold() -> void:
	_header.text = ("▾ " if _expanded else "▸ ") + tr(_title_key)
	if _body != null:
		_body.visible = _expanded

func _on_pick_pressed() -> void:
	if _image_dialog_open:
		return
	_image_dialog_open = true
	DisplayServer.file_dialog_show(
		tr("background.dialog"),
		"",
		"",
		false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
		["*.png, *.jpg, *.jpeg, *.webp"],
		func(status: bool, selected_paths: PackedStringArray, _idx: int) -> void:
			_image_dialog_open = false
			if status and selected_paths.size() > 0 and is_instance_valid(self):
				image_chosen.emit(selected_paths[0])
	)
