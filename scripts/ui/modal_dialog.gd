class_name ModalDialog
extends ColorRect

signal canceled

const BACKDROP: Color = Color(0.04, 0.04, 0.06, 0.65)
const TITLE_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const TEXT_COLOR: Color = Color(0.85, 0.86, 0.9, 1.0)
const MUTED_COLOR: Color = Color(0.65, 0.68, 0.78, 1.0)
const WARNING_COLOR: Color = Color(0.95, 0.62, 0.3, 1.0)
const OPEN_DURATION: float = 0.2
const CLOSE_DURATION: float = 0.12

var dismiss_on_backdrop: bool = true

var _card: PanelContainer = null
var _body: VBoxContainer = null
var _tween: Tween = null
var _is_open: bool = false

func _init() -> void:
	color = BACKDROP
	visible = false
	modulate.a = 0.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_card = PanelContainer.new()
	var card_style: StyleBoxFlat = UiStyle.box(PopupList.PANEL_BG, UiStyle.BORDER, 10, 0.0, 0.0)
	card_style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	card_style.shadow_size = 18
	card_style.shadow_offset = Vector2(0.0, 8.0)
	_card.add_theme_stylebox_override("panel", card_style)
	center.add_child(_card)

	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["margin_left", "margin_right"]:
		margin.add_theme_constant_override(side, 20)
	for side: String in ["margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	_card.add_child(margin)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 10)
	margin.add_child(_body)

	set_process_input(false)

func is_open() -> bool:
	return _is_open

func _set_card_width(width: float) -> void:
	_card.custom_minimum_size = Vector2(width, 0.0)

func open() -> void:
	_is_open = true
	_kill_tween()
	visible = true
	modulate.a = 0.0
	_card.pivot_offset = _card.size / 2.0
	_card.scale = Vector2(0.92, 0.92)
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, OPEN_DURATION * 0.75)
	_tween.tween_property(_card, "scale", Vector2.ONE, OPEN_DURATION)
	set_process_input(true)

func close() -> void:
	if not _is_open:
		return
	_is_open = false
	set_process_input(false)
	_kill_tween()
	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(self, "modulate:a", 0.0, CLOSE_DURATION)
	_tween.tween_property(_card, "scale", Vector2(0.95, 0.95), CLOSE_DURATION)
	_tween.chain().tween_callback(_hide_when_closed)

func cancel() -> void:
	if not _is_open:
		return
	close()
	canceled.emit()

func _on_cancel_requested() -> void:
	cancel()

func _hide_when_closed() -> void:
	if not _is_open:
		visible = false

func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

func _clear_body() -> void:
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT and click.pressed and dismiss_on_backdrop:
			if not _card.get_global_rect().has_point(click.global_position):
				_on_cancel_requested()
		accept_event()

func _input(event: InputEvent) -> void:
	if not _is_open or not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if key.pressed and not key.is_echo() and key.keycode == KEY_ESCAPE:
		_on_cancel_requested()
		get_viewport().set_input_as_handled()

func _make_label(text: String, font_size: int, text_color: Color, wrap: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", text_color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _make_button(text: String, primary: bool) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, 34.0)
	button.add_theme_font_size_override("font_size", 13)
	if primary:
		button.add_theme_color_override("font_color", TITLE_COLOR)
		button.add_theme_color_override("font_hover_color", TITLE_COLOR)
		button.add_theme_color_override("font_pressed_color", TITLE_COLOR)
		button.add_theme_color_override("font_disabled_color", Color(1.0, 1.0, 1.0, 0.4))
		button.add_theme_stylebox_override("normal", UiStyle.box(UiStyle.ACCENT_SOFT, UiStyle.ACCENT_SOFT, 6, 16.0, 8.0))
		button.add_theme_stylebox_override("hover", UiStyle.box(UiStyle.ACCENT, UiStyle.ACCENT, 6, 16.0, 8.0))
		button.add_theme_stylebox_override("pressed", UiStyle.box(UiStyle.ACCENT, UiStyle.ACCENT, 6, 16.0, 8.0))
		button.add_theme_stylebox_override("disabled", UiStyle.box(UiStyle.BG_NORMAL, UiStyle.BG_NORMAL, 6, 16.0, 8.0))
	else:
		button.add_theme_color_override("font_color", TEXT_COLOR)
		button.add_theme_stylebox_override("normal", UiStyle.box(UiStyle.BG_NORMAL, UiStyle.BG_NORMAL, 6, 16.0, 8.0))
		button.add_theme_stylebox_override("hover", UiStyle.box(UiStyle.BG_HOVER, UiStyle.BG_HOVER, 6, 16.0, 8.0))
	return button
