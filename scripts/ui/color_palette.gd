class_name SwatchPalette
extends RefCounted

const PUNCH_META: StringName = &"punch_tween"

static func build(container: Container, colors: Array[Color], swatch_shader: Shader, on_pick: Callable) -> Array[ColorRect]:
	for child: Node in container.get_children():
		child.queue_free()

	var swatches: Array[ColorRect] = []
	for color: Color in colors:
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(24, 24)
		btn.pivot_offset = Vector2(12, 12)
		btn.focus_mode = Control.FOCUS_NONE
		UiStyle.make_borderless(btn)

		var swatch_rect: ColorRect = ColorRect.new()
		swatch_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		swatch_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = swatch_shader
		mat.set_shader_parameter("circle_color", color)
		mat.set_shader_parameter("is_selected", false)
		swatch_rect.material = mat

		btn.add_child(swatch_rect)

		var chosen_color: Color = color
		btn.pressed.connect(func() -> void:
			punch(btn)
			on_pick.call(chosen_color)
		)
		container.add_child(btn)
		swatches.append(swatch_rect)

	return swatches

static func punch(button: Button) -> void:
	var previous: Variant = button.get_meta(PUNCH_META) if button.has_meta(PUNCH_META) else null
	if previous is Tween and (previous as Tween).is_valid():
		(previous as Tween).kill()
	button.scale = Vector2.ONE
	var tween: Tween = button.create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(button, "scale", Vector2(ColorBar.PUNCH_SCALE, ColorBar.PUNCH_SCALE), ColorBar.PUNCH_UP_DURATION).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, ColorBar.PUNCH_DOWN_DURATION).set_ease(Tween.EASE_IN_OUT)
	button.set_meta(PUNCH_META, tween)

static func set_active(swatches: Array[ColorRect], active_color: Color) -> void:
	for swatch: ColorRect in swatches:
		if is_instance_valid(swatch) and swatch.material is ShaderMaterial:
			var mat: ShaderMaterial = swatch.material as ShaderMaterial
			var col: Color = mat.get_shader_parameter("circle_color") as Color
			mat.set_shader_parameter("is_selected", col.is_equal_approx(active_color))
