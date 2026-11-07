class_name LinkMismatchDialog
extends ModalDialog

signal applied(choices: Dictionary)

const DIALOG_WIDTH: float = 520.0
const LIST_MAX_HEIGHT: float = 300.0
const ROW_ESTIMATE: float = 78.0
const FONT_SIZE: int = 13
const HINT_SIZE: int = 12

var _rows: Array[Dictionary] = []
var _keep_buttons: Array[Button] = []
var _remove_buttons: Array[Button] = []

func _init() -> void:
	super()
	dismiss_on_backdrop = false
	_set_card_width(DIALOG_WIDTH)

func open_rows(rows: Array[Dictionary], titles: Dictionary) -> void:
	_rows = rows
	_keep_buttons.clear()
	_remove_buttons.clear()
	_clear_body()

	_body.add_child(_make_label("links.mismatch.title", 15, TITLE_COLOR))
	_body.add_child(_make_label("links.mismatch.hint", HINT_SIZE, MUTED_COLOR, true))

	var all_row: HBoxContainer = HBoxContainer.new()
	all_row.add_theme_constant_override("separation", 8)
	_body.add_child(all_row)
	all_row.add_child(_make_label("links.mismatch.apply_all", FONT_SIZE, TEXT_COLOR))
	var keep_all: Button = _make_button("links.mismatch.keep_all", false)
	keep_all.pressed.connect(choose_all.bind(true))
	all_row.add_child(keep_all)
	var remove_all: Button = _make_button("links.mismatch.remove_all", false)
	remove_all.pressed.connect(choose_all.bind(false))
	all_row.add_child(remove_all)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0.0, minf(ROW_ESTIMATE * float(rows.size()), LIST_MAX_HEIGHT))
	_body.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	for index: int in rows.size():
		list.add_child(_build_row(rows[index], titles))

	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	footer.alignment = BoxContainer.ALIGNMENT_END
	_body.add_child(footer)
	var close_button: Button = _make_button("links.mismatch.close", false)
	close_button.pressed.connect(cancel)
	footer.add_child(close_button)
	var apply_button: Button = _make_button("links.mismatch.apply", true)
	apply_button.pressed.connect(apply)
	footer.add_child(apply_button)

	open()

func row_count() -> int:
	return _rows.size()

func choose(index: int, keep: bool) -> void:
	if index < 0 or index >= _rows.size():
		return
	_keep_buttons[index].set_pressed_no_signal(keep)
	_remove_buttons[index].set_pressed_no_signal(not keep)

func choose_all(keep: bool) -> void:
	for index: int in _rows.size():
		choose(index, keep)

func choices() -> Dictionary:
	var result: Dictionary = {}
	for index: int in _rows.size():
		if _keep_buttons[index].button_pressed:
			result[index] = true
		elif _remove_buttons[index].button_pressed:
			result[index] = false
	return result

func apply() -> void:
	var picked: Dictionary = choices()
	if picked.is_empty():
		cancel()
		return
	close()
	applied.emit(picked)

func _build_row(row: Dictionary, titles: Dictionary) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var from_title: String = str(titles.get(str(row["from"]), ""))
	var to_title: String = str(titles.get(str(row["to"]), ""))
	var is_stale: bool = str(row["kind"]) == LinkReconciler.ROW_STALE
	if is_stale:
		box.add_child(_make_label(tr("links.mismatch.stale") % [from_title, to_title], FONT_SIZE, TEXT_COLOR, true))
		box.add_child(_make_label("links.mismatch.stale.hint", HINT_SIZE, MUTED_COLOR, true))
	else:
		box.add_child(_make_label(tr("links.mismatch.unlinked") % [from_title, str(row["title"])], FONT_SIZE, TEXT_COLOR, true))
		box.add_child(_make_label("links.mismatch.unlinked.hint", HINT_SIZE, MUTED_COLOR, true))

	var group: ButtonGroup = ButtonGroup.new()
	group.allow_unpress = true
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	var keep_button: Button = _make_button("links.mismatch.keep", false)
	var remove_button: Button = _make_button("links.mismatch.remove", false)
	for button: Button in [keep_button, remove_button]:
		button.toggle_mode = true
		button.button_group = group
		_style_toggle(button)
		buttons.add_child(button)
	_keep_buttons.append(keep_button)
	_remove_buttons.append(remove_button)
	return box
