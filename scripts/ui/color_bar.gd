class_name ColorBar
extends VBoxContainer

signal color_picked(color: Color)
signal color_previewed(color: Color)
signal color_committed(color: Color)
signal eyedropper_requested

const SWATCH_SIZE: float = 24.0
const ROW_GAP: int = 8
const PUNCH_SCALE: float = 1.1
const PUNCH_UP_DURATION: float = 0.06
const PUNCH_DOWN_DURATION: float = 0.1
const CLEAR_DURATION: float = 0.09
const EMPTY_RING_COLOR: StringName = &"swatch.empty_ring"
const EMPTY_RING_WIDTH: float = 1.5
const MENU_WIDTH: float = 120.0
const MENU_CHANGE: int = 0
const MENU_DELETE: int = 1
const MENU_RESET: int = 2
const ICON_COLOR: StringName = &"text.caption"
const ICON_PIPETTE: Texture2D = preload("res://assets/icons/pipette.svg")
const PIPETTE_ICON_SIZE: int = 14

var _swatch_shader: Shader = null
var _preset_row: HBoxContainer = null
var _slot_row: HBoxContainer = null
var _preset_swatches: Array[ColorRect] = []
var _editable_presets: bool = false
var _menu: PopupList = null
var _edit_popup: ColorPickerPopup = null
var _edit_preset: bool = false
var _edit_index: int = -1
var _custom_button: CustomColorButton = null
var _eyedropper_button: Button = null
var _slot_buttons: Array[Button] = []
var _slot_materials: Array[ShaderMaterial] = []
var _slot_rings: Array[RoundedShape] = []
var _punch_tweens: Dictionary = {}
var _active_color: Color = Color.TRANSPARENT
var _has_active: bool = false

func _init() -> void:
	add_theme_constant_override("separation", ROW_GAP)

func setup(swatch_shader: Shader, fixed_presets: Array[Color] = []) -> void:
	_swatch_shader = swatch_shader
	_editable_presets = fixed_presets.is_empty()
	var preset_colors: Array[Color] = PaletteStore.instance().presets() if _editable_presets else fixed_presets

	_preset_row = HBoxContainer.new()
	_preset_row.add_theme_constant_override("separation", ROW_GAP)
	add_child(_preset_row)
	_preset_swatches = SwatchPalette.build(_preset_row, preset_colors, swatch_shader, func(color: Color) -> void: color_picked.emit(color))
	if _editable_presets:
		for i: int in _preset_swatches.size():
			(_preset_swatches[i].get_parent() as Button).gui_input.connect(_on_preset_gui_input.bind(i))

	_custom_button = CustomColorButton.new()
	_custom_button.setup(swatch_shader, preset_colors)
	_custom_button.color_previewed.connect(color_previewed.emit)
	_custom_button.color_committed.connect(color_committed.emit)
	_preset_row.add_child(_custom_button)

	_eyedropper_button = _make_eyedropper_button()
	_preset_row.add_child(_eyedropper_button)

	_slot_row = HBoxContainer.new()
	_slot_row.add_theme_constant_override("separation", ROW_GAP)
	add_child(_slot_row)
	for i: int in PaletteStore.SLOT_COUNT:
		_slot_row.add_child(_make_slot_button(i))

	_menu = PopupList.new()
	_menu.item_chosen.connect(_on_menu_chosen)
	add_child(_menu)
	_edit_popup = ColorPickerPopup.new()
	_edit_popup.color_committed.connect(_on_edit_committed)
	add_child(_edit_popup)

	PaletteStore.instance().changed.connect(_on_store_changed)
	_refresh_slots()
	ThemeColors.watch(_apply_theme_colors)

func set_active_color(color: Color) -> void:
	_active_color = color
	_has_active = true
	SwatchPalette.set_active(_preset_swatches, color)
	_custom_button.sync(color)
	_update_slot_highlight()

func set_eyedropper_visible(value: bool) -> void:
	if is_instance_valid(_eyedropper_button):
		_eyedropper_button.visible = value

func clear_active() -> void:
	_has_active = false
	SwatchPalette.set_active(_preset_swatches, Color.TRANSPARENT)
	_custom_button.clear_active()
	_update_slot_highlight()


func _make_eyedropper_button() -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(SWATCH_SIZE, SWATCH_SIZE)
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "eyedropper.tooltip"
	UiStyle.apply_round(button)
	button.pressed.connect(eyedropper_requested.emit)

	button.icon = ICON_PIPETTE
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", PIPETTE_ICON_SIZE)
	for color_name: String in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		ThemeColors.bind_override(button, StringName(color_name), ICON_COLOR)
	return button

func _make_slot_button(index: int) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(SWATCH_SIZE, SWATCH_SIZE)
	button.pivot_offset = Vector2(SWATCH_SIZE, SWATCH_SIZE) * 0.5
	button.focus_mode = Control.FOCUS_NONE
	UiStyle.make_borderless(button)

	var swatch: ColorRect = ColorRect.new()
	swatch.set_anchors_preset(Control.PRESET_FULL_RECT)
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot_material: ShaderMaterial = ShaderMaterial.new()
	slot_material.shader = _swatch_shader
	slot_material.set_shader_parameter("circle_color", Color.WHITE)
	slot_material.set_shader_parameter("is_selected", false)
	swatch.material = slot_material
	button.add_child(swatch)

	var ring: RoundedShape = RoundedShape.new()
	ring.set_style(Color.TRANSPARENT, ThemeColors.color(EMPTY_RING_COLOR), EMPTY_RING_WIDTH)
	ring.place_centered(Vector2(SWATCH_SIZE, SWATCH_SIZE) * 0.5, (SWATCH_SIZE * 0.5 - 3.0 + EMPTY_RING_WIDTH * 0.5) * 2.0)
	button.add_child(ring)
	_slot_rings.append(ring)
	button.pressed.connect(_on_slot_pressed.bind(index))
	button.gui_input.connect(_on_slot_gui_input.bind(index))

	_slot_buttons.append(button)
	_slot_materials.append(slot_material)
	return button


func _apply_theme_colors() -> void:
	for ring: RoundedShape in _slot_rings:
		ring.set_style(Color.TRANSPARENT, ThemeColors.color(EMPTY_RING_COLOR), EMPTY_RING_WIDTH)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and not _slot_buttons.is_empty():
		_refresh_slots()

func _on_store_changed() -> void:
	if _editable_presets:
		var colors: Array[Color] = PaletteStore.instance().presets()
		for i: int in _preset_swatches.size():
			(_preset_swatches[i].material as ShaderMaterial).set_shader_parameter("circle_color", colors[i])
		_custom_button.set_presets(colors)
		if _has_active:
			SwatchPalette.set_active(_preset_swatches, _active_color)
			_custom_button.sync(_active_color)
	_refresh_slots()

func _refresh_slots() -> void:
	var store: PaletteStore = PaletteStore.instance()
	for i: int in _slot_buttons.size():
		var color: Variant = store.get_slot(i)
		var button: Button = _slot_buttons[i]
		var swatch: Node = button.get_child(0)
		(swatch as CanvasItem).visible = color != null
		if color != null:
			_slot_materials[i].set_shader_parameter("circle_color", color as Color)
			button.tooltip_text = tr("palette.slot.filled") % (color as Color).to_html(false).to_upper()
		else:
			button.tooltip_text = "palette.slot.empty"
		_slot_rings[i].visible = color == null
	_update_slot_highlight()

func _update_slot_highlight() -> void:
	var store: PaletteStore = PaletteStore.instance()
	for i: int in _slot_materials.size():
		var color: Variant = store.get_slot(i)
		var selected: bool = _has_active and color != null and (color as Color).is_equal_approx(_active_color)
		_slot_materials[i].set_shader_parameter("is_selected", selected)

func _on_slot_pressed(index: int) -> void:
	var color: Variant = PaletteStore.instance().get_slot(index)
	if color == null:
		return
	_punch(_slot_buttons[index])
	color_picked.emit(color as Color)

func _on_slot_gui_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var button_event: InputEventMouseButton = event as InputEventMouseButton
	if button_event.button_index != MOUSE_BUTTON_RIGHT or not button_event.pressed:
		return
	_slot_buttons[index].accept_event()
	if PaletteStore.instance().get_slot(index) == null:
		return
	_open_menu(false, index, _slot_buttons[index])

func _on_preset_gui_input(event: InputEvent, index: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var button_event: InputEventMouseButton = event as InputEventMouseButton
	if button_event.button_index != MOUSE_BUTTON_RIGHT or not button_event.pressed:
		return
	_preset_swatches[index].get_parent().accept_event()
	_open_menu(true, index, _preset_swatches[index].get_parent() as Button)

func _open_menu(is_preset: bool, index: int, anchor: Button) -> void:
	_edit_preset = is_preset
	_edit_index = index
	_menu.clear()
	_menu.add_item(tr("palette.menu.change"), MENU_CHANGE)
	if is_preset:
		_menu.add_item(tr("palette.menu.reset"), MENU_RESET)
		_menu.set_item_disabled(MENU_RESET, not PaletteStore.instance().is_preset_overridden(index))
	else:
		_menu.add_item(tr("palette.menu.delete"), MENU_DELETE)
	_menu.open_below(anchor.get_global_rect(), MENU_WIDTH)

func _on_menu_chosen(id: int) -> void:
	var store: PaletteStore = PaletteStore.instance()
	match id:
		MENU_CHANGE:
			var anchor: Button = (_preset_swatches[_edit_index].get_parent() if _edit_preset else _slot_buttons[_edit_index]) as Button
			var current: Color = store.presets()[_edit_index] if _edit_preset else store.get_slot(_edit_index) as Color
			_edit_popup.open_for(anchor.get_global_rect(), current, get_viewport_rect().size)
		MENU_DELETE:
			_clear_slot_animated(_edit_index)
		MENU_RESET:
			store.reset_preset(_edit_index)

func _on_edit_committed(color: Color) -> void:
	if _edit_preset:
		PaletteStore.instance().set_preset(_edit_index, color)
	else:
		PaletteStore.instance().set_slot(_edit_index, color)

func _clear_slot_animated(index: int) -> void:
	var button: Button = _slot_buttons[index]
	_kill_punch(button)
	var tween: Tween = button.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(button, "scale", Vector2(0.4, 0.4), CLEAR_DURATION)
	tween.tween_property(button, "modulate:a", 0.0, CLEAR_DURATION)
	tween.chain().tween_callback(func() -> void:
		button.scale = Vector2.ONE
		button.modulate.a = 1.0
		PaletteStore.instance().clear_slot(index)
	)
	_punch_tweens[button] = tween

func _punch(button: Button) -> void:
	_kill_punch(button)
	var tween: Tween = button.create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(button, "scale", Vector2(PUNCH_SCALE, PUNCH_SCALE), PUNCH_UP_DURATION).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2.ONE, PUNCH_DOWN_DURATION).set_ease(Tween.EASE_IN_OUT)
	_punch_tweens[button] = tween

func _kill_punch(button: Button) -> void:
	var previous: Variant = _punch_tweens.get(button, null)
	if previous is Tween and (previous as Tween).is_valid():
		(previous as Tween).kill()
	button.scale = Vector2.ONE
	button.modulate.a = 1.0
