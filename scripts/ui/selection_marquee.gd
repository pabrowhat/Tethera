class_name SelectionMarquee
extends Control

const FILL_COLOR: Color = Color(0.41, 0.44, 0.98, 0.12)
const BORDER_COLOR: Color = Color(0.41, 0.44, 0.98, 0.8)

var _screen_rect: Rect2 = Rect2()
var _has_rect: bool = false

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_rect(screen_rect: Rect2) -> void:
	_screen_rect = screen_rect
	_has_rect = true
	queue_redraw()

func hide_rect() -> void:
	if _has_rect:
		_has_rect = false
		queue_redraw()

func _draw() -> void:
	if not _has_rect:
		return
	draw_rect(_screen_rect, FILL_COLOR, true)
	draw_rect(_screen_rect, BORDER_COLOR, false, 1.0)
