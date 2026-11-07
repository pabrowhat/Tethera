class_name LicenseDialog
extends ModalDialog

const WIDTH_FRACTION: float = 0.8
const HEIGHT_FRACTION: float = 0.7
const MIN_WIDTH: float = 360.0
const MIN_HEIGHT: float = 240.0
const FONT_SIZE: int = 14

var _title_label: Label = null
var _text_view: RichTextLabel = null

func _init() -> void:
	super()
	_title_label = _make_label("", 15, TITLE_COLOR)
	_body.add_child(_title_label)
	_text_view = RichTextLabel.new()
	_text_view.bbcode_enabled = false
	_text_view.scroll_active = true
	_text_view.selection_enabled = true
	_text_view.focus_mode = Control.FOCUS_CLICK
	AppFonts.apply_note_fonts(_text_view)
	_text_view.add_theme_font_size_override("normal_font_size", FONT_SIZE)
	ThemeColors.bind_override(_text_view, &"default_color", TEXT_COLOR)
	_body.add_child(_text_view)
	var footer: HBoxContainer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	_body.add_child(footer)
	var close_button: Button = _make_button("about.close", true)
	close_button.pressed.connect(close)
	footer.add_child(close_button)

func open_license(title_key: String, notice: Callable) -> void:
	var screen: Vector2 = get_viewport_rect().size
	_set_card_width(maxf(screen.x * WIDTH_FRACTION, MIN_WIDTH))
	_text_view.custom_minimum_size = Vector2(0.0, maxf(screen.y * HEIGHT_FRACTION, MIN_HEIGHT))
	_title_label.text = title_key
	_text_view.text = str(notice.call())
	_text_view.scroll_to_line(0)
	open()
