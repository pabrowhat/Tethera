class_name StyledSlider
extends HSlider

const KNOB_RADIUS: float = 8.0
const RING_WIDTH: float = 2.0
const KNOB_FILL: Color = Color(0.88, 0.89, 0.94, 1.0)
const KNOB_FILL_ACTIVE: Color = Color(1.0, 1.0, 1.0, 1.0)
const KNOB_RING: Color = Color(0.407843, 0.439216, 0.980392, 1.0)
const KNOB_RING_ACTIVE: Color = Color(0.54, 0.565, 1.0, 1.0)

var _hovered: bool = false
var _dragging: bool = false

func _init() -> void:
	var blank: Image = Image.create_empty(int(KNOB_RADIUS * 2.0), int(KNOB_RADIUS * 2.0), false, Image.FORMAT_RGBA8)
	var blank_texture: ImageTexture = ImageTexture.create_from_image(blank)
	add_theme_icon_override("grabber", blank_texture)
	add_theme_icon_override("grabber_highlight", blank_texture)
	add_theme_icon_override("grabber_disabled", blank_texture)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	drag_started.connect(_set_dragging.bind(true))
	drag_ended.connect(func(_changed: bool) -> void: _set_dragging(false))
	value_changed.connect(func(_value: float) -> void: queue_redraw())

func _set_hovered(active: bool) -> void:
	_hovered = active
	queue_redraw()

func _set_dragging(active: bool) -> void:
	_dragging = active
	queue_redraw()

func _draw() -> void:
	var travel: float = maxf(size.x - KNOB_RADIUS * 2.0, 0.0)
	var center: Vector2 = Vector2(KNOB_RADIUS + travel * get_as_ratio(), size.y * 0.5)
	var active: bool = _hovered or _dragging
	draw_circle(center, KNOB_RADIUS, KNOB_FILL_ACTIVE if active else KNOB_FILL, true, -1.0, true)
	draw_arc(center, KNOB_RADIUS - RING_WIDTH * 0.5, 0.0, TAU, 48, KNOB_RING_ACTIVE if active else KNOB_RING, RING_WIDTH, true)
