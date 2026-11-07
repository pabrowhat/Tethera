class_name DecorNode
extends Node2D

const HANDLE_NONE: int = -1
const HANDLE_TOP_LEFT: int = 0
const HANDLE_TOP_RIGHT: int = 1
const HANDLE_BOTTOM_RIGHT: int = 2
const HANDLE_BOTTOM_LEFT: int = 3
const HANDLE_ROTATE: int = 4
const HANDLE_LEFT: int = 5
const HANDLE_RIGHT: int = 6
const HANDLE_TOP: int = 7
const HANDLE_BOTTOM: int = 8
const HANDLE_COUNT: int = 9

const HANDLE_RADIUS_PX: float = 6.0
const HANDLE_GRAB_RADIUS_PX: float = 11.0
const ROTATE_OFFSET_PX: float = 30.0
const OUTLINE_WIDTH_PX: float = 2.0
const REMOVE_DURATION: float = 0.15
const REMOVE_SCALE: float = 0.85

const OUTLINE_COLOR: StringName = &"decor.outline"
const HANDLE_FILL: StringName = &"decor.handle"
const PLACEHOLDER_FILL: StringName = &"decor.placeholder"
const PLACEHOLDER_LINE: StringName = &"decor.placeholder_line"
const EMPTY_TEXT_OUTLINE: StringName = &"text.dim"
const DEFAULT_TEXT_COLOR: StringName = &"text.primary"

var decor_id: String = ""
var kind: String = DecorItem.KIND_IMAGE
var text: String = ""
var text_color: String = ""
var font_size: int = DecorItem.TEXT_DEFAULT_FONT_SIZE
var text_width: float = DecorItem.TEXT_DEFAULT_WIDTH
var image_path: String = ""
var box_size: Vector2 = Vector2(200.0, 200.0):
	set(value):
		box_size = value
		queue_redraw()
var layer: String = DecorItem.LAYER_BELOW
var flip_h: bool = false:
	set(value):
		flip_h = value
		queue_redraw()
var flip_v: bool = false:
	set(value):
		flip_v = value
		queue_redraw()
var is_selected: bool = false
var show_handles: bool = false

var _texture: Texture2D = null
var _paragraph: TextParagraph = null
var _text_height: float = 0.0
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
	kind = item.kind
	if item.is_text():
		text = item.text
		text_color = item.color
		font_size = item.font_size
		text_width = item.text_width
		_rebuild_paragraph()
		box_size = Vector2(item.size.x, _text_height * item.size.x / text_width)
	else:
		flip_h = item.flip_h
		flip_v = item.flip_v
		set_image(item.image)

func to_item() -> DecorItem:
	var item: DecorItem = DecorItem.new()
	item.id = decor_id
	item.kind = kind
	item.image = image_path
	item.text = text
	item.color = text_color
	item.font_size = font_size
	item.text_width = text_width
	item.pos = position
	item.size = box_size
	item.rotation_deg = DecorItem.normalize_angle(rad_to_deg(rotation))
	item.layer = layer
	if not is_text():
		item.flip_h = flip_h
		item.flip_v = flip_v
	return item

func shows_empty_frame() -> bool:
	return is_text() and text == ""

func is_text() -> bool:
	return kind == DecorItem.KIND_TEXT

static func layout_height(content: String, size_px: int, width: float) -> float:
	var paragraph: TextParagraph = _make_paragraph(content, size_px, width)
	return maxf(paragraph.get_size().y, AppFonts.note_regular().get_height(size_px))

static func _make_paragraph(content: String, size_px: int, width: float) -> TextParagraph:
	var paragraph: TextParagraph = TextParagraph.new()
	paragraph.width = width
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	paragraph.add_string(content, AppFonts.note_regular(), size_px)
	return paragraph

func text_scale() -> float:
	return box_size.x / text_width

func fit_text_to_width(new_box_width: float, keep_scale: float) -> void:
	text_width = clampf(new_box_width / keep_scale, DecorItem.TEXT_MIN_WIDTH, DecorItem.TEXT_MAX_WIDTH)
	_rebuild_paragraph()
	box_size = Vector2(text_width * keep_scale, _text_height * keep_scale)

func edge_handle_enabled(handle: int) -> bool:
	if handle == HANDLE_LEFT or handle == HANDLE_RIGHT:
		return true
	return not is_text()

func set_text_content(new_text: String, new_color: String, new_font_size: int) -> void:
	var scale_now: float = text_scale()
	text = new_text
	text_color = new_color
	font_size = new_font_size
	_rebuild_paragraph()
	box_size = Vector2(box_size.x, _text_height * scale_now)

func _rebuild_paragraph() -> void:
	_paragraph = _make_paragraph(text, font_size, text_width)
	_text_height = maxf(_paragraph.get_size().y, AppFonts.note_regular().get_height(font_size))
	queue_redraw()

func _text_draw_color() -> Color:
	if text_color != "":
		return Color(text_color)
	return ThemeColors.color(DEFAULT_TEXT_COLOR)

func set_image(path: String) -> void:
	image_path = path
	_texture = InlineImages.texture_for(path)
	if _texture == null and path != "":
		InlineImages.report_missing(path)
	queue_redraw()

func average_color(fallback: Color) -> Color:
	return InlineImages.average_color_of(_texture, fallback)

func get_state() -> Dictionary:
	return {"pos": position, "size": box_size, "rot": DecorItem.normalize_angle(rad_to_deg(rotation)), "text_width": text_width, "flip_h": flip_h, "flip_v": flip_v}

func apply_state(state: Dictionary) -> void:
	position = state["pos"] as Vector2
	flip_h = bool(state.get("flip_h", flip_h))
	flip_v = bool(state.get("flip_v", flip_v))
	if is_text() and state.has("text_width") and not is_equal_approx(text_width, float(state["text_width"])):
		text_width = float(state["text_width"])
		_rebuild_paragraph()
	box_size = state["size"] as Vector2
	rotation = deg_to_rad(float(state["rot"]))

func play_spawn_animation() -> void:
	if Preferences.reduce_motion():
		scale = Vector2.ONE
		modulate.a = 1.0
		return
	scale = Vector2(0.3, 0.3)
	modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3)
	tween.tween_property(self, "modulate:a", 1.0, 0.2)

func play_remove_animation() -> void:
	if not is_inside_tree() or Preferences.reduce_motion():
		queue_free()
		return
	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", scale * REMOVE_SCALE, REMOVE_DURATION)
	tween.tween_property(self, "modulate:a", 0.0, REMOVE_DURATION)
	tween.chain().tween_callback(queue_free)

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
	var own: float = maxf(absf(scale.x), 0.0001)
	return maxf(absf(get_global_transform().get_scale().x) / own, 0.0001)

func _draw() -> void:
	var rect: Rect2 = Rect2(-box_size / 2.0, box_size)
	if is_text():
		_draw_text(rect)
	elif _texture != null:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(-1.0 if flip_h else 1.0, -1.0 if flip_v else 1.0))
		draw_texture_rect(_texture, rect, false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
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
	for edge: int in range(HANDLE_LEFT, HANDLE_COUNT):
		_handle_shapes[edge].visible = edge_handle_enabled(edge)
		if edge_handle_enabled(edge):
			_place_handle(_handle_shapes[edge], edge_position(edge), unit)

func _draw_text(rect: Rect2) -> void:
	if _paragraph == null:
		return
	var factor: float = text_scale()
	draw_set_transform(rect.position, 0.0, Vector2(factor, factor))
	_paragraph.draw(get_canvas_item(), Vector2.ZERO, _text_draw_color())
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if text == "":
		draw_rect(rect, ThemeColors.color(EMPTY_TEXT_OUTLINE), false, OUTLINE_WIDTH_PX / screen_scale(), true)

func _show_handles(active: bool) -> void:
	if _handle_shapes.is_empty():
		if not active:
			return
		for i: int in HANDLE_COUNT:
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

func edge_position(handle: int) -> Vector2:
	var half: Vector2 = box_size / 2.0
	match handle:
		HANDLE_LEFT:
			return Vector2(-half.x, 0.0)
		HANDLE_RIGHT:
			return Vector2(half.x, 0.0)
		HANDLE_TOP:
			return Vector2(0.0, -half.y)
	return Vector2(0.0, half.y)

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
	var best: int = HANDLE_NONE
	var best_distance: float = grab
	for corner: int in 4:
		var corner_distance: float = local.distance_to(corner_position(corner))
		if corner_distance <= best_distance:
			best = corner
			best_distance = corner_distance
	for edge: int in range(HANDLE_LEFT, HANDLE_COUNT):
		if not edge_handle_enabled(edge):
			continue
		var edge_distance: float = local.distance_to(edge_position(edge))
		if edge_distance < best_distance:
			best = edge
			best_distance = edge_distance
	return best

func canvas_bounds() -> Rect2:
	var first: Vector2 = position + corner_position(0).rotated(rotation)
	var bounds: Rect2 = Rect2(first, Vector2.ZERO)
	for corner: int in range(1, 4):
		bounds = bounds.expand(position + corner_position(corner).rotated(rotation))
	return bounds
