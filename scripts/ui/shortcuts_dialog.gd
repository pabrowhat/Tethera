class_name ShortcutsDialog
extends ModalDialog

const DIALOG_WIDTH: float = 520.0
const LIST_HEIGHT: float = 380.0

var _list: VBoxContainer = null

func _init() -> void:
	super()
	_set_card_width(DIALOG_WIDTH)
	_body.add_child(_make_label("shortcuts.title", 15, TITLE_COLOR))

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0.0, LIST_HEIGHT)
	_body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 4)
	scroll.add_child(_list)

	var footer: HBoxContainer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	_body.add_child(footer)
	var close_button: Button = _make_button("about.close", true)
	close_button.pressed.connect(close)
	footer.add_child(close_button)

func open_shortcuts() -> void:
	if is_open():
		return
	for row: Node in _list.get_children():
		_list.remove_child(row)
		row.queue_free()
	for entry: Dictionary in ShortcutList.ROWS:
		var line: HBoxContainer = HBoxContainer.new()
		line.add_theme_constant_override("separation", 18)
		var text: Label = Label.new()
		text.text = tr(str(entry["text"]))
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_theme_font_size_override("font_size", 13)
		text.add_theme_color_override("font_color", TEXT_COLOR)
		line.add_child(text)
		var keys: Label = Label.new()
		keys.text = PlatformKeys.hint(str(entry["keys"]))
		keys.add_theme_font_size_override("font_size", 12)
		keys.add_theme_color_override("font_color", MUTED_COLOR)
		line.add_child(keys)
		_list.add_child(line)
	open()
