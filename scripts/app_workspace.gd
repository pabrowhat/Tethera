class_name AppWorkspace
extends Control

@export_group("Spawning")
@export var card_scene: PackedScene = preload("res://scenes/graph/graph_card.tscn")

@onready var navigator: CanvasNavigator = $CanvasNavigator
@onready var background: ColorRect = $Background
@onready var canvas: Control = $Canvas
@onready var connection_renderer: ConnectionRenderer = $Canvas/ConnectionRenderer
@onready var add_button: Button = $UI/TopBar/AddCardButton
@onready var search_input: LineEdit = $UI/TopBar/SearchInput
@onready var sidebar_editor: SidebarEditor = $UI/SidebarEditor
@onready var confirm_modal: ConfirmModal = $UI/ConfirmModal

var _storage: VaultStorage = null
var _worlds: WorldRegistry = WorldRegistry.new()
var _world_id: String = ""
var _world_flow: WorkspaceWorlds = null
var _vault_dialog: VaultFolderDialog = null
var _saving_links_paused: bool = false
var _world_prompt: WorldPromptDialog = null
var _start_screen: StartScreen = null
var _about_dialog: AboutDialog = null
var _whats_new_pending: bool = false
var _types: EntityTypeRegistry = EntityTypeRegistry.new()
var _graph: GraphNetwork = GraphNetwork.new()
var _selection: SelectionController = SelectionController.new()
var _is_panning: bool = false
var _note_counter: int = 1
var _carried_cards: Array[GraphCard] = []
var _link_source_card: GraphCard = null
var _cards_by_id: Dictionary = {}
var _last_titles: Dictionary = {}
var _last_contents: Dictionary = {}
var _lod_compact: bool = false
var _lod_font: int = GraphCard.TITLE_FONT_SIZE
var _active_search_query: String = ""
var _marquee: SelectionMarquee = null
var _minimap: Minimap = null
var _lightbox: Lightbox = null
var _eyedropper: EyeDropper = null
var _sampler: CanvasColorSampler = null
var _screen_grab: ScreenGrab = ScreenGrab.new()
var _sampling_target: int = 0
var _sampling_card_id: String = ""
var _zen_backdrop: ZenBackdrop = null
var _zen_active: bool = false
var _cover_click_suppressed: bool = false
var _marquee_active: bool = false
var _marquee_dragging: bool = false
var _marquee_origin_screen: Vector2 = Vector2.ZERO
var _marquee_origin_canvas: Vector2 = Vector2.ZERO
var _marquee_base: Array[GraphCard] = []
var _marquee_base_decor: Array[DecorNode] = []
var _group_drag_followers: Array[GraphCard] = []
var _group_drag_decor: Array[DecorNode] = []
var _drag_decor_before: Dictionary = {}
var _group_drag_start_pos: Vector2 = Vector2.ZERO

var _history: CanvasHistory = CanvasHistory.new()
var _undo: WorkspaceHistory = null
var _type_ops: WorkspaceTypes = null
var _drag_leader: GraphCard = null
var _decor_below: Node2D = null
var _decor_above: Node2D = null
var _decor_by_id: Dictionary = {}
var _decor: WorkspaceDecor = null
var _canvas_bg: WorkspaceCanvasBackground = null
var _layout: WorkspaceLayout = null
var _canvas_bg_dialog: CanvasBackgroundDialog = null
var _decor_gesture: Dictionary = {}
var _decor_menu: PopupList = null
var _decor_menu_target: DecorNode = null
var _decor_right_press: Dictionary = {}
var _picked_link: Dictionary = {}
var _link_menu: PopupList = null
var _drag_before: Dictionary = {}
var _carry_before: Dictionary = {}
var _saved_colors: Dictionary = {}

var _toast: HudToast = null
var _missing_image_paths: PackedStringArray = PackedStringArray()
var _shutter_flash: ShutterFlash = null
var _snapshot_exporter: SnapshotExporter = null
var _project_menu: Button = null
var _project_popup: PopupList = null
var _project_files: ProjectFilesController = null
var _import: WorkspaceImport = null
var _clipboard_ops: WorkspaceClipboard = null
var _shortcuts_dialog: ShortcutsDialog = null
var _search_popup: LinkAutocompletePopup = null
var _search: CanvasSearch = null
var _type_filter: TypeFilter = TypeFilter.new()
var _filter_panel: TypeFilterPanel = null
var _recent_panel: RecentPanel = null
var _palette: CommandPalette = null
var _snapshot_busy: bool = false
var _snapshot_saving: bool = false
var _file_dialog_open: bool = false
var _note_picker: NoteSelectionDialog = null
var _type_conflict: TypeConflictDialog = null
var _settings_dialog: SettingsDialog = null
var _pending_confirm: Callable = Callable()
var _project_path: String = ""
var _project_created: int = 0
var _canvas_background: CanvasBackground = CanvasBackground.new()

const SEARCH_ICON: Texture2D = preload("res://assets/icons/search.svg")
const MARQUEE_DRAG_THRESHOLD: float = 4.0
const LINE_PICK_RADIUS: float = 8.0
const LINK_MENU_WIDTH: float = 140.0
const GROUP_CLICK_TOLERANCE: float = 2.0
const VAULT_WARNING_HOLD: float = 9.0
const GRID_VISIBILITY_LAYER: int = 2

const LOD_ENTER_ZOOM: float = 0.4
const LOD_EXIT_ZOOM: float = 0.44
const LOD_ONSCREEN_MARGIN: float = 120.0
const COMPACT_SCREEN_FONT: float = 13.0
const COMPACT_FONT_STEP: int = 4
const COMPACT_FONT_MIN: int = 14
const COMPACT_FONT_MAX: int = 56
const BACKLINK_FOCUS_ZOOM_MIN: float = 0.7

func _init() -> void:
	Localization.apply_saved()
	ThemeColors.apply_saved()

func _ready() -> void:
	get_tree().auto_accept_quit = false
	_undo = WorkspaceHistory.new(self)
	_type_ops = WorkspaceTypes.new(self)
	_decor = WorkspaceDecor.new(self)
	_canvas_bg = WorkspaceCanvasBackground.new(self)
	_layout = WorkspaceLayout.new(self)
	_project_files = ProjectFilesController.new(self)
	_import = WorkspaceImport.new(self)
	_clipboard_ops = WorkspaceClipboard.new(self)
	_search =CanvasSearch.new(self)
	_sampler = CanvasColorSampler.new(self)
	_world_flow = WorkspaceWorlds.new(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE

	navigator.target_canvas = canvas
	navigator.background_rect = background
	navigator.panned.connect(_on_canvas_panned)
	navigator.transform_changed.connect(_on_navigator_transform_changed)

	add_button.pressed.connect(_on_add_card_pressed)
	_refresh_search_hint()
	search_input.text_changed.connect(_search.on_search_input_changed)
	search_input.text_submitted.connect(_search.on_search_text_submitted)
	search_input.gui_input.connect(_search.on_search_input_gui_input)
	search_input.focus_exited.connect(_search.close_search_popup)
	_search.build_search_popup()
	_search_popup.item_chosen.connect(_search.on_search_result_chosen)

	sidebar_editor.article_updated.connect(_on_sidebar_article_updated)
	sidebar_editor.card_color_changed.connect(_on_sidebar_card_color_changed)
	sidebar_editor.card_image_changed.connect(_on_sidebar_card_image_changed)
	sidebar_editor.image_view_requested.connect(_on_sidebar_image_view_requested)
	sidebar_editor.image_insert_failed.connect(func(reason: String) -> void:
		_toast.show_message(reason if reason != "" else tr("image.insert.failed"), true))
	sidebar_editor.card_delete_requested.connect(_delete_card_by_id)
	sidebar_editor.wiki_link_requested.connect(_on_wiki_link_requested)
	sidebar_editor.wiki_link_navigate_requested.connect(_on_backlink_pressed)
	sidebar_editor.batch_color_chosen.connect(_on_batch_color_chosen)
	sidebar_editor.batch_delete_requested.connect(_on_batch_delete_requested)
	sidebar_editor.batch_chip_focus_requested.connect(_on_batch_chip_focus_requested)
	sidebar_editor.batch_chip_remove_requested.connect(_on_batch_chip_remove_requested)
	sidebar_editor.closed.connect(_on_sidebar_closed)
	sidebar_editor.setup_types(_types, _type_ops.count_notes_of_type)
	sidebar_editor.card_type_chosen.connect(_on_card_type_chosen)
	sidebar_editor.card_type_color_follow_requested.connect(_type_ops.follow_type_color)
	sidebar_editor.card_background_previewed.connect(_on_sidebar_background_previewed)
	sidebar_editor.card_background_color_changed.connect(_on_sidebar_background_color_changed)
	sidebar_editor.card_background_color2_previewed.connect(_on_sidebar_background_color2_previewed)
	sidebar_editor.card_background_color2_changed.connect(_on_sidebar_background_color2_changed)
	sidebar_editor.card_background_gradient_cleared.connect(_on_sidebar_background_gradient_cleared)
	sidebar_editor.card_background_image_chosen.connect(_on_sidebar_background_image_chosen)
	sidebar_editor.card_background_cleared.connect(_on_sidebar_background_cleared)
	sidebar_editor.card_fields_changed.connect(_on_sidebar_card_fields_changed)
	sidebar_editor.type_manager.create_requested.connect(_type_ops.create_type)
	sidebar_editor.type_manager.rename_requested.connect(_type_ops.rename_type)
	sidebar_editor.type_manager.recolor_requested.connect(_type_ops.recolor_type)
	sidebar_editor.type_manager.delete_requested.connect(_type_ops.request_delete_type)
	sidebar_editor.type_manager.background_color_requested.connect(_type_ops.set_type_background_color)
	sidebar_editor.type_manager.background_color2_requested.connect(_type_ops.set_type_background_color2)
	sidebar_editor.type_manager.background_gradient_clear_requested.connect(_type_ops.clear_type_gradient)
	sidebar_editor.type_manager.background_image_requested.connect(_type_ops.set_type_background_image)
	sidebar_editor.type_manager.background_clear_requested.connect(_type_ops.clear_type_background)
	sidebar_editor.type_manager.field_add_requested.connect(_type_ops.add_field)
	sidebar_editor.type_manager.field_remove_requested.connect(_type_ops.remove_field)
	sidebar_editor.setup_link_source(_cards_by_id)
	_selection.selection_changed.connect(_on_selection_changed)
	connection_renderer.setup(_cards_by_id)

	_decor_below = Node2D.new()
	_decor_below.name = "DecorBelow"
	canvas.add_child(_decor_below)
	canvas.move_child(_decor_below, 0)
	_decor_above = Node2D.new()
	_decor_above.name = "DecorAbove"
	_decor_above.z_index = 1
	canvas.add_child(_decor_above)

	_marquee = SelectionMarquee.new()
	$UI.add_child(_marquee)
	$UI.move_child(_marquee, 0)

	_minimap = Minimap.new()
	$UI.add_child(_minimap)
	$UI.move_child(_minimap, 1)
	_minimap.setup(navigator, _cards_by_id, _selection)
	_minimap.fit_requested.connect(_focus_camera_to_selection_or_bounds)

	_recent_panel = RecentPanel.new()
	$UI.add_child(_recent_panel)
	_recent_panel.setup(_collect_recent_entries, _now)
	_recent_panel.note_chosen.connect(_on_recent_note_chosen)

	_filter_panel = TypeFilterPanel.new()
	$UI/TopBar.add_child(_filter_panel)
	_layout.build_menu()
	_filter_panel.type_toggled.connect(_type_filter.toggle)
	_filter_panel.show_all_requested.connect(_type_filter.show_all)
	_filter_panel.hide_all_requested.connect(_on_filter_hide_all_requested)
	_type_filter.changed.connect(_on_type_filter_changed)

	_zen_backdrop = ZenBackdrop.new()
	$UI.add_child(_zen_backdrop)
	$UI.move_child(_zen_backdrop, sidebar_editor.get_index())
	_zen_backdrop.dismissed.connect(sidebar_editor.exit_zen)
	sidebar_editor.zen_changed.connect(_on_zen_changed)
	sidebar_editor.eyedropper_requested.connect(_sampler.begin_sampling)
	sidebar_editor.background_eyedropper_requested.connect(_sampler.begin_sampling_for_background)

	confirm_modal.confirmed.connect(_on_confirm_accepted)
	confirm_modal.canceled.connect(_on_confirm_canceled)

	_eyedropper = EyeDropper.new()
	$UI.add_child(_eyedropper)

	background.visibility_layer = GRID_VISIBILITY_LAYER
	_bind_scene_colors()
	ThemeColors.watch(_apply_preferences)
	_snapshot_exporter = SnapshotExporter.new()
	add_child(_snapshot_exporter)

	_start_screen = StartScreen.new()
	$UI.add_child(_start_screen)
	_start_screen.input_blocked = _is_modal_over_start
	_note_picker = NoteSelectionDialog.new()
	$UI.add_child(_note_picker)
	_type_conflict = TypeConflictDialog.new()
	$UI.add_child(_type_conflict)
	_settings_dialog = SettingsDialog.new()
	$UI.add_child(_settings_dialog)
	_settings_dialog.saved.connect(_on_settings_saved)
	_settings_dialog.vault_change_requested.connect(_world_flow.change_vault)
	_about_dialog = AboutDialog.new()
	$UI.add_child(_about_dialog)
	_canvas_bg_dialog = CanvasBackgroundDialog.new()
	$UI.add_child(_canvas_bg_dialog)
	_canvas_bg_dialog.pick_requested.connect(_canvas_bg.request_pick)
	_canvas_bg_dialog.clear_requested.connect(_canvas_bg.remove)
	_canvas_bg_dialog.opacity_changed.connect(_canvas_bg.set_opacity)
	_vault_dialog = VaultFolderDialog.new()
	$UI.add_child(_vault_dialog)
	_world_prompt = WorldPromptDialog.new()
	$UI.add_child(_world_prompt)
	_shortcuts_dialog = ShortcutsDialog.new()
	$UI.add_child(_shortcuts_dialog)
	_palette = CommandPalette.new()
	$UI.add_child(_palette)
	_palette.setup(_project_files.palette_entries, _project_files.run_command)

	_toast = HudToast.new()
	$UI.add_child(_toast)
	InlineImages.missing_reporter = _on_inline_image_missing
	_shutter_flash = ShutterFlash.new()
	$UI.add_child(_shutter_flash)
	_project_files.build_project_menu()
	get_window().files_dropped.connect(_project_files.on_files_dropped)

	$UI.add_child(TextContextMenu.new())

	_lightbox = Lightbox.new()
	$UI.add_child(_lightbox)

	_graph.network_changed.connect(_on_graph_network_changed)
	_graph.link_created.connect(connection_renderer.animate_link)
	_graph.link_reinforced.connect(connection_renderer.pulse_link)
	_graph.link_removed.connect(connection_renderer.dissolve_link)
	connection_renderer.link_anchored.connect(_on_link_anchored)

	_world_flow.start()
	navigator.update_shader()

func _bind_scene_colors() -> void:
	ThemeColors.bind(background, &"color", &"canvas.background")
	ThemeColors.bind_override(add_button, &"font_color", &"text.primary")
	ThemeColors.bind_override(search_input, &"font_color", &"text.strong")
	var search_style: StyleBoxFlat = search_input.get_theme_stylebox(&"normal") as StyleBoxFlat
	ThemeColors.bind(search_style, &"bg_color", &"surface.raised")
	ThemeColors.bind(search_style, &"border_color", UiStyle.BORDER)
	ThemeColors.watch(_tint_search_icon)

func _tint_search_icon() -> void:
	var image: Image = SEARCH_ICON.get_image()
	if image.is_compressed():
		image.decompress()
	var tint: Color = ThemeColors.color(&"text.muted")
	for y: int in image.get_height():
		for x: int in image.get_width():
			image.set_pixel(x, y, Color(tint, tint.a * image.get_pixel(x, y).a))
	search_input.right_icon = ImageTexture.create_from_image(image)

func _apply_preferences() -> void:
	if background.material is ShaderMaterial:
		var grid_color: Color = ThemeColors.color(&"canvas.dot")
		if not Preferences.show_grid():
			grid_color.a = 0.0
		var grid_material: ShaderMaterial = background.material as ShaderMaterial
		grid_material.set_shader_parameter("dot_color", grid_color)
		grid_material.set_shader_parameter("bg_color", ThemeColors.color(&"canvas.background"))
	connection_renderer.width_scale = Preferences.line_width_scale()
	connection_renderer.queue_redraw()

func focus_search() -> void:
	search_input.grab_focus()
	search_input.select_all()

func open_command_palette() -> void:
	if _snapshot_busy or _file_dialog_open or _is_modal_open() or _zen_active or _lightbox.is_open() or _eyedropper.is_active():
		return
	_search.close_search_popup()
	_palette.open_palette()

func open_settings() -> void:
	if _snapshot_busy or _file_dialog_open or _is_modal_open() or _zen_active or _lightbox.is_open() or _eyedropper.is_active():
		return
	_settings_dialog.open_with_current()

func open_about() -> void:
	if _snapshot_busy or _file_dialog_open or _is_modal_open() or _zen_active or _lightbox.is_open() or _eyedropper.is_active():
		return
	_about_dialog.open_tab(AboutDialog.Tab.ABOUT)

func _on_settings_saved() -> void:
	Localization.apply_saved()
	ThemeColors.apply_saved()
	_apply_preferences()
	_toast.show_message(tr("settings.saved"))

func _refresh_search_hint() -> void:
	if PlatformKeys.is_macos():
		search_input.placeholder_text = PlatformKeys.localize(tr("topbar.search.placeholder"))

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and search_input != null:
		_refresh_search_hint()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		_save_all_vault_data()

func request_quit() -> void:
	if not _world_flow.flush_or_warn():
		return
	if is_instance_valid(_settings_dialog) and _settings_dialog.has_unsaved_changes():
		_settings_dialog.request_leave(_quit_app)
		return
	_quit_app()

func _quit_app() -> void:
	get_tree().quit()

func _load_vault_data(skipped_worlds: int = 0) -> void:
	_storage.ensure_directories()
	_storage.purge_trash(_now())
	var snapshot: VaultStorage.SnapshotResult = _storage.take_daily_snapshot(Time.get_date_string_from_system())
	_load_types()
	var loaded_notes: Array[Dictionary] = _storage.load_all_notes()

	for note: Dictionary in loaded_notes:
		_instantiate_card(note)
		_note_counter += 1

	_graph.load_from_data(_storage.load_connections())
	_decor.load_all()
	_canvas_bg.load_saved()
	_pin_positions(loaded_notes)
	_update_lod(navigator.get_zoom(), false)
	_report_vault_problems(snapshot == VaultStorage.SnapshotResult.FAILED, skipped_worlds)

func _report_vault_problems(snapshot_failed: bool, skipped_worlds: int = 0) -> void:
	var problems: PackedStringArray = PackedStringArray()
	if skipped_worlds > 0:
		problems.append(tr("worlds.damaged_skipped") % skipped_worlds)
	if snapshot_failed:
		problems.append(tr("vault.snapshot_failed"))
	if not _storage.last_corrupt.is_empty():
		problems.append(tr("vault.corrupt_notes") % [_storage.last_corrupt.size(), _short_list(_storage.last_corrupt)])
	if not _storage.last_unreadable.is_empty():
		problems.append(tr("vault.unreadable_notes") % [_storage.last_unreadable.size(), _short_list(_storage.last_unreadable)])
	if not problems.is_empty():
		_toast.show_message(" ".join(problems), true, VAULT_WARNING_HOLD)

func _short_list(names: PackedStringArray) -> String:
	var shown: String = ", ".join(names.slice(0, 3))
	return shown + (", …" if names.size() > 3 else "")

func _load_types() -> void:
	if _types.changed.is_connected(_on_types_changed):
		_types.changed.disconnect(_on_types_changed)
	var stored: Dictionary = _storage.load_types()
	if bool(stored["exists"]):
		_types.load_array(stored["types"])
	else:
		_types.seed_defaults()
		_storage.save_types(_types.to_array())
	_types.changed.connect(_on_types_changed)
	_rebuild_filter_panel()

func _on_types_changed() -> void:
	_storage.save_types(_types.to_array())
	_type_ops.refresh_all_backgrounds()
	_rebuild_filter_panel()

func _rebuild_filter_panel() -> void:
	var valid_ids: Array[String] = []
	for entity_type: EntityType in _types.get_all():
		valid_ids.append(entity_type.id)
	_type_filter.prune(valid_ids)
	_filter_panel.rebuild(_types.get_all(), _type_filter)
	_apply_type_filter()

func _on_filter_hide_all_requested() -> void:
	var type_ids: Array[String] = [""]
	for entity_type: EntityType in _types.get_all():
		type_ids.append(entity_type.id)
	_type_filter.hide_all(type_ids)

func _on_type_filter_changed() -> void:
	_filter_panel.refresh_states(_type_filter)
	_apply_type_filter()

func _apply_type_filter() -> void:
	for card: GraphCard in _cards_by_id.values():
		if is_instance_valid(card):
			_apply_filter_to(card)

func _apply_filter_to(card: GraphCard, immediate: bool = false) -> void:
	var type_key: String = card.entity_type_id if _types.find(card.entity_type_id) != null else ""
	card.set_filter_alpha(_type_filter.alpha_for(type_key), immediate)

func _on_card_type_chosen(card_id: String, type_id: String) -> void:
	_type_ops.assign_type(card_id, type_id)
	var card: GraphCard = _cards_by_id.get(card_id, null)
	if is_instance_valid(card):
		_apply_filter_to(card)

func _pin_positions(notes: Array[Dictionary]) -> void:
	for note: Dictionary in notes:
		var card: GraphCard = _cards_by_id.get(str(note["id"]), null)
		if is_instance_valid(card):
			card.position = note.get("pos", card.position)

func _instantiate_card(note: Dictionary) -> GraphCard:
	var card: GraphCard = card_scene.instantiate() as GraphCard
	canvas.add_child(card)

	var id: String = str(note["id"])
	var title: String = str(note.get("title", ""))
	var content: String = str(note.get("content", ""))
	var pos: Vector2 = note.get("pos", Vector2.ZERO)

	card.position = pos
	card.setup(id, title, content, str(note.get("color", "313549")), str(note.get("image", "")))
	card.apply_meta(str(note.get("status", "")), int(note.get("created", 0)), int(note.get("modified", 0)))
	card.apply_type_data(str(note.get("type", "")), note.get("fields", {}) as Dictionary, bool(note.get("color_overridden", false)))
	card.apply_background_data(str(note.get("bg_color", "")), str(note.get("bg_color2", "")), str(note.get("bg_image", "")))
	var note_type: EntityType = _types.find(card.entity_type_id)
	if note_type != null and not card.color_overridden:
		card.set_category_color(note_type.color, false)
	_type_ops.apply_background(card)
	_cards_by_id[id] = card
	_last_titles[id] = title
	_last_contents[id] = content
	_saved_colors[id] = card.card_color
	_apply_filter_to(card, true)

	_connect_card_signals(card)

	if bool(note.get("flipped", false)):
		_refresh_back_face(card)
		card.set_flipped(true, false)

	if _lod_compact:
		card.set_compact_font(_lod_font)
		card.set_compact(true, false)
	return card

func _snapshot_card(card: GraphCard) -> Dictionary:
	return {
		"id": card.card_id,
		"title": card.title_label.text,
		"content": card.content_text,
		"pos": card.position,
		"color": card.card_color.to_html(false),
		"image": card.image_path,
		"status": card.status,
		"created": card.created_at,
		"modified": card.modified_at,
		"flipped": card.is_flipped,
		"type": card.entity_type_id,
		"fields": card.field_values.duplicate(true),
		"color_overridden": card.color_overridden,
		"bg_color": card.bg_color_hex,
		"bg_color2": card.bg_color2_hex,
		"bg_image": card.bg_image_path,
	}

func _save_all_vault_data() -> bool:
	if _storage == null:
		return true
	var saved: bool = true
	for id: String in _cards_by_id:
		var card: GraphCard = _cards_by_id[id]
		if is_instance_valid(card):
			saved = _save_card(card) and saved
	saved = _storage.save_connections(_graph.get_all_connections()) and saved
	saved = _storage.save_types(_types.to_array()) and saved
	saved = _decor.save() and saved
	return saved

func flush_world() -> bool:
	if _storage == null:
		return false
	sidebar_editor.flush_pending_save()
	var saved: bool = _save_all_vault_data()
	var world_name: String = _world_flow.current_name()
	if world_name != "":
		saved = WorldRegistry.write_world_file(_storage.root, world_name) and saved
	return saved

func _close_world() -> void:
	_clear_canvas()
	_history.clear()
	_clipboard_ops.clear()
	_note_counter = 1
	_project_path = ""
	_project_created = 0

func _end_interactions() -> void:
	_cancel_link_source()
	_finish_carry()
	_drag_before = {}
	_drag_leader = null
	_group_drag_followers.clear()
	_group_drag_decor.clear()
	_decor_gesture = {}
	_picked_link = {}
	_is_panning = false
	sidebar_editor.close_sidebar()
	_selection.clear()

func _clear_canvas() -> void:
	_end_interactions()
	for card: GraphCard in _cards_by_id.values():
		if is_instance_valid(card):
			card.queue_free()
	_cards_by_id.clear()
	for decor_node: DecorNode in _decor.all_nodes():
		decor_node.queue_free()
	_decor_by_id.clear()
	_last_titles.clear()
	_last_contents.clear()
	_saved_colors.clear()
	var no_links: Array[Dictionary] = []
	_saving_links_paused = true
	_graph.load_from_data(no_links)
	_saving_links_paused = false

func _save_card(card: GraphCard, title_override: String = "", content_override: String = "") -> bool:
	var title: String = title_override if title_override != "" else card.title_label.text
	var content: String = content_override if content_override != "" else card.content_text
	return _storage.save_note(card.card_id, title, content, card.position, card.card_color.to_html(false), card.image_path, {
		"status": card.status,
		"created": card.created_at,
		"modified": card.modified_at,
		"flipped": card.is_flipped,
		"type": card.entity_type_id,
		"fields": card.field_values,
		"color_overridden": card.color_overridden,
		"bg_color": card.bg_color_hex,
		"bg_color2": card.bg_color2_hex,
		"bg_image": card.bg_image_path,
	})

func _touch_card(card: GraphCard) -> void:
	card.modified_at = _now()
	if card.is_flipped:
		_refresh_back_face(card)
	card.refresh_compact_layout()
	_save_card(card)

func _now() -> int:
	return int(Time.get_unix_time_from_system())

func _format_timestamp(unix_time: int) -> String:
	if unix_time <= 0:
		return "—"
	var local_now: int = int(Time.get_unix_time_from_datetime_dict(Time.get_datetime_dict_from_system(false)))
	var offset_seconds: int = roundi(float(local_now - _now()) / 60.0) * 60
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time + offset_seconds)
	return "%02d.%02d.%04d %02d:%02d" % [d["day"], d["month"], d["year"], d["hour"], d["minute"]]


func _refresh_back_face(card: GraphCard) -> void:
	var backlinks: Array[Dictionary] = []
	for source_id: String in _graph.get_inbound_links(card.card_id):
		var source: GraphCard = _cards_by_id.get(source_id, null)
		if is_instance_valid(source):
			backlinks.append({"id": source_id, "title": source.title_label.text, "color": source.card_color})
	card.populate_back(_format_timestamp(card.created_at), _format_timestamp(card.modified_at), backlinks)

func _refresh_flipped_back_faces() -> void:
	for card: GraphCard in _cards_by_id.values():
		if is_instance_valid(card) and card.is_flipped:
			_refresh_back_face(card)

func _compact_font_for_zoom(zoom: float) -> int:
	var steps: int = roundi(COMPACT_SCREEN_FONT / maxf(zoom, 0.01) / float(COMPACT_FONT_STEP))
	return clampi(steps * COMPACT_FONT_STEP, COMPACT_FONT_MIN, COMPACT_FONT_MAX)

func _update_lod(zoom: float, animate: bool = true) -> void:
	var want_compact: bool = zoom < (LOD_EXIT_ZOOM if _lod_compact else LOD_ENTER_ZOOM)
	var font_px: int = _compact_font_for_zoom(zoom)
	var mode_changed: bool = want_compact != _lod_compact
	var font_changed: bool = font_px != _lod_font
	if not mode_changed and not font_changed:
		return

	_lod_compact = want_compact
	_lod_font = font_px
	if not mode_changed and not _lod_compact:
		return

	var near_rect: Rect2 = navigator.get_visible_canvas_rect(get_viewport_rect().size).grow(LOD_ONSCREEN_MARGIN / maxf(zoom, 0.01))
	for card: GraphCard in _cards_by_id.values():
		if not is_instance_valid(card):
			continue
		card.set_compact_font(font_px)
		if mode_changed:
			var smooth: bool = animate and near_rect.intersects(Rect2(card.position, card.size))
			card.set_compact(_lod_compact, smooth)

func _glide_to_card(card: GraphCard, keep_zoom: bool = false) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var usable_width: float = viewport_size.x
	if sidebar_editor.is_open:
		usable_width = maxf(viewport_size.x - sidebar_editor.panel_width, 100.0)
	var zoom: float = navigator.get_zoom() if keep_zoom else maxf(navigator.get_zoom(), BACKLINK_FOCUS_ZOOM_MIN)
	navigator.focus_to_point(card.get_card_center(), zoom, Vector2(usable_width / 2.0, viewport_size.y / 2.0))

func focus_and_open_card(card: GraphCard) -> void:
	_selection.select_only(card)
	_glide_to_card(card)

func _collect_recent_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for card: GraphCard in _cards_by_id.values():
		if is_instance_valid(card):
			var title: String = card.title_label.text.strip_edges()
			entries.append({"id": card.card_id, "title": title if title != "" else tr("note.untitled"), "modified": card.modified_at})
	return RecentNotes.top(entries, RecentNotes.DEFAULT_LIMIT)

func open_recent() -> void:
	if _snapshot_busy or _is_modal_open() or _zen_active or _lightbox.is_open() or _eyedropper.is_active():
		return
	_recent_panel.open_below(_project_menu.get_global_rect())

func _on_recent_note_chosen(card_id: String) -> void:
	var card: GraphCard = _cards_by_id.get(card_id, null)
	if is_instance_valid(card):
		focus_and_open_card(card)

func _bookmark_slot_for(key: InputEventKey) -> int:
	if key.ctrl_pressed or key.meta_pressed:
		return -1
	var slot: int = int(key.physical_keycode) - int(KEY_1)
	if slot < 0 or slot >= BookmarkStore.SLOT_COUNT:
		return -1
	return slot

func _set_bookmark(slot: int) -> void:
	if _selection.count() != 1:
		_toast.show_message(tr("bookmark.need_one"), true)
		return
	var card: GraphCard = _selection.get_cards()[0]
	BookmarkStore.set_slot(_world_id, slot, card.card_id)
	var title: String = card.title_label.text.strip_edges()
	_toast.show_message(tr("bookmark.set") % [slot + 1, title if title != "" else tr("note.untitled")])

func _clear_bookmark(slot: int) -> void:
	if BookmarkStore.get_slot(_world_id, slot) == "":
		_toast.show_message(tr("bookmark.empty") % [slot + 1, slot + 1])
		return
	BookmarkStore.clear_slot(_world_id, slot)
	_toast.show_message(tr("bookmark.cleared") % (slot + 1))

func _jump_to_bookmark(slot: int) -> void:
	var card_id: String = BookmarkStore.get_slot(_world_id, slot)
	if card_id == "":
		_toast.show_message(tr("bookmark.empty") % [slot + 1, slot + 1])
		return
	var card: GraphCard = _cards_by_id.get(card_id, null)
	if not is_instance_valid(card):
		BookmarkStore.clear_slot(_world_id, slot)
		_toast.show_message(tr("bookmark.missing"), true)
		return
	_glide_to_card(card, true)
	card.flash_highlight()

func _process(_delta: float) -> void:
	if is_instance_valid(_link_source_card):
		var mouse_screen: Vector2 = get_viewport().get_mouse_position()
		var hovered_card: GraphCard = _find_card_under_mouse(mouse_screen)
		var is_disconnect: bool = false

		if is_instance_valid(hovered_card) and hovered_card != _link_source_card:
			is_disconnect = _graph.are_connected(_link_source_card.card_id, hovered_card.card_id)

		connection_renderer.set_preview_line(
			_link_source_card.get_card_center(),
			navigator.screen_to_canvas(mouse_screen),
			is_disconnect
		)
	elif not _graph.get_all_connections().is_empty():
		connection_renderer.queue_redraw()

func _input(event: InputEvent) -> void:
	if _snapshot_busy:
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey:
		var quit_key: InputEventKey = event as InputEventKey
		if quit_key.pressed and not quit_key.is_echo() and PlatformKeys.is_primary(quit_key) and not quit_key.alt_pressed \
				and not quit_key.shift_pressed and (quit_key.keycode == KEY_Q or quit_key.physical_keycode == KEY_Q):
			get_viewport().set_input_as_handled()
			request_quit()
			return

	if _is_dialog_open():
		return

	if _lightbox.is_open():
		if event is InputEventKey:
			var lightbox_key: InputEventKey = event as InputEventKey
			if lightbox_key.pressed and not lightbox_key.is_echo() and lightbox_key.keycode == KEY_ESCAPE:
				_lightbox.close()
			get_viewport().set_input_as_handled()
		return

	if _eyedropper.is_active():
		_sampler.handle_sampling_input(event)
		return

	if _zen_active:
		_handle_zen_input(event)
		return

	if event is InputEventKey and event.pressed and not event.is_echo():
		var is_ctrl_cmd: bool = PlatformKeys.is_primary(event as InputEventKey)
		var focus_owner: Control = get_viewport().gui_get_focus_owner()
		var is_typing: bool = focus_owner is LineEdit or focus_owner is TextEdit

		var is_enter: bool = event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER
		if (event.keycode == KEY_F11 or (is_ctrl_cmd and is_enter)) and not _is_modal_open():
			if sidebar_editor.can_enter_zen():
				sidebar_editor.enter_zen()
				get_viewport().set_input_as_handled()
			return

		if is_ctrl_cmd and not event.alt_pressed and not _is_modal_open():
			if _handle_global_shortcut(event as InputEventKey, is_typing):
				get_viewport().set_input_as_handled()
				return

		if is_ctrl_cmd and event.keycode == KEY_F:
			focus_search()
			get_viewport().set_input_as_handled()
			return

		if event.keycode == KEY_ESCAPE:
			if sidebar_editor.is_link_popup_open() or PopupList.is_any_open():
				return
			if search_input.has_focus() or _active_search_query != "":
				search_input.text = ""
				_search.on_search_text_changed("")
				_search.close_search_popup()
				search_input.release_focus()
				get_viewport().set_input_as_handled()
				return
			elif confirm_modal.visible:
				confirm_modal._on_cancel_pressed()
				get_viewport().set_input_as_handled()
				return
			elif is_instance_valid(_link_source_card):
				_cancel_link_source()
				get_viewport().set_input_as_handled()
				return
			elif not _picked_link.is_empty():
				_unpick_link()
				get_viewport().set_input_as_handled()
				return
			elif sidebar_editor.is_open:
				sidebar_editor.close_sidebar()
				get_viewport().set_input_as_handled()
				return

		elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if confirm_modal.visible:
				confirm_modal._on_confirm_pressed()
				get_viewport().set_input_as_handled()
				return

		elif event.keycode == KEY_F2 and not is_typing and not _is_modal_open():
			if _selection.count() == 1:
				_selection.get_cards()[0].start_rename()
				get_viewport().set_input_as_handled()
				return

		elif (event.keycode == KEY_F or event.keycode == KEY_HOME) and not is_typing and not _is_modal_open():
			_focus_camera_to_selection_or_bounds()
			get_viewport().set_input_as_handled()
			return

		elif event.keycode == KEY_M and not is_ctrl_cmd and not is_typing and not _is_modal_open():
			_minimap.toggle_collapsed()
			get_viewport().set_input_as_handled()
			return

		elif event.keycode == KEY_P and not is_ctrl_cmd and not event.alt_pressed and not event.shift_pressed and not is_typing and not _is_modal_open() and not PopupList.is_any_open():
			_project_files.open_project_menu()
			get_viewport().set_input_as_handled()
			return

		elif _bookmark_slot_for(event as InputEventKey) >= 0 and not is_typing and not _is_modal_open() and not PopupList.is_any_open():
			var slot: int = _bookmark_slot_for(event as InputEventKey)
			if event.alt_pressed:
				_clear_bookmark(slot)
			elif event.shift_pressed:
				_set_bookmark(slot)
			else:
				_jump_to_bookmark(slot)
			get_viewport().set_input_as_handled()
			return

		elif (event.keycode == KEY_DELETE or event.keycode == KEY_BACKSPACE) and not is_typing and not _is_modal_open():
			if _selection.item_count() > 0:
				_delete_cards(_selection.get_cards(), _selection.get_decor())
				get_viewport().set_input_as_handled()
				return

	if _is_modal_open():
		return

	if _marquee_active:
		if event is InputEventMouseMotion:
			_update_marquee(get_viewport().get_mouse_position())
		elif event is InputEventMouseButton:
			var release: InputEventMouseButton = event as InputEventMouseButton
			if release.button_index == MOUSE_BUTTON_LEFT and not release.pressed:
				_finish_marquee()

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		var is_over_sidebar: bool = _is_mouse_over_sidebar(mb.global_position)
		var is_over_topbar: bool = _is_mouse_over_topbar(mb.global_position) or _is_mouse_over_search_popup(mb.global_position) \
			or PopupList.is_point_over_open(mb.global_position)
		var is_over_minimap: bool = _is_mouse_over_minimap(mb.global_position)

		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var focus_owner: Control = get_viewport().gui_get_focus_owner()
			if focus_owner is LineEdit or focus_owner is TextEdit:
				var click_pos: Vector2 = mb.global_position
				var keeps_focus: bool = sidebar_editor.is_point_over_link_popup(click_pos) or sidebar_editor.is_point_over_text_tools(click_pos) \
					or _is_mouse_over_search_popup(click_pos) or PopupList.is_point_over_open(click_pos)
				if not focus_owner.get_global_rect().has_point(click_pos) and not keeps_focus:
					focus_owner.release_focus()

		if mb.button_index == MOUSE_BUTTON_RIGHT:
			if (is_over_sidebar or is_over_topbar or is_over_minimap) and mb.pressed:
				return
			if mb.pressed:
				_decor.note_right_press(mb)
			else:
				_decor.note_right_release(mb)
			_is_panning = mb.pressed
			get_viewport().set_input_as_handled()

		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			if not is_over_sidebar and not is_over_topbar and not is_over_minimap:
				navigator.zoom_towards(navigator.zoom_factor, mb.position)
				get_viewport().set_input_as_handled()

		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			if not is_over_sidebar and not is_over_topbar and not is_over_minimap:
				navigator.zoom_towards(1.0 / navigator.zoom_factor, mb.position)
				get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _is_panning:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		navigator.pan(mm.relative, mm.velocity)
		get_viewport().set_input_as_handled()

	if _handle_decor_input(event):
		get_viewport().set_input_as_handled()

func _handle_decor_input(event: InputEvent) -> bool:
	if not _decor_gesture.is_empty():
		if event is InputEventMouseMotion:
			var motion: InputEventMouseMotion = event as InputEventMouseMotion
			_decor.update_gesture(navigator.screen_to_canvas(motion.position), motion.position, motion.velocity.x)
		elif event is InputEventMouseButton:
			var release: InputEventMouseButton = event as InputEventMouseButton
			if release.button_index == MOUSE_BUTTON_LEFT and not release.pressed:
				_decor.finish_gesture()
				return true
		return false
	if event is InputEventMouseButton:
		var press: InputEventMouseButton = event as InputEventMouseButton
		if press.button_index == MOUSE_BUTTON_LEFT and press.pressed:
			return _decor.try_begin_from_press(press)
	return false

func _key_is(key: InputEventKey, code: Key) -> bool:
	return key.keycode == code or key.physical_keycode == code

func _handle_global_shortcut(key: InputEventKey, is_typing: bool) -> bool:
	if (key.keycode == KEY_COMMA or key.physical_keycode == KEY_COMMA) and not key.shift_pressed:
		open_settings()
		return true
	if (key.keycode == KEY_K or key.physical_keycode == KEY_K) and not key.shift_pressed:
		open_command_palette()
		return true
	if (key.keycode == KEY_M or key.physical_keycode == KEY_M) and not key.shift_pressed:
		_world_flow.go_to_main_menu()
		return true
	if _key_is(key, KEY_E) and not key.shift_pressed and not PopupList.is_any_open():
		if not sidebar_editor.can_toggle_mode():
			return false
		sidebar_editor.toggle_mode()
		return true
	if not is_typing and not key.shift_pressed and not PopupList.is_any_open():
		if _key_is(key, KEY_N):
			_spawn_card_at_viewport_center()
			return true
		if _key_is(key, KEY_C):
			return _clipboard_ops.copy()
		if _key_is(key, KEY_X):
			_clipboard_ops.cut()
			return _selection.item_count() == 0
		if _key_is(key, KEY_V):
			_clipboard_ops.paste()
			return true
		if _key_is(key, KEY_D):
			_clipboard_ops.duplicate()
			return true
		if _key_is(key, KEY_A):
			_clipboard_ops.select_all()
			return true
	match key.keycode:
		KEY_Z:
			if is_typing:
				return false
			_undo.run_history_command(key.shift_pressed)
			return true
		KEY_Y:
			if is_typing or key.shift_pressed:
				return false
			_undo.run_history_command(true)
			return true
		KEY_S:
			if key.shift_pressed:
				_project_files.export_snapshot()
			else:
				_project_files.save_project()
			return true
		KEY_O:
			if key.shift_pressed:
				return false
			_project_files.open_project_dialog()
			return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	if _snapshot_busy or _is_modal_open() or _lightbox.is_open() or _zen_active or _eyedropper.is_active():
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if not Input.is_key_pressed(KEY_SPACE):
				_finish_carry()
			if is_instance_valid(_link_source_card):
				_cancel_link_source()
			elif not Input.is_key_pressed(KEY_SPACE) and not _is_mouse_over_sidebar(mb.global_position) and not _is_mouse_over_topbar(mb.global_position):
				var picked: Dictionary = _link_at(mb.position) if mb.double_click else {}
				if not picked.is_empty() and not Input.is_key_pressed(KEY_SHIFT):
					_selection.clear()
					_pick_link(picked, mb.global_position)
					return
				_unpick_link()
				var below: DecorNode = _decor.node_at(navigator.screen_to_canvas(mb.position), _decor_below)
				if below != null:
					_decor.press(below, mb)
				else:
					_begin_marquee(mb.position)


func _on_zen_changed(active: bool) -> void:
	_zen_active = active
	_is_panning = false
	if active:
		_zen_backdrop.fade_in()
	else:
		_zen_backdrop.fade_out()

func _handle_zen_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.is_echo():
		return

	var is_enter: bool = key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER
	if key.keycode == KEY_ESCAPE:
		if sidebar_editor.is_link_popup_open() or PopupList.is_any_open():
			return
		sidebar_editor.exit_zen()
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_F11 or (is_enter and PlatformKeys.is_primary(key)):
		sidebar_editor.exit_zen()
		get_viewport().set_input_as_handled()

func _begin_marquee(screen_pos: Vector2) -> void:
	_marquee_active = true
	_marquee_dragging = false
	_marquee_origin_screen = screen_pos
	_marquee_origin_canvas = navigator.screen_to_canvas(screen_pos)
	_marquee_base.clear()
	_marquee_base_decor.clear()
	if Input.is_key_pressed(KEY_SHIFT):
		_marquee_base.append_array(_selection.get_cards())
		_marquee_base_decor.append_array(_selection.get_decor())

func _update_marquee(screen_pos: Vector2) -> void:
	if not _marquee_dragging:
		if screen_pos.distance_to(_marquee_origin_screen) < MARQUEE_DRAG_THRESHOLD:
			return
		_marquee_dragging = true

	var origin_screen: Vector2 = navigator.canvas_to_screen(_marquee_origin_canvas)
	_marquee.set_rect(Rect2(origin_screen, Vector2.ZERO).expand(screen_pos))

	var canvas_rect: Rect2 = Rect2(_marquee_origin_canvas, Vector2.ZERO).expand(navigator.screen_to_canvas(screen_pos)).grow(1.0)
	var captured: Array[GraphCard] = []
	captured.append_array(_marquee_base)
	for card: GraphCard in _cards_by_id.values():
		if is_instance_valid(card) and not captured.has(card) and Rect2(card.position, card.size).intersects(canvas_rect):
			captured.append(card)

	var items: Array = []
	items.append_array(captured)
	items.append_array(_marquee_base_decor)
	for node: DecorNode in _decor.all_nodes():
		if not items.has(node) and node.canvas_bounds().intersects(canvas_rect):
			items.append(node)

	_selection.set_items(items, true, true)

func _finish_marquee() -> void:
	var was_dragging: bool = _marquee_dragging
	_marquee_active = false
	_marquee_dragging = false
	_marquee_base = []
	_marquee_base_decor = []
	_marquee.hide_rect()

	if was_dragging:
		_selection.commit()
	elif not Input.is_key_pressed(KEY_SHIFT):
		_selection.clear()

func _is_mouse_over_sidebar(global_pos: Vector2) -> bool:
	return is_instance_valid(sidebar_editor) and sidebar_editor.is_open and sidebar_editor.contains_global_point(global_pos)

func _is_mouse_over_topbar(global_pos: Vector2) -> bool:
	var topbar: HBoxContainer = $UI/TopBar
	if is_instance_valid(_filter_panel) and _filter_panel.is_point_over_panel(global_pos):
		return true
	if is_instance_valid(_recent_panel) and _recent_panel.is_point_over_panel(global_pos):
		return true
	return is_instance_valid(topbar) and topbar.get_global_rect().has_point(global_pos)

func _is_mouse_over_search_popup(global_pos: Vector2) -> bool:
	return is_instance_valid(_search_popup) and _search_popup.is_open() and _search_popup.get_global_rect().has_point(global_pos)

func _is_mouse_over_minimap(global_pos: Vector2) -> bool:
	return is_instance_valid(_minimap) and _minimap.is_point_over(global_pos)

func _on_canvas_panned(_delta_screen: Vector2, delta_canvas: Vector2, velocity_canvas_x: float) -> void:
	for card: GraphCard in _carried_cards:
		if is_instance_valid(card):
			card.apply_carrier_shift(delta_canvas, velocity_canvas_x)

func _on_navigator_transform_changed(_offset: Vector2, zoom: float) -> void:
	connection_renderer.queue_redraw()
	_decor.on_zoom_changed()
	_update_lod(zoom)

func _on_graph_network_changed() -> void:
	var conns: Array[Dictionary] = _graph.get_all_connections()
	connection_renderer.connections = conns
	connection_renderer.queue_redraw()
	if not _picked_link.is_empty() and not _graph.are_connected(str(_picked_link["from"]), str(_picked_link["to"])):
		_unpick_link()
	if not _saving_links_paused:
		_storage.save_connections(conns)
	_refresh_flipped_back_faces()

func _focus_camera_to_selection_or_bounds() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var screen_rect: Rect2 = Rect2(Vector2.ZERO, viewport_size)
	if sidebar_editor.is_open:
		screen_rect.size.x = maxf(viewport_size.x - sidebar_editor.panel_width, 100.0)

	var targets: Array[GraphCard] = _selection.get_cards()
	var decor_targets: Array[DecorNode] = _selection.get_decor()
	if targets.is_empty() and decor_targets.is_empty():
		for card: GraphCard in _cards_by_id.values():
			if is_instance_valid(card):
				targets.append(card)
		decor_targets = _decor.all_nodes()

	if targets.is_empty() and decor_targets.is_empty():
		navigator.focus_to_point(Vector2.ZERO, 1.0, screen_rect.get_center())
		return

	navigator.focus_to_bounds(_items_bounds(targets, decor_targets), screen_rect, 0.12)

func _items_bounds(cards: Array[GraphCard], decor: Array[DecorNode]) -> Rect2:
	var rects: Array[Rect2] = []
	for card: GraphCard in cards:
		rects.append(Rect2(card.position, card.size))
	for node: DecorNode in decor:
		rects.append(node.canvas_bounds())
	var bounds: Rect2 = rects[0]
	for rect: Rect2 in rects:
		bounds = bounds.merge(rect)
	return bounds

func open_vault_folder() -> void:
	if _storage == null:
		return
	_storage.ensure_directories()
	OS.shell_open(ProjectSettings.globalize_path(_storage.root))

func _on_add_card_pressed() -> void:
	_spawn_card_at_viewport_center()

func _spawn_card_at_viewport_center() -> void:
	if not card_scene:
		push_error("Card scene is not assigned!")
		return

	var card: GraphCard = card_scene.instantiate() as GraphCard
	canvas.add_child(card)

	var unique_id: String = UuidUtil.generate_v4()
	var note_title: String = tr("note.default_title") % _note_counter
	_note_counter += 1

	card.setup(unique_id, note_title, tr("note.default_body"), Preferences.default_note_color().to_html(false), "")
	var now: int = _now()
	card.apply_meta(GraphCard.STATUS_NONE, now, now)
	_cards_by_id[unique_id] = card
	_last_titles[unique_id] = note_title
	_last_contents[unique_id] = card.content_text
	_saved_colors[unique_id] = card.card_color
	_apply_filter_to(card, true)

	_connect_card_signals(card)

	var viewport_center: Vector2 = get_viewport_rect().size / 2.0
	var canvas_target_pos: Vector2 = navigator.screen_to_canvas(viewport_center) - (card.custom_minimum_size / 2.0)
	var jitter: Vector2 = Vector2(randf_range(-15.0, 15.0), randf_range(-15.0, 15.0))

	card.position = canvas_target_pos + jitter
	if _lod_compact:
		card.set_compact_font(_lod_font)
		card.set_compact(true, false)
	card.play_spawn_animation()
	_save_card(card)

	if _active_search_query != "":
		_search.on_search_text_changed(_active_search_query)

	var created_ids: Array[String] = [unique_id]
	var holder: Dictionary = {"ids": created_ids, "state": _undo.capture(created_ids)}
	_history.record(tr("history.note.create"), _undo.remove_with_holder.bind(holder), _undo.restore_with_holder.bind(holder))

func _delete_card_by_id(id: String) -> void:
	var card: GraphCard = _cards_by_id.get(id, null)
	if is_instance_valid(card):
		var single: Array[GraphCard] = [card]
		_delete_cards(single)

func _delete_cards(cards: Array[GraphCard], decor: Array[DecorNode] = [], history_label: String = "") -> void:
	var ids: Array[String] = []
	for card: GraphCard in cards:
		if is_instance_valid(card):
			ids.append(card.card_id)
	var decor_ids: Array[String] = []
	for node: DecorNode in decor:
		if is_instance_valid(node):
			decor_ids.append(node.decor_id)
	if ids.is_empty() and decor_ids.is_empty():
		return

	var holder: Dictionary = {"ids": ids, "state": _undo.capture(ids), "decor_ids": decor_ids, "decor_state": _undo.capture_decor(decor_ids)}
	_undo.remove_cards(ids)
	_undo.remove_decor(decor_ids)

	if history_label != "":
		_history.record(history_label, _undo.restore_with_holder.bind(holder), _undo.remove_with_holder.bind(holder))
	elif not decor_ids.is_empty():
		_history.record(tr("decor.history.delete") % (ids.size() + decor_ids.size()), _undo.restore_with_holder.bind(holder), _undo.remove_with_holder.bind(holder))
		_toast.show_message(PlatformKeys.localize(tr("decor.deleted")) % (ids.size() + decor_ids.size()))
	elif ids.size() == 1:
		_history.record(tr("history.note.delete"), _undo.restore_with_holder.bind(holder), _undo.remove_with_holder.bind(holder))
		_toast.show_message(PlatformKeys.localize(tr("note.deleted")))
	else:
		_history.record(tr("history.notes.delete") % ids.size(), _undo.restore_with_holder.bind(holder), _undo.remove_with_holder.bind(holder))
		_toast.show_message(PlatformKeys.localize(tr("notes.deleted")) % ids.size())

func _on_selection_changed() -> void:
	_decor.refresh_selection_visuals()
	var cards: Array[GraphCard] = _selection.get_cards()
	match cards.size():
		0:
			sidebar_editor.close_sidebar()
		1:
			sidebar_editor.open_card(cards[0])
		_:
			sidebar_editor.show_batch(cards)

func _on_sidebar_closed() -> void:
	_selection.clear_cards()

func _on_batch_color_chosen(color: Color) -> void:
	var before: Dictionary = {}
	var after: Dictionary = {}
	var overrides_before: Dictionary = {}
	var overrides_after: Dictionary = {}
	for card: GraphCard in _selection.get_cards():
		var previous: Color = _saved_colors.get(card.card_id, card.card_color)
		if not previous.is_equal_approx(color):
			before[card.card_id] = previous
			after[card.card_id] = color
			overrides_before[card.card_id] = card.color_overridden
			overrides_after[card.card_id] = true
			card.color_overridden = true
		card.set_category_color(color)
		card.play_capture_punch()
		_saved_colors[card.card_id] = color
		_touch_card(card)
	_undo.record_color_change(before, after, overrides_before, overrides_after)
	sidebar_editor.show_batch(_selection.get_cards())

func _on_batch_delete_requested() -> void:
	_delete_cards(_selection.get_cards())

func _on_batch_chip_focus_requested(card_id: String) -> void:
	var card: GraphCard = _cards_by_id.get(card_id, null)
	if not is_instance_valid(card):
		return
	var viewport_size: Vector2 = get_viewport_rect().size
	var screen_focus: Vector2 = Vector2((viewport_size.x - sidebar_editor.panel_width) / 2.0, viewport_size.y / 2.0)
	navigator.focus_to_point(card.position + (card.size / 2.0), navigator.get_zoom(), screen_focus)

func _on_batch_chip_remove_requested(card_id: String) -> void:
	var card: GraphCard = _cards_by_id.get(card_id, null)
	if is_instance_valid(card):
		_selection.remove(card)

func _connect_card_signals(card: GraphCard) -> void:
	card.carried_toggled.connect(_on_card_carried_toggled)
	card.card_clicked.connect(_on_card_clicked)
	card.title_changed.connect(_on_card_title_changed)
	card.drag_started.connect(_on_card_drag_started)
	card.drag_moved.connect(_on_card_drag_moved)
	card.drag_ended.connect(_on_card_drag_ended)
	card.flip_started.connect(_on_card_flip_started)
	card.flip_finished.connect(_on_card_flip_finished)
	card.status_changed.connect(_on_card_status_changed)
	card.backlink_pressed.connect(_on_backlink_pressed)
	card.cover_clicked.connect(_on_card_cover_clicked)

func _on_card_cover_clicked(card: GraphCard) -> void:
	if _cover_click_suppressed:
		_cover_click_suppressed = false
		return

	var texture: Texture2D = card.get_cover_texture()
	if texture == null:
		return
	_is_panning = false
	_lightbox.open(texture, card.get_cover_screen_rect())

func _on_sidebar_image_view_requested(path: String) -> void:
	var texture: Texture2D = InlineImages.texture_for(path)
	if texture == null:
		InlineImages.report_missing(path)
		return
	_lightbox.open(texture, Rect2(get_viewport().get_mouse_position(), Vector2.ONE))

func _on_card_flip_started(card: GraphCard, to_back: bool) -> void:
	if to_back:
		_refresh_back_face(card)

func _on_card_flip_finished(card: GraphCard) -> void:
	_save_card(card)

func _on_card_status_changed(card: GraphCard, _new_status: String) -> void:
	_touch_card(card)

func _on_backlink_pressed(target_id: String) -> void:
	var target: GraphCard = _cards_by_id.get(target_id, null)
	if not is_instance_valid(target):
		return
	_glide_to_card(target)
	target.flash_highlight()

func _on_card_drag_started(card: GraphCard) -> void:
	_group_drag_followers.clear()
	_group_drag_decor.clear()
	_drag_decor_before = {}
	_group_drag_start_pos = card.position
	_drag_leader = card
	_drag_before = {card.card_id: card.position}
	if _selection.item_count() > 1 and _selection.has(card):
		for member: GraphCard in _selection.get_cards():
			if member != card:
				_group_drag_followers.append(member)
				member.set_group_following(true)
				_drag_before[member.card_id] = member.position
		for node: DecorNode in _selection.get_decor():
			_group_drag_decor.append(node)
			_drag_decor_before[node.decor_id] = node.get_state()

func _on_card_drag_moved(_card: GraphCard, delta: Vector2, velocity_x: float) -> void:
	for follower: GraphCard in _group_drag_followers:
		if is_instance_valid(follower):
			follower.apply_carrier_shift(delta, velocity_x)
	for node: DecorNode in _group_drag_decor:
		if is_instance_valid(node):
			node.position += delta

func _on_card_drag_ended(card: GraphCard) -> void:
	_save_card(card)

	for follower: GraphCard in _group_drag_followers:
		if is_instance_valid(follower):
			follower.set_group_following(false)
			_save_card(follower)

	var was_group_drag: bool = not _group_drag_followers.is_empty() or not _group_drag_decor.is_empty()
	_group_drag_followers.clear()
	if not _group_drag_decor.is_empty():
		_decor.save()
	_group_drag_decor.clear()

	_undo.record_move(_drag_before, tr("history.move"), _drag_decor_before)
	_drag_before = {}
	_drag_decor_before = {}
	_drag_leader = null

	if was_group_drag and card.position.distance_to(_group_drag_start_pos) < GROUP_CLICK_TOLERANCE:
		_selection.select_only(card)

func _on_card_title_changed(card: GraphCard, new_title: String) -> void:
	if is_instance_valid(sidebar_editor):
		sidebar_editor.update_card_title_from_external(card, new_title)
	_touch_card(card)
	_apply_title_change(card.card_id, new_title)

func _on_sidebar_article_updated(card_id: String, new_title: String, new_content: String) -> void:
	var card: GraphCard = _cards_by_id.get(card_id, null)
	if not is_instance_valid(card):
		return

	var changed: bool = new_title != _last_titles.get(card_id, "") or new_content != _last_contents.get(card_id, "")
	_last_contents[card_id] = new_content
	if changed:
		card.modified_at = _now()
		if card.is_flipped:
			_refresh_back_face(card)
		card.refresh_compact_layout()
	_save_card(card, new_title, new_content)
	_apply_title_change(card_id, new_title)

func _apply_title_change(card_id: String, new_title: String) -> void:
	var old_title: String = _last_titles.get(card_id, "")
	_last_titles[card_id] = new_title
	if old_title != new_title:
		_refresh_flipped_back_faces()
	if old_title == "" or old_title == new_title:
		return

	for neighbor_id: String in _graph.get_neighbors(card_id):
		var neighbor: GraphCard = _cards_by_id.get(neighbor_id, null)
		if not is_instance_valid(neighbor):
			continue
		var text: String = neighbor.content_text
		var updated: String = WikiLink.replace_title(text, old_title, new_title)
		if updated == text:
			continue

		neighbor.set_content(updated)
		_last_contents[neighbor.card_id] = neighbor.content_text
		_touch_card(neighbor)
		sidebar_editor.refresh_content(neighbor)

func _on_sidebar_card_color_changed(card_id: String, _new_color: Color) -> void:
	var card: GraphCard = _cards_by_id.get(card_id, null)
	if not is_instance_valid(card):
		return

	var previous: Color = _saved_colors.get(card_id, card.card_color)
	var current: Color = card.card_color
	var changed: bool = not previous.is_equal_approx(current)
	var was_overridden: bool = card.color_overridden
	if changed:
		card.color_overridden = true
	_saved_colors[card_id] = current
	_touch_card(card)
	if changed:
		_undo.record_color_change({card_id: previous}, {card_id: current}, {card_id: was_overridden}, {card_id: true})
		sidebar_editor.refresh_type_section()

func _on_sidebar_card_fields_changed(card_id: String) -> void:
	var card: GraphCard = _cards_by_id.get(card_id, null)
	if is_instance_valid(card):
		_touch_card(card)

func _on_inline_image_missing(path: String) -> void:
	if _missing_image_paths.has(path):
		return
	if _missing_image_paths.is_empty():
		_announce_missing_images.call_deferred()
	_missing_image_paths.append(path)

func _announce_missing_images() -> void:
	var paths: PackedStringArray = _missing_image_paths
	_missing_image_paths = PackedStringArray()
	if paths.is_empty() or not is_instance_valid(_toast):
		return
	if paths.size() == 1:
		_toast.show_message(tr("image.missing_toast") % paths[0].get_file(), true)
	else:
		_toast.show_message(tr("image.missing_toast_many") % paths.size(), true)

func _on_sidebar_background_previewed(card_id: String, color: Color) -> void:
	var card: GraphCard = _cards_by_id.get(card_id, null)
	if not is_instance_valid(card):
		return
	card.bg_color_hex = color.to_html(false)
	_type_ops.apply_background(card)

func _on_sidebar_background_color_changed(card_id: String, color: Color) -> void:
	var card: GraphCard = _cards_by_id.get(card_id, null)
	if not is_instance_valid(card):
		return
	card.bg_color_hex = color.to_html(false)
	_type_ops.apply_background(card)
	_touch_card(card)
	sidebar_editor.refresh_background_section()

func _on_sidebar_background_color2_previewed(card_id: String, color: Color) -> void:
	var card: GraphCard = _cards_by_id.get(card_id, null)
	if not is_instance_valid(card):
		return
	card.bg_color2_hex = color.to_html(false)
	_type_ops.apply_background(card)

func _on_sidebar_background_color2_changed(card_id: String, color: Color) -> void:
	var card: GraphCard = _cards_by_id.get(card_id, null)
	if not is_instance_valid(card):
		return
	card.bg_color2_hex = color.to_html(false)
	_type_ops.apply_background(card)
	_touch_card(card)
	sidebar_editor.refresh_background_section()

func _on_sidebar_background_gradient_cleared(card_id: String) -> void:
	var card: GraphCard = _cards_by_id.get(card_id, null)
	if not is_instance_valid(card):
		return
	card.bg_color2_hex = ""
	_type_ops.apply_background(card)
	_touch_card(card)
	sidebar_editor.refresh_background_section()

func _on_sidebar_background_image_chosen(card_id: String, source_path: String) -> void:
	var card: GraphCard = _cards_by_id.get(card_id, null)
	if not is_instance_valid(card):
		return
	var vault_path: String = _storage.copy_image_to_vault(source_path)
	if vault_path == "":
		var reason: String = _storage.last_refusal
		_toast.show_message(reason if reason != "" else tr("image.insert.failed"), true)
		return
	card.bg_image_path = vault_path
	_type_ops.apply_background(card)
	_touch_card(card)
	sidebar_editor.refresh_background_section()

func _on_sidebar_background_cleared(card_id: String) -> void:
	var card: GraphCard = _cards_by_id.get(card_id, null)
	if not is_instance_valid(card):
		return
	card.bg_color_hex = ""
	card.bg_color2_hex = ""
	card.bg_image_path = ""
	_type_ops.apply_background(card)
	_touch_card(card)
	sidebar_editor.refresh_background_section()

func _on_sidebar_card_image_changed(card_id: String, source_image_path: String) -> void:
	var card: GraphCard = _cards_by_id.get(card_id, null)
	if not is_instance_valid(card):
		return
	var vault_image_path: String = _storage.copy_image_to_vault(source_image_path)
	if vault_image_path != "":
		card.set_cover_image(vault_image_path)
		_touch_card(card)
	else:
		var reason: String = _storage.last_refusal
		_toast.show_message(reason if reason != "" else tr("image.insert.failed"), true)

func _on_card_clicked(card: GraphCard, is_ctrl: bool) -> void:
	_cover_click_suppressed = is_instance_valid(_link_source_card)
	if is_instance_valid(_link_source_card):
		if _link_source_card == card:
			_cancel_link_source()
		else:
			_toggle_connection(_link_source_card.card_id, card.card_id)
			if not is_ctrl:
				_cancel_link_source()
	elif is_ctrl:
		_link_source_card = card
		_link_source_card.set_link_source(true)
	elif Input.is_key_pressed(KEY_SHIFT):
		_selection.toggle(card)
	else:
		var keeps_group: bool = _selection.has(card) and _selection.item_count() > 1
		if not keeps_group:
			_selection.select_only(card)

func _cancel_link_source() -> void:
	if is_instance_valid(_link_source_card):
		_link_source_card.set_link_source(false)
	_link_source_card = null
	connection_renderer.clear_preview_line()

func _toggle_connection(id_a: String, id_b: String) -> void:
	var existing: Dictionary = _graph.get_link(id_a, id_b)
	if existing.is_empty():
		if not _graph.toggle_connection(id_a, id_b):
			return
		var created: Array[Dictionary] = [_graph.get_link(id_a, id_b)]
		_history.record(tr("history.link.create"), _graph.remove_link.bind(id_a, id_b), _graph.restore_links.bind(created))
	else:
		_graph.remove_link(id_a, id_b)
		var removed: Array[Dictionary] = [existing]
		_history.record(tr("history.link.delete"), _graph.restore_links.bind(removed), _graph.remove_link.bind(id_a, id_b))


const LINK_MENU_STYLES: Array[String] = ["solid", "dashed", "dotted"]

func _link_at(screen_pos: Vector2) -> Dictionary:
	var canvas_pos: Vector2 = navigator.screen_to_canvas(screen_pos)
	var max_distance: float = LINE_PICK_RADIUS / maxf(navigator.get_zoom(), 0.001)
	var best: Dictionary = {}
	var best_distance: float = max_distance
	for conn: Dictionary in _graph.get_all_connections():
		var card_a: GraphCard = _cards_by_id.get(str(conn.get("from", "")), null)
		var card_b: GraphCard = _cards_by_id.get(str(conn.get("to", "")), null)
		if not is_instance_valid(card_a) or not is_instance_valid(card_b):
			continue
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(canvas_pos, card_a.get_card_center(), card_b.get_card_center())
		var distance: float = canvas_pos.distance_to(closest)
		if distance <= best_distance:
			best_distance = distance
			best = conn.duplicate()
	return best

func _pick_link(link: Dictionary, global_pos: Vector2) -> void:
	_picked_link = {"from": str(link["from"]), "to": str(link["to"])}
	connection_renderer.set_selected_link(str(link["from"]), str(link["to"]))
	if _link_menu == null:
		_link_menu = PopupList.new()
		$UI.add_child(_link_menu)
		_link_menu.item_chosen.connect(_on_link_menu_chosen)
	_link_menu.clear()
	_link_menu.add_item(tr("link.style.solid"), 0)
	_link_menu.add_item(tr("link.style.dashed"), 1)
	_link_menu.add_item(tr("link.style.dotted"), 2)
	_link_menu.open_at(global_pos, LINK_MENU_WIDTH)

func _unpick_link() -> void:
	if _picked_link.is_empty():
		return
	_picked_link = {}
	connection_renderer.set_selected_link("", "")

func _on_link_menu_chosen(id: int) -> void:
	if _picked_link.is_empty() or id < 0 or id >= LINK_MENU_STYLES.size():
		return
	var id_a: String = str(_picked_link["from"])
	var id_b: String = str(_picked_link["to"])
	var old_style: String = _graph.get_link_style(id_a, id_b)
	var new_style: String = LINK_MENU_STYLES[id]
	if old_style == "" or old_style == new_style:
		return
	if _graph.set_link_style(id_a, id_b, new_style):
		_history.record(tr("link.history.style"), _graph.set_link_style.bind(id_a, id_b, old_style), _graph.set_link_style.bind(id_a, id_b, new_style))

func _on_link_anchored(to_id: String) -> void:
	var target: GraphCard = _cards_by_id.get(to_id, null)
	if is_instance_valid(target):
		target.flash_highlight()

func _on_wiki_link_requested(source_id: String, target_id: String) -> void:
	var result: GraphNetwork.LinkResult = _graph.add_directed_link(source_id, target_id, GraphNetwork.KIND_WIKI)
	if result != GraphNetwork.LinkResult.CREATED:
		return
	var created: Array[Dictionary] = [_graph.get_link(source_id, target_id)]
	_history.record(tr("history.link.create"), _graph.remove_link.bind(source_id, target_id), _graph.restore_links.bind(created))

func _find_card_under_mouse(mouse_screen_pos: Vector2) -> GraphCard:
	for id: String in _cards_by_id:
		var card: GraphCard = _cards_by_id[id]
		if is_instance_valid(card) and card.contains_global_point(mouse_screen_pos):
			return card
	return null

func _on_card_carried_toggled(card: GraphCard) -> void:
	if _carried_cards.has(card):
		_carried_cards.erase(card)
		card.set_carried(false)
		if _carried_cards.is_empty():
			_finish_carry()
	else:
		_carried_cards.append(card)
		card.set_carried(true)
		if not _carry_before.has(card.card_id):
			_carry_before[card.card_id] = card.position

func _finish_carry() -> void:
	for card: GraphCard in _carried_cards:
		if is_instance_valid(card):
			_save_card(card)
	_undo.record_move(_carry_before, tr("history.carry"))
	_carry_before = {}
	_clear_carried_cards()

func _clear_carried_cards() -> void:
	for card: GraphCard in _carried_cards:
		if is_instance_valid(card):
			card.set_carried(false)
	_carried_cards.clear()


func _is_interaction_in_flight() -> bool:
	return _snapshot_busy \
		or _marquee_active \
		or _is_panning \
		or is_instance_valid(_drag_leader) \
		or not _decor_gesture.is_empty() \
		or not _carried_cards.is_empty() \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)

func _is_dialog_open() -> bool:
	return (is_instance_valid(_start_screen) and _start_screen.is_open()) or _is_dialog_over_start()

func _is_modal_over_start() -> bool:
	return confirm_modal.visible or _is_dialog_over_start()

func _is_dialog_over_start() -> bool:
	return (is_instance_valid(_note_picker) and _note_picker.is_open()) \
		or (is_instance_valid(_about_dialog) and _about_dialog.is_open()) \
		or (is_instance_valid(_type_conflict) and _type_conflict.is_open()) \
		or (is_instance_valid(_settings_dialog) and _settings_dialog.is_open()) \
		or (is_instance_valid(_canvas_bg_dialog) and _canvas_bg_dialog.is_open()) \
		or (is_instance_valid(_vault_dialog) and _vault_dialog.is_open()) \
		or (is_instance_valid(_world_prompt) and _world_prompt.is_open()) \
		or (is_instance_valid(_shortcuts_dialog) and _shortcuts_dialog.is_open()) \
		or (is_instance_valid(_palette) and _palette.is_open())

func _is_modal_open() -> bool:
	return confirm_modal.visible or _is_dialog_open()


func _on_confirm_accepted() -> void:
	var action: Callable = _pending_confirm
	_pending_confirm = Callable()
	if action.is_valid():
		action.call()

func _on_confirm_canceled() -> void:
	_pending_confirm = Callable()
