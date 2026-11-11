class_name SwatchDropdownButton
extends Button

signal color_picked(color: Color)

const POPUP_GAP: float = 6.0
const STRIPE_HEIGHT: float = 3.0
const POPUP_BG: StringName = &"surface.panel"
const POPUP_BORDER: StringName = &"border"

var _popup: PopupPanel = null
var _grid: GridContainer = null
var _stripe: ColorRect = null
var _swatch_shader: Shader = null

func _init() -> void:
	focus_mode = Control.FOCUS_NONE

	_stripe = ColorRect.new()
	_stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stripe)
	_stripe.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_stripe.offset_left = 7.0
	_stripe.offset_right = -7.0
	_stripe.offset_top = -(STRIPE_HEIGHT + 4.0)
	_stripe.offset_bottom = -4.0

	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	ThemeColors.bind(panel_style, &"bg_color", POPUP_BG)
	ThemeColors.bind(panel_style, &"border_color", POPUP_BORDER)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(8)
	panel_style.set_content_margin_all(10.0)

	_popup = PopupPanel.new()
	_popup.add_theme_stylebox_override("panel", panel_style)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_popup.add_child(_grid)
	add_child(_popup)

	pressed.connect(_open_popup)

func use_theme_stripe(key: StringName) -> void:
	ThemeColors.bind(_stripe, &"color", key)

func setup(glyph: String, icon_texture: Texture2D, swatch_shader: Shader, columns: int, stripe_color: Color) -> void:
	text = glyph
	if icon_texture != null:
		icon = icon_texture
		expand_icon = true
		add_theme_constant_override("icon_max_width", 16)
	_swatch_shader = swatch_shader
	_grid.columns = columns
	_stripe.color = stripe_color
	_rebuild_swatches()

func is_popup_open() -> bool:
	return is_instance_valid(_popup) and _popup.visible

func _rebuild_swatches() -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()

	var colors: Array[Color] = []
	var store: PaletteStore = PaletteStore.instance()
	colors.append_array(store.presets())
	for i: int in PaletteStore.SLOT_COUNT:
		var slot: Variant = store.get_slot(i)
		if slot != null and not colors.has(slot as Color):
			colors.append(slot as Color)
	SwatchPalette.build(_grid, colors, _swatch_shader, _on_swatch_pressed)

func _on_swatch_pressed(color: Color) -> void:
	ThemeColors.unbind(_stripe, &"color")
	_stripe.color = color
	_popup.hide()
	color_picked.emit(color)

func _open_popup() -> void:
	_rebuild_swatches()
	_popup.reset_size()
	var popup_size: Vector2i = _popup.get_contents_minimum_size()
	var bounds: Vector2 = get_viewport_rect().size
	var anchor: Rect2 = get_global_rect()
	var x: float = clampf(anchor.position.x, 0.0, maxf(bounds.x - float(popup_size.x), 0.0))
	var y: float = minf(anchor.end.y + POPUP_GAP, maxf(bounds.y - float(popup_size.y), 0.0))
	_popup.popup(Rect2i(Vector2i(int(x), int(y)), popup_size))
