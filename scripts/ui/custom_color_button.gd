class_name CustomColorButton
extends Button

signal color_previewed(color: Color)
signal color_committed(color: Color)

const BUTTON_SIZE: Vector2 = Vector2(24.0, 24.0)
const IDLE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.0)
const PLUS_COLOR: Color = Color(0.85, 0.87, 0.95, 1.0)
const POPUP_GAP: float = 6.0
const POPUP_BG: Color = Color(0.0901961, 0.0980392, 0.137255, 1.0)
const POPUP_BORDER: Color = Color(0.247059, 0.266667, 0.364706, 1.0)

var _material: ShaderMaterial = null
var _plus_label: Label = null
var _popup: PopupPanel = null
var _picker: ColorPickerPanel = null

var _presets: Array[Color] = []
var _picker_color: Color = Color.WHITE
var _is_custom_active: bool = false
var _has_changed: bool = false

func _init() -> void:
	custom_minimum_size = BUTTON_SIZE
	focus_mode = Control.FOCUS_NONE
	UiStyle.apply_round(self)
	tooltip_text = "palette.custom"

func setup(swatch_shader: Shader, preset_colors: Array[Color]) -> void:
	_presets = preset_colors

	var swatch: ColorRect = ColorRect.new()
	swatch.set_anchors_preset(Control.PRESET_FULL_RECT)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = swatch_shader
	_material.set_shader_parameter("circle_color", IDLE_COLOR)
	_material.set_shader_parameter("is_selected", false)
	swatch.material = _material
	add_child(swatch)

	_plus_label = Label.new()
	_plus_label.text = "+"
	_plus_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_plus_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plus_label.add_theme_font_size_override("font_size", 16)
	_plus_label.add_theme_color_override("font_color", PLUS_COLOR)
	add_child(_plus_label)

	_picker = ColorPickerPanel.new()
	_picker.color_changed.connect(_on_picker_color_changed)

	var popup_style: StyleBoxFlat = StyleBoxFlat.new()
	popup_style.bg_color = POPUP_BG
	popup_style.border_color = POPUP_BORDER
	popup_style.set_border_width_all(1)
	popup_style.set_corner_radius_all(10)
	popup_style.set_content_margin_all(12.0)

	_popup = PopupPanel.new()
	_popup.add_theme_stylebox_override("panel", popup_style)
	_popup.add_child(_picker)
	_popup.popup_hide.connect(_on_popup_hidden)
	_popup.window_input.connect(_on_popup_window_input)
	add_child(_popup)

	pressed.connect(_open_picker)

func sync(active_color: Color) -> void:
	_picker_color = active_color
	var is_known: bool = _is_preset(active_color) or PaletteStore.instance().find_color(active_color) != -1
	_set_custom_active(not is_known, active_color)

func clear_active() -> void:
	_set_custom_active(false, IDLE_COLOR)

func _is_preset(color: Color) -> bool:
	for preset: Color in _presets:
		if preset.is_equal_approx(color):
			return true
	return false

func _set_custom_active(active: bool, color: Color) -> void:
	_is_custom_active = active
	if _material == null:
		return
	_material.set_shader_parameter("circle_color", color if active else IDLE_COLOR)
	_material.set_shader_parameter("is_selected", active)
	_plus_label.visible = not active

func _open_picker() -> void:
	_has_changed = false
	_picker.begin(_picker_color)

	_popup.reset_size()
	var popup_size: Vector2i = _popup.get_contents_minimum_size()
	var bounds: Vector2 = get_viewport_rect().size
	var anchor: Rect2 = get_global_rect()
	var x: float = clampf(anchor.end.x - float(popup_size.x), 0.0, maxf(bounds.x - float(popup_size.x), 0.0))
	var y: float = minf(anchor.end.y + POPUP_GAP, maxf(bounds.y - float(popup_size.y), 0.0))
	_popup.popup(Rect2i(Vector2i(int(x), int(y)), popup_size))

func _on_picker_color_changed(color: Color) -> void:
	_has_changed = true
	_picker_color = color
	_set_custom_active(true, color)
	color_previewed.emit(color)

func _on_popup_window_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if key.pressed and not key.is_echo() and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER):
		_popup.set_input_as_handled()
		_popup.hide()

func _on_popup_hidden() -> void:
	if not _has_changed:
		return
	_has_changed = false
	PaletteStore.instance().add_color(_picker_color, _presets)
	color_committed.emit(_picker_color)
