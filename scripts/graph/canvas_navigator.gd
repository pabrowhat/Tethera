class_name CanvasNavigator
extends Node

signal panned(delta_screen: Vector2, delta_canvas: Vector2, velocity_canvas_x: float)
signal transform_changed(offset: Vector2, zoom: float)

const FOLLOW_SHARPNESS: float = 18.0
const FOLLOW_SNAP_DISTANCE: float = 0.5

@export var target_canvas: Control = null
@export var background_rect: ColorRect = null
@export var min_zoom: float = 0.1
@export var max_zoom: float = 5.0
@export var zoom_factor: float = 1.12
@export var focus_duration: float = 0.35

var _camera_tween: Tween = null
var _follow_active: bool = false
var _follow_center: Vector2 = Vector2.ZERO
var _follow_viewport_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	if not _follow_active or not is_instance_valid(target_canvas):
		set_process(false)
		return

	var zoom: float = target_canvas.scale.x
	var goal_pos: Vector2 = (_follow_viewport_size / 2.0) - (_follow_center * zoom)
	var weight: float = 1.0 - exp(-FOLLOW_SHARPNESS * delta)
	var new_pos: Vector2 = target_canvas.position.lerp(goal_pos, weight)
	var arrived: bool = new_pos.distance_to(goal_pos) < FOLLOW_SNAP_DISTANCE
	if arrived:
		new_pos = goal_pos

	target_canvas.position = new_pos
	update_shader()
	transform_changed.emit(target_canvas.position, zoom)

	if arrived:
		_follow_active = false
		set_process(false)

func pan(relative: Vector2, velocity: Vector2) -> void:
	if not is_instance_valid(target_canvas):
		return

	stop_animation()
	target_canvas.position += relative
	update_shader()

	var current_zoom: float = target_canvas.scale.x
	var delta_canvas: Vector2 = -relative / current_zoom
	var velocity_canvas_x: float = -velocity.x / current_zoom
	panned.emit(relative, delta_canvas, velocity_canvas_x)
	transform_changed.emit(target_canvas.position, current_zoom)

func zoom_towards(factor: float, screen_cursor_pos: Vector2) -> void:
	if not is_instance_valid(target_canvas):
		return

	var old_zoom: float = target_canvas.scale.x
	var new_zoom: float = clampf(old_zoom * factor, min_zoom, max_zoom)
	if is_equal_approx(old_zoom, new_zoom):
		return

	stop_animation()
	var canvas_mouse_offset: Vector2 = (screen_cursor_pos - target_canvas.position) / old_zoom
	target_canvas.scale = Vector2(new_zoom, new_zoom)
	target_canvas.position = screen_cursor_pos - (canvas_mouse_offset * new_zoom)
	update_shader()
	transform_changed.emit(target_canvas.position, new_zoom)

func focus_to_bounds(bounds: Rect2, screen_rect: Rect2, margin_ratio: float = 0.12, max_fit_zoom: float = 1.2) -> void:
	if not is_instance_valid(target_canvas):
		return

	var padded_size: Vector2 = bounds.size * (1.0 + 2.0 * margin_ratio)
	var zoom_fit_x: float = screen_rect.size.x / maxf(padded_size.x, 1.0)
	var zoom_fit_y: float = screen_rect.size.y / maxf(padded_size.y, 1.0)
	var upper_zoom: float = minf(max_fit_zoom, max_zoom)
	var target_zoom: float = clampf(minf(zoom_fit_x, zoom_fit_y), min_zoom, upper_zoom)
	var target_pos: Vector2 = screen_rect.get_center() - (bounds.get_center() * target_zoom)

	_animate_transform(target_pos, target_zoom)

func focus_to_point(target_center: Vector2, target_zoom: float, screen_focus_pos: Vector2) -> void:
	if not is_instance_valid(target_canvas):
		return

	var clamped_zoom: float = clampf(target_zoom, min_zoom, max_zoom)
	var target_pos: Vector2 = screen_focus_pos - (target_center * clamped_zoom)
	_animate_transform(target_pos, clamped_zoom)

func glide_center_to(canvas_point: Vector2, viewport_size: Vector2) -> void:
	if not is_instance_valid(target_canvas):
		return
	focus_to_point(canvas_point, target_canvas.scale.x, viewport_size / 2.0)

func follow_center(canvas_point: Vector2, viewport_size: Vector2) -> void:
	if not is_instance_valid(target_canvas):
		return
	if _camera_tween and _camera_tween.is_valid():
		_camera_tween.kill()
	_follow_center = canvas_point
	_follow_viewport_size = viewport_size
	_follow_active = true
	set_process(true)

func stop_animation() -> void:
	if _camera_tween and _camera_tween.is_valid():
		_camera_tween.kill()
	_follow_active = false
	set_process(false)

func screen_to_canvas(screen_pos: Vector2) -> Vector2:
	if not is_instance_valid(target_canvas):
		return screen_pos
	return (screen_pos - target_canvas.position) / target_canvas.scale.x

func canvas_to_screen(canvas_pos: Vector2) -> Vector2:
	if not is_instance_valid(target_canvas):
		return canvas_pos
	return canvas_pos * target_canvas.scale.x + target_canvas.position

func get_visible_canvas_rect(viewport_size: Vector2) -> Rect2:
	return Rect2(screen_to_canvas(Vector2.ZERO), viewport_size / get_zoom())

func get_zoom() -> float:
	if not is_instance_valid(target_canvas):
		return 1.0
	return target_canvas.scale.x

func update_shader() -> void:
	if is_instance_valid(background_rect) and background_rect.material is ShaderMaterial:
		var mat: ShaderMaterial = background_rect.material as ShaderMaterial
		mat.set_shader_parameter("pan_offset", target_canvas.position)
		mat.set_shader_parameter("zoom", target_canvas.scale.x)

func _animate_transform(target_pos: Vector2, target_zoom: float) -> void:
	stop_animation()

	_camera_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_camera_tween.tween_property(target_canvas, "position", target_pos, focus_duration)
	_camera_tween.tween_property(target_canvas, "scale", Vector2(target_zoom, target_zoom), focus_duration)
	_camera_tween.tween_method(_on_camera_step, 0.0, 1.0, focus_duration)

func _on_camera_step(_progress: float) -> void:
	if not is_instance_valid(target_canvas):
		return
	update_shader()
	transform_changed.emit(target_canvas.position, target_canvas.scale.x)
