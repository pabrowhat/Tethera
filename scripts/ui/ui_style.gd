class_name UiStyle
extends RefCounted

const BG_NORMAL: Color = Color(0.141176, 0.152941, 0.211765, 1.0)
const BG_HOVER: Color = Color(0.192157, 0.207843, 0.286275, 1.0)
const BORDER: Color = Color(0.247059, 0.266667, 0.364706, 1.0)
const ACCENT: Color = Color(0.407843, 0.439216, 0.980392, 1.0)
const ACCENT_SOFT: Color = Color(0.407843, 0.439216, 0.980392, 0.55)

static var _empty: StyleBoxEmpty = null

static func box(background: Color, border: Color, radius: int, margin_x: float = 6.0, margin_y: float = 4.0) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	return style

static func apply_round(button: Button) -> void:
	RoundedShape.attach_to_button(button, {
		BaseButton.DRAW_NORMAL: [BG_NORMAL, BORDER],
		BaseButton.DRAW_HOVER: [BG_HOVER, ACCENT_SOFT],
		BaseButton.DRAW_PRESSED: [ACCENT, ACCENT],
		BaseButton.DRAW_HOVER_PRESSED: [ACCENT, ACCENT],
	}, 1.0)

static func apply_danger_text(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color(0.85, 0.35, 0.35, 0.85))
	button.add_theme_color_override("font_pressed_color", Color(0.9, 0.25, 0.25, 1.0))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.45, 0.45, 1.0))
	button.add_theme_stylebox_override("normal", _danger_box(Color(0.0, 0.0, 0.0, 0.0)))
	button.add_theme_stylebox_override("pressed", _danger_box(Color(0.0, 0.0, 0.0, 0.0)))
	button.add_theme_stylebox_override("hover", _danger_box(Color(0.141176, 0.152941, 0.211765, 0.6)))
	button.add_theme_stylebox_override("focus", _get_empty())

static func _danger_box(background: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.set_corner_radius_all(6)
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

static func make_borderless(button: Button) -> void:
	button.flat = true
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, _get_empty())

static func _get_empty() -> StyleBoxEmpty:
	if _empty == null:
		_empty = StyleBoxEmpty.new()
	return _empty
