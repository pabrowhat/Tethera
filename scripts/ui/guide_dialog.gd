class_name GuideDialog
extends ModalDialog

const GUIDE_DIR: String = "res://guide/"
const WIDTH_FRACTION: float = 0.8
const HEIGHT_FRACTION: float = 0.7
const MIN_WIDTH: float = 360.0
const MIN_HEIGHT: float = 240.0
const FONT_SIZE: int = 14
const CODE_OPEN: String = ""
const CODE_CLOSE: String = ""

var _text_view: RichTextLabel = null

func _init() -> void:
	super()
	_body.add_child(_make_label("guide.title", 15, TITLE_COLOR))
	_text_view = RichTextLabel.new()
	_text_view.bbcode_enabled = true
	_text_view.scroll_active = true
	_text_view.selection_enabled = true
	_text_view.focus_mode = Control.FOCUS_CLICK
	AppFonts.apply_note_fonts(_text_view)
	_text_view.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	_text_view.add_theme_color_override("default_color", TEXT_COLOR)
	_body.add_child(_text_view)
	var footer: HBoxContainer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	_body.add_child(footer)
	var close_button: Button = _make_button("about.close", true)
	close_button.pressed.connect(close)
	footer.add_child(close_button)

static func guide_path(locale: String) -> String:
	return GUIDE_DIR + ("guide_ru.md" if locale == "ru" else "guide_en.md")

func open_guide() -> void:
	var screen: Vector2 = get_viewport_rect().size
	_set_card_width(maxf(screen.x * WIDTH_FRACTION, MIN_WIDTH))
	_text_view.custom_minimum_size = Vector2(0.0, maxf(screen.y * HEIGHT_FRACTION, MIN_HEIGHT))
	_load_text()
	open()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _text_view != null and is_open():
		_load_text()

func _load_text() -> void:
	var path: String = guide_path(Localization.applied_locale())
	if not FileAccess.file_exists(path):
		_text_view.text = tr("guide.not_found")
		return
	_text_view.text = markdown_to_bbcode(PlatformKeys.localize(FileAccess.get_file_as_string(path)))
	_text_view.scroll_to_line(0)

static func markdown_to_bbcode(markdown: String) -> String:
	var spans: Array[String] = []
	var lifted: String = ""
	var cursor: int = 0
	var span_re: RegEx = RegEx.create_from_string("`([^`\\n]+)`")
	for found: RegExMatch in span_re.search_all(markdown):
		lifted += markdown.substr(cursor, found.get_start() - cursor)
		lifted += CODE_OPEN + str(spans.size()) + CODE_CLOSE
		spans.append(found.get_string(1))
		cursor = found.get_end()
	lifted += markdown.substr(cursor)

	var bbcode: String = MarkdownBBCode.to_bbcode(lifted, MarkdownBBCode.Profile.PREVIEW)
	for index: int in range(spans.size() - 1, -1, -1):
		var shown: String = spans[index].replace("[", "[lb]")
		bbcode = bbcode.replace(CODE_OPEN + str(index) + CODE_CLOSE, "[code]" + shown + "[/code]")
	return bbcode
