class_name Lightbox
extends ColorRect

signal closed

const BACKDROP_COLOR: StringName = &"overlay.lightbox"
const SCREEN_FILL: float = 0.9
const MAX_UPSCALE: float = 3.0
const FADE_IN_DURATION: float = 0.15
const POP_DURATION: float = 0.18
const POP_START_SCALE: float = 0.8
const CLOSE_DURATION: float = 0.12
const CLOSE_END_SCALE: float = 0.92
const MIN_ZOOM: float = 0.25
const MAX_PIXEL_ZOOM: float = 16.0
const WHEEL_STEP: float = 1.2
const DRAG_THRESHOLD: float = 5.0

var _picture: TextureRect = null
var _tween: Tween = null
var _is_open: bool = false
var _fit_position: Vector2 = Vector2.ZERO
var _max_zoom: float = 1.0
var _pressed: bool = false
var _dragging: bool = false
var _press_origin: Vector2 = Vector2.ZERO

func _ready() -> void:
	ThemeColors.bind(self, &"color", BACKDROP_COLOR)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	modulate.a = 0.0

	_picture = TextureRect.new()
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_picture)

func is_open() -> bool:
	return _is_open

func open(texture: Texture2D, origin_rect: Rect2) -> void:
	if texture == null or _is_open:
		return
	var texture_size: Vector2 = texture.get_size()
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return

	_kill_tween()
	_is_open = true
	get_viewport().gui_release_focus()

	var view_size: Vector2 = get_viewport_rect().size
	var limit: Vector2 = view_size * SCREEN_FILL
	var fit: float = minf(minf(limit.x / texture_size.x, limit.y / texture_size.y), MAX_UPSCALE)
	var shown_size: Vector2 = (texture_size * fit).floor()
	var final_position: Vector2 = ((view_size - shown_size) * 0.5).floor()

	var start_center: Vector2 = origin_rect.get_center() if origin_rect.size != Vector2.ZERO else view_size * 0.5

	_picture.texture = texture
	_picture.size = shown_size
	_picture.pivot_offset = shown_size * 0.5
	_picture.scale = Vector2(POP_START_SCALE, POP_START_SCALE)
	_picture.position = start_center - shown_size * 0.5
	_fit_position = final_position
	_max_zoom = maxf(MAX_PIXEL_ZOOM / fit, 1.0)
	_pressed = false
	_dragging = false

	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 0.0
	visible = true

	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN_DURATION)
	_tween.tween_property(_picture, "scale", Vector2.ONE, POP_DURATION)
	_tween.tween_property(_picture, "position", final_position, POP_DURATION)
	UiMotion.settle(_tween)

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_kill_tween()
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, CLOSE_DURATION)
	_tween.tween_property(_picture, "scale", Vector2(CLOSE_END_SCALE, CLOSE_END_SCALE), CLOSE_DURATION)
	_tween.chain().tween_callback(_on_close_finished)
	UiMotion.settle(_tween)
	closed.emit()

func _gui_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventMouseButton:
		_on_mouse_button(event as InputEventMouseButton)
	elif event is InputEventMouseMotion and _pressed:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if not _dragging and motion.position.distance_to(_press_origin) >= DRAG_THRESHOLD:
			_dragging = true
			_settle()
		if _dragging:
			_picture.position += motion.relative
	accept_event()

func _on_mouse_button(mb: InputEventMouseButton) -> void:
	match mb.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			if mb.pressed:
				_zoom_at(mb.position, WHEEL_STEP)
		MOUSE_BUTTON_WHEEL_DOWN:
			if mb.pressed:
				_zoom_at(mb.position, 1.0 / WHEEL_STEP)
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE:
			if mb.pressed:
				if mb.double_click:
					_reset_view()
					_pressed = false
				else:
					_pressed = true
					_dragging = false
					_press_origin = mb.position
			else:
				var was_click: bool = _pressed and not _dragging and mb.button_index == MOUSE_BUTTON_LEFT
				_pressed = false
				_dragging = false
				if was_click:
					close()

func _settle() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
		_picture.scale = Vector2.ONE
		_picture.position = _fit_position
		modulate.a = 1.0
	_picture.pivot_offset = Vector2.ZERO

func _zoom_at(screen_point: Vector2, factor: float) -> void:
	_settle()
	var old_zoom: float = _picture.scale.x
	var new_zoom: float = clampf(old_zoom * factor, MIN_ZOOM, _max_zoom)
	if is_equal_approx(new_zoom, old_zoom):
		return
	_picture.position = screen_point - (screen_point - _picture.position) * (new_zoom / old_zoom)
	_picture.scale = Vector2(new_zoom, new_zoom)

func _reset_view() -> void:
	_settle()
	_picture.scale = Vector2.ONE
	_picture.position = _fit_position

func _on_close_finished() -> void:
	visible = false
	_picture.texture = null

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
