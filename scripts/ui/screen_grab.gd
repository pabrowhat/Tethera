class_name ScreenGrab
extends RefCounted

const REFRESH_DELAY: float = 0.25

var _image: Image = null
var _scale: Vector2 = Vector2.ONE
var _busy: bool = false
var _again: bool = false
var _refresh_token: int = 0

func has_image() -> bool:
	return _image != null

func is_busy() -> bool:
	return _busy

func capture(viewport: Viewport, hidden: CanvasItem) -> void:
	if _busy:
		_again = true
		return
	_busy = true
	var was_visible: bool = hidden.visible
	while true:
		_again = false
		hidden.visible = false
		await RenderingServer.frame_post_draw
		var texture: ViewportTexture = viewport.get_texture()
		var shot: Image = texture.get_image() if texture != null else null
		if shot != null and not shot.is_empty():
			var logical: Vector2 = viewport.get_visible_rect().size
			if logical.x > 0.0 and logical.y > 0.0:
				_image = shot
				_scale = Vector2(shot.get_width(), shot.get_height()) / logical
		if not _again:
			break
	hidden.visible = was_visible
	_busy = false

func refresh_soon(viewport: Viewport, hidden: CanvasItem) -> void:
	_refresh_token += 1
	var mine: int = _refresh_token
	await viewport.get_tree().create_timer(REFRESH_DELAY).timeout
	if mine == _refresh_token:
		await capture(viewport, hidden)

func release() -> void:
	_refresh_token += 1
	_image = null

func color_at(viewport_pos: Vector2) -> Variant:
	if _image == null:
		return null
	var x: int = floori(viewport_pos.x * _scale.x)
	var y: int = floori(viewport_pos.y * _scale.y)
	if x < 0 or y < 0 or x >= _image.get_width() or y >= _image.get_height():
		return null
	return Color(_image.get_pixel(x, y), 1.0)
