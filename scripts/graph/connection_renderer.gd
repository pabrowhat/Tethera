class_name ConnectionRenderer
extends Node2D

signal link_anchored(to_id: String)

const PREVIEW_CONNECT_KEY: StringName = &"accent"
const PREVIEW_DISCONNECT_KEY: StringName = &"link.preview_disconnect"
@export var line_width: float = 2.5
@export_group("Link Animation")
@export var grow_duration: float = 0.45
@export var pulse_duration: float = 0.5
@export var pulse_width_boost: float = 1.2
@export var pulse_lighten: float = 0.5
@export var dissolve_duration: float = 0.14

var _anims: Dictionary = {}
var _dying: Dictionary = {}

var connections: Array[Dictionary] = []:
	set(value):
		connections = value
		_previous_styles = _styles
		_styles = {}
		for conn: Dictionary in connections:
			_styles[_pair_key(str(conn.get("from", "")), str(conn.get("to", "")))] = _style_of(conn)
var selected_key: String = "":
	set(value):
		selected_key = value
		queue_redraw()
var _styles: Dictionary = {}
var _previous_styles: Dictionary = {}
var cards_by_id: Dictionary = {}
var preview_from_pos: Vector2 = Vector2.ZERO
var preview_to_pos: Vector2 = Vector2.ZERO
var is_drawing_preview: bool = false
var is_preview_disconnect: bool = false
var zoom_override: float = 0.0
var width_scale: float = 1.0

const INFINITE_BOUNDS: Rect2 = Rect2(-10000000.0, -10000000.0, 20000000.0, 20000000.0)
const DASH_LENGTH: float = 10.0
const DASH_GAP: float = 6.0
const DOT_SIZE: float = 2.0
const DOT_GAP: float = 5.0
const DOUBLE_LINE_SCALE: float = 0.4
const MAX_PATTERN_PIECES: int = 4000
const LINE_SHADER: Shader = preload("res://shaders/link_line.gdshader")
const EDGE_MARGIN_PIXELS: float = 1.5
const MIN_SEGMENT_LENGTH: float = 0.001

var _margin: float = 1.0
const SELECTED_LIGHTEN: float = 0.35
const SELECTED_WIDTH_BOOST: float = 1.5

func _ready() -> void:
	RenderingServer.canvas_item_set_custom_rect(get_canvas_item(), true, INFINITE_BOUNDS)
	var line_material: ShaderMaterial = ShaderMaterial.new()
	line_material.shader = LINE_SHADER
	material = line_material
	ThemeColors.watch(queue_redraw)

func setup(cards_map: Dictionary) -> void:
	cards_by_id = cards_map

func set_preview_line(from_pos: Vector2, to_pos: Vector2, is_disconnecting: bool = false) -> void:
	preview_from_pos = from_pos
	preview_to_pos = to_pos
	is_preview_disconnect = is_disconnecting
	is_drawing_preview = true
	queue_redraw()

func clear_preview_line() -> void:
	if is_drawing_preview:
		is_drawing_preview = false
		queue_redraw()

func animate_link(from_id: String, to_id: String) -> void:
	var key: String = _pair_key(from_id, to_id)
	_clear_dying(key)
	if Preferences.reduce_motion():
		_drop_anim(key)
		link_anchored.emit(to_id)
		queue_redraw()
		return
	var state: Dictionary = _get_anim_state(key)
	_kill_anim_tween(state, "grow_tween")
	state["progress"] = 0.0

	var tween: Tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(value: float) -> void: _set_anim_value(key, "progress", value), 0.0, 1.0, grow_duration)
	tween.tween_callback(func() -> void:
		_set_anim_value(key, "progress", 1.0)
		_cleanup_anim(key)
		link_anchored.emit(to_id)
	)
	state["grow_tween"] = tween
	queue_redraw()

func pulse_link(from_id: String, to_id: String) -> void:
	var key: String = _pair_key(from_id, to_id)
	if Preferences.reduce_motion():
		return
	var state: Dictionary = _get_anim_state(key)
	_kill_anim_tween(state, "pulse_tween")
	state["pulse"] = 1.0

	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(func(value: float) -> void: _set_anim_value(key, "pulse", value), 1.0, 0.0, pulse_duration)
	tween.tween_callback(func() -> void:
		_set_anim_value(key, "pulse", 0.0)
		_cleanup_anim(key)
	)
	state["pulse_tween"] = tween
	queue_redraw()

func dissolve_link(from_id: String, to_id: String) -> void:
	var key: String = _pair_key(from_id, to_id)
	_clear_dying(key)
	if Preferences.reduce_motion():
		_drop_anim(key)
		queue_redraw()
		return

	var progress: float = 1.0
	if _anims.has(key):
		var state: Dictionary = _anims[key] as Dictionary
		_kill_anim_tween(state, "grow_tween")
		_kill_anim_tween(state, "pulse_tween")
		progress = float(state.get("progress", 1.0))
		_anims.erase(key)

	var tween: Tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_method(func(value: float) -> void: _set_dying_fade(key, value), 1.0, 0.0, dissolve_duration)
	tween.tween_callback(func() -> void:
		_dying.erase(key)
		queue_redraw()
	)
	var style: String = str(_previous_styles.get(key, _styles.get(key, GraphNetwork.STYLE_SOLID)))
	_dying[key] = {"from": from_id, "to": to_id, "progress": progress, "fade": 1.0, "tween": tween, "style": style}
	queue_redraw()

func set_selected_link(id_a: String, id_b: String) -> void:
	selected_key = _pair_key(id_a, id_b) if id_a != "" and id_b != "" else ""

func _style_of(conn: Dictionary) -> String:
	return GraphNetwork.sanitize_style(conn.get("style", null), str(conn.get("kind", GraphNetwork.KIND_MANUAL)))

func _pair_key(id_a: String, id_b: String) -> String:
	return id_a + "|" + id_b if id_a < id_b else id_b + "|" + id_a

func _get_anim_state(key: String) -> Dictionary:
	if not _anims.has(key):
		_anims[key] = {"progress": 1.0, "pulse": 0.0}
	return _anims[key] as Dictionary

func _kill_anim_tween(state: Dictionary, tween_key: String) -> void:
	var existing: Variant = state.get(tween_key, null)
	if existing is Tween and (existing as Tween).is_valid():
		(existing as Tween).kill()

func _set_anim_value(key: String, field: String, value: float) -> void:
	if _anims.has(key):
		(_anims[key] as Dictionary)[field] = value
		queue_redraw()

func _set_dying_fade(key: String, value: float) -> void:
	if _dying.has(key):
		(_dying[key] as Dictionary)["fade"] = value
		queue_redraw()

func _clear_dying(key: String) -> void:
	if not _dying.has(key):
		return
	_kill_anim_tween(_dying[key] as Dictionary, "tween")
	_dying.erase(key)

func _drop_anim(key: String) -> void:
	if not _anims.has(key):
		return
	var state: Dictionary = _anims[key] as Dictionary
	_kill_anim_tween(state, "grow_tween")
	_kill_anim_tween(state, "pulse_tween")
	_anims.erase(key)

func _cleanup_anim(key: String) -> void:
	if not _anims.has(key):
		return
	var state: Dictionary = _anims[key] as Dictionary
	if float(state.get("progress", 1.0)) >= 1.0 and float(state.get("pulse", 0.0)) <= 0.0:
		_anims.erase(key)

func _draw() -> void:
	var zoom: float = 1.0
	var parent_node: Node = get_parent()
	if zoom_override > 0.0:
		zoom = zoom_override
	elif parent_node is Control:
		zoom = (parent_node as Control).scale.x
	elif parent_node is Node2D:
		zoom = (parent_node as Node2D).scale.x

	var effective_width: float = maxf(line_width * width_scale, 1.8 / zoom)
	var pixel_scale: float = (get_viewport().get_final_transform() * get_global_transform_with_canvas()).get_scale().x
	_margin = EDGE_MARGIN_PIXELS / maxf(pixel_scale, 0.001)

	for conn: Dictionary in connections:
		var from_id: String = conn.get("from", "")
		var to_id: String = conn.get("to", "")

		var progress: float = 1.0
		var pulse: float = 0.0
		var anim_key: String = _pair_key(from_id, to_id)
		if _anims.has(anim_key):
			var state: Dictionary = _anims[anim_key] as Dictionary
			progress = float(state.get("progress", 1.0))
			pulse = float(state.get("pulse", 0.0))

		_draw_link(from_id, to_id, progress, pulse, 1.0, effective_width, _style_of(conn), anim_key == selected_key)

	for entry: Dictionary in _dying.values():
		_draw_link(
			str(entry["from"]), str(entry["to"]),
			float(entry["progress"]), 0.0, float(entry["fade"]), effective_width, str(entry.get("style", GraphNetwork.STYLE_SOLID)), false
		)

	if is_drawing_preview:
		var current_preview_color: Color = ThemeColors.color(PREVIEW_DISCONNECT_KEY if is_preview_disconnect else PREVIEW_CONNECT_KEY)
		_segment(preview_from_pos, preview_to_pos, current_preview_color, current_preview_color, effective_width, false)

func _draw_link(from_id: String, to_id: String, progress: float, pulse: float, fade: float, base_width: float, style: String, selected: bool) -> void:
	var card_from: GraphCard = cards_by_id.get(from_id, null)
	var card_to: GraphCard = cards_by_id.get(to_id, null)
	if not is_instance_valid(card_from) or not is_instance_valid(card_to):
		return

	var p1: Vector2 = card_from.get_card_center()
	var p2: Vector2 = card_to.get_card_center()

	var c1: Color = card_from.display_line_color
	var c2: Color = card_to.display_line_color

	var width: float = base_width * (1.0 + pulse * pulse_width_boost) * fade
	if pulse > 0.0:
		c1 = c1.lightened(pulse * pulse_lighten)
		c2 = c2.lightened(pulse * pulse_lighten)
	if selected:
		width *= SELECTED_WIDTH_BOOST
		c1 = c1.lightened(SELECTED_LIGHTEN)
		c2 = c2.lightened(SELECTED_LIGHTEN)

	var alpha: float = minf(card_from.modulate.a, card_to.modulate.a) * fade
	c1.a *= alpha
	c2.a *= alpha

	if style != GraphNetwork.STYLE_SOLID:
		var full_length: float = p1.distance_to(p2)
		if _draw_pattern(p1, p2, full_length * progress, full_length, c1, c2, width, style):
			return

	if progress < 1.0:
		p2 = p1.lerp(p2, progress)
		c2 = c1.lerp(c2, progress)

	_segment(p1, p2, c1, c2, width, false)

func _draw_pattern(from: Vector2, to: Vector2, visible_length: float, full_length: float, c_start: Color, c_end: Color, width: float, style: String) -> bool:
	if full_length <= 0.001 or visible_length <= 0.0:
		return true
	var direction: Vector2 = (to - from) / full_length
	if style == GraphNetwork.STYLE_DOUBLE:
		_draw_double(from, direction, visible_length, full_length, c_start, c_end, width)
		return true
	var has_dash: bool = style != GraphNetwork.STYLE_DOTTED
	var has_dot: bool = style != GraphNetwork.STYLE_DASHED
	var dot_start: float = DASH_LENGTH + DASH_GAP if has_dash else 0.0
	var pitch: float = DASH_LENGTH + DASH_GAP
	if has_dot:
		pitch = dot_start + DOT_SIZE + (DASH_GAP if has_dash else DOT_GAP)
	if visible_length / pitch > float(MAX_PATTERN_PIECES):
		return false

	var radius: float = maxf(width, DOT_SIZE) * 0.5
	var offset: float = 0.0
	while offset < visible_length:
		if has_dash:
			var end: float = minf(offset + DASH_LENGTH, visible_length)
			_segment(from + direction * offset, from + direction * end, c_start.lerp(c_end, offset / full_length), c_start.lerp(c_end, end / full_length), width, true)
		if has_dot and offset + dot_start < visible_length:
			var middle: float = minf(offset + dot_start + DOT_SIZE * 0.5, visible_length)
			_dot(from + direction * middle, radius, c_start.lerp(c_end, middle / full_length))
		offset += pitch
	return true

func _draw_double(from: Vector2, direction: Vector2, visible_length: float, full_length: float, c_start: Color, c_end: Color, width: float) -> void:
	var shift: Vector2 = direction.orthogonal() * width * (1.0 + DOUBLE_LINE_SCALE) * 0.5
	var colors: PackedColorArray = PackedColorArray([c_start, c_start.lerp(c_end, visible_length / full_length)])
	var end: Vector2 = from + direction * visible_length
	for side: float in [-1.0, 1.0]:
		_segment(from + shift * side, end + shift * side, colors[0], colors[1], width * DOUBLE_LINE_SCALE, false)

func _segment(from: Vector2, to: Vector2, c_start: Color, c_end: Color, width: float, round_caps: bool) -> void:
	var length: float = from.distance_to(to)
	if length < MIN_SEGMENT_LENGTH:
		return
	var direction: Vector2 = (to - from) / length
	var radius: float = width * 0.5
	var reach: float = radius + _margin
	var extent: float = reach / radius
	var across: Vector2 = direction.orthogonal() * reach
	if round_caps:
		var inset: float = minf(radius, length * 0.5)
		from += direction * inset
		to -= direction * inset
		_quad(from - direction * reach, from, -extent, 0.0, c_start, c_start, across, extent)
		_quad(to, to + direction * reach, 0.0, extent, c_end, c_end, across, extent)
	_quad(from, to, 0.0, 0.0, c_start, c_end, across, extent)

func _quad(from: Vector2, to: Vector2, along_from: float, along_to: float, c_from: Color, c_to: Color, across: Vector2, extent: float) -> void:
	var points: PackedVector2Array = PackedVector2Array([from + across, to + across, to - across, from - across])
	var colors: PackedColorArray = PackedColorArray([c_from, c_to, c_to, c_from])
	var uvs: PackedVector2Array = PackedVector2Array([Vector2(along_from, extent), Vector2(along_to, extent), Vector2(along_to, -extent), Vector2(along_from, -extent)])
	draw_primitive(points, colors, uvs)

func _dot(center: Vector2, radius: float, color: Color) -> void:
	var reach: float = radius + _margin
	var extent: float = reach / radius
	var points: PackedVector2Array = PackedVector2Array([center + Vector2(-reach, -reach), center + Vector2(reach, -reach), center + Vector2(reach, reach), center + Vector2(-reach, reach)])
	var uvs: PackedVector2Array = PackedVector2Array([Vector2(-extent, -extent), Vector2(extent, -extent), Vector2(extent, extent), Vector2(-extent, extent)])
	draw_primitive(points, PackedColorArray([color, color, color, color]), uvs)
