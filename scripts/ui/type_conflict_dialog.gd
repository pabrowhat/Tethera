class_name TypeConflictDialog
extends ModalDialog

signal resolved(decision: Dictionary)

enum Choice { MERGE, RENAME, SKIP, CANCEL }

const DIALOG_WIDTH: float = 440.0

var _name_field: LineEdit = null
var _error: Label = null
var _is_name_taken: Callable = Callable()

func _init() -> void:
	super()
	dismiss_on_backdrop = false
	_set_card_width(DIALOG_WIDTH)

func ask(type_name: String, index: int, total: int, suggested_name: String, is_name_taken: Callable, can_merge: bool) -> void:
	_is_name_taken = is_name_taken
	_clear_body()

	_body.add_child(_make_label("import.conflict.title", 15, TITLE_COLOR))
	_body.add_child(_make_label(tr("import.conflict.message") % [type_name, index, total], 13, TEXT_COLOR, true))
	_body.add_child(_make_label("import.conflict.help", 12, MUTED_COLOR, true))

	_name_field = LineEdit.new()
	_name_field.text = suggested_name
	_name_field.placeholder_text = "import.conflict.name"
	_name_field.add_theme_font_size_override("font_size", 13)
	_name_field.text_changed.connect(_on_name_changed)
	_name_field.text_submitted.connect(_on_name_submitted)
	_body.add_child(_name_field)

	_error = _make_label("", 12, WARNING_COLOR, true)
	_error.visible = false
	_body.add_child(_error)

	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	footer.alignment = BoxContainer.ALIGNMENT_END
	_body.add_child(footer)

	var cancel_button: Button = _make_button("import.conflict.cancel", false)
	cancel_button.pressed.connect(_decide.bind(Choice.CANCEL))
	footer.add_child(cancel_button)
	var skip_button: Button = _make_button("import.conflict.skip", false)
	skip_button.pressed.connect(_decide.bind(Choice.SKIP))
	footer.add_child(skip_button)
	var rename_button: Button = _make_button("import.conflict.rename", false)
	rename_button.pressed.connect(_on_rename_pressed)
	footer.add_child(rename_button)
	var merge_button: Button = _make_button("import.conflict.merge", true)
	merge_button.disabled = not can_merge
	merge_button.pressed.connect(_decide.bind(Choice.MERGE))
	footer.add_child(merge_button)

	open()
	_name_field.grab_focus()
	_name_field.select_all()

func _on_cancel_requested() -> void:
	_decide(Choice.CANCEL)

func _decide(choice: Choice, type_name: String = "") -> void:
	close()
	resolved.emit({"choice": choice, "name": type_name})

func _on_rename_pressed() -> void:
	_on_name_submitted(_name_field.text)

func _on_name_submitted(new_text: String) -> void:
	var clean: String = new_text.strip_edges()
	var problem: String = ""
	if clean == "":
		problem = tr("import.conflict.name_empty")
	elif _is_name_taken.is_valid() and bool(_is_name_taken.call(clean)):
		problem = tr("import.conflict.name_taken") % clean
	if problem != "":
		_error.text = problem
		_error.visible = true
		return
	_decide(Choice.RENAME, clean)

func _on_name_changed(_new_text: String) -> void:
	_error.visible = false
