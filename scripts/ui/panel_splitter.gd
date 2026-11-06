class_name PanelSplitter
extends Control

signal width_dragged(new_width: float)
signal drag_finished

const HANDLE_WIDTH: float = 8.0
const LINE_WIDTH: float = 2.0
const IDLE_COLOR: StringName = &"border.soft"
const ACCENT_COLOR: StringName = &"accent"
const HIGHLIGHT_DURATION: float = 0.1

var _highlight: float = 0.0
var _is_hovered: bool = false
var _is_dragging: bool = false
var _highlight_tween: Tween = null

func _init() -> void:
	custom_minimum_size = Vector2(HANDLE_WIDTH, 0.0)
	mouse_default_cursor_shape = Control.CURSOR_HSIZE
	mouse_filter = Control.MOUSE_FILTER_STOP

func _ready() -> void:
	mouse_entered.connect(_on_hover_changed.bind(true))
	mouse_exited.connect(_on_hover_changed.bind(false))

func is_dragging() -> bool:
	return _is_dragging

func _draw() -> void:
	var accent: Color = ThemeColors.color(ACCENT_COLOR)
	var line_color: Color = ThemeColors.color(IDLE_COLOR).lerp(accent, _highlight)
	var x: float = size.x - LINE_WIDTH
	draw_rect(Rect2(x, 0.0, LINE_WIDTH, size.y), line_color)
	if _highlight > 0.01:
		draw_rect(Rect2(x - 3.0, 0.0, 3.0, size.y), Color(accent, 0.12 * _highlight))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button: InputEventMouseButton = event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT:
			return
		_is_dragging = button.pressed
		if not button.pressed:
			drag_finished.emit()
			_refresh_highlight()
		else:
			_refresh_highlight()
		accept_event()
	elif event is InputEventMouseMotion and _is_dragging:
		var viewport_width: float = get_viewport_rect().size.x
		width_dragged.emit(viewport_width - get_global_mouse_position().x)
		accept_event()

func _on_hover_changed(hovered: bool) -> void:
	_is_hovered = hovered
	_refresh_highlight()

func _refresh_highlight() -> void:
	var target: float = 1.0 if (_is_hovered or _is_dragging) else 0.0
	if _highlight_tween != null and _highlight_tween.is_valid():
		_highlight_tween.kill()
	_highlight_tween = create_tween()
	_highlight_tween.tween_method(_set_highlight, _highlight, target, HIGHLIGHT_DURATION)

func _set_highlight(value: float) -> void:
	_highlight = value
	queue_redraw()
