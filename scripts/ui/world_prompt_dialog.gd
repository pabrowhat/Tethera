class_name WorldPromptDialog
extends ModalDialog

const DIALOG_WIDTH: float = 460.0

var _callback: Callable = Callable()
var _is_taken: Callable = Callable()
var _title_label: Label = null
var _name_page: VBoxContainer = null
var _name_edit: LineEdit = null
var _name_ok: Button = null
var _confirm_page: VBoxContainer = null
var _confirm_label: Label = null
var _delete_button: Button = null
var _error_label: Label = null

func _init() -> void:
	super()
	_set_card_width(DIALOG_WIDTH)
	_title_label = _make_label("", 15, TITLE_COLOR)
	_body.add_child(_title_label)

	_name_page = VBoxContainer.new()
	_name_page.add_theme_constant_override("separation", 10)
	_body.add_child(_name_page)
	_name_edit = LineEdit.new()
	_name_edit.max_length = WorldRegistry.MAX_NEW_NAME_LENGTH
	_name_edit.placeholder_text = "worlds.name.placeholder"
	_name_edit.custom_minimum_size = Vector2(0.0, 34.0)
	_name_edit.text_changed.connect(_on_name_changed)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _confirm_name())
	_name_page.add_child(_name_edit)
	var name_footer: HBoxContainer = _make_footer(_name_page)
	_name_ok = _make_button("worlds.name.ok", true)
	_name_ok.pressed.connect(_confirm_name)
	name_footer.add_child(_name_ok)

	_confirm_page = VBoxContainer.new()
	_confirm_page.add_theme_constant_override("separation", 10)
	_body.add_child(_confirm_page)
	_confirm_label = _make_label("", 13, TEXT_COLOR, true)
	_confirm_page.add_child(_confirm_label)
	var confirm_footer: HBoxContainer = _make_footer(_confirm_page)
	_delete_button = _make_button("worlds.delete.confirm", true)
	_delete_button.pressed.connect(_confirm_delete)
	confirm_footer.add_child(_delete_button)

	_error_label = _make_label("", 12, WARNING_COLOR, true)
	_error_label.visible = false
	_body.add_child(_error_label)

func _make_footer(page: VBoxContainer) -> HBoxContainer:
	var footer: HBoxContainer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	footer.add_theme_constant_override("separation", 8)
	page.add_child(footer)
	var cancel_button: Button = _make_button("worlds.cancel", false)
	cancel_button.pressed.connect(cancel)
	footer.add_child(cancel_button)
	return footer

func prompt_name(title: String, default_name: String, callback: Callable, is_taken: Callable = Callable()) -> void:
	_callback = callback
	_is_taken = is_taken
	_title_label.text = title
	_name_page.visible = true
	_confirm_page.visible = false
	_name_edit.text = default_name.left(WorldRegistry.MAX_NEW_NAME_LENGTH)
	_on_name_changed(_name_edit.text)
	open()
	_name_edit.grab_focus.call_deferred()
	_name_edit.select_all.call_deferred()

func prompt_delete(world_name: String, note_count: int, callback: Callable) -> void:
	_callback = callback
	_title_label.text = "worlds.delete.title"
	_confirm_label.text = tr("worlds.delete.message") % [world_name, note_count]
	_delete_button.text = "worlds.delete.confirm"
	_name_page.visible = false
	_confirm_page.visible = true
	show_error("")
	open()

func prompt_delete_damaged(world_name: String, note_count: int, callback: Callable) -> void:
	_callback = callback
	_title_label.text = "worlds.delete.title"
	_confirm_label.text = tr("worlds.delete.damaged_message") % [world_name, note_count]
	_delete_button.text = "worlds.delete.forever"
	_name_page.visible = false
	_confirm_page.visible = true
	show_error("")
	open()

func show_error(text: String) -> void:
	_error_label.text = text
	_error_label.visible = text != ""

func close() -> void:
	_callback = Callable()
	_is_taken = Callable()
	super()

func _name_problem(text: String) -> String:
	var problem: String = WorldRegistry.check_name(text)
	if problem == "" and _is_taken.is_valid() and bool(_is_taken.call(text)):
		return WorldRegistry.REASON_NAME_TAKEN
	return problem

func _on_name_changed(text: String) -> void:
	var problem: String = _name_problem(text)
	_name_ok.disabled = problem != ""
	show_error(tr(problem) if problem != "" and text != "" else "")

func _confirm_name() -> void:
	var problem: String = _name_problem(_name_edit.text)
	if problem != "":
		show_error(tr(problem))
		return
	if _callback.is_valid():
		_callback.call(_name_edit.text.strip_edges())

func _confirm_delete() -> void:
	if _callback.is_valid():
		_callback.call()
