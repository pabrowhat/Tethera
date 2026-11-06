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
const MAX_PATTERN_PIECES: int = 4000
const SELECTED_LIGHTEN: float = 0.35
const SELECTED_WIDTH_BOOST: float = 1.5

func _ready() -> void:
	RenderingServer.canvas_item_set_custom_rect(get_canvas_item(), true, INFINITE_BOUNDS)
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
		draw_line(preview_from_pos, preview_to_pos, current_preview_color, effective_width, true)

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

	if c1.is_equal_approx(c2):
		draw_line(p1, p2, c1, width, true)
	else:
		var points: PackedVector2Array = PackedVector2Array([p1, p2])
		var colors: PackedColorArray = PackedColorArray([c1, c2])
		draw_polyline_colors(points, colors, width, true)

func _draw_pattern(from: Vector2, to: Vector2, visible_length: float, full_length: float, c_start: Color, c_end: Color, width: float, style: String) -> bool:
	if full_length <= 0.001 or visible_length <= 0.0:
		return true
	var is_dotted: bool = style == GraphNetwork.STYLE_DOTTED
	var piece: float = DOT_SIZE if is_dotted else DASH_LENGTH
	var pitch: float = piece + (DOT_GAP if is_dotted else DASH_GAP)
	if visible_length / pitch > float(MAX_PATTERN_PIECES):
		return false

	var direction: Vector2 = (to - from) / full_length
	var radius: float = maxf(width, DOT_SIZE) * 0.5
	var offset: float = 0.0
	while offset < visible_length:
		if is_dotted:
			var middle: float = minf(offset + piece * 0.5, visible_length)
			draw_circle(from + direction * middle, radius, c_start.lerp(c_end, middle / full_length), true, -1.0, true)
		else:
			var end: float = minf(offset + piece, visible_length)
			var points: PackedVector2Array = PackedVector2Array([from + direction * offset, from + direction * end])
			var colors: PackedColorArray = PackedColorArray([c_start.lerp(c_end, offset / full_length), c_start.lerp(c_end, end / full_length)])
			draw_polyline_colors(points, colors, width, true)
		offset += pitch
	return true
