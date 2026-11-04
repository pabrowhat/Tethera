class_name ConfirmModal
extends ColorRect

signal confirmed
signal canceled

@onready var panel: PanelContainer = $CenterContainer/PanelContainer
@onready var title_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var message_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/MessageLabel
@onready var cancel_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/CancelButton
@onready var confirm_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonContainer/ConfirmButton

var _tween: Tween = null

func _ready() -> void:
	visible = false
	modulate.a = 0.0
	cancel_button.pressed.connect(_on_cancel_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var panel_rect: Rect2 = panel.get_global_rect()
			if not panel_rect.has_point(mb.global_position):
				_on_cancel_pressed()
				accept_event()

func prompt(title_text: String, message_text: String, confirm_btn_text: String = "", cancel_btn_text: String = "") -> void:
	title_label.text = title_text
	message_label.text = message_text
	confirm_button.text = confirm_btn_text if confirm_btn_text != "" else tr("confirm.delete")
	cancel_button.text = cancel_btn_text if cancel_btn_text != "" else tr("confirm.cancel")
	_animate_open(true)

func _animate_open(open_state: bool) -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

	_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC)

	if open_state:
		visible = true
		panel.scale = Vector2(0.92, 0.92)
		panel.pivot_offset = panel.size / 2.0
		_tween.set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "modulate:a", 1.0, 0.15)
		_tween.tween_property(panel, "scale", Vector2.ONE, 0.2)
	else:
		_tween.set_ease(Tween.EASE_IN)
		_tween.tween_property(self, "modulate:a", 0.0, 0.12)
		_tween.tween_property(panel, "scale", Vector2(0.95, 0.95), 0.12)
		_tween.chain().tween_callback(func() -> void: visible = false)

func _on_cancel_pressed() -> void:
	_animate_open(false)
	canceled.emit()

func _on_confirm_pressed() -> void:
	_animate_open(false)
	confirmed.emit()
