class_name VaultFolderDialog
extends ModalDialog

signal folder_chosen(path: String)
signal create_requested

const DIALOG_WIDTH: float = 460.0

var _title_label: Label = null
var _message_label: Label = null
var _error_label: Label = null
var _choose_button: Button = null
var _create_button: Button = null
var _system_dialog_open: bool = false

func _init() -> void:
	super()
	dismiss_on_backdrop = false
	_set_card_width(DIALOG_WIDTH)

	_title_label = _make_label("", 15, TITLE_COLOR)
	_body.add_child(_title_label)
	_message_label = _make_label("", 13, TEXT_COLOR, true)
	_body.add_child(_message_label)
	_error_label = _make_label("", 12, WARNING_COLOR, true)
	_error_label.visible = false
	_body.add_child(_error_label)

	var footer: HBoxContainer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 8)
	_body.add_child(footer)
	_create_button = _make_button("vault.missing.create", false)
	_create_button.pressed.connect(func() -> void: create_requested.emit())
	footer.add_child(_create_button)
	_choose_button = _make_button("vault.pick.choose", true)
	_choose_button.pressed.connect(_open_system_dialog)
	footer.add_child(_choose_button)

func open_first_launch() -> void:
	_title_label.text = "vault.pick.title"
	_message_label.text = "vault.pick.message"
	_choose_button.text = "vault.pick.choose"
	_create_button.visible = false
	_show_error_text("")
	open()

func open_missing(path: String) -> void:
	_title_label.text = "vault.missing.title"
	_message_label.text = tr("vault.missing.message") % path
	_choose_button.text = "vault.missing.choose"
	_create_button.visible = true
	_show_error_text("")
	open()

func show_error(text: String) -> void:
	_show_error_text(text)

func _show_error_text(text: String) -> void:
	_error_label.text = text
	_error_label.visible = text != ""

func _on_cancel_requested() -> void:
	pass

func _open_system_dialog() -> void:
	if _system_dialog_open:
		return
	_system_dialog_open = true
	DisplayServer.file_dialog_show(
		tr("vault.pick.dialog_title"),
		OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS),
		"",
		false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_DIR,
		PackedStringArray(),
		_on_system_dialog_result
	)

func _on_system_dialog_result(status: bool, selected_paths: PackedStringArray, _filter_index: int) -> void:
	_system_dialog_open = false
	if status and not selected_paths.is_empty():
		folder_chosen.emit(selected_paths[0])
