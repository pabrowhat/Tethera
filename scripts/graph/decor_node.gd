class_name DecorNode
extends Node2D

const HANDLE_NONE: int = -1
const HANDLE_TOP_LEFT: int = 0
const HANDLE_TOP_RIGHT: int = 1
const HANDLE_BOTTOM_RIGHT: int = 2
const HANDLE_BOTTOM_LEFT: int = 3
const HANDLE_ROTATE: int = 4

const HANDLE_RADIUS_PX: float = 6.0
const HANDLE_GRAB_RADIUS_PX: float = 11.0
const ROTATE_OFFSET_PX: float = 30.0
const OUTLINE_WIDTH_PX: float = 2.0

const OUTLINE_COLOR: StringName = &"decor.outline"
const HANDLE_FILL: StringName = &"decor.handle"
const PLACEHOLDER_FILL: StringName = &"decor.placeholder"
const PLACEHOLDER_LINE: StringName = &"decor.placeholder_line"

var decor_id: String = ""
var image_path: String = ""
var box_size: Vector2 = Vector2(200.0, 200.0):
	set(value):
		box_size = value
		queue_redraw()
var layer: String = DecorItem.LAYER_BELOW
var is_selected: bool = false
var show_handles: bool = false

var _texture: Texture2D = null
var _handle_shapes: Array[RoundedShape] = []

func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ThemeColors.watch(queue_redraw)

func apply_item(item: DecorItem) -> void:
	decor_id = item.id
	layer = item.layer
	box_size = item.size
	position = item.pos
	rotation = deg_to_rad(item.rotation_deg)
	set_image(item.image)

func to_item() -> DecorItem:
	var item: DecorItem = DecorItem.new()
	item.id = decor_id
	item.image = image_path
	item.pos = position
	item.size = box_size
	item.rotation_deg = DecorItem.normalize_angle(rad_to_deg(rotation))
	item.layer = layer
	return item

func set_image(path: String) -> void:
	image_path = path
	_texture = InlineImages.texture_for(path)
	if _texture == null and path != "":
		InlineImages.report_missing(path)
	queue_redraw()

func get_state() -> Dictionary:
	return {"pos": position, "size": box_size, "rot": DecorItem.normalize_angle(rad_to_deg(rotation))}

func apply_state(state: Dictionary) -> void:
	position = state["pos"] as Vector2
	box_size = state["size"] as Vector2
	rotation = deg_to_rad(float(state["rot"]))

func play_spawn_animation() -> void:
	scale = Vector2(0.3, 0.3)
	modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func set_selected(active: bool) -> void:
	if is_selected == active:
		return
	is_selected = active
	queue_redraw()

func set_handles_visible(active: bool) -> void:
	if show_handles == active:
		return
	show_handles = active
	queue_redraw()

func screen_scale() -> float:
	return maxf(absf(get_global_transform().get_scale().x), 0.0001)

func _draw() -> void:
	var rect: Rect2 = Rect2(-box_size / 2.0, box_size)
	if _texture != null:
		draw_texture_rect(_texture, rect, false)
	else:
		draw_rect(rect, ThemeColors.color(PLACEHOLDER_FILL), true)
		draw_line(rect.position, rect.end, ThemeColors.color(PLACEHOLDER_LINE), 2.0)
		draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), ThemeColors.color(PLACEHOLDER_LINE), 2.0)
	if not is_selected:
		_show_handles(false)
		return

	var unit: float = 1.0 / screen_scale()
	draw_rect(rect, ThemeColors.color(OUTLINE_COLOR), false, OUTLINE_WIDTH_PX * unit)
	if not show_handles:
		_show_handles(false)
		return
	var top: Vector2 = Vector2(0.0, -box_size.y / 2.0)
	var knob: Vector2 = rotate_handle_position()
	draw_line(top, knob, ThemeColors.color(OUTLINE_COLOR), OUTLINE_WIDTH_PX * unit)
	_show_handles(true)
	for corner: int in 4:
		_place_handle(_handle_shapes[corner], corner_position(corner), unit)
	_place_handle(_handle_shapes[HANDLE_ROTATE], knob, unit)

func _show_handles(active: bool) -> void:
	if _handle_shapes.is_empty():
		if not active:
			return
		for i: int in 5:
			var shape: RoundedShape = RoundedShape.new()
			add_child(shape)
			_handle_shapes.append(shape)
	for shape: RoundedShape in _handle_shapes:
		shape.visible = active

func _place_handle(shape: RoundedShape, at: Vector2, unit: float) -> void:
	var outer: float = (HANDLE_RADIUS_PX + OUTLINE_WIDTH_PX * 0.5) * unit
	shape.place_centered(at, outer * 2.0)
	shape.set_style(ThemeColors.color(HANDLE_FILL), ThemeColors.color(OUTLINE_COLOR), OUTLINE_WIDTH_PX * unit)

func corner_position(corner: int) -> Vector2:
	var half: Vector2 = box_size / 2.0
	match corner:
		HANDLE_TOP_LEFT:
			return Vector2(-half.x, -half.y)
		HANDLE_TOP_RIGHT:
			return Vector2(half.x, -half.y)
		HANDLE_BOTTOM_RIGHT:
			return Vector2(half.x, half.y)
	return Vector2(-half.x, half.y)

func rotate_handle_position() -> Vector2:
	return Vector2(0.0, -box_size.y / 2.0 - ROTATE_OFFSET_PX / screen_scale())

func to_local_point(canvas_point: Vector2) -> Vector2:
	return (canvas_point - position).rotated(-rotation)

func hit_test(canvas_point: Vector2) -> bool:
	var local: Vector2 = to_local_point(canvas_point)
	return absf(local.x) <= box_size.x / 2.0 and absf(local.y) <= box_size.y / 2.0

func handle_at(canvas_point: Vector2) -> int:
	if not show_handles:
		return HANDLE_NONE
	var local: Vector2 = to_local_point(canvas_point)
	var grab: float = HANDLE_GRAB_RADIUS_PX / screen_scale()
	if local.distance_to(rotate_handle_position()) <= grab:
		return HANDLE_ROTATE
	for corner: int in 4:
		if local.distance_to(corner_position(corner)) <= grab:
			return corner
	return HANDLE_NONE

func canvas_bounds() -> Rect2:
	var first: Vector2 = position + corner_position(0).rotated(rotation)
	var bounds: Rect2 = Rect2(first, Vector2.ZERO)
	for corner: int in range(1, 4):
		bounds = bounds.expand(position + corner_position(corner).rotated(rotation))
	return bounds
