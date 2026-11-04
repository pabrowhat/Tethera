class_name ShutterFlash
extends ColorRect

const PEAK_ALPHA: float = 0.4
const IN_DURATION: float = 0.06
const OUT_DURATION: float = 0.25

var _tween: Tween = null

func _ready() -> void:
	color = Color(1.0, 1.0, 1.0, 0.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

func begin() -> void:
	_kill_tween()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "color:a", PEAK_ALPHA, IN_DURATION)

func end() -> void:
	_kill_tween()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "color:a", 0.0, OUT_DURATION)
	_tween.tween_callback(func() -> void: visible = false)

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
