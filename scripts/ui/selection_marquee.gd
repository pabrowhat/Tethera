class_name SelectionMarquee
extends Control

const FILL_ALPHA: float = 0.12
const BORDER_ALPHA: float = 0.8

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
	draw_rect(_screen_rect, ThemeColors.faded(&"accent", FILL_ALPHA), true)
	draw_rect(_screen_rect, ThemeColors.faded(&"accent", BORDER_ALPHA), false, 1.0)
