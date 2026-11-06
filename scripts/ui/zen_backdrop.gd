class_name ZenBackdrop
extends ColorRect

signal dismissed

const BLUR_SHADER: Shader = preload("res://shaders/zen_blur.gdshader")
const FADE_DURATION: float = 0.25
const MAX_BLUR: float = 5.0
const MAX_DIM: float = 0.5
const MAX_VIGNETTE: float = 0.6

var _material: ShaderMaterial = null
var _tween: Tween = null
var _amount: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	color = Color.WHITE
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false

	_material = ShaderMaterial.new()
	_material.shader = BLUR_SHADER
	material = _material
	_set_amount(0.0)
	ThemeColors.watch(_apply_theme_colors)

func _apply_theme_colors() -> void:
	_material.set_shader_parameter("shade_color", ThemeColors.color(&"zen.shade"))

func fade_in() -> void:
	_kill_tween()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_amount, _amount, 1.0, FADE_DURATION)

func fade_out() -> void:
	if not visible:
		return
	_kill_tween()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_amount, _amount, 0.0, FADE_DURATION)
	_tween.tween_callback(func() -> void: visible = false)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			dismissed.emit()
	accept_event()

func _set_amount(value: float) -> void:
	_amount = value
	_material.set_shader_parameter("strength", value * MAX_BLUR)
	_material.set_shader_parameter("dim", value * MAX_DIM)
	_material.set_shader_parameter("vignette", value * MAX_VIGNETTE)

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
