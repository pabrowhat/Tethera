class_name ColorPickerPopup
extends PopupPanel

signal color_previewed(color: Color)
signal color_committed(color: Color)

const POPUP_GAP: float = 6.0
const POPUP_BG: StringName = &"surface.panel"
const POPUP_BORDER: StringName = &"border"

var _picker: ColorPickerPanel = null
var _picker_color: Color = Color.WHITE
var _has_changed: bool = false

func _init() -> void:
	_picker = ColorPickerPanel.new()
	_picker.color_changed.connect(_on_picker_color_changed)

	var popup_style: StyleBoxFlat = StyleBoxFlat.new()
	ThemeColors.bind(popup_style, &"bg_color", POPUP_BG)
	ThemeColors.bind(popup_style, &"border_color", POPUP_BORDER)
	popup_style.set_border_width_all(1)
	popup_style.set_corner_radius_all(10)
	popup_style.set_content_margin_all(12.0)

	add_theme_stylebox_override("panel", popup_style)
	add_child(_picker)
	popup_hide.connect(_on_popup_hidden)
	window_input.connect(_on_window_input)

func open_for(anchor: Rect2, color: Color, bounds: Vector2) -> void:
	_has_changed = false
	_picker_color = color
	_picker.begin(color)

	reset_size()
	var popup_size: Vector2i = get_contents_minimum_size()
	var x: float = clampf(anchor.end.x - float(popup_size.x), 0.0, maxf(bounds.x - float(popup_size.x), 0.0))
	var y: float = minf(anchor.end.y + POPUP_GAP, maxf(bounds.y - float(popup_size.y), 0.0))
	popup(Rect2i(Vector2i(int(x), int(y)), popup_size))

func _on_picker_color_changed(color: Color) -> void:
	_has_changed = true
	_picker_color = color
	color_previewed.emit(color)

func _on_window_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if key.pressed and not key.is_echo() and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER):
		set_input_as_handled()
		hide()

func _on_popup_hidden() -> void:
	if not _has_changed:
		return
	_has_changed = false
	color_committed.emit(_picker_color)
