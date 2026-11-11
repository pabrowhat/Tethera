class_name FormatToolbar
extends HFlowContainer

signal wrap_requested(open: String, close: String)
signal value_tag_requested(tag: String, value: String)
signal prefix_requested(prefix: String, heading: bool)
signal align_requested(tag: String)
signal code_block_requested
signal image_insert_requested

const ICON_HIGHLIGHTER: Texture2D = preload("res://assets/icons/highlighter.svg")
const ICON_IMAGE: Texture2D = preload("res://assets/icons/image.svg")
const ICON_CHECKLIST: Texture2D = preload("res://assets/icons/square-check.svg")
const ICON_CODE: Texture2D = preload("res://assets/icons/code.svg")
const ICON_CODE_BLOCK: Texture2D = preload("res://assets/icons/square-code.svg")
const ICON_ALIGN_LEFT: Texture2D = preload("res://assets/icons/align-left.svg")
const ICON_ALIGN_CENTER: Texture2D = preload("res://assets/icons/align-center.svg")
const ICON_ALIGN_RIGHT: Texture2D = preload("res://assets/icons/align-right.svg")
const ICON_MAX_WIDTH: int = 16
const BUTTON_SIZE: Vector2 = Vector2(28.0, 28.0)
const BUTTON_GAP: int = 3
const PRESS_SCALE: float = 0.95
const PRESS_DURATION: float = 0.05
const RELEASE_DURATION: float = 0.09

const NORMAL_BG: StringName = &"control.normal"
const HOVER_BG: StringName = &"control.hover"
const PRESSED_BG: StringName = &"accent"
const BORDER: StringName = &"border"
const TEXT: StringName = &"text.primary"

const PALETTE_COLUMNS: int = 6
const DEFAULT_TEXT_STRIPE: StringName = &"text.primary"

const HIGHLIGHT_STRIPE_INDEX: int = 3

var _text_color_button: SwatchDropdownButton = null
var _highlight_button: SwatchDropdownButton = null
var _punch_tweens: Dictionary = {}

func _init() -> void:
	add_theme_constant_override("h_separation", BUTTON_GAP)
	add_theme_constant_override("v_separation", BUTTON_GAP)

func setup(swatch_shader: Shader) -> void:
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

	var checklist_button: Button = _add_icon_button(ICON_CHECKLIST, "format.checklist")
	checklist_button.pressed.connect(prefix_requested.emit.bind(TextFormatOps.CHECKLIST_PREFIX, false))

	add_child(_make_separator())

	_add_icon_button(ICON_CODE, "format.inline_code").pressed.connect(wrap_requested.emit.bind("`", "`"))
	_add_icon_button(ICON_CODE_BLOCK, "format.code_block").pressed.connect(code_block_requested.emit)

	add_child(_make_separator())

	_add_icon_button(ICON_ALIGN_LEFT, "format.align_left").pressed.connect(align_requested.emit.bind("left"))
	_add_icon_button(ICON_ALIGN_CENTER, "format.align_center").pressed.connect(align_requested.emit.bind("center"))
	_add_icon_button(ICON_ALIGN_RIGHT, "format.align_right").pressed.connect(align_requested.emit.bind("right"))

	add_child(_make_separator())

	_text_color_button = SwatchDropdownButton.new()
	_style_button(_text_color_button, "format.text_color")
	_text_color_button.add_theme_font_override("font", AppFonts.note_bold())
	_text_color_button.setup("A", null, swatch_shader, PALETTE_COLUMNS, Color.WHITE)
	_text_color_button.use_theme_stripe(DEFAULT_TEXT_STRIPE)
	_text_color_button.color_picked.connect(_on_text_color_picked)
	add_child(_text_color_button)
	_attach_press_feedback(_text_color_button)

	_highlight_button = SwatchDropdownButton.new()
	_style_button(_highlight_button, "format.highlight")
	_highlight_button.setup("", ICON_HIGHLIGHTER, swatch_shader, PALETTE_COLUMNS, PaletteStore.DEFAULT_PRESETS[HIGHLIGHT_STRIPE_INDEX])
	_highlight_button.color_picked.connect(_on_highlight_picked)
	add_child(_highlight_button)
	_attach_press_feedback(_highlight_button)

	_add_icon_button(ICON_IMAGE, "image.insert").pressed.connect(image_insert_requested.emit)

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

func _add_icon_button(icon: Texture2D, tooltip: String) -> Button:
	var button: Button = _add_button("", tooltip)
	button.icon = icon
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", ICON_MAX_WIDTH)
	return button

func _style_button(button: Button, tooltip: String) -> void:
	button.custom_minimum_size = BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tooltip
	button.add_theme_font_size_override("font_size", 13)
	ThemeColors.bind_override(button, &"font_color", TEXT)
	ThemeColors.bind_override(button, &"font_hover_color", &"text.strong")
	ThemeColors.bind_override(button, &"font_pressed_color", &"text.on_accent")
	button.add_theme_stylebox_override("normal", _make_style(NORMAL_BG, BORDER))
	button.add_theme_stylebox_override("hover", _make_style(HOVER_BG, BORDER))
	button.add_theme_stylebox_override("pressed", _make_style(PRESSED_BG, PRESSED_BG))
	button.add_theme_stylebox_override("disabled", _make_style(NORMAL_BG, BORDER))

func _make_style(background: StringName, border: StringName) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	ThemeColors.bind(style, &"bg_color", background)
	ThemeColors.bind(style, &"border_color", border)
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
	ThemeColors.bind(separator, &"color", BORDER)
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
