class_name BatchInspector
extends VBoxContainer

signal chip_focus_requested(card_id: String)
signal chip_remove_requested(card_id: String)
signal color_chosen(color: Color)
signal delete_requested
signal eyedropper_requested

const ICON_X: Texture2D = preload("res://assets/icons/x.svg")
const SURFACE_COLOR: StringName = &"control.normal"
const BORDER_COLOR: StringName = &"border"

var _header: Label = null
var _count: int = 0
var _chip_list: VBoxContainer = null
var _palette_row: HBoxContainer = null
var _delete_button: Button = null
var _color_bar: ColorBar = null

func _init() -> void:
	add_theme_constant_override("separation", 12)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_header = Label.new()
	_header.add_theme_font_size_override("font_size", 15)
	ThemeColors.bind_override(_header, &"font_color", &"text.strong")
	add_child(_header)

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_chip_list = VBoxContainer.new()
	_chip_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chip_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_chip_list)

	var palette_caption: Label = Label.new()
	palette_caption.text = "batch.palette_caption"
	palette_caption.add_theme_font_size_override("font_size", 12)
	ThemeColors.bind_override(palette_caption, &"font_color", &"text.caption")
	add_child(palette_caption)

	_palette_row = HBoxContainer.new()
	_palette_row.add_theme_constant_override("separation", 8)
	add_child(_palette_row)

	_delete_button = Button.new()
	_delete_button.focus_mode = Control.FOCUS_NONE
	_delete_button.add_theme_font_size_override("font_size", 13)
	ThemeColors.bind_override(_delete_button, &"font_color", &"danger.text")
	ThemeColors.bind_override(_delete_button, &"font_pressed_color", &"danger.text_pressed")
	ThemeColors.bind_override(_delete_button, &"font_hover_color", &"danger.text_hover")
	_delete_button.add_theme_stylebox_override("normal", _make_delete_style(UiStyle.CLEAR))
	_delete_button.add_theme_stylebox_override("pressed", _make_delete_style(UiStyle.CLEAR))
	_delete_button.add_theme_stylebox_override("hover", _make_delete_style(UiStyle.BG_NORMAL, 0.6))
	_delete_button.pressed.connect(func() -> void: delete_requested.emit())
	add_child(_delete_button)

func setup(swatch_shader: Shader) -> void:
	_color_bar = ColorBar.new()
	_color_bar.setup(swatch_shader)
	_color_bar.color_picked.connect(func(color: Color) -> void: color_chosen.emit(color))
	_color_bar.color_committed.connect(func(color: Color) -> void: color_chosen.emit(color))
	_color_bar.eyedropper_requested.connect(eyedropper_requested.emit)
	_palette_row.add_child(_color_bar)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		_apply_count_texts()

func _apply_count_texts() -> void:
	if _header != null and _delete_button != null:
		_header.text = tr("batch.header") % _count
		_delete_button.text = tr("batch.delete") % _count

func show_cards(cards: Array[GraphCard]) -> void:
	if is_instance_valid(_color_bar):
		_color_bar.clear_active()

	_count = cards.size()
	_apply_count_texts()

	for child: Node in _chip_list.get_children():
		_chip_list.remove_child(child)
		child.queue_free()

	for card: GraphCard in cards:
		if is_instance_valid(card):
			_chip_list.add_child(_make_chip(card))

func _make_chip(card: GraphCard) -> HBoxContainer:
	var card_id: String = card.card_id
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var title_button: Button = Button.new()
	title_button.text = card.title_label.text
	title_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_button.clip_text = true
	title_button.focus_mode = Control.FOCUS_NONE
	title_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_button.add_theme_font_size_override("font_size", 13)
	title_button.add_theme_stylebox_override("normal", _make_chip_style(card.card_color, SURFACE_COLOR))
	title_button.add_theme_stylebox_override("hover", _make_chip_style(card.card_color, BORDER_COLOR))
	title_button.add_theme_stylebox_override("pressed", _make_chip_style(card.card_color, BORDER_COLOR))
	title_button.pressed.connect(func() -> void: chip_focus_requested.emit(card_id))
	row.add_child(title_button)

	var remove_button: Button = Button.new()
	remove_button.icon = ICON_X
	remove_button.expand_icon = true
	remove_button.add_theme_constant_override("icon_max_width", 14)
	remove_button.custom_minimum_size = Vector2(32, 32)
	remove_button.focus_mode = Control.FOCUS_NONE
	remove_button.tooltip_text = "batch.remove_chip"
	remove_button.add_theme_stylebox_override("normal", _make_chip_style(ThemeColors.color(BORDER_COLOR), SURFACE_COLOR, 0))
	remove_button.add_theme_stylebox_override("hover", _make_chip_style(ThemeColors.color(BORDER_COLOR), BORDER_COLOR, 0))
	remove_button.pressed.connect(func() -> void: chip_remove_requested.emit(card_id))
	row.add_child(remove_button)

	return row

func _make_chip_style(accent: Color, bg: StringName, accent_width: int = 4) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	ThemeColors.bind(style, &"bg_color", bg)
	style.border_color = accent.lightened(0.25)
	style.border_width_left = accent_width
	style.set_corner_radius_all(6)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	return style

func _make_delete_style(bg: StringName, alpha: float = -1.0) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	ThemeColors.bind(style, &"bg_color", bg, alpha)
	style.set_corner_radius_all(6)
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style
