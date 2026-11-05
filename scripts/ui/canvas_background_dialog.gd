class_name CanvasBackgroundDialog
extends ModalDialog

signal pick_requested
signal clear_requested
signal opacity_changed(value: float, persist: bool)

const DIALOG_WIDTH: float = 380.0

var _name_label: Label = null
var _picture_name: String = ""
var _clear_button: Button = null
var _slider: HSlider = null
var _value_label: Label = null
var _dragging: bool = false

func _init() -> void:
	super()
	_set_card_width(DIALOG_WIDTH)

	_body.add_child(_make_label("canvas_bg.title", 15, TITLE_COLOR))
	_name_label = _make_label("", 12, MUTED_COLOR, true)
	_body.add_child(_name_label)

	var picture_row: HBoxContainer = HBoxContainer.new()
	picture_row.add_theme_constant_override("separation", 8)
	_body.add_child(picture_row)
	var pick_button: Button = _make_button("canvas_bg.pick", true)
	pick_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pick_button.pressed.connect(func() -> void: pick_requested.emit())
	picture_row.add_child(pick_button)
	_clear_button = _make_button("canvas_bg.clear", false)
	_clear_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_clear_button.pressed.connect(func() -> void: clear_requested.emit())
	picture_row.add_child(_clear_button)

	var opacity_row: HBoxContainer = HBoxContainer.new()
	opacity_row.add_theme_constant_override("separation", 10)
	_body.add_child(opacity_row)
	opacity_row.add_child(_make_label("canvas_bg.opacity", 13, TEXT_COLOR))
	_slider = StyledSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 100.0
	_slider.step = 1.0
	_slider.value = CanvasBackground.DEFAULT_OPACITY * 100.0
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_slider.focus_mode = Control.FOCUS_NONE
	_slider.value_changed.connect(_on_slider_changed)
	_slider.drag_started.connect(func() -> void: _dragging = true)
	_slider.drag_ended.connect(_on_slider_drag_ended)
	opacity_row.add_child(_slider)
	_value_label = _make_label("100 %", 13, TEXT_COLOR)
	_value_label.custom_minimum_size = Vector2(48.0, 0.0)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	opacity_row.add_child(_value_label)

	var footer: HBoxContainer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	_body.add_child(footer)
	var done_button: Button = _make_button("canvas_bg.done", false)
	done_button.pressed.connect(close)
	footer.add_child(done_button)

func show_state(picture_name: String, opacity: float) -> void:
	_picture_name = picture_name
	_name_label.text = picture_name if picture_name != "" else "canvas_bg.none"
	_clear_button.disabled = picture_name == ""
	_slider.set_value_no_signal(roundf(opacity * 100.0))
	_value_label.text = "%d %%" % int(_slider.value)

func open_dialog() -> void:
	_dragging = false
	open()

func _on_slider_changed(value: float) -> void:
	_value_label.text = "%d %%" % int(value)
	opacity_changed.emit(value / 100.0, not _dragging)

func _on_slider_drag_ended(value_changed: bool) -> void:
	_dragging = false
	if value_changed:
		opacity_changed.emit(_slider.value / 100.0, true)
