class_name UiStyle
extends RefCounted

const BG_NORMAL: StringName = &"control.normal"
const BG_HOVER: StringName = &"control.hover"
const BORDER: StringName = &"border"
const ACCENT: StringName = &"accent"
const ACCENT_SOFT: StringName = &"accent.soft"
const ACCENT_TINT: StringName = &"accent.tint"
const CLEAR: StringName = &""

static var _empty: StyleBoxEmpty = null

static func box(background: StringName, border: StringName, radius: int, margin_x: float = 6.0, margin_y: float = 4.0) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	ThemeColors.bind(style, &"bg_color", background)
	ThemeColors.bind(style, &"border_color", border)
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
	ThemeColors.bind_override(button, &"font_color", &"danger.text")
	ThemeColors.bind_override(button, &"font_pressed_color", &"danger.text_pressed")
	ThemeColors.bind_override(button, &"font_hover_color", &"danger.text_hover")
	button.add_theme_stylebox_override("normal", _danger_box(CLEAR))
	button.add_theme_stylebox_override("pressed", _danger_box(CLEAR))
	button.add_theme_stylebox_override("hover", _danger_box(BG_NORMAL, 0.6))
	button.add_theme_stylebox_override("focus", _get_empty())

static func _danger_box(background: StringName, alpha: float = -1.0) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	ThemeColors.bind(style, &"bg_color", background, alpha)
	style.set_corner_radius_all(6)
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style

static func paint_row_text(row: Button, disabled: bool, active: bool, text_key: StringName = &"text.primary", hint_key: StringName = &"text.muted") -> void:
	var box: HBoxContainer = row.get_child(0) as HBoxContainer
	var main_color: StringName = &"text.disabled" if disabled else (&"text.on_accent" if active else text_key)
	var side_color: StringName = &"text.disabled" if disabled else (&"text.on_accent" if active else hint_key)
	ThemeColors.bind_override(box.get_child(0) as Label, &"font_color", main_color)
	if box.get_child_count() > 1:
		ThemeColors.bind_override(box.get_child(1) as Label, &"font_color", side_color)

static func make_borderless(button: Button) -> void:
	button.flat = true
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, _get_empty())

static func _get_empty() -> StyleBoxEmpty:
	if _empty == null:
		_empty = StyleBoxEmpty.new()
	return _empty
