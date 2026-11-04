class_name SidebarEditor
extends PanelContainer

signal article_updated(card_id: String, new_title: String, new_content: String)
signal card_color_changed(card_id: String, new_color: Color)
signal card_image_changed(card_id: String, new_image_path: String)
signal image_insert_failed(reason: String)
signal card_type_chosen(card_id: String, type_id: String)
signal card_background_previewed(card_id: String, color: Color)
signal card_background_color_changed(card_id: String, color: Color)
signal card_background_color2_previewed(card_id: String, color: Color)
signal card_background_color2_changed(card_id: String, color: Color)
signal card_background_gradient_cleared(card_id: String)
signal card_background_image_chosen(card_id: String, source_path: String)
signal card_background_cleared(card_id: String)
signal card_fields_changed(card_id: String)
signal card_type_color_follow_requested(card_id: String)
signal card_delete_requested(card_id: String)
signal wiki_link_requested(source_id: String, target_id: String)
signal wiki_link_navigate_requested(target_id: String)
signal image_view_requested(path: String)
signal batch_color_chosen(color: Color)
signal batch_delete_requested
signal batch_chip_focus_requested(card_id: String)
signal batch_chip_remove_requested(card_id: String)
signal eyedropper_requested
signal background_eyedropper_requested(second: bool)
signal zen_changed(active: bool)
signal closed

@export var panel_width: float = 380.0
@export var animation_duration: float = 0.25
@export var auto_save_delay: float = 0.5
@export var swatch_shader: Shader = preload("res://shaders/color_swatch.gdshader")

@onready var single_view: VBoxContainer = $MarginContainer/VBoxContainer
@onready var title_input: LineEdit = $MarginContainer/VBoxContainer/Header/TitleInput
@onready var header_row: HBoxContainer = $MarginContainer/VBoxContainer/Header
@onready var close_button: Button = $MarginContainer/VBoxContainer/Header/CloseButton
@onready var zen_button: Button = $MarginContainer/VBoxContainer/Header/ZenButton
@onready var mode_row: HBoxContainer = $MarginContainer/VBoxContainer/ModeRow
@onready var mode_toggle: ModeToggle = $MarginContainer/VBoxContainer/ModeRow/ModeToggle
@onready var toolbar_row: HFlowContainer = $MarginContainer/VBoxContainer/Toolbar
@onready var footer_row: HBoxContainer = $MarginContainer/VBoxContainer/Footer
@onready var margin_box: MarginContainer = $MarginContainer
@onready var image_button: Button = $MarginContainer/VBoxContainer/Toolbar/ImageButton
@onready var color_container: HBoxContainer = $MarginContainer/VBoxContainer/Toolbar/ColorPalette
@onready var format_bar: FormatToolbar = $MarginContainer/VBoxContainer/FormatBar
@onready var content_edit: TextEdit = $MarginContainer/VBoxContainer/ContentStack/ContentEdit
@onready var preview_label: RichTextLabel = $MarginContainer/VBoxContainer/ContentStack/PreviewLabel
@onready var delete_button: Button = $MarginContainer/VBoxContainer/Footer/DeleteButton

var storage: VaultStorage = null
var title_label: Label = null
var current_card: GraphCard = null
var is_open: bool = false
var _user_chose_edit: bool = false
var is_preview: bool = false
var _slide_tween: Tween = null
var _mode_tween: Tween = null
var _color_bar: ColorBar = null
var _save_timer: Timer = null
var _link_popup: LinkAutocompletePopup = null
var _link_cards: Dictionary = {}
var _last_link_query: String = ""
var _batch_inspector: BatchInspector = null
var type_manager: TypeManagerPanel = null
var type_section: NoteTypeSection = null
var background_section: NoteBackgroundSection = null
var _type_registry: EntityTypeRegistry = null
var _fields_dirty: bool = false
var _splitter: PanelSplitter = null
var is_zen: bool = false
var _zen_tween: Tween = null
var _zen_animating: bool = false
var _zen_start_scale: float = 0.3
var _zen_origin_center: Vector2 = Vector2.ZERO
var _ribbon_alpha: float = 1.0
var _ribbon_interactive: bool = true
var _dock_style: StyleBox = null
var _preview_image_width: int = 0
var _image_dialog_open: bool = false

const ICON_ZEN_ENTER: Texture2D = preload("res://assets/icons/maximize-2.svg")
const ICON_ZEN_EXIT: Texture2D = preload("res://assets/icons/minimize-2.svg")
const ICON_X: Texture2D = preload("res://assets/icons/x.svg")
const LINK_OPEN: String = "[["
const LINK_CLOSE: String = "]]"

const MIN_WIDTH: float = 320.0
const MAX_WIDTH_RATIO: float = 0.65
const PREVIEW_SCROLLBAR_ROOM: int = 16
const INSERT_IMAGE_WIDTH: int = 300
const MODE_FADE_DURATION: float = 0.1
const SETTINGS_SECTION: String = "inspector"
const SETTING_WIDTH: String = "width"
const EMPTY_PREVIEW_COLOR: String = "6b7090"
const WRAP_PAIR_CHARS: Array[String] = ["*", "_", "\"", "~", "`"]

const ZEN_WIDTH_RATIO: float = 0.6
const ZEN_HEIGHT_RATIO: float = 0.86
const ZEN_MIN_WIDTH: float = 480.0
const ZEN_MAX_WIDTH: float = 1100.0
const ZEN_DURATION: float = 0.25
const ZEN_MARGIN: int = 36
const DOCK_MARGIN: int = 16
const ZEN_TITLE_FONT: int = 22
const DOCK_TITLE_FONT: int = 15
const ZEN_EDIT_FONT: int = 17
const DOCK_EDIT_FONT: int = 14
const ZEN_PREVIEW_FONT: int = 18
const DOCK_PREVIEW_FONT: int = 16
const RIBBON_REVEAL_SLACK: float = 28.0
const RIBBON_FADE_SPEED: float = 7.0
const PREVIEW_FONT_KEYS: Array[String] = ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]

const COLOR_PALETTE: Array[Color] = [
	Color("313549"),
	Color("3498db"),
	Color("2ecc71"),
	Color("f1c40f"),
	Color("9b59b6"),
	Color("e74c3c")
]

func _ready() -> void:
	_wrap_single_view_in_scroll()
	panel_width = _clamp_width(float(AppSettings.get_value(SETTINGS_SECTION, SETTING_WIDTH, panel_width)))
	custom_minimum_size = Vector2(panel_width, 0.0)
	size.x = panel_width
	get_viewport().size_changed.connect(_on_viewport_resized)

	close_button.text = ""
	close_button.icon = ICON_X
	close_button.expand_icon = true
	close_button.add_theme_constant_override("icon_max_width", 16)
	close_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	close_button.pressed.connect(close_sidebar)
	zen_button.pressed.connect(toggle_zen)
	set_process(false)
	delete_button.pressed.connect(_on_delete_pressed)
	image_button.pressed.connect(_on_image_button_pressed)
	title_input.text_changed.connect(_on_title_changed)
	content_edit.text_changed.connect(_on_content_changed)

	title_label = Label.new()
	title_label.visible = false
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.clip_text = true
	title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_label.add_theme_color_override("font_color", Color.WHITE)
	title_label.add_theme_font_size_override("font_size", DOCK_TITLE_FONT)
	header_row.add_child(title_label)
	header_row.move_child(title_label, title_input.get_index() + 1)

	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = auto_save_delay
	_save_timer.timeout.connect(_flush_save)
	add_child(_save_timer)

	_link_popup = LinkAutocompletePopup.new()
	_link_popup.item_chosen.connect(_on_link_item_chosen)
	add_child(_link_popup)

	content_edit.text_changed.connect(_on_content_text_changed_for_links)
	content_edit.caret_changed.connect(_on_content_caret_changed_for_links)
	content_edit.gui_input.connect(_on_content_gui_input)
	content_edit.focus_exited.connect(_close_link_popup)
	content_edit.get_v_scroll_bar().value_changed.connect(_on_content_scrolled)
	content_edit.deselect_on_focus_loss_enabled = false

	_setup_editor_fonts()
	_setup_format_bar()
	_setup_mode_toggle()
	_setup_splitter()

	_batch_inspector = BatchInspector.new()
	_batch_inspector.visible = false
	$MarginContainer.add_child(_batch_inspector)
	_batch_inspector.setup(COLOR_PALETTE, swatch_shader)
	_batch_inspector.color_chosen.connect(batch_color_chosen.emit)
	_batch_inspector.delete_requested.connect(batch_delete_requested.emit)
	_batch_inspector.chip_focus_requested.connect(batch_chip_focus_requested.emit)
	_batch_inspector.chip_remove_requested.connect(batch_chip_remove_requested.emit)
	_batch_inspector.eyedropper_requested.connect(eyedropper_requested.emit)

	type_manager = TypeManagerPanel.new()
	type_manager.visible = false
	$MarginContainer.add_child(type_manager)
	type_manager.close_requested.connect(close_sidebar)

	type_section = NoteTypeSection.new()
	single_view.add_child(type_section)
	single_view.move_child(type_section, toolbar_row.get_index() + 1)
	type_section.type_chosen.connect(_on_type_section_type_chosen)
	type_section.field_edited.connect(_on_type_section_field_edited)
	type_section.follow_type_color_requested.connect(_on_type_section_follow_requested)

	background_section = NoteBackgroundSection.new()
	background_section.setup(swatch_shader, true)
	background_section.eyedropper_requested.connect(background_eyedropper_requested.emit)
	single_view.add_child(background_section)
	single_view.move_child(background_section, type_section.get_index() + 1)
	background_section.color_previewed.connect(_on_background_previewed)
	background_section.color_chosen.connect(_on_background_color_chosen)
	background_section.color2_previewed.connect(func(color: Color) -> void:
		if is_instance_valid(current_card):
			card_background_color2_previewed.emit(current_card.card_id, color))
	background_section.color2_chosen.connect(func(color: Color) -> void:
		if is_instance_valid(current_card):
			card_background_color2_changed.emit(current_card.card_id, color))
	background_section.gradient_cleared.connect(func() -> void:
		if is_instance_valid(current_card):
			card_background_gradient_cleared.emit(current_card.card_id))
	background_section.image_chosen.connect(_on_background_image_chosen)
	(content_edit.get_parent() as Control).custom_minimum_size.y = 160.0
	background_section.cleared.connect(_on_background_cleared)

	_build_color_palette()
	color_container.alignment = BoxContainer.ALIGNMENT_BEGIN
	background_section.attach_border_control(color_container, "background.border_color")
	_apply_mode_visibility()
	visible = false

func _wrap_single_view_in_scroll() -> void:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin_box.add_child(scroll)
	margin_box.move_child(scroll, single_view.get_index())
	single_view.reparent(scroll, false)
	single_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	single_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	single_view.visibility_changed.connect(func() -> void: scroll.visible = single_view.visible)

func setup_link_source(cards_by_id: Dictionary) -> void:
	_link_cards = cards_by_id

func setup_types(registry: EntityTypeRegistry, count_of: Callable) -> void:
	type_manager.setup(registry, count_of, COLOR_PALETTE, swatch_shader)
	type_section.setup(registry)
	_type_registry = registry

func refresh_type_section() -> void:
	if is_open and single_view.visible and is_instance_valid(current_card):
		type_section.show_card(current_card)
		refresh_background_section()

func refresh_background_section() -> void:
	if not is_instance_valid(current_card) or background_section == null:
		return
	var entity_type: EntityType = _type_registry.find(current_card.entity_type_id) if _type_registry != null else null
	var effective: Dictionary = NoteBackground.resolve(current_card.bg_color_hex, current_card.bg_color2_hex, current_card.bg_image_path, entity_type)
	var hint_key: String = "background.from_default"
	if effective["color_from"] == NoteBackground.FROM_NOTE or effective["image_from"] == NoteBackground.FROM_NOTE:
		hint_key = "background.from_note"
	elif effective["color_from"] == NoteBackground.FROM_TYPE or effective["image_from"] == NoteBackground.FROM_TYPE:
		hint_key = "background.from_type"
	background_section.show_state(current_card.bg_color_hex, current_card.bg_color2_hex, current_card.bg_image_path, hint_key)

func is_link_popup_open() -> bool:
	return is_instance_valid(_link_popup) and _link_popup.is_open()

func is_point_over_link_popup(global_pos: Vector2) -> bool:
	return is_link_popup_open() and _link_popup.get_global_rect().has_point(global_pos)

func contains_global_point(global_pos: Vector2) -> bool:
	if get_global_rect().has_point(global_pos):
		return true
	return is_instance_valid(_splitter) and _splitter.visible and _splitter.get_global_rect().has_point(global_pos)

func is_point_over_text_tools(global_pos: Vector2) -> bool:
	return is_open and is_instance_valid(format_bar) and format_bar.get_global_rect().has_point(global_pos)


func _setup_editor_fonts() -> void:
	content_edit.add_theme_font_override("font", AppFonts.mono())
	AppFonts.apply_note_fonts(preview_label)
	preview_label.meta_clicked.connect(_on_preview_meta_clicked)
	preview_label.resized.connect(_on_preview_resized)

func _setup_format_bar() -> void:
	format_bar.setup(swatch_shader, COLOR_PALETTE)
	format_bar.wrap_requested.connect(_on_format_wrap_requested)
	format_bar.value_tag_requested.connect(_on_format_value_tag_requested)
	format_bar.prefix_requested.connect(_on_format_prefix_requested)
	format_bar.image_insert_requested.connect(_on_format_image_requested)

func _setup_mode_toggle() -> void:
	mode_toggle.mode_changed.connect(_on_mode_toggled)
	mode_toggle.set_preview(false, false)
	_set_preview_mode(false, false)

func _setup_splitter() -> void:
	_splitter = PanelSplitter.new()
	_splitter.top_level = true
	add_child(_splitter)
	_splitter.width_dragged.connect(_on_splitter_dragged)
	_splitter.drag_finished.connect(_on_splitter_drag_finished)
	item_rect_changed.connect(_sync_splitter)
	_sync_splitter()

func _build_color_palette() -> void:
	_color_bar = ColorBar.new()
	_color_bar.setup(COLOR_PALETTE, swatch_shader)
	_color_bar.color_picked.connect(_on_color_button_pressed)
	_color_bar.color_previewed.connect(_on_custom_color_previewed)
	_color_bar.color_committed.connect(_on_custom_color_committed)
	_color_bar.eyedropper_requested.connect(eyedropper_requested.emit)
	color_container.add_child(_color_bar)


func _clamp_width(width: float) -> float:
	var max_width: float = maxf(MIN_WIDTH, get_viewport_rect().size.x * MAX_WIDTH_RATIO)
	return clampf(width, MIN_WIDTH, max_width)

func set_panel_width(width: float) -> void:
	panel_width = _clamp_width(width)
	if is_zen or _zen_animating:
		return
	custom_minimum_size.x = panel_width
	size.x = panel_width
	if is_open:
		if _slide_tween != null and _slide_tween.is_valid():
			_slide_tween.kill()
		position.x = get_viewport_rect().size.x - size.x
	_sync_splitter()

func _on_viewport_resized() -> void:
	if is_zen and not _zen_animating:
		_apply_zen_rect(_zen_rect())
		return
	set_panel_width(panel_width)

func _on_splitter_dragged(new_width: float) -> void:
	set_panel_width(new_width)

func _on_splitter_drag_finished() -> void:
	AppSettings.set_value(SETTINGS_SECTION, SETTING_WIDTH, panel_width)

func _sync_splitter() -> void:
	if not is_instance_valid(_splitter):
		return
	_splitter.size = Vector2(PanelSplitter.HANDLE_WIDTH, size.y)
	_splitter.global_position = Vector2(global_position.x - (PanelSplitter.HANDLE_WIDTH - PanelSplitter.LINE_WIDTH), global_position.y)


func open_card(card: GraphCard) -> void:
	if is_instance_valid(current_card) and current_card != card:
		_flush_save()
	var switched: bool = current_card != card
	if switched:
		_fields_dirty = false

	_close_link_popup()
	current_card = card
	_batch_inspector.visible = false
	type_manager.visible = false
	single_view.visible = true
	title_input.text = card.title_label.text
	_sync_title_label()
	content_edit.text = card.content_text
	if switched:
		var open_in_preview: bool = card.content_text.strip_edges() != "" and not _user_chose_edit
		mode_toggle.set_preview(open_in_preview, false)
		_set_preview_mode(open_in_preview, false)
	elif is_preview:
		_render_preview()
	_update_active_color_swatch(card.card_color)
	type_section.show_card(card)
	refresh_background_section()

	if not is_open:
		_animate_visibility(true)

func show_batch(cards: Array[GraphCard]) -> void:
	if is_instance_valid(current_card):
		_flush_save()

	_close_link_popup()
	current_card = null
	single_view.visible = false
	type_manager.visible = false
	_batch_inspector.visible = true
	_batch_inspector.show_cards(cards)

	if not is_open:
		_animate_visibility(true)

func show_type_manager() -> void:
	if is_instance_valid(current_card):
		_flush_save()

	_close_link_popup()
	current_card = null
	single_view.visible = false
	_batch_inspector.visible = false
	type_manager.visible = true
	type_manager.refresh()

	if not is_open:
		_animate_visibility(true)

func is_showing_types() -> bool:
	return is_open and type_manager.visible

func refresh_content(card: GraphCard) -> void:
	if current_card != card or not is_open:
		return
	var line: int = content_edit.get_caret_line()
	var column: int = content_edit.get_caret_column()
	content_edit.text = card.content_text
	content_edit.set_caret_line(mini(line, content_edit.get_line_count() - 1))
	content_edit.set_caret_column(column)
	if is_preview:
		_render_preview()

func update_card_title_from_external(card: GraphCard, new_title: String) -> void:
	if current_card == card and is_open:
		title_input.text = new_title
		_sync_title_label()

func close_sidebar() -> void:
	if not is_open:
		return
	if is_zen or _zen_animating:
		_leave_zen_instantly()
	if is_instance_valid(current_card):
		_flush_save()
	_close_link_popup()
	current_card = null
	_animate_visibility(false)
	closed.emit()

func _update_active_color_swatch(active_color: Color) -> void:
	if is_instance_valid(_color_bar):
		_color_bar.set_active_color(active_color)

func apply_external_color(color: Color) -> void:
	if is_instance_valid(current_card):
		_update_active_color_swatch(color)

func _on_custom_color_previewed(color: Color) -> void:
	if is_instance_valid(current_card):
		current_card.set_category_color(color)
		_update_active_color_swatch(color)

func _on_custom_color_committed(color: Color) -> void:
	if is_instance_valid(current_card):
		card_color_changed.emit(current_card.card_id, color)

func _on_color_button_pressed(color: Color) -> void:
	if is_instance_valid(current_card):
		current_card.set_category_color(color)
		_update_active_color_swatch(color)
		card_color_changed.emit(current_card.card_id, color)

func _on_image_button_pressed() -> void:
	if not is_instance_valid(current_card):
		return
	DisplayServer.file_dialog_show(
		tr("sidebar.cover.dialog"),
		"",
		"",
		false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
		["*.png, *.jpg, *.jpeg, *.webp"],
		func(status: bool, selected_paths: PackedStringArray, _idx: int) -> void:
			if status and selected_paths.size() > 0:
				card_image_changed.emit(current_card.card_id, selected_paths[0])
	)

func _on_background_previewed(color: Color) -> void:
	if is_instance_valid(current_card):
		card_background_previewed.emit(current_card.card_id, color)

func _on_background_color_chosen(color: Color) -> void:
	if is_instance_valid(current_card):
		card_background_color_changed.emit(current_card.card_id, color)

func _on_background_image_chosen(source_path: String) -> void:
	if is_instance_valid(current_card):
		card_background_image_chosen.emit(current_card.card_id, source_path)

func _on_background_cleared() -> void:
	if is_instance_valid(current_card):
		card_background_cleared.emit(current_card.card_id)

func _on_type_section_type_chosen(type_id: String) -> void:
	if is_instance_valid(current_card):
		card_type_chosen.emit(current_card.card_id, type_id)

func _on_type_section_field_edited(field_key: String, value: Variant) -> void:
	if not is_instance_valid(current_card):
		return
	if value == null:
		current_card.field_values.erase(field_key)
	else:
		current_card.field_values[field_key] = value
	_fields_dirty = true
	_request_save()

func _on_type_section_follow_requested() -> void:
	if is_instance_valid(current_card):
		card_type_color_follow_requested.emit(current_card.card_id)

func _on_delete_pressed() -> void:
	if is_instance_valid(current_card):
		card_delete_requested.emit(current_card.card_id)

func _animate_visibility(show_panel: bool) -> void:
	is_open = show_panel

	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()

	_slide_tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	var viewport_w: float = get_viewport_rect().size.x

	if show_panel:
		visible = true
		position.x = viewport_w
		_slide_tween.set_ease(Tween.EASE_OUT)
		_slide_tween.tween_property(self, "position:x", viewport_w - panel_width, animation_duration)
	else:
		_slide_tween.set_ease(Tween.EASE_IN)
		_slide_tween.tween_property(self, "position:x", viewport_w, animation_duration)
		_slide_tween.chain().tween_callback(func() -> void: visible = false)

func _sync_title_label() -> void:
	if title_label == null:
		return
	var shown: String = title_input.text.strip_edges()
	title_label.text = shown if shown != "" else "note.untitled"

func _on_title_changed(new_title: String) -> void:
	if is_instance_valid(current_card):
		var clean_title: String = new_title.strip_edges()
		if clean_title != "":
			current_card.title_label.text = clean_title
			current_card.title_edit.text = clean_title
			_sync_title_label()
			_request_save()

func _on_content_changed() -> void:
	if is_instance_valid(current_card):
		current_card.set_content(content_edit.text)
		_request_save()

func _request_save() -> void:
	if _save_timer:
		_save_timer.start()

func flush_pending_save() -> void:
	_flush_save()

func _flush_save() -> void:
	if _save_timer and not _save_timer.is_stopped():
		_save_timer.stop()

	if is_instance_valid(current_card):
		var title: String = title_input.text.strip_edges()
		if title == "":
			title = current_card.title_label.text
		article_updated.emit(current_card.card_id, title, content_edit.text)
		if _fields_dirty:
			_fields_dirty = false
			card_fields_changed.emit(current_card.card_id)


func can_enter_zen() -> bool:
	return is_open and not is_zen and not _zen_animating and is_instance_valid(current_card) and single_view.visible

func toggle_zen() -> void:
	if is_zen:
		exit_zen()
	else:
		enter_zen()

func enter_zen() -> void:
	if not can_enter_zen():
		return
	_close_link_popup()
	if _slide_tween != null and _slide_tween.is_valid():
		_slide_tween.kill()

	is_zen = true
	_zen_animating = true
	_splitter.visible = false
	_apply_zen_look(true)
	zen_changed.emit(true)

	var target: Rect2 = _zen_rect()
	var origin: Rect2 = current_card.get_screen_rect()
	_zen_origin_center = origin.get_center()
	_zen_start_scale = clampf(origin.size.x / maxf(target.size.x, 1.0), 0.15, 0.7)

	pivot_offset = target.size * 0.5
	size = target.size
	position = _zen_origin_center - target.size * 0.5
	scale = Vector2(_zen_start_scale, _zen_start_scale)
	modulate.a = 0.0

	_kill_zen_tween()
	_zen_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zen_tween.tween_property(self, "position", target.position, ZEN_DURATION)
	_zen_tween.tween_property(self, "scale", Vector2.ONE, ZEN_DURATION)
	_zen_tween.tween_property(self, "modulate:a", 1.0, ZEN_DURATION * 0.4)
	_zen_tween.chain().tween_callback(func() -> void:
		_zen_animating = false
		if is_zen:
			set_process(true)
			if not is_preview:
				content_edit.grab_focus()
	)

func exit_zen() -> void:
	if not is_zen or _zen_animating:
		return
	_flush_save()
	_close_link_popup()

	is_zen = false
	_zen_animating = true
	set_process(false)
	zen_changed.emit(false)

	var folded_position: Vector2 = _zen_origin_center - size * 0.5
	_kill_zen_tween()
	_zen_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_zen_tween.tween_property(self, "position", folded_position, ZEN_DURATION)
	_zen_tween.tween_property(self, "scale", Vector2(_zen_start_scale, _zen_start_scale), ZEN_DURATION)
	_zen_tween.tween_property(self, "modulate:a", 0.0, ZEN_DURATION * 0.5).set_delay(ZEN_DURATION * 0.5)
	_zen_tween.chain().tween_callback(func() -> void:
		_restore_dock()
		_animate_visibility(true)
	)

func _leave_zen_instantly() -> void:
	_kill_zen_tween()
	var was_zen: bool = is_zen
	is_zen = false
	set_process(false)
	if is_instance_valid(current_card):
		_flush_save()
	_restore_dock()
	if was_zen:
		zen_changed.emit(false)

func _restore_dock() -> void:
	_zen_animating = false
	scale = Vector2.ONE
	modulate.a = 1.0
	_apply_zen_look(false)
	_ribbon_alpha = 1.0
	mode_row.modulate.a = 1.0
	format_bar.modulate.a = 1.0
	_ribbon_interactive = false
	_set_ribbon_interactive(true)

	var view_size: Vector2 = get_viewport_rect().size
	custom_minimum_size = Vector2(panel_width, 0.0)
	size = Vector2(panel_width, view_size.y)
	position = Vector2(view_size.x - panel_width, 0.0)
	_splitter.visible = true
	_sync_splitter()

func _zen_rect() -> Rect2:
	var view_size: Vector2 = get_viewport_rect().size
	var width: float = minf(clampf(view_size.x * ZEN_WIDTH_RATIO, ZEN_MIN_WIDTH, ZEN_MAX_WIDTH), view_size.x - 24.0)
	var pad_size: Vector2 = Vector2(width, view_size.y * ZEN_HEIGHT_RATIO)
	return Rect2((view_size - pad_size) * 0.5, pad_size)

func _apply_zen_rect(rect: Rect2) -> void:
	pivot_offset = rect.size * 0.5
	size = rect.size
	position = rect.position

func _apply_zen_look(on: bool) -> void:
	_apply_mode_visibility()
	close_button.visible = not on
	zen_button.icon = ICON_ZEN_EXIT if on else ICON_ZEN_ENTER
	zen_button.tooltip_text = "sidebar.zen.exit" if on else "sidebar.zen.enter"

	if _dock_style == null:
		_dock_style = get_theme_stylebox("panel")
	if on:
		var pad_style: StyleBoxFlat = StyleBoxFlat.new()
		pad_style.bg_color = Color(0.0901961, 0.0980392, 0.137255, 1.0)
		pad_style.border_color = Color(0.247059, 0.266667, 0.364706, 1.0)
		pad_style.set_border_width_all(1)
		pad_style.set_corner_radius_all(14)
		pad_style.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
		pad_style.shadow_size = 28
		add_theme_stylebox_override("panel", pad_style)
	else:
		add_theme_stylebox_override("panel", _dock_style)

	var margin: int = ZEN_MARGIN if on else DOCK_MARGIN
	for key: String in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin_box.add_theme_constant_override(key, margin)

	title_input.add_theme_font_size_override("font_size", ZEN_TITLE_FONT if on else DOCK_TITLE_FONT)
	title_label.add_theme_font_size_override("font_size", ZEN_TITLE_FONT if on else DOCK_TITLE_FONT)
	content_edit.add_theme_font_size_override("font_size", ZEN_EDIT_FONT if on else DOCK_EDIT_FONT)
	for key: String in PREVIEW_FONT_KEYS:
		preview_label.add_theme_font_size_override(key, ZEN_PREVIEW_FONT if on else DOCK_PREVIEW_FONT)

func _apply_mode_visibility() -> void:
	var editing: bool = not is_preview
	toolbar_row.visible = editing and not is_zen
	footer_row.visible = editing and not is_zen
	format_bar.visible = editing
	title_input.visible = editing
	if title_label != null:
		title_label.visible = not editing
	if type_section != null:
		type_section.visible = not is_zen
		type_section.set_read_only(is_preview)
	if background_section != null:
		background_section.visible = editing

func _kill_zen_tween() -> void:
	if _zen_tween != null and _zen_tween.is_valid():
		_zen_tween.kill()

func _process(delta: float) -> void:
	if not is_zen:
		return
	var reveal: bool = _is_pointer_in_ribbon_zone() or format_bar.has_open_popup()
	_ribbon_alpha = move_toward(_ribbon_alpha, 1.0 if reveal else 0.0, delta * RIBBON_FADE_SPEED)
	mode_row.modulate.a = _ribbon_alpha
	format_bar.modulate.a = _ribbon_alpha
	_set_ribbon_interactive(_ribbon_alpha > 0.5)

func _is_pointer_in_ribbon_zone() -> bool:
	var mouse: Vector2 = get_local_mouse_position()
	if mouse.x < 0.0 or mouse.x > size.x:
		return false
	var bottom_row: Control = format_bar if format_bar.visible else mode_row
	var bar_origin: Vector2 = get_global_transform().affine_inverse() * bottom_row.get_global_position()
	var zone_bottom: float = bar_origin.y + bottom_row.size.y + RIBBON_REVEAL_SLACK
	return mouse.y >= -40.0 and mouse.y <= zone_bottom

func _set_ribbon_interactive(interactive: bool) -> void:
	if interactive == _ribbon_interactive:
		return
	_ribbon_interactive = interactive
	var filter: Control.MouseFilter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	mode_toggle.mouse_filter = filter
	mode_row.mouse_filter = Control.MOUSE_FILTER_PASS if interactive else Control.MOUSE_FILTER_IGNORE
	format_bar.mouse_filter = Control.MOUSE_FILTER_PASS if interactive else Control.MOUSE_FILTER_IGNORE
	format_bar.set_enabled(interactive and not is_preview)


func _on_mode_toggled(preview: bool) -> void:
	_user_chose_edit = not preview
	_set_preview_mode(preview, true)

func _set_preview_mode(preview: bool, animate: bool) -> void:
	_close_link_popup()
	var ratio: float = _get_scroll_ratio(preview_label if is_preview else content_edit)
	is_preview = preview

	var leaving: Control = content_edit if preview else preview_label
	var entering: Control = preview_label if preview else content_edit
	if preview:
		_render_preview()

	if _mode_tween != null and _mode_tween.is_valid():
		_mode_tween.kill()
	format_bar.set_enabled(not preview)
	_apply_mode_visibility()

	if not animate or not is_inside_tree():
		leaving.visible = false
		leaving.modulate.a = 1.0
		entering.visible = true
		entering.modulate.a = 1.0
	else:
		entering.visible = true
		entering.modulate.a = 0.0
		_mode_tween = create_tween().set_parallel(true)
		_mode_tween.tween_property(entering, "modulate:a", 1.0, MODE_FADE_DURATION)
		_mode_tween.tween_property(leaving, "modulate:a", 0.0, MODE_FADE_DURATION)
		_mode_tween.chain().tween_callback(func() -> void:
			leaving.visible = false
			leaving.modulate.a = 1.0
		)

	_restore_scroll_ratio(entering, ratio)
	if not preview and animate and visible:
		content_edit.grab_focus()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and preview_label != null and is_preview:
		_render_preview()

func _render_preview() -> void:
	var source: String = content_edit.text
	_preview_image_width = _preview_text_width()
	if source.strip_edges().is_empty():
		preview_label.text = "[color=#%s][i]%s[/i][/color]" % [EMPTY_PREVIEW_COLOR, tr("sidebar.preview.empty")]
	else:
		preview_label.text = MarkdownBBCode.to_bbcode(source, MarkdownBBCode.Profile.PREVIEW, _preview_image_width)

func _preview_text_width() -> int:
	return maxi(int(preview_label.size.x) - PREVIEW_SCROLLBAR_ROOM, 0)

func _on_preview_resized() -> void:
	if is_preview and _preview_text_width() != _preview_image_width and not NoteImages.find_inline(content_edit.text).is_empty():
		_render_preview()

func _get_scroll_ratio(control: Control) -> float:
	var bar: VScrollBar = null
	if control is TextEdit:
		bar = (control as TextEdit).get_v_scroll_bar()
	elif control is RichTextLabel:
		bar = (control as RichTextLabel).get_v_scroll_bar()
	if bar == null:
		return 0.0
	var span: float = bar.max_value - bar.page
	return clampf(bar.value / span, 0.0, 1.0) if span > 0.5 else 0.0

func _restore_scroll_ratio(control: Control, ratio: float) -> void:
	await get_tree().process_frame
	if not is_instance_valid(control):
		return
	var bar: VScrollBar = null
	if control is TextEdit:
		bar = (control as TextEdit).get_v_scroll_bar()
	elif control is RichTextLabel:
		bar = (control as RichTextLabel).get_v_scroll_bar()
	if bar == null:
		return
	var span: float = bar.max_value - bar.page
	if span <= 0.5:
		return
	if control is TextEdit:
		(control as TextEdit).scroll_vertical = ratio * span
	else:
		bar.value = ratio * span

func _on_preview_meta_clicked(meta: Variant) -> void:
	var target: String = str(meta)
	if target.begins_with(MarkdownBBCode.IMAGE_META_PREFIX):
		image_view_requested.emit(target.substr(MarkdownBBCode.IMAGE_META_PREFIX.length()))
	elif target.begins_with(MarkdownBBCode.WIKI_META_PREFIX):
		var card_id: String = _find_card_id_by_title(target.substr(MarkdownBBCode.WIKI_META_PREFIX.length()))
		if card_id != "":
			if is_zen:
				exit_zen()
			wiki_link_navigate_requested.emit(card_id)
	elif target.begins_with("http://") or target.begins_with("https://") or target.begins_with("mailto:"):
		OS.shell_open(target)

func _find_card_id_by_title(title: String) -> String:
	var wanted: String = title.strip_edges().to_lower()
	for id: String in _link_cards:
		var card: GraphCard = _link_cards[id]
		if is_instance_valid(card) and card.title_label.text.strip_edges().to_lower() == wanted:
			return card.card_id
	return ""


func _can_format() -> bool:
	return not is_preview and is_instance_valid(current_card)

func can_insert_image() -> bool:
	return _can_format()

func request_insert_image() -> void:
	_on_format_image_requested()

func _on_format_wrap_requested(open: String, close: String) -> void:
	if not _can_format():
		return
	content_edit.grab_focus()
	TextFormatOps.wrap_selection(content_edit, open, close)

func _on_format_value_tag_requested(tag: String, value: String) -> void:
	if not _can_format():
		return
	content_edit.grab_focus()
	TextFormatOps.apply_value_tag(content_edit, tag, value)

func _on_format_prefix_requested(prefix: String, heading: bool) -> void:
	if not _can_format():
		return
	content_edit.grab_focus()
	TextFormatOps.toggle_line_prefix(content_edit, prefix, heading)

func _on_format_image_requested() -> void:
	if not _can_format() or _image_dialog_open:
		return
	var card_id: String = current_card.card_id
	_image_dialog_open = true
	DisplayServer.file_dialog_show(
		tr("image.insert.dialog"),
		"",
		"",
		false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
		["*.png, *.jpg, *.jpeg, *.webp"],
		func(status: bool, selected_paths: PackedStringArray, _idx: int) -> void:
			_image_dialog_open = false
			if status and selected_paths.size() > 0:
				_insert_image(card_id, selected_paths[0])
	)

func _insert_image(card_id: String, source_path: String) -> void:
	if not is_instance_valid(current_card) or current_card.card_id != card_id or storage == null:
		return
	var vault_path: String = storage.copy_image_to_vault(source_path)
	if vault_path == "":
		image_insert_failed.emit(storage.last_refusal)
		return

	var width: int = INSERT_IMAGE_WIDTH
	var image: Image = ImageGuard.load_image(vault_path)
	if image != null:
		width = mini(width, image.get_width())

	var markdown: String = NoteImages.to_markdown(source_path.get_file().get_basename(), width, vault_path)
	content_edit.begin_complex_operation()
	content_edit.insert_text_at_caret(markdown)
	content_edit.end_complex_operation()
	if is_preview:
		_render_preview()
	else:
		content_edit.grab_focus()


func _on_content_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed:
		return

	var is_shortcut: bool = (key.ctrl_pressed and not key.alt_pressed) or key.meta_pressed
	if key.unicode > 0 and content_edit.has_selection() and not is_shortcut:
		var typed: String = char(key.unicode)
		if WRAP_PAIR_CHARS.has(typed):
			TextFormatOps.wrap_selection(content_edit, typed, typed, false)
			get_viewport().set_input_as_handled()
			return

	if key.unicode == 91 and not is_link_popup_open():
		call_deferred("_auto_close_brackets")

	if not is_link_popup_open():
		return

	match key.keycode:
		KEY_UP:
			_link_popup.move_selection(-1)
			get_viewport().set_input_as_handled()
		KEY_DOWN:
			_link_popup.move_selection(1)
			get_viewport().set_input_as_handled()
		KEY_ENTER, KEY_KP_ENTER, KEY_TAB:
			if not _link_popup.confirm():
				_close_link_popup()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			_close_link_popup()
			get_viewport().set_input_as_handled()

func _auto_close_brackets() -> void:
	var line_idx: int = content_edit.get_caret_line()
	var col: int = content_edit.get_caret_column()
	var line: String = content_edit.get_line(line_idx)
	if col < LINK_OPEN.length() or line.substr(col - LINK_OPEN.length(), LINK_OPEN.length()) != LINK_OPEN:
		return
	if line.substr(col, LINK_CLOSE.length()) == LINK_CLOSE:
		return
	content_edit.insert_text_at_caret(LINK_CLOSE)
	content_edit.set_caret_column(col)

func _on_content_text_changed_for_links() -> void:
	_update_link_popup(true)

func _on_content_caret_changed_for_links() -> void:
	if is_link_popup_open():
		_update_link_popup(false)

func _on_content_scrolled(_value: float) -> void:
	if is_link_popup_open():
		_place_link_popup()

func _find_link_zone() -> Dictionary:
	var line_idx: int = content_edit.get_caret_line()
	var col: int = content_edit.get_caret_column()
	var line: String = content_edit.get_line(line_idx)
	var before: String = line.substr(0, col)
	var after: String = line.substr(col)

	var open_idx: int = before.rfind(LINK_OPEN)
	if open_idx == -1:
		return {}
	var typed_before: String = before.substr(open_idx + LINK_OPEN.length())
	if typed_before.contains("[") or typed_before.contains("]"):
		return {}

	var close_rel: int = after.find(LINK_CLOSE)
	if close_rel == -1:
		return {}
	var typed_after: String = after.substr(0, close_rel)
	if typed_after.contains("[") or typed_after.contains("]"):
		return {}

	var inner: String = typed_before + typed_after
	var separator: int = WikiLink.separator_index(inner)
	if separator >= 0 and typed_before.length() > separator:
		return {}
	var title_raw: String = inner if separator < 0 else inner.substr(0, separator)

	var start: int = open_idx + LINK_OPEN.length()
	return {
		"line": line_idx,
		"start": start,
		"end": start + title_raw.length(),
		"has_label": separator >= 0,
		"query": WikiLink.unescape(title_raw)
	}

func _update_link_popup(allow_open: bool) -> void:
	if not is_instance_valid(current_card) or not content_edit.has_focus():
		_close_link_popup()
		return

	var zone: Dictionary = _find_link_zone()
	if zone.is_empty():
		_close_link_popup()
		return
	if not allow_open and not is_link_popup_open():
		return

	var query: String = zone["query"]
	if is_link_popup_open() and query == _last_link_query:
		_place_link_popup()
		return

	_last_link_query = query
	_link_popup.update_results(FuzzyMatcher.rank(query, _collect_link_candidates()))
	_place_link_popup()

func _collect_link_candidates() -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for id: String in _link_cards:
		var card: GraphCard = _link_cards[id]
		if not is_instance_valid(card) or card == current_card:
			continue
		items.append({"id": card.card_id, "title": card.title_label.text})
	return items

func _place_link_popup() -> void:
	var rect: Rect2i = content_edit.get_rect_at_line_column(content_edit.get_caret_line(), content_edit.get_caret_column())
	if rect.position.x < 0 or rect.position.y < 0:
		_close_link_popup()
		return
	var line_h: float = maxf(float(content_edit.get_line_height()), float(rect.size.y))
	var caret_global: Vector2 = content_edit.get_global_rect().position + Vector2(rect.position)
	_link_popup.open_at(caret_global, line_h)

func _close_link_popup() -> void:
	_last_link_query = ""
	if is_instance_valid(_link_popup):
		_link_popup.close()

func _on_link_item_chosen(target_id: String, title: String) -> void:
	var zone: Dictionary = _find_link_zone()
	if zone.is_empty() or not is_instance_valid(current_card):
		_close_link_popup()
		return

	var line_idx: int = zone["line"]
	var start_col: int = zone["start"]
	var end_col: int = zone["end"]

	content_edit.begin_complex_operation()
	content_edit.remove_text(line_idx, start_col, line_idx, end_col)
	var written: String = WikiLink.escape(title)
	content_edit.insert_text(written, line_idx, start_col)
	content_edit.end_complex_operation()
	content_edit.set_caret_line(line_idx)
	var past_close: int = 0 if bool(zone["has_label"]) else LINK_CLOSE.length()
	content_edit.set_caret_column(start_col + written.length() + past_close)

	_close_link_popup()
	_on_content_changed()
	_flush_save()
	wiki_link_requested.emit(current_card.card_id, target_id)
