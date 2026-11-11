class_name ProjectFilesController
extends RefCounted

enum MenuItem { OPEN, SAVE, EXPORT, EXPORT_PNG, UNDO, REDO, TYPES, CLEAN_IMAGES, TRASH_RESTORE, TRASH_EMPTY, TRASH_MENU, SETTINGS, ADD_DECOR, OPEN_FOLDER, RECENT, NEW_NOTE, SEARCH, TYPE_FILTER, CANVAS_BACKGROUND, ABOUT, MAIN_MENU, QUIT, EXPORT_MENU, IMAGES_MENU, EXPORT_ALL, INSERT_IMAGE, COPY, PASTE, CUT, DUPLICATE, SELECT_ALL, TOGGLE_MODE, OPEN_PROJECT_MENU, SHORTCUTS, ADD_TEXT, OPEN_SELECTED }

const GROUP_MENU: String = "menu"
const GROUP_EXPORT: String = "export"
const GROUP_IMAGES: String = "images"
const GROUP_TRASH: String = "trash"
const GROUP_BAR: String = "bar"

const ACTION_EXPORT: int = 0
const ACTION_IMPORT: int = 1
const ACTION_NEW_WORLD: int = 2
const ACTION_RESTORE: int = 3

const ICON_MENU: Texture2D = preload("res://assets/icons/menu.svg")
const PROJECT_MENU_WIDTH: float = 280.0
const SETTINGS_FILES_SECTION: String = "files"
const SETTING_EXPORT_DIR: String = "export_dir"
const SETTING_PROJECT_DIR: String = "project_dir"
const SETTING_PROJECT_NAME: String = "project_name"
const DEFAULT_PROJECT_NAME: String = "Tethera_Project.tether"

var _ws: AppWorkspace = null

func _init(workspace: AppWorkspace) -> void:
	_ws = workspace


func build_project_menu() -> void:
	var button: Button = Button.new()
	button.text = "menu.project"
	button.icon = ICON_MENU
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 16)
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(110.0, 36.0)
	button.add_theme_font_size_override("font_size", 13)
	ThemeColors.bind_override(button, &"font_color", &"text.primary")
	_ws._project_menu = button
	_ws.get_node("UI/TopBar").add_child(button)
	_ws.get_node("UI/TopBar").move_child(button, 0)

	_ws._project_popup = PopupList.new()
	button.add_child(_ws._project_popup)
	_ws._project_popup.item_chosen.connect(run_command)
	button.pressed.connect(open_project_menu)
	fill_project_menu()

func open_project_menu() -> void:
	fill_project_menu()
	_ws._project_popup.open_below(_ws._project_menu.get_global_rect(), PROJECT_MENU_WIDTH)

func fill_project_menu() -> void:
	_fill_popup(_ws._project_popup, GROUP_MENU)

func _fill_popup(popup: PopupList, group: String) -> void:
	popup.clear()
	var all_entries: Array[Dictionary] = commands()
	for entry: Dictionary in all_entries:
		if str(entry["group"]) != group:
			continue
		if bool(entry["separator"]):
			popup.add_separator()
			continue
		var id: int = int(entry["id"])
		if str(entry["submenu"]) != "":
			var submenu: PopupList = popup.add_submenu(str(entry["text"]), id)
			for child: Dictionary in all_entries:
				if str(child["group"]) == str(entry["submenu"]) and not bool(child["separator"]):
					submenu.add_item(str(child["text"]), int(child["id"]), str(child["hint"]))
					submenu.set_item_disabled(int(child["id"]), str(child["reason"]) != "")
			continue
		popup.add_item(str(entry["text"]), id, str(entry["hint"]))
		popup.set_item_disabled(id, str(entry["reason"]) != "")


func commands() -> Array[Dictionary]:
	var undo_label: String = _ws._history.peek_undo_label()
	var redo_label: String = _ws._history.peek_redo_label()
	var undo_text: String = tr("menu.undo.labeled") % undo_label if undo_label != "" else tr("menu.undo")
	var redo_text: String = tr("menu.redo.labeled") % redo_label if redo_label != "" else tr("menu.redo")
	var insert_reason: String = "" if _ws.sidebar_editor.can_insert_image() else tr("command.reason.no_editor")
	var trash_reason: String = tr("trash.none") if _ws._storage != null and _ws._storage.trash_file_count() == 0 else ""
	var selection_reason: String = "" if _ws._selection.item_count() > 0 else tr("command.reason.no_selection")
	var open_reason: String = "" if _ws._selection.count() == 1 else tr("command.reason.no_selection")
	var list: Array[Dictionary] = [
		_command(MenuItem.MAIN_MENU, tr("menu.main_menu"), "Ctrl+M"),
		_separator(GROUP_MENU),
		_command(MenuItem.OPEN, tr("menu.open"), "Ctrl+O"),
		_command(MenuItem.SAVE, tr("menu.save"), "Ctrl+S"),
		_submenu(MenuItem.EXPORT_MENU, tr("menu.export_group"), GROUP_EXPORT),
		_separator(GROUP_MENU),
		_command(MenuItem.RECENT, tr("recent.button")),
		_command(MenuItem.OPEN_SELECTED, tr("command.open_selected_note"), "Enter", open_reason),
		_command(MenuItem.OPEN_FOLDER, tr("menu.open_folder")),
		_separator(GROUP_MENU),
		_command(MenuItem.EXPORT_PNG, tr("menu.export_png"), "Ctrl+Shift+S"),
		_command(MenuItem.ADD_DECOR, tr("menu.add_decor")),
		_command(MenuItem.ADD_TEXT, tr("menu.add_text")),
		_command(MenuItem.CANVAS_BACKGROUND, tr("menu.canvas_background")),
		_separator(GROUP_MENU),
		_command(MenuItem.TYPES, tr("menu.types")),
		_submenu(MenuItem.IMAGES_MENU, tr("menu.images_group"), GROUP_IMAGES),
		_submenu(MenuItem.TRASH_MENU, tr("menu.trash"), GROUP_TRASH),
		_command(MenuItem.SETTINGS, tr("menu.settings"), "Ctrl+,"),
		_command(MenuItem.ABOUT, tr("menu.about")),
		_separator(GROUP_MENU),
		_command(MenuItem.UNDO, undo_text, "Ctrl+Z", "" if _ws._history.can_undo() else tr("command.reason.no_undo")),
		_command(MenuItem.REDO, redo_text, "Ctrl+Y", "" if _ws._history.can_redo() else tr("command.reason.no_redo")),
		_separator(GROUP_MENU),
		_command(MenuItem.QUIT, tr("menu.quit")),
		_command(MenuItem.EXPORT, tr("menu.export"), "", "", GROUP_EXPORT),
		_command(MenuItem.EXPORT_ALL, tr("menu.export_all"), "", "", GROUP_EXPORT),
		_command(MenuItem.INSERT_IMAGE, tr("menu.insert_image"), "", insert_reason, GROUP_IMAGES),
		_command(MenuItem.CLEAN_IMAGES, tr("menu.clean_images"), "", "", GROUP_IMAGES),
		_command(MenuItem.TRASH_RESTORE, tr("menu.trash_restore"), "", trash_reason, GROUP_TRASH),
		_command(MenuItem.TRASH_EMPTY, tr("menu.trash_empty"), "", trash_reason, GROUP_TRASH),
		_command(MenuItem.NEW_NOTE, tr("command.new_note"), "Ctrl+N", "", GROUP_BAR),
		_command(MenuItem.COPY, tr("command.copy"), "Ctrl+C", selection_reason, GROUP_BAR),
		_command(MenuItem.CUT, tr("command.cut"), "Ctrl+X", selection_reason, GROUP_BAR),
		_command(MenuItem.PASTE, tr("command.paste"), "Ctrl+V", "" if not _ws._clipboard_ops.is_empty() else tr("command.reason.clipboard_empty"), GROUP_BAR),
		_command(MenuItem.DUPLICATE, tr("command.duplicate"), "Ctrl+D", selection_reason, GROUP_BAR),
		_command(MenuItem.SELECT_ALL, tr("command.select_all"), "Ctrl+A", "", GROUP_BAR),
		_command(MenuItem.TOGGLE_MODE, tr("command.toggle_mode"), "Ctrl+E", "" if _ws.sidebar_editor.can_toggle_mode() else tr("command.reason.no_editor"), GROUP_BAR),
		_command(MenuItem.OPEN_PROJECT_MENU, tr("command.open_project_menu"), "P", "", GROUP_BAR),
		_command(MenuItem.SHORTCUTS, tr("command.shortcuts"), "", "", GROUP_BAR),
		_command(MenuItem.SEARCH, tr("command.search"), "Ctrl+F", "", GROUP_BAR),
		_command(MenuItem.TYPE_FILTER, tr("command.type_filter"), "", "", GROUP_BAR),
	]
	return list

func _command(id: int, text: String, hint: String = "", reason: String = "", group: String = GROUP_MENU, menu_only: bool = false) -> Dictionary:
	return {"id": id, "text": PlatformKeys.localize(text), "hint": PlatformKeys.hint(hint), "reason": reason, "group": group, "menu_only": menu_only, "separator": false, "submenu": ""}

func _submenu(id: int, text: String, submenu_group: String) -> Dictionary:
	var row: Dictionary = _command(id, text, "", "", GROUP_MENU, true)
	row["submenu"] = submenu_group
	return row

func _separator(group: String) -> Dictionary:
	return {"id": -1, "text": "", "hint": "", "reason": "", "group": group, "menu_only": false, "separator": true, "submenu": ""}

func palette_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for entry: Dictionary in commands():
		if not bool(entry["separator"]) and not bool(entry["menu_only"]):
			entries.append(entry)
	return entries

func run_command(id: int) -> void:
	if _ws._snapshot_busy or _ws._zen_active or _ws._lightbox.is_open() or _ws._eyedropper.is_active() or _ws._is_modal_open():
		return
	match id:
		MenuItem.OPEN:
			open_project_dialog()
		MenuItem.SAVE:
			save_project()
		MenuItem.EXPORT:
			open_export_dialog()
		MenuItem.EXPORT_ALL:
			open_export_dialog(true)
		MenuItem.INSERT_IMAGE:
			_ws.sidebar_editor.request_insert_image()
		MenuItem.EXPORT_PNG:
			export_snapshot()
		MenuItem.ADD_DECOR:
			_ws._decor.request_add()
		MenuItem.ADD_TEXT:
			_ws._decor.request_add_text()
		MenuItem.CANVAS_BACKGROUND:
			_ws._canvas_bg.open_dialog()
		MenuItem.OPEN_FOLDER:
			_ws.open_vault_folder()
		MenuItem.RECENT:
			_ws.open_recent.call_deferred()
		MenuItem.UNDO:
			_ws._undo.run_history_command(false)
		MenuItem.REDO:
			_ws._undo.run_history_command(true)
		MenuItem.TYPES:
			_ws._type_ops.open_manager()
		MenuItem.SETTINGS:
			_ws.open_settings()
		MenuItem.MAIN_MENU:
			_ws._world_flow.go_to_main_menu.call_deferred()
		MenuItem.QUIT:
			_ws.request_quit.call_deferred()
		MenuItem.ABOUT:
			_ws.open_about.call_deferred()
		MenuItem.CLEAN_IMAGES:
			clean_unused_images()
		MenuItem.TRASH_RESTORE:
			open_trash_restore()
		MenuItem.TRASH_EMPTY:
			empty_trash_command()
		MenuItem.NEW_NOTE:
			_ws._on_add_card_pressed()
		MenuItem.COPY:
			_ws._clipboard_ops.copy()
		MenuItem.CUT:
			_ws._clipboard_ops.cut()
		MenuItem.PASTE:
			_ws._clipboard_ops.paste()
		MenuItem.DUPLICATE:
			_ws._clipboard_ops.duplicate()
		MenuItem.SELECT_ALL:
			_ws._clipboard_ops.select_all()
		MenuItem.OPEN_SELECTED:
			_ws.open_selected_note()
		MenuItem.TOGGLE_MODE:
			_ws.sidebar_editor.toggle_mode()
		MenuItem.OPEN_PROJECT_MENU:
			open_project_menu()
		MenuItem.SHORTCUTS:
			_ws._shortcuts_dialog.open_shortcuts()
		MenuItem.SEARCH:
			_ws.focus_search()
		MenuItem.TYPE_FILTER:
			_ws._filter_panel.open()


func empty_trash_command() -> void:
	var count: int = _ws._storage.trash_file_count()
	if count == 0:
		_ws._toast.show_message(tr("trash.none"))
		return
	_ws._pending_confirm = _empty_trash
	_ws.confirm_modal.prompt(tr("trash.empty.title"), tr("trash.empty.message") % count, tr("trash.empty.confirm"))

func _empty_trash() -> void:
	_ws._toast.show_message(tr("trash.empty.done") % _ws._storage.empty_trash())

func open_trash_restore() -> void:
	var trashed: Array[Dictionary] = _ws._storage.list_trashed_notes()
	if trashed.is_empty():
		_ws._toast.show_message(tr("trash.none"))
		return
	var rows: Array[Dictionary] = []
	for note: Dictionary in trashed:
		var day: String = Time.get_date_string_from_unix_time(int(note["deleted_at"]))
		rows.append({"id": str(note["trash_file"]), "title": "%s (%s)" % [str(note["title"]), day], "type": ""})
	var no_links: Array[Dictionary] = []
	var no_types: Array[Dictionary] = []
	var none_ticked: Array[String] = []
	var actions: Array[Dictionary] = [{"id": ACTION_RESTORE, "text": tr("trash.restore.action"), "primary": true}]
	_ws._note_picker.open_for(tr("trash.restore.title"), rows, no_links, no_types, none_ticked, {}, actions, \
		_on_restore_choice.bind(trashed), false)

func _on_restore_choice(_action_id: int, trash_files: Array[String], _include_linked: bool, trashed: Array[Dictionary]) -> void:
	var created_ids: Array[String] = []
	var restored: Array[Dictionary] = []
	for note: Dictionary in trashed:
		if not trash_files.has(str(note["trash_file"])):
			continue
		var note_id: String = str(note["id"])
		if _ws._cards_by_id.has(note_id) or FileAccess.file_exists(_ws._storage.notes_dir + note_id + ".md"):
			note_id = UuidUtil.generate_v4()
		if not _ws._storage.restore_trashed_note(str(note["trash_file"]), note_id, note):
			continue
		var entry: Dictionary = note.duplicate()
		entry["id"] = note_id
		entry.erase("trash_file")
		entry.erase("deleted_at")
		var card: GraphCard = _ws._instantiate_card(entry)
		card.play_spawn_animation()
		_ws._save_card(card)
		_ws._note_counter += 1
		created_ids.append(note_id)
		restored.append(entry)
	if created_ids.is_empty():
		_ws._toast.show_message(tr("trash.restore.failed"), true)
		return

	_ws._pin_positions(restored)
	if _ws._active_search_query != "":
		_ws._search.on_search_text_changed(_ws._active_search_query)
	var holder: Dictionary = {"ids": created_ids, "state": _ws._undo.capture(created_ids)}
	_ws._history.record(tr("trash.restore.history") % created_ids.size(), \
		_ws._undo.remove_with_holder.bind(holder), _ws._undo.restore_with_holder.bind(holder))
	_ws._toast.show_message(tr("trash.restore.done") % created_ids.size())


func clean_unused_images() -> void:
	_ws.sidebar_editor.flush_pending_save()

	var used: Dictionary = used_image_names()
	var unused: PackedStringArray = PackedStringArray()
	for file_name: String in _ws._storage.list_images():
		if not used.has(file_name.to_lower()):
			unused.append(file_name)

	if unused.is_empty():
		_ws._toast.show_message(tr("images.clean.none"))
		return
	_ws._pending_confirm = _delete_unused_images.bind(unused)
	_ws.confirm_modal.prompt(tr("images.clean.title"), tr("images.clean.message") % unused.size(), tr("images.clean.confirm"))

func used_image_names() -> Dictionary:
	var used: Dictionary = _ws._storage.backup_image_refs()
	for card: GraphCard in _ws._cards_by_id.values():
		if not is_instance_valid(card):
			continue
		for picture: String in NoteImages.used_paths({"image": card.image_path, "bg_image": card.bg_image_path, "content": card.content_text}):
			used[picture.get_file().to_lower()] = true
	for type_picture: String in NoteImages.type_paths(_ws._types.to_array()):
		used[type_picture.get_file().to_lower()] = true
	for node: DecorNode in _ws._decor.all_nodes():
		if node.image_path != "":
			used[node.image_path.get_file().to_lower()] = true
	if _ws._canvas_background.is_set():
		used[_ws._canvas_background.image.get_file().to_lower()] = true
	return used

func _delete_unused_images(file_names: PackedStringArray) -> void:
	var deleted: int = 0
	for file_name: String in file_names:
		if _ws._storage.delete_image(file_name):
			InlineImages.forget(VaultStorage.IMAGE_REF_PREFIX + file_name)
			deleted += 1
	_ws._toast.show_message(tr("images.clean.done") % deleted)


func export_snapshot() -> void:
	if _ws._snapshot_busy or _ws._snapshot_saving or _ws._file_dialog_open or _ws._is_modal_open():
		return
	if _ws._marquee_active or _ws._is_panning or is_instance_valid(_ws._drag_leader) or not _ws._decor_gesture.is_empty():
		return
	if _ws._cards_by_id.is_empty() and _ws._decor_by_id.is_empty():
		_ws._toast.show_message(tr("export.empty"), true)
		return

	var stamp: String = Time.get_datetime_string_from_system().replace("T", "_").replace(":", "-")
	var default_dir: String = str(AppSettings.get_value(SETTINGS_FILES_SECTION, SETTING_EXPORT_DIR, ""))
	if default_dir == "" or not DirAccess.dir_exists_absolute(default_dir):
		default_dir = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)

	_ws._file_dialog_open = true
	SystemFileDialog.open(
		tr("snapshot.dialog.title"),
		default_dir,
		"Tethera_Snapshot_%s.png" % stamp,
		false,
		DisplayServer.FILE_DIALOG_MODE_SAVE_FILE,
		["*.png;" + tr("filedialog.filter.png")],
		_on_snapshot_dialog_result
	)

func _on_snapshot_dialog_result(status: bool, selected_paths: PackedStringArray, _filter_index: int) -> void:
	_ws._file_dialog_open = false
	if not status or selected_paths.is_empty():
		return
	var path: String = selected_paths[0]
	if path.get_extension().to_lower() != "png":
		path += ".png"
	run_snapshot(path)

func run_snapshot(path: String) -> void:
	_ws._pictures.finish_now()
	_ws._snapshot_busy = true
	_ws._cancel_link_source()
	_ws._finish_carry()
	_ws._is_panning = false
	_ws.navigator.stop_animation()
	_ws._shutter_flash.begin()

	var cards: Array[GraphCard] = []
	for card: GraphCard in _ws._cards_by_id.values():
		if is_instance_valid(card):
			cards.append(card)

	var selected: Array[GraphCard] = _ws._selection.get_cards()
	for card: GraphCard in selected:
		card.set_selected(false)
	var selected_decor: Array[DecorNode] = _ws._selection.get_decor()
	for node: DecorNode in selected_decor:
		node.set_selected(false)
		node.set_handles_visible(false)
	for card: GraphCard in cards:
		card.set_search_alpha(1.0, true)
		card.set_filter_alpha(1.0, true)

	var was_compact: bool = _ws._lod_compact
	if was_compact:
		for card: GraphCard in cards:
			card.set_compact(false, false)
	await _ws.get_tree().process_frame
	await _ws.get_tree().process_frame

	var region: Rect2 = _ws._items_bounds(cards, _ws._decor.all_nodes()).grow(SnapshotExporter.PADDING)
	var px_per_unit: float = SnapshotExporter.fit_scale(region.size)
	_ws.connection_renderer.zoom_override = px_per_unit
	_ws.connection_renderer.queue_redraw()

	var image: Image = await _ws._snapshot_exporter.capture(_ws.canvas, region, px_per_unit, _ws.background.material)

	_ws.connection_renderer.zoom_override = 0.0
	_ws.connection_renderer.queue_redraw()
	if was_compact:
		for card: GraphCard in cards:
			if is_instance_valid(card):
				card.set_compact(true, false)
	for card: GraphCard in selected:
		if is_instance_valid(card):
			card.set_selected(true)
	for node: DecorNode in selected_decor:
		if is_instance_valid(node):
			node.set_selected(true)
	_ws._decor.refresh_selection_visuals()
	_ws._search.on_search_text_changed(_ws._active_search_query)
	_ws._apply_type_filter()
	_ws._shutter_flash.end()
	_ws._snapshot_busy = false

	if image == null or image.is_empty():
		_ws._toast.show_message(tr("snapshot.failed.create"), true)
		return

	_ws._snapshot_saving = true
	var outcome: Dictionary = {"error": ERR_BUSY}
	var task_id: int = WorkerThreadPool.add_task(func() -> void: outcome["error"] = image.save_png(path))
	while not WorkerThreadPool.is_task_completed(task_id):
		await _ws.get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task_id)
	_ws._snapshot_saving = false

	if int(outcome["error"]) != OK:
		_ws._toast.show_message(tr("snapshot.failed.save") % path.get_file(), true)
		return

	AppSettings.set_value(SETTINGS_FILES_SECTION, SETTING_EXPORT_DIR, path.get_base_dir())
	_ws._toast.show_message(tr("snapshot.saved") % path.get_file())


func _project_dialog_dir() -> String:
	var directory: String = str(AppSettings.get_value(SETTINGS_FILES_SECTION, SETTING_PROJECT_DIR, ""))
	if directory == "" or not DirAccess.dir_exists_absolute(directory):
		directory = OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	return directory

func open_project_dialog(from_start: bool = false) -> void:
	if _ws._snapshot_busy or _ws._file_dialog_open or (_ws._is_modal_open() and not (from_start and not _ws._is_modal_over_start())):
		return
	_ws._file_dialog_open = true
	SystemFileDialog.open(
		tr("open.dialog.title"),
		_project_dialog_dir(),
		"",
		false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
		["*.tether;" + tr("filedialog.filter.project")],
		_on_open_dialog_result
	)

func _on_open_dialog_result(status: bool, selected_paths: PackedStringArray, _filter_index: int) -> void:
	_ws._file_dialog_open = false
	if status and not selected_paths.is_empty():
		_begin_open_project(selected_paths[0])

func on_files_dropped(files: PackedStringArray) -> void:
	if files.is_empty() or _ws._snapshot_busy or _ws._is_modal_open() or _ws._zen_active or _ws._lightbox.is_open() or _ws._eyedropper.is_active():
		return
	for path: String in files:
		if path.get_extension().to_lower() == ProjectBundle.EXTENSION:
			_begin_open_project(path)
			return
	_ws._toast.show_message(tr("open.drop_hint"), true)

func save_project() -> void:
	if _ws._snapshot_busy or _ws._file_dialog_open or _ws._is_modal_open():
		return
	if _ws.flush_world():
		_ws._toast.show_message(tr("save.world_done"))
	else:
		_ws._toast.show_message(tr("save.world_failed"), true)

func open_export_dialog(all_notes: bool = false) -> void:
	if _ws._snapshot_busy or _ws._file_dialog_open or _ws._is_modal_open():
		return
	if _ws._cards_by_id.is_empty():
		_ws._toast.show_message(tr("export.empty"), true)
		return

	_ws.sidebar_editor.flush_pending_save()
	var notes: Array[Dictionary] = _snapshot_notes()
	var preselected: Array[String] = []
	if not all_notes:
		for card: GraphCard in _ws._selection.get_cards():
			preselected.append(card.card_id)
	if preselected.is_empty():
		for note: Dictionary in notes:
			preselected.append(str(note["id"]))

	var actions: Array[Dictionary] = [{"id": ACTION_EXPORT, "text": tr("export.dialog.action"), "primary": true}]
	_ws._note_picker.open_for(tr("export.dialog.title"), notes, _ws._graph.get_all_connections(), _ws._types.to_array(), \
		preselected, {}, actions, _on_export_choice, true, Preferences.export_include_linked())

func _on_export_choice(_action_id: int, ids: Array[String], include_linked: bool) -> void:
	var name_hint: String = _ws._project_path.get_file() if _ws._project_path != "" \
		else str(AppSettings.get_value(SETTINGS_FILES_SECTION, SETTING_PROJECT_NAME, DEFAULT_PROJECT_NAME))
	var directory: String = _ws._project_path.get_base_dir() if _ws._project_path != "" else _project_dialog_dir()

	_ws._file_dialog_open = true
	SystemFileDialog.open(
		tr("save.dialog.title"),
		directory,
		name_hint,
		false,
		DisplayServer.FILE_DIALOG_MODE_SAVE_FILE,
		["*.tether;" + tr("filedialog.filter.project")],
		_on_export_file_result.bind(ids, include_linked)
	)

func _on_export_file_result(status: bool, selected_paths: PackedStringArray, _filter_index: int, ids: Array[String], include_linked: bool) -> void:
	_ws._file_dialog_open = false
	if not status or selected_paths.is_empty():
		return
	var path: String = selected_paths[0]
	if path.get_extension().to_lower() != ProjectBundle.EXTENSION:
		path += "." + ProjectBundle.EXTENSION
	write_selection(path, ids, include_linked)

func write_selection(path: String, ids: Array[String], include_linked: bool) -> void:
	_ws.sidebar_editor.flush_pending_save()
	var notes: Array[Dictionary] = _snapshot_notes()
	var links: Array[Dictionary] = _ws._graph.get_all_connections()
	var selection: Dictionary = ProjectSelection.select(notes, links, _ws._types.to_array(), ids, include_linked)
	var chosen: Array[Dictionary] = selection["notes"]
	if chosen.is_empty():
		_ws._toast.show_message(tr("export.none_selected"), true)
		return
	if chosen.size() == notes.size():
		write_project(path)
		return

	var chosen_links: Array[Dictionary] = selection["connections"]
	var chosen_types: Array[Dictionary] = selection["types"]
	var no_decor: Array[Dictionary] = []
	var result: Dictionary = ProjectBundle.write(path, chosen, chosen_links, chosen_types, _ws._now(), no_decor, null, _ws._world_flow.current_name())
	if not bool(result["ok"]):
		_ws._toast.show_message(str(result["message"]), true)
		return

	AppSettings.set_value(SETTINGS_FILES_SECTION, SETTING_PROJECT_DIR, path.get_base_dir())
	var missing: int = int(result["missing_images"]) + int(result["missing_inline"])
	if missing > 0:
		_ws._toast.show_message(tr("export.done_missing") % [path.get_file(), chosen.size(), missing], true)
	else:
		_ws._toast.show_message(tr("export.done") % [path.get_file(), chosen.size()])

func _snapshot_notes() -> Array[Dictionary]:
	var notes: Array[Dictionary] = []
	for card: GraphCard in _ws._cards_by_id.values():
		if is_instance_valid(card):
			notes.append(_ws._snapshot_card(card))
	return notes

func write_project(path: String) -> void:
	_ws.sidebar_editor.flush_pending_save()

	var notes: Array[Dictionary] = []
	for card: GraphCard in _ws._cards_by_id.values():
		if is_instance_valid(card):
			notes.append(_ws._snapshot_card(card))

	var created: int = _ws._project_created if _ws._project_created > 0 else _ws._now()
	var result: Dictionary = ProjectBundle.write(path, notes, _ws._graph.get_all_connections(), _ws._types.to_array(), created, _ws._decor.snapshot_all(), _ws._canvas_bg.snapshot(), _ws._world_flow.current_name(), _ws._decor.snapshot_extras())
	if not bool(result["ok"]):
		_ws._toast.show_message(str(result["message"]), true)
		return

	_ws._project_path = path
	_ws._project_created = created
	AppSettings.set_value(SETTINGS_FILES_SECTION, SETTING_PROJECT_DIR, path.get_base_dir())
	AppSettings.set_value(SETTINGS_FILES_SECTION, SETTING_PROJECT_NAME, path.get_file())

	var missing: int = int(result["missing_images"]) + int(result["missing_inline"])
	if missing > 0:
		_ws._toast.show_message(tr("save.done_missing") % [path.get_file(), missing], true)
	else:
		_ws._toast.show_message(tr("save.done") % path.get_file())

func _begin_open_project(path: String) -> void:
	var bundle: Dictionary = ProjectBundle.read(path)
	if not bool(bundle["ok"]):
		_ws._toast.show_message(str(bundle["message"]), true)
		return

	var notes: Array[Dictionary] = bundle["notes"]
	var preselected: Array[String] = []
	for note: Dictionary in notes:
		preselected.append(str(note["id"]))

	var existing_titles: Dictionary = {}
	for card: GraphCard in _ws._cards_by_id.values():
		if is_instance_valid(card):
			existing_titles[card.title_label.text.strip_edges().to_lower()] = true

	var actions: Array[Dictionary] = [
		{"id": ACTION_NEW_WORLD, "text": tr("import.dialog.action.new_world"), "primary": false},
		{"id": ACTION_IMPORT, "text": tr("import.dialog.action.import"), "primary": true},
	]
	if _ws._storage == null:
		actions = [{"id": ACTION_NEW_WORLD, "text": tr("import.dialog.action.new_world"), "primary": true}]
	_ws._note_picker.open_for(tr("import.dialog.title") % path.get_file(), notes, bundle["connections"] as Array[Dictionary], \
		bundle["types"] as Array[Dictionary], preselected, existing_titles, actions, _on_import_choice.bind(bundle, path))

func _on_import_choice(action_id: int, ids: Array[String], include_linked: bool, bundle: Dictionary, path: String) -> void:
	match action_id:
		ACTION_IMPORT:
			_ws._import.import_selection(bundle, ids, include_linked, path)
		ACTION_NEW_WORLD:
			_ws._world_flow.import_into_new_world.call_deferred(bundle, ids, include_linked, path)

func fill_new_world(bundle: Dictionary, path: String, remember_file: bool = true) -> void:
	_ws._end_interactions()
	var write_failed: bool = false
	var assets: Dictionary = bundle["assets"]
	var vault_images: Dictionary = {}
	var project_types: Array[Dictionary] = []
	for type_data: Dictionary in (bundle["types"] as Array[Dictionary]):
		var type_entry: Dictionary = type_data.duplicate()
		type_entry["bg_image"] = NoteImages.localize_asset(str(type_data.get("bg_image", "")), assets, _ws._storage, vault_images)
		project_types.append(type_entry)
	if not project_types.is_empty():
		_ws._types.load_array(project_types)
		write_failed = not _ws._storage.save_types(_ws._types.to_array())

	var inline_stored: Dictionary = {}
	var notes: Array[Dictionary] = bundle["notes"]
	var imported: Array[Dictionary] = []
	var imported_ids: Dictionary = {}
	_ws._note_counter = 1
	for note: Dictionary in notes:
		if write_failed:
			break
		var entry: Dictionary = note.duplicate()
		var asset_name: String = str(note.get("image", ""))
		entry["image"] = ""
		if asset_name != "" and assets.has(asset_name):
			if not vault_images.has(asset_name):
				vault_images[asset_name] = _ws._storage.store_image_bytes(asset_name, assets[asset_name] as PackedByteArray)
			entry["image"] = str(vault_images[asset_name])
		entry["bg_image"] = NoteImages.localize_asset(str(note.get("bg_image", "")), assets, _ws._storage, vault_images)
		entry["content"] = NoteImages.localize_inline(str(note.get("content", "")), assets, _ws._storage, inline_stored)
		var card: GraphCard = _ws._instantiate_card(entry)
		if not _ws._save_card(card):
			_ws._cards_by_id.erase(card.card_id)
			card.queue_free()
			write_failed = true
			break
		imported.append(entry)
		imported_ids[str(entry["id"])] = true
		_ws._note_counter += 1

	var links: Array[Dictionary] = []
	for conn: Dictionary in (bundle["connections"] as Array[Dictionary]):
		if imported_ids.has(str(conn.get("from", ""))) and imported_ids.has(str(conn.get("to", ""))):
			links.append(conn)
	_ws._graph.load_from_data(links)
	write_failed = not _ws._storage.save_connections(_ws._graph.get_all_connections()) or write_failed
	_ws._pin_positions(imported)
	_ws._links.scan_world()

	var lost_decor: int = int(bundle["skipped_decor"])
	var lost_background: bool = bool(bundle["lost_canvas_background"])
	if not write_failed:
		for decor_data: Dictionary in (bundle["decor"] as Array[Dictionary]):
			var decor_item: DecorItem = DecorItem.from_dict(decor_data)
			if decor_item == null:
				lost_decor += 1
				continue
			decor_item.image = NoteImages.localize_asset(decor_item.image, assets, _ws._storage, vault_images)
			if decor_item.image == "" or _ws._decor.create_node(decor_item) == null:
				lost_decor += 1
		for extra: Dictionary in (bundle["extras"] as Array[Dictionary]):
			if _ws._decor.is_full():
				lost_decor += 1
			elif str(extra.get("kind", "")) == DecorItem.KIND_TEXT:
				var text_item: DecorItem = DecorItem.from_dict(extra)
				if text_item == null or _ws._decor.create_node(text_item) == null:
					lost_decor += 1
			else:
				_ws._extras_kept.append(extra)
		write_failed = not _ws._decor.save()

		var project_background: CanvasBackground = CanvasBackground.from_dict(bundle["canvas_background"])
		if project_background.is_set():
			project_background.image = NoteImages.localize_asset(project_background.image, assets, _ws._storage, vault_images)
			lost_background = lost_background or not project_background.is_set()
			_ws._canvas_bg.replace(project_background)

	_ws._history.clear()
	if remember_file:
		_ws._project_path = path
		_ws._project_created = int(bundle["created"])
		AppSettings.set_value(SETTINGS_FILES_SECTION, SETTING_PROJECT_DIR, path.get_base_dir())
		AppSettings.set_value(SETTINGS_FILES_SECTION, SETTING_PROJECT_NAME, path.get_file())
	if _ws._active_search_query != "":
		_ws._search.on_search_text_changed(_ws._active_search_query)
	_ws._focus_camera_to_selection_or_bounds()

	var problems: PackedStringArray = PackedStringArray()
	if int(bundle["skipped_notes"]) > 0:
		problems.append(tr("import.problem.skipped") % int(bundle["skipped_notes"]))
	if int(bundle["dropped_images"]) > 0:
		problems.append(tr("import.problem.images") % int(bundle["dropped_images"]))
	var refused: Dictionary = bundle["refused_assets"]
	var lost_inline: int = NoteImages.failed_count(inline_stored, refused)
	if lost_inline > 0:
		problems.append(tr("import.problem.inline_images") % lost_inline)
	if not refused.is_empty():
		problems.append(tr("import.problem.refused_images") % refused.size())
	if lost_decor > 0:
		problems.append(tr("import.problem.decor") % lost_decor)
	if lost_background:
		problems.append(tr("import.problem.canvas_bg"))

	if write_failed:
		_ws._toast.show_message(tr("import.failed_partial") % imported.size(), true, AppWorkspace.VAULT_WARNING_HOLD)
		return
	if not remember_file and problems.is_empty():
		return
	var message: String = tr("open.done") % [path.get_file(), imported.size()]
	if problems.is_empty():
		_ws._toast.show_message(message)
	else:
		_ws._toast.show_message("%s — %s" % [message, ", ".join(problems)], true)
