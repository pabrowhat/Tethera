class_name HudToast
extends Control

const BOTTOM_MARGIN: float = 28.0
const SLIDE_DISTANCE: float = 14.0
const SHOW_DURATION: float = 0.18
const HIDE_DURATION: float = 0.25
const DEFAULT_HOLD: float = 2.2
const WARNING_HOLD: float = 3.8
const BACKGROUND: Color = Color(0.141176, 0.152941, 0.211765, 0.96)
const WARNING_BORDER: Color = Color(0.905882, 0.298039, 0.235294, 0.9)
const TEXT_COLOR: Color = Color(0.88, 0.89, 0.94, 1.0)

var _panel: PanelContainer = null
var _label: Label = null
var _style: StyleBoxFlat = null
var _tween: Tween = null
var _slide: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	_style = UiStyle.box(BACKGROUND, UiStyle.BORDER, 18, 16.0, 8.0)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _style)
	_panel.minimum_size_changed.connect(_refit)
	add_child(_panel)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_panel.add_child(_label)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()

func show_message(text: String, warning: bool = false, hold: float = 0.0) -> void:
	if _label == null:
		return

	var was_visible: bool = visible and modulate.a > 0.05
	_kill_tween()

	_label.text = text
	_style.border_color = WARNING_BORDER if warning else UiStyle.BORDER
	_refit()
	visible = true

	var hold_time: float = hold if hold > 0.0 else (WARNING_HOLD if warning else DEFAULT_HOLD)
	_tween = create_tween()
	if was_visible:
		_set_progress(1.0)
	else:
		_set_progress(0.0)
		_tween.tween_method(_set_progress, 0.0, 1.0, SHOW_DURATION) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(hold_time)
	_tween.tween_property(self, "modulate:a", 0.0, HIDE_DURATION)
	_tween.tween_callback(func() -> void: visible = false)

func _set_progress(progress: float) -> void:
	modulate.a = progress
	_slide = (1.0 - progress) * SLIDE_DISTANCE
	_layout()

func _refit() -> void:
	_panel.reset_size()
	_layout()

func _layout() -> void:
	if _panel == null:
		return
	var panel_size: Vector2 = _panel.size
	_panel.position = Vector2(
		roundf((size.x - panel_size.x) * 0.5),
		size.y - BOTTOM_MARGIN - panel_size.y + _slide
	)

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
