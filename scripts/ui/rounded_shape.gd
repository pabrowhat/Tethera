class_name RoundedShape
extends Control

const SHADER: Shader = preload("res://shaders/rounded_shape.gdshader")
const FULL_RADIUS: float = -1.0

var _material: ShaderMaterial = null

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	material = _material

func _draw() -> void:
	_material.set_shader_parameter("rect_size", Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0)))
	draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)

func set_style(fill: Color, border: Color, border_width: float, radius: float = FULL_RADIUS) -> void:
	_material.set_shader_parameter("fill_color", fill)
	_material.set_shader_parameter("border_color", border)
	_material.set_shader_parameter("border_width", border_width)
	_material.set_shader_parameter("corner_radius", radius)

func set_inner(color: Color, inset: float, right_half: bool = false) -> void:
	_material.set_shader_parameter("inner_color", color)
	_material.set_shader_parameter("inner_inset", inset)
	_material.set_shader_parameter("inner_right_half", right_half)

func clear_inner() -> void:
	_material.set_shader_parameter("inner_color", Color.TRANSPARENT)

func place_centered(center: Vector2, diameter: float) -> void:
	size = Vector2(diameter, diameter)
	position = center - size * 0.5

static func attach_to_button(button: Button, states: Dictionary, border_width: float, radius: float = FULL_RADIUS, margin_x: float = 0.0, margin_y: float = 0.0) -> RoundedShape:
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	empty.content_margin_left = margin_x
	empty.content_margin_right = margin_x
	empty.content_margin_top = margin_y
	empty.content_margin_bottom = margin_y
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, empty)
	button.flat = false

	var shape: RoundedShape = RoundedShape.new()
	shape.show_behind_parent = true
	shape.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(shape)
	button.move_child(shape, 0)

	var apply: Callable = func() -> void:
		var pair: Array = states.get(button.get_draw_mode(), states[BaseButton.DRAW_NORMAL]) as Array
		shape.set_style(ThemeColors.resolve(pair[0] as StringName), ThemeColors.resolve(pair[1] as StringName), border_width, radius)
	apply.call()
	button.draw.connect(apply)
	ThemeColors.watch(button.queue_redraw)
	return shape
