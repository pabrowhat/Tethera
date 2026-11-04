class_name FormatToolbar
extends HBoxContainer

signal wrap_requested(open: String, close: String)
signal value_tag_requested(tag: String, value: String)
signal prefix_requested(prefix: String, heading: bool)
signal image_insert_requested

const ICON_HIGHLIGHTER: Texture2D = preload("res://assets/icons/highlighter.svg")
const ICON_IMAGE: Texture2D = preload("res://assets/icons/image.svg")
const BUTTON_SIZE: Vector2 = Vector2(28.0, 28.0)
const BUTTON_GAP: int = 3
const PRESS_SCALE: float = 0.95
const PRESS_DURATION: float = 0.05
const RELEASE_DURATION: float = 0.09

const NORMAL_BG: Color = Color(0.141176, 0.152941, 0.211765, 1.0)
const HOVER_BG: Color = Color(0.192157, 0.207843, 0.286275, 1.0)
const PRESSED_BG: Color = Color(0.407843, 0.439216, 0.980392, 1.0)
const BORDER: Color = Color(0.247059, 0.266667, 0.364706, 1.0)
const TEXT: Color = Color(0.88, 0.89, 0.94, 1.0)

const PALETTE_COLUMNS: int = 6
const DEFAULT_TEXT_STRIPE: Color = Color(0.88, 0.89, 0.94, 1.0)

var _text_color_button: SwatchDropdownButton = null
var _highlight_button: SwatchDropdownButton = null
var _punch_tweens: Dictionary = {}

func _init() -> void:
	add_theme_constant_override("separation", BUTTON_GAP)

func setup(swatch_shader: Shader, palette_colors: Array[Color]) -> void:
	var bold_button: Button = _add_button("B", "format.bold")
	bold_button.add_theme_font_override("font", AppFonts.note_bold())
	bold_button.pressed.connect(wrap_requested.emit.bind("**", "**"))

	var italic_button: Button = _add_button("I", "format.italic")
	italic_button.add_theme_font_override("font", AppFonts.note_italic())
	italic_button.pressed.connect(wrap_requested.emit.bind("*", "*"))

	var strike_button: Button = _add_button("S", "format.strike")
	strike_button.pressed.connect(wrap_requested.emit.bind("~~", "~~"))

	add_child(_make_separator())

	var h1_button: Button = _add_button("H1", "format.h1")
	h1_button.pressed.connect(prefix_requested.emit.bind("# ", true))

	var h2_button: Button = _add_button("H2", "format.h2")
	h2_button.pressed.connect(prefix_requested.emit.bind("## ", true))

	var bullet_button: Button = _add_button("•", "format.bullet")
	bullet_button.pressed.connect(prefix_requested.emit.bind("- ", false))

	add_child(_make_separator())

	_text_color_button = SwatchDropdownButton.new()
	_style_button(_text_color_button, "format.text_color")
	_text_color_button.add_theme_font_override("font", AppFonts.note_bold())
	_text_color_button.setup("A", null, palette_colors, swatch_shader, PALETTE_COLUMNS, DEFAULT_TEXT_STRIPE)
	_text_color_button.color_picked.connect(_on_text_color_picked)
	add_child(_text_color_button)
	_attach_press_feedback(_text_color_button)

	_highlight_button = SwatchDropdownButton.new()
	_style_button(_highlight_button, "format.highlight")
	var highlight_stripe: Color = palette_colors[mini(3, palette_colors.size() - 1)] if not palette_colors.is_empty() else DEFAULT_TEXT_STRIPE
	_highlight_button.setup("", ICON_HIGHLIGHTER, palette_colors, swatch_shader, PALETTE_COLUMNS, highlight_stripe)
	_highlight_button.color_picked.connect(_on_highlight_picked)
	add_child(_highlight_button)
	_attach_press_feedback(_highlight_button)

	var image_button: Button = _add_button("", "image.insert")
	image_button.icon = ICON_IMAGE
	image_button.expand_icon = true
	image_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	image_button.add_theme_constant_override("icon_max_width", 16)
	image_button.pressed.connect(image_insert_requested.emit)

func has_open_popup() -> bool:
	return _text_color_button.is_popup_open() or _highlight_button.is_popup_open()

func set_enabled(enabled: bool) -> void:
	for child: Node in get_children():
		if child is Button:
			(child as Button).disabled = not enabled

func _on_text_color_picked(color: Color) -> void:
	value_tag_requested.emit("color", "#" + color.to_html(false))

func _on_highlight_picked(color: Color) -> void:
	value_tag_requested.emit("bgcolor", "#" + color.to_html(false))

func _add_button(label: String, tooltip: String) -> Button:
	var button: Button = Button.new()
	button.text = label
	_style_button(button, tooltip)
	add_child(button)
	_attach_press_feedback(button)
	return button

func _style_button(button: Button, tooltip: String) -> void:
	button.custom_minimum_size = BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tooltip
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _make_style(NORMAL_BG, BORDER))
	button.add_theme_stylebox_override("hover", _make_style(HOVER_BG, BORDER))
	button.add_theme_stylebox_override("pressed", _make_style(PRESSED_BG, PRESSED_BG))
	button.add_theme_stylebox_override("disabled", _make_style(NORMAL_BG, BORDER))

func _make_style(background: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style

func _make_separator() -> Control:
	var separator: ColorRect = ColorRect.new()
	separator.custom_minimum_size = Vector2(1.0, 18.0)
	separator.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	separator.color = BORDER
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return separator

func _attach_press_feedback(button: Button) -> void:
	button.resized.connect(func() -> void: button.pivot_offset = button.size * 0.5)
	button.button_down.connect(func() -> void:
		_animate_scale(button, PRESS_SCALE, PRESS_DURATION, Tween.TRANS_CUBIC)
	)
	button.button_up.connect(func() -> void:
		_animate_scale(button, 1.0, RELEASE_DURATION, Tween.TRANS_BACK)
	)

func _animate_scale(button: Button, target: float, duration: float, trans: Tween.TransitionType) -> void:
	var previous: Variant = _punch_tweens.get(button, null)
	if previous is Tween and (previous as Tween).is_valid():
		(previous as Tween).kill()
	var tween: Tween = button.create_tween().set_trans(trans).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(target, target), duration)
	_punch_tweens[button] = tween
