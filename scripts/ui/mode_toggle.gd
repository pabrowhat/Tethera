class_name ModeToggle
extends Control

signal mode_changed(preview: bool)

const SLIDE_DURATION: float = 0.1
const HEIGHT: float = 30.0
const PADDING: float = 3.0
const TRACK_COLOR: Color = Color(0.141176, 0.152941, 0.211765, 1.0)
const TRACK_BORDER: Color = Color(0.247059, 0.266667, 0.364706, 1.0)
const PILL_COLOR: Color = Color("6870fa")
const TEXT_ACTIVE: Color = Color(1.0, 1.0, 1.0, 1.0)
const TEXT_IDLE: Color = Color(0.62, 0.65, 0.76, 1.0)
const FONT_SIZE: int = 13

@export var edit_text: String = ""
@export var preview_text: String = ""

var is_preview: bool = false

var _slide: float = 0.0
var _slide_tween: Tween = null
var _pill: RoundedShape = null

func _init() -> void:
	custom_minimum_size = Vector2(190.0, HEIGHT)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_NONE

	var track: RoundedShape = RoundedShape.new()
	track.show_behind_parent = true
	track.set_style(TRACK_COLOR, TRACK_BORDER, 1.0)
	track.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(track)

	_pill = RoundedShape.new()
	_pill.show_behind_parent = true
	_pill.set_style(PILL_COLOR, PILL_COLOR, 0.0)
	add_child(_pill)
	_layout_pill()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()
	elif what == NOTIFICATION_RESIZED and _pill != null:
		_layout_pill()

func set_preview(value: bool, animate: bool = true) -> void:
	if value == is_preview and is_equal_approx(_slide, 1.0 if value else 0.0):
		return
	is_preview = value
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()

	if not animate or not is_inside_tree():
		_set_slide(1.0 if value else 0.0)
		return

	_slide_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slide_tween.tween_method(_set_slide, _slide, 1.0 if value else 0.0, SLIDE_DURATION)

func _set_slide(value: float) -> void:
	_slide = value
	_layout_pill()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	var want_preview: bool = button.position.x >= size.x * 0.5
	accept_event()
	if want_preview == is_preview:
		return
	set_preview(want_preview, true)
	mode_changed.emit(want_preview)

func _layout_pill() -> void:
	var half: float = size.x * 0.5
	_pill.position = Vector2(PADDING + half * _slide, PADDING)
	_pill.size = Vector2(half - PADDING * 2.0, size.y - PADDING * 2.0)

func _draw() -> void:
	var half: float = size.x * 0.5
	var font: Font = get_theme_default_font()
	_draw_label(font, edit_text if edit_text != "" else tr("sidebar.mode.edit"), 0.0, half, 1.0 - _slide)
	_draw_label(font, preview_text if preview_text != "" else tr("sidebar.mode.view"), half, half, _slide)

func _draw_label(font: Font, text: String, left: float, width: float, active_amount: float) -> void:
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE)
	var baseline: float = (size.y + font.get_ascent(FONT_SIZE) - font.get_descent(FONT_SIZE)) * 0.5
	var origin: Vector2 = Vector2(left + (width - text_size.x) * 0.5, baseline)
	draw_string(font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, TEXT_IDLE.lerp(TEXT_ACTIVE, active_amount))
