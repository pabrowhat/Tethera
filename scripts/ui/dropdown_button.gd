class_name DropdownButton
extends Button

signal item_selected(id: int)

const ICON_CHEVRON: Texture2D = preload("res://assets/icons/chevron-down.svg")
const CHEVRON_SIZE: float = 14.0
const RIGHT_PADDING: float = 28.0

var _items: Array[Dictionary] = []
var _selected_id: int = -1
var _popup: PopupList = null

func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	clip_text = true
	custom_minimum_size = Vector2(0.0, 32.0)
	add_theme_font_size_override("font_size", 13)
	add_theme_stylebox_override("normal", _make_style(UiStyle.BG_NORMAL, UiStyle.BORDER))
	add_theme_stylebox_override("hover", _make_style(UiStyle.BG_HOVER, UiStyle.ACCENT_SOFT))
	add_theme_stylebox_override("pressed", _make_style(UiStyle.BG_HOVER, UiStyle.ACCENT))
	add_theme_stylebox_override("hover_pressed", _make_style(UiStyle.BG_HOVER, UiStyle.ACCENT))

	var chevron: TextureRect = TextureRect.new()
	chevron.texture = ICON_CHEVRON
	chevron.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chevron.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chevron.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chevron.modulate = Color(0.7, 0.72, 0.8)
	chevron.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	chevron.offset_left = -(CHEVRON_SIZE + 8.0)
	chevron.offset_right = -8.0
	chevron.offset_top = -CHEVRON_SIZE * 0.5
	chevron.offset_bottom = CHEVRON_SIZE * 0.5
	add_child(chevron)

	_popup = PopupList.new()
	_popup.item_chosen.connect(_on_item_chosen)
	add_child(_popup)

	pressed.connect(_open_popup)

func _make_style(background: Color, border: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = UiStyle.box(background, border, 6, 10.0, 4.0)
	style.content_margin_right = RIGHT_PADDING
	return style

func clear() -> void:
	_items.clear()
	_selected_id = -1
	text = ""

func add_item(item_text: String, id: int, metadata: Variant = null) -> void:
	_items.append({"id": id, "text": item_text, "metadata": metadata})

func get_item_count() -> int:
	return _items.size()

func select_id(id: int) -> void:
	_selected_id = -1
	text = ""
	for item: Dictionary in _items:
		if int(item["id"]) == id:
			_selected_id = id
			text = str(item["text"])
			return

func get_selected_id() -> int:
	return _selected_id

func get_selected_metadata() -> Variant:
	for item: Dictionary in _items:
		if int(item["id"]) == _selected_id:
			return item["metadata"]
	return null

func is_popup_open() -> bool:
	return _popup.is_open()

func _open_popup() -> void:
	_popup.clear()
	for item: Dictionary in _items:
		_popup.add_item(str(item["text"]), int(item["id"]))
	_popup.open_below(get_global_rect(), size.x, _selected_id)

func _on_item_chosen(id: int) -> void:
	select_id(id)
	item_selected.emit(id)
