class_name CustomColorButton
extends Button

signal color_previewed(color: Color)
signal color_committed(color: Color)

const BUTTON_SIZE: Vector2 = Vector2(24.0, 24.0)
const IDLE_COLOR: Color = Color.TRANSPARENT
const PLUS_COLOR: StringName = &"text.caption"

var _material: ShaderMaterial = null
var _plus_label: Label = null
var _popup: ColorPickerPopup = null

var _presets: Array[Color] = []
var _picker_color: Color = Color.WHITE
var _is_custom_active: bool = false

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
	ThemeColors.bind_override(_plus_label, &"font_color", PLUS_COLOR)
	add_child(_plus_label)

	_popup = ColorPickerPopup.new()
	_popup.color_previewed.connect(_on_picker_color_changed)
	_popup.color_committed.connect(_on_picker_committed)
	add_child(_popup)

	pressed.connect(_open_picker)

func sync(active_color: Color) -> void:
	_picker_color = active_color
	var is_known: bool = _is_preset(active_color) or PaletteStore.instance().find_color(active_color) != -1
	_set_custom_active(not is_known, active_color)

func set_presets(preset_colors: Array[Color]) -> void:
	_presets = preset_colors

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
	_popup.open_for(get_global_rect(), _picker_color, get_viewport_rect().size)

func _on_picker_color_changed(color: Color) -> void:
	_picker_color = color
	_set_custom_active(true, color)
	color_previewed.emit(color)

func _on_picker_committed(color: Color) -> void:
	PaletteStore.instance().add_color(color, _presets)
	color_committed.emit(color)
