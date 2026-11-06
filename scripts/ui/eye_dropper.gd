class_name EyeDropper
extends Control

const ICON: Texture2D = preload("res://assets/icons/pipette.svg")
const ICON_SIZE: float = 30.0
const ICON_TIP: Vector2 = Vector2(2.0, 22.0) / 24.0
const ICON_OUTLINE: StringName = &"marker.outline"
const RING_OFFSET: Vector2 = Vector2(30.0, 28.0)
const RING_RADIUS: float = 16.0
const RING_BORDER: float = 3.0
const RIPPLE_DURATION: float = 0.35
const RIPPLE_START_RADIUS: float = 8.0
const RIPPLE_END_RADIUS: float = 58.0
const NO_COLOR_RING: StringName = &"marker.none"
const NO_COLOR_WIDTH: float = 2.0
const RING_HALO: StringName = &"marker.halo"

var _active: bool = false
var _sampler: Callable = Callable()
var _mouse_pos: Vector2 = Vector2.ZERO
var _hover_color: Variant = null
var _ripples: Array[Dictionary] = []
var _ring: RoundedShape = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(false)
	_ring = RoundedShape.new()
	_ring.visible = false
	add_child(_ring)

func _exit_tree() -> void:
	_restore_cursor()

func is_active() -> bool:
	return _active

func begin(sampler: Callable) -> void:
	_sampler = sampler
	_active = true
	_mouse_pos = get_viewport().get_mouse_position()
	_hover_color = _sampler.call(_mouse_pos) if _sampler.is_valid() else null
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	set_process(true)
	queue_redraw()

func end() -> void:
	_active = false
	_restore_cursor()
	_hover_color = null
	set_process(not _ripples.is_empty())
	queue_redraw()

func confirm_sample(screen_pos: Vector2, color: Color) -> void:
	_ripples.append({"pos": screen_pos, "color": color, "t": 0.0})
	set_process(true)

func _restore_cursor() -> void:
	if Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	if _active:
		_mouse_pos = get_viewport().get_mouse_position()
		_hover_color = _sampler.call(_mouse_pos) if _sampler.is_valid() else null

	for i: int in range(_ripples.size() - 1, -1, -1):
		var ripple: Dictionary = _ripples[i]
		ripple["t"] = float(ripple["t"]) + delta / RIPPLE_DURATION
		if float(ripple["t"]) >= 1.0:
			_ripples.remove_at(i)

	if not _active and _ripples.is_empty():
		set_process(false)
	queue_redraw()

func _draw() -> void:
	for ripple: Dictionary in _ripples:
		_draw_ripple(ripple)

	if not _active:
		_ring.visible = false
		return

	var view_size: Vector2 = get_viewport_rect().size
	var offset: Vector2 = RING_OFFSET
	if _mouse_pos.x + offset.x + RING_RADIUS + 4.0 > view_size.x:
		offset.x = -offset.x
	if _mouse_pos.y + offset.y + RING_RADIUS + 4.0 > view_size.y:
		offset.y = -offset.y
		offset.x = -absf(offset.x)
	var center: Vector2 = _mouse_pos + offset

	_ring.visible = true
	if _hover_color == null:
		_ring.place_centered(center, (RING_RADIUS + NO_COLOR_WIDTH * 0.5) * 2.0)
		_ring.set_style(ThemeColors.faded(NO_COLOR_RING, 0.0), ThemeColors.color(NO_COLOR_RING), NO_COLOR_WIDTH)
		_ring.clear_inner()
		draw_line(center + Vector2(-7.0, 7.0), center + Vector2(7.0, -7.0), ThemeColors.color(NO_COLOR_RING), 2.0, true)
	else:
		_ring.place_centered(center, (RING_RADIUS + RING_BORDER) * 2.0)
		_ring.set_style(Color.WHITE, ThemeColors.color(RING_HALO), RING_BORDER)
		_ring.set_inner(_hover_color as Color, RING_BORDER * 2.0)

	_draw_pipette_cursor()

func _draw_ripple(ripple: Dictionary) -> void:
	var progress: float = clampf(float(ripple["t"]), 0.0, 1.0)
	var eased: float = 1.0 - pow(1.0 - progress, 3.0)
	var radius: float = lerpf(RIPPLE_START_RADIUS, RIPPLE_END_RADIUS, eased)
	var color: Color = ripple["color"] as Color
	var pos: Vector2 = ripple["pos"] as Vector2
	var fade: float = 1.0 - progress

	draw_circle(pos, radius, Color(color, 0.22 * fade * fade))
	draw_arc(pos, radius, 0.0, TAU, 48, Color(color.lightened(0.35), 0.95 * fade), lerpf(4.0, 1.0, progress), true)

func _draw_pipette_cursor() -> void:
	var rect: Rect2 = Rect2(_mouse_pos - ICON_TIP * ICON_SIZE, Vector2(ICON_SIZE, ICON_SIZE))
	for outline_offset: Vector2 in [Vector2(-1.5, 0.0), Vector2(1.5, 0.0), Vector2(0.0, -1.5), Vector2(0.0, 1.5)]:
		draw_texture_rect(ICON, Rect2(rect.position + outline_offset, rect.size), false, ThemeColors.color(ICON_OUTLINE))
	draw_texture_rect(ICON, rect, false, Color.WHITE)
