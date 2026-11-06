class_name ColorPickerPanel
extends VBoxContainer

signal color_changed(color: Color)

const ICON_COPY: Texture2D = preload("res://assets/icons/copy.svg")
const ICON_CHECK: Texture2D = preload("res://assets/icons/check.svg")
const SV_SHADER: Shader = preload("res://shaders/sv_square.gdshader")
const HUE_SHADER: Shader = preload("res://shaders/hue_bar.gdshader")

const SV_SIZE: Vector2 = Vector2(200.0, 140.0)
const HUE_SIZE: Vector2 = Vector2(200.0, 16.0)
const PREVIEW_HEIGHT: float = 28.0
const MARKER_RADIUS: float = 6.0

const INPUT_BG: StringName = &"control.normal"
const INPUT_BORDER: StringName = &"border"
const TEXT_COLOR: StringName = &"text.primary"
const CAPTION_COLOR: StringName = &"text.muted"
const MARKER_HALO: StringName = &"marker.halo"
const COPY_CONFIRM_SECONDS: float = 0.8

var _hue: float = 0.0
var _sat: float = 0.0
var _val: float = 1.0
var _old_color: Color = Color.WHITE

var _sv_rect: ColorRect = null
var _sv_material: ShaderMaterial = null
var _sv_marker: Control = null
var _hue_rect: ColorRect = null
var _hue_handle: Control = null
var _hex_edit: LineEdit = null
var _copy_button: Button = null
var _preview: Control = null
var _sv_dragging: bool = false
var _hue_dragging: bool = false

func _init() -> void:
	add_theme_constant_override("separation", 10)

	_sv_rect = ColorRect.new()
	_sv_rect.custom_minimum_size = SV_SIZE
	_sv_material = ShaderMaterial.new()
	_sv_material.shader = SV_SHADER
	_sv_rect.material = _sv_material
	_sv_rect.mouse_default_cursor_shape = Control.CURSOR_CROSS
	_sv_rect.gui_input.connect(_on_sv_gui_input)
	add_child(_sv_rect)
	_sv_marker = _make_overlay(_draw_sv_marker)
	_sv_rect.add_child(_sv_marker)

	_hue_rect = ColorRect.new()
	_hue_rect.custom_minimum_size = HUE_SIZE
	var hue_material: ShaderMaterial = ShaderMaterial.new()
	hue_material.shader = HUE_SHADER
	_hue_rect.material = hue_material
	_hue_rect.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	_hue_rect.gui_input.connect(_on_hue_gui_input)
	add_child(_hue_rect)
	_hue_handle = _make_overlay(_draw_hue_handle)
	_hue_rect.add_child(_hue_handle)

	var hex_row: HBoxContainer = HBoxContainer.new()
	hex_row.add_theme_constant_override("separation", 6)
	add_child(hex_row)

	_hex_edit = LineEdit.new()
	_hex_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hex_edit.max_length = 9
	_hex_edit.placeholder_text = "#RRGGBB"
	_hex_edit.select_all_on_focus = true
	_hex_edit.add_theme_font_override("font", AppFonts.mono())
	_hex_edit.add_theme_font_size_override("font_size", 13)
	ThemeColors.bind_override(_hex_edit, &"font_color", TEXT_COLOR)
	_hex_edit.add_theme_stylebox_override("normal", _make_box(INPUT_BG, INPUT_BORDER, 6, 8.0, 5.0))
	_hex_edit.add_theme_stylebox_override("focus", _make_box(INPUT_BG, UiStyle.ACCENT, 6, 8.0, 5.0))
	_hex_edit.text_changed.connect(_on_hex_text_changed)
	_hex_edit.text_submitted.connect(_on_hex_submitted)
	_hex_edit.focus_exited.connect(_sync_hex_text)
	hex_row.add_child(_hex_edit)

	_copy_button = Button.new()
	_copy_button.icon = ICON_COPY
	_copy_button.expand_icon = true
	_copy_button.add_theme_constant_override("icon_max_width", 16)
	_copy_button.tooltip_text = "picker.copy_hex"
	_copy_button.focus_mode = Control.FOCUS_NONE
	_copy_button.custom_minimum_size = Vector2(34.0, 0.0)
	ThemeColors.bind_override(_copy_button, &"icon_normal_color", TEXT_COLOR)
	_copy_button.add_theme_stylebox_override("normal", _make_box(INPUT_BG, INPUT_BORDER, 6, 6.0, 5.0))
	_copy_button.add_theme_stylebox_override("hover", _make_box(UiStyle.BG_HOVER, INPUT_BORDER, 6, 6.0, 5.0))
	_copy_button.add_theme_stylebox_override("pressed", _make_box(UiStyle.ACCENT, UiStyle.ACCENT, 6, 6.0, 5.0))
	_copy_button.pressed.connect(_on_copy_pressed)
	hex_row.add_child(_copy_button)

	_preview = Control.new()
	_preview.custom_minimum_size = Vector2(0.0, PREVIEW_HEIGHT)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.draw.connect(_draw_preview)
	add_child(_preview)

func begin(color: Color) -> void:
	_old_color = Color(color, 1.0)
	set_color(color)

func set_color(color: Color) -> void:
	_hue = color.h
	_sat = color.s
	_val = color.v
	_refresh(true)

func get_color() -> Color:
	return Color.from_hsv(_hue, _sat, _val)

func _refresh(update_hex: bool) -> void:
	_sv_material.set_shader_parameter("hue", _hue)
	if update_hex:
		_sync_hex_text()
	_sv_marker.queue_redraw()
	_hue_handle.queue_redraw()
	_preview.queue_redraw()

func _emit_change(update_hex: bool) -> void:
	_refresh(update_hex)
	color_changed.emit(get_color())


func _on_sv_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		_sv_dragging = button.pressed
		if button.pressed:
			_pick_sv(button.position)
	elif event is InputEventMouseMotion and _sv_dragging:
		_pick_sv((event as InputEventMouseMotion).position)

func _pick_sv(local_pos: Vector2) -> void:
	_sat = clampf(local_pos.x / maxf(_sv_rect.size.x, 1.0), 0.0, 1.0)
	_val = 1.0 - clampf(local_pos.y / maxf(_sv_rect.size.y, 1.0), 0.0, 1.0)
	_emit_change(true)

func _on_hue_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		_hue_dragging = button.pressed
		if button.pressed:
			_pick_hue(button.position)
	elif event is InputEventMouseMotion and _hue_dragging:
		_pick_hue((event as InputEventMouseMotion).position)

func _pick_hue(local_pos: Vector2) -> void:
	_hue = clampf(local_pos.x / maxf(_hue_rect.size.x, 1.0), 0.0, 0.999)
	_emit_change(true)

func _make_overlay(draw_callback: Callable) -> Control:
	var overlay: Control = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(draw_callback)
	return overlay

func _draw_sv_marker() -> void:
	var pos: Vector2 = Vector2(_sat * _sv_rect.size.x, (1.0 - _val) * _sv_rect.size.y)
	_sv_marker.draw_arc(pos, MARKER_RADIUS + 1.0, 0.0, TAU, 28, ThemeColors.color(MARKER_HALO), 1.5, true)
	_sv_marker.draw_arc(pos, MARKER_RADIUS, 0.0, TAU, 28, Color.WHITE, 2.0, true)

func _draw_hue_handle() -> void:
	var x: float = _hue * _hue_rect.size.x
	var handle: Rect2 = Rect2(x - 2.5, -2.0, 5.0, _hue_rect.size.y + 4.0)
	_hue_handle.draw_rect(handle.grow(1.0), ThemeColors.color(MARKER_HALO), true)
	_hue_handle.draw_rect(handle, Color.WHITE, true)


func _on_hex_text_changed(new_text: String) -> void:
	var parsed: Variant = _parse_hex(new_text)
	if parsed == null:
		return
	var color: Color = parsed as Color
	_hue = color.h
	_sat = color.s
	_val = color.v
	_emit_change(false)

func _on_hex_submitted(_text: String) -> void:
	_sync_hex_text()

func _sync_hex_text() -> void:
	if is_instance_valid(_hex_edit):
		_hex_edit.text = "#" + get_color().to_html(false).to_upper()

func _parse_hex(text: String) -> Variant:
	var cleaned: String = text.strip_edges().trim_prefix("#")
	if cleaned.length() != 3 and cleaned.length() != 6:
		return null
	if not cleaned.is_valid_hex_number(false):
		return null
	return Color("#" + cleaned)

func _on_copy_pressed() -> void:
	DisplayServer.clipboard_set("#" + get_color().to_html(false).to_upper())
	_copy_button.icon = ICON_CHECK
	await get_tree().create_timer(COPY_CONFIRM_SECONDS).timeout
	if is_instance_valid(_copy_button):
		_copy_button.icon = ICON_COPY


func _draw_preview() -> void:
	var full: Rect2 = Rect2(Vector2.ZERO, _preview.size)
	var half: float = full.size.x * 0.5
	var left: Rect2 = Rect2(full.position, Vector2(half, full.size.y))
	var right: Rect2 = Rect2(full.position + Vector2(half, 0.0), Vector2(half, full.size.y))
	var current: Color = get_color()

	_preview.draw_rect(left, _old_color, true)
	_preview.draw_rect(right, current, true)
	_preview.draw_rect(full, ThemeColors.color(INPUT_BORDER), false, 1.0)

	var font: Font = get_theme_default_font()
	_draw_caption(font, tr("picker.was"), left, _old_color)
	_draw_caption(font, tr("picker.now"), right, current)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _preview != null:
		_preview.queue_redraw()

func _draw_caption(font: Font, text: String, area: Rect2, background: Color) -> void:
	var font_size: int = 11
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var ink: Color = ThemeColors.ink_for(background)
	var baseline: float = area.position.y + (area.size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	_preview.draw_string(font, Vector2(area.position.x + (area.size.x - text_size.x) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, ink)

func _make_box(background: StringName, border: StringName, radius: int, margin_x: float, margin_y: float) -> StyleBoxFlat:
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
