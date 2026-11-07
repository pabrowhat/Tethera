class_name WorkspaceWorlds
extends RefCounted

const EXAMPLE_PATH_RU: String = "res://examples/example_ru.tether"
const EXAMPLE_PATH_EN: String = "res://examples/example_en.tether"

var _ws: AppWorkspace = null

func _init(workspace: AppWorkspace) -> void:
	_ws = workspace

func start() -> void:
	_ws._vault_dialog.folder_chosen.connect(_on_folder_chosen)
	_ws._vault_dialog.create_requested.connect(_on_create_requested)
	_ws._start_screen.open_requested.connect(_on_start_open)
	_ws._start_screen.create_requested.connect(_on_start_create)
	_ws._start_screen.rename_requested.connect(_on_start_rename)
	_ws._start_screen.delete_requested.connect(_on_start_delete)
	_ws._start_screen.import_requested.connect(_ws._project_files.open_project_dialog.bind(true))
	_ws._start_screen.settings_requested.connect(_ws._settings_dialog.open_with_current)
	_ws._start_screen.about_requested.connect(_ws._about_dialog.open_tab.bind(AboutDialog.Tab.ABOUT))
	_ws._start_screen.quit_requested.connect(_ws.request_quit)
	_ws._whats_new_pending = AppVersion.notes_pending()
	match _ws._worlds.vault_state():
		WorldRegistry.VaultState.NOT_SET:
			_ws._vault_dialog.open_first_launch()
		WorldRegistry.VaultState.MISSING:
			_ws._vault_dialog.open_missing(WorldRegistry.saved_vault_dir())
		WorldRegistry.VaultState.READY:
			var problem: String = _prepare_vault()
			if problem != "":
				_ws._vault_dialog.open_missing(WorldRegistry.saved_vault_dir())
				_ws._vault_dialog.show_error(problem)
			else:
				show_start_screen()

func _on_folder_chosen(path: String) -> void:
	var checked: Dictionary = WorldRegistry.check_vault_dir(path)
	if not bool(checked["ok"]):
		_ws._vault_dialog.show_error(tr(str(checked["reason"])))
		return
	var first_launch: bool = _ws._worlds.vault_state() == WorldRegistry.VaultState.NOT_SET
	_ws._worlds.select_vault_dir(str(checked["path"]))
	var problem: String = _prepare_vault(first_launch)
	if problem != "":
		_ws._vault_dialog.show_error(problem)
		return
	_ws._vault_dialog.close()
	show_start_screen()

func _on_create_requested() -> void:
	var reason: String = _ws._worlds.create_saved_vault_dir()
	if reason != "":
		_ws._vault_dialog.show_error(tr(reason))
		return
	var problem: String = _prepare_vault()
	if problem != "":
		_ws._vault_dialog.show_error(problem)
		return
	_ws._vault_dialog.close()
	show_start_screen()

func _prepare_vault(copy_old_data: bool = false) -> String:
	_ws._worlds.purge_world_trash(_ws._now())
	var worlds: Array[Dictionary] = _ws._worlds.list_worlds()
	for world: Dictionary in worlds:
		if not bool(world["ok"]):
			push_warning("World folder skipped, its %s is missing or damaged: %s" % [WorldRegistry.WORLD_FILE, _ws._worlds.vault_dir + str(world["id"])])
	if worlds.is_empty():
		var problem: String = _make_first_world(copy_old_data)
		if problem != "":
			return problem
	_ws._worlds.remember_vault_dir()
	return ""

func _make_first_world(copy_old_data: bool) -> String:
	if not (copy_old_data and LegacyVaultCopy.has_data()):
		return _make_example_world()
	var made: Dictionary = _ws._worlds.create_world(tr("worlds.default_name"), false)
	if not bool(made["ok"]):
		return tr(str(made["reason"]))
	var copy: Dictionary = LegacyVaultCopy.copy_into(str(made["root"]))
	if not bool(copy["ok"]):
		_ws._worlds.remove_unfinished_world(str(made["id"]))
		return tr(str(copy["reason"])) % str(copy["file"])
	return ""


func _make_example_world() -> String:
	var path: String = EXAMPLE_PATH_RU if TranslationServer.get_locale().begins_with("ru") else EXAMPLE_PATH_EN
	if not FileAccess.file_exists(path):
		return _make_empty_world()
	var bundle: Dictionary = ProjectBundle.read(path)
	if not bool(bundle["ok"]):
		push_warning("The example world could not be read: " + str(bundle["message"]))
		var problem: String = _make_empty_world()
		if problem == "":
			_ws._toast.show_message(tr("start.example_failed"), true, AppWorkspace.VAULT_WARNING_HOLD)
		return problem
	var made: Dictionary = _ws._worlds.create_world(tr("worlds.example_name"))
	if not bool(made["ok"]):
		return tr(str(made["reason"]))
	_open_world(str(made["id"]), 0)
	_ws._project_files.fill_new_world(bundle, path, false)
	if not _leave_world():
		push_warning("The example world could not be written completely.")
	return ""

func _make_empty_world() -> String:
	var made: Dictionary = _ws._worlds.create_world(tr("worlds.default_name"))
	return "" if bool(made["ok"]) else tr(str(made["reason"]))


func show_start_screen() -> void:
	_ws._start_screen.show_worlds(_ws._worlds.list_worlds(true), _ws._worlds.last_world_id())

func _on_start_open(world_id: String) -> void:
	var problem: String = switch_to(world_id)
	if problem != "":
		_ws._start_screen.show_error(problem)
		return
	_finish_start_screen(true)

func _on_start_create() -> void:
	_ws._world_prompt.prompt_name(tr("worlds.name.title_create"), "", _on_start_create_named, _ws._worlds.is_name_taken)

func _on_start_create_named(world_name: String) -> void:
	var made: Dictionary = _ws._worlds.create_world(world_name)
	if not bool(made["ok"]):
		_ws._world_prompt.show_error(tr(str(made["reason"])))
		return
	var problem: String = switch_to(str(made["id"]))
	if problem != "":
		_ws._world_prompt.close()
		show_start_screen()
		_ws._start_screen.show_error(problem)
		return
	_ws._world_prompt.close()
	_finish_start_screen(true)

func _finish_start_screen(with_toast: bool) -> void:
	_ws._start_screen.close()
	if with_toast:
		_ws._toast.show_message(tr("worlds.switch.done") % current_name())
	_ws._links.show_dialog_if_ready.call_deferred()
	show_whats_new_if_due.call_deferred()

func show_whats_new_if_due() -> void:
	if not _ws._whats_new_pending or _ws._is_modal_open():
		return
	_ws._whats_new_pending = false
	AppVersion.mark_seen()
	_ws._about_dialog.open_tab(AboutDialog.Tab.WHATS_NEW)

func _open_world(world_id: String, skipped_worlds: int) -> void:
	var root: String = _ws._worlds.world_root(world_id)
	_ws._world_id = world_id
	_ws._storage = VaultStorage.new(root)
	InlineImages.set_images_dir(_ws._storage.images_dir)
	_ws.sidebar_editor.storage = _ws._storage
	_ws._worlds.remember_last(world_id)
	_ws._load_vault_data(skipped_worlds)


func _leave_world() -> bool:
	if _ws._storage == null:
		return true
	_ws._end_interactions()
	if not _ws.flush_world():
		return false
	_ws._close_world()
	_ws._storage = null
	_ws._world_id = ""
	_ws.sidebar_editor.storage = null
	InlineImages.set_images_dir("")
	return true


func change_vault(path: String) -> void:
	var checked: Dictionary = WorldRegistry.check_vault_dir(path)
	if not bool(checked["ok"]):
		_ws._toast.show_message(tr(str(checked["reason"])), true)
		return
	if not _leave_world():
		_ws._toast.show_message(tr("vault.change.flush_failed"), true)
		return
	_ws._worlds.select_vault_dir(str(checked["path"]))
	_ws._worlds.remember_vault_dir()
	_ws._worlds = WorldRegistry.new()
	if not _ws._start_screen.is_open():
		var last_id: String = _ws._worlds.last_world_id()
		if _ws._worlds.world_root(last_id) != "":
			_open_world(last_id, 0)
			_ws._focus_camera_to_selection_or_bounds()
			_ws._toast.show_message(tr("vault.change.done") % current_name())
			_ws._links.show_dialog_if_ready.call_deferred()
			return
	var problem: String = _prepare_vault()
	if problem != "":
		_ws._toast.show_message(problem, true)
	show_start_screen()


func import_into_new_world(bundle: Dictionary, ids: Array[String], include_linked: bool, path: String) -> void:
	var default_name: String = str(bundle.get("name", ""))
	if default_name == "":
		default_name = path.get_file().get_basename().replace("\n", " ").replace("\r", " ").strip_edges()
	if WorldRegistry.check_name(default_name) != "":
		default_name = default_name.left(WorldRegistry.MAX_NEW_NAME_LENGTH).strip_edges()
	if default_name == "":
		default_name = tr("worlds.default_name")
	_ws._world_prompt.prompt_name(tr("import.new_world.title"), default_name, _on_import_world_named.bind(bundle, ids, include_linked, path), _ws._worlds.is_name_taken)

func _on_import_world_named(world_name: String, bundle: Dictionary, ids: Array[String], include_linked: bool, path: String) -> void:
	var selection: Dictionary = ProjectSelection.select(bundle["notes"] as Array[Dictionary], bundle["connections"] as Array[Dictionary], \
		bundle["types"] as Array[Dictionary], ids, include_linked)
	if (selection["notes"] as Array[Dictionary]).is_empty():
		_ws._world_prompt.show_error(tr("import.none_selected"))
		return
	var made: Dictionary = _ws._worlds.create_world(world_name)
	if not bool(made["ok"]):
		_ws._world_prompt.show_error(tr(str(made["reason"])))
		return
	var problem: String = switch_to(str(made["id"]))
	if problem != "":
		_ws._worlds.remove_unfinished_world(str(made["id"]))
		_ws._world_prompt.show_error(problem)
		return
	_ws._world_prompt.close()
	var filtered: Dictionary = bundle.duplicate()
	filtered["notes"] = selection["notes"]
	filtered["connections"] = selection["connections"]
	filtered["types"] = selection["types"]
	_ws._project_files.fill_new_world(filtered, path)
	if _ws._start_screen.is_open():
		_finish_start_screen(false)


func current_name() -> String:
	var root: String = _ws._worlds.world_root(_ws._world_id)
	return str(WorldRegistry.read_world_file(root)["name"]) if root != "" else ""

func switch_to(world_id: String) -> String:
	if world_id == _ws._world_id:
		return ""
	if _ws._worlds.world_root(world_id) == "":
		return tr("worlds.switch.failed")
	if _ws._storage != null:
		_ws._end_interactions()
		if not _ws.flush_world():
			return tr("worlds.switch.flush_failed")
		_ws._close_world()
	_open_world(world_id, 0)
	if _ws._active_search_query != "":
		_ws._search.on_search_text_changed(_ws._active_search_query)
	_ws._focus_camera_to_selection_or_bounds()
	return ""


func flush_or_warn() -> bool:
	if _ws._storage == null:
		return true
	_ws._end_interactions()
	if _ws.flush_world():
		return true
	_ws._toast.show_message(tr("exit.flush_failed"), true, AppWorkspace.VAULT_WARNING_HOLD)
	return false

func go_to_main_menu() -> void:
	if _ws._storage == null or _ws._is_modal_open():
		return
	if not _leave_world():
		_ws._toast.show_message(tr("exit.flush_failed"), true, AppWorkspace.VAULT_WARNING_HOLD)
		return
	show_start_screen()


func _world_row(world_id: String) -> Dictionary:
	for world: Dictionary in _ws._worlds.list_worlds(true):
		if str(world["id"]) == world_id:
			return world
	return {}

func _on_start_rename(world_id: String) -> void:
	var row: Dictionary = _world_row(world_id)
	if row.is_empty() or not bool(row["ok"]):
		show_start_screen()
		_ws._start_screen.show_error(tr(WorldRegistry.REASON_RENAME_FAILED))
		return
	_ws._world_prompt.prompt_name(tr("worlds.name.title_rename"), str(row["name"]), _on_start_rename_named.bind(world_id), _ws._worlds.is_name_taken.bind(world_id))

func _on_start_rename_named(world_name: String, world_id: String) -> void:
	var problem: String = _ws._worlds.rename_world(world_id, world_name)
	if problem != "":
		_ws._world_prompt.show_error(tr(problem))
		return
	_ws._world_prompt.close()
	_ws._start_screen.refresh(_ws._worlds.list_worlds(true), _ws._worlds.last_world_id())

func _on_start_delete(world_id: String) -> void:
	var row: Dictionary = _world_row(world_id)
	if row.is_empty():
		show_start_screen()
		_ws._start_screen.show_error(tr(WorldRegistry.REASON_DELETE_FAILED))
		return
	if not bool(row["ok"]):
		var shown_name: String = str(row["name"]) if str(row["name"]) != "" else world_id.substr(0, 8)
		_ws._world_prompt.prompt_delete_damaged(shown_name, int(row.get("notes", 0)), _on_start_delete_damaged_confirmed.bind(world_id, shown_name))
		return
	_ws._world_prompt.prompt_delete(str(row["name"]), int(row.get("notes", 0)), _on_start_delete_confirmed.bind(world_id, str(row["name"])))

func _on_start_delete_damaged_confirmed(world_id: String, world_name: String) -> void:
	_ws._world_prompt.close()
	var problem: String = _ws._worlds.delete_damaged_world(world_id)
	_ws._start_screen.refresh(_ws._worlds.list_worlds(true), _ws._worlds.last_world_id())
	if problem != "":
		_ws._start_screen.show_error(tr(problem))
		return
	_ws._toast.show_message(tr("worlds.delete.damaged_done") % world_name)

func _on_start_delete_confirmed(world_id: String, world_name: String) -> void:
	_ws._world_prompt.close()
	if world_id == _ws._world_id and not _leave_world():
		_ws._start_screen.show_error(tr("exit.flush_failed"))
		return
	var problem: String = _ws._worlds.trash_world(world_id, _ws._now())
	_ws._start_screen.refresh(_ws._worlds.list_worlds(true), _ws._worlds.last_world_id())
	if problem != "":
		_ws._start_screen.show_error(tr(problem))
		return
	_ws._toast.show_message(tr("worlds.delete.done") % world_name)
