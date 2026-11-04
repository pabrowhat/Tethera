class_name WorkspaceCanvasBackground
extends RefCounted

var _ws: AppWorkspace = null

func _init(workspace: AppWorkspace) -> void:
	_ws = workspace

func load_saved() -> void:
	_ws._canvas_background = _ws._storage.load_canvas_background()
	if _ws._canvas_background.is_set() and _texture() == null:
		_ws._canvas_background = CanvasBackground.new()
		_ws._toast.show_message(tr("canvas_bg.load_failed"), true)
	apply()

func apply() -> void:
	if not (_ws.background.material is ShaderMaterial):
		return
	var material: ShaderMaterial = _ws.background.material as ShaderMaterial
	var texture: Texture2D = _texture()
	material.set_shader_parameter("bg_texture", texture)
	material.set_shader_parameter("bg_opacity", _ws._canvas_background.opacity)
	material.set_shader_parameter("use_texture", texture != null)

func open_dialog() -> void:
	if _ws._snapshot_busy or _ws._file_dialog_open or _ws._is_modal_open() or _ws._zen_active or _ws._lightbox.is_open() or _ws._eyedropper.is_active():
		return
	_refresh_dialog()
	_ws._canvas_bg_dialog.open_dialog()

func request_pick() -> void:
	if _ws._file_dialog_open:
		return
	_ws._file_dialog_open = true
	DisplayServer.file_dialog_show(
		tr("canvas_bg.dialog"),
		"",
		"",
		false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
		["*.png, *.jpg, *.jpeg, *.webp"],
		_on_pick_result
	)

func _on_pick_result(status: bool, selected_paths: PackedStringArray, _filter_index: int) -> void:
	_ws._file_dialog_open = false
	if status and not selected_paths.is_empty():
		add_from_file(selected_paths[0])

func add_from_file(source_path: String) -> bool:
	var vault_path: String = _ws._storage.copy_image_to_vault(source_path, CanvasBackground.MAX_SIDE, CanvasBackground.MAX_FILE_BYTES)
	if vault_path == "":
		_ws._toast.show_message(_refusal_message(source_path), true)
		return false
	if not set_image(vault_path):
		_ws._toast.show_message(tr("image.insert.failed"), true)
		return false
	_refresh_dialog()
	return true

func remove() -> void:
	clear()
	_refresh_dialog()

func _refresh_dialog() -> void:
	var picture_name: String = _ws._canvas_background.image.get_file() if _ws._canvas_background.is_set() else ""
	_ws._canvas_bg_dialog.show_state(picture_name, _ws._canvas_background.opacity)

func _refusal_message(source_path: String) -> String:
	match _ws._storage.last_refusal_reason:
		ImageGuard.REASON_TOO_LARGE:
			return tr("canvas_bg.refused.too_large") % source_path.get_file()
		ImageGuard.REASON_FILE_TOO_LARGE:
			return tr("canvas_bg.refused.file_too_large") % source_path.get_file()
	return _ws._storage.last_refusal if _ws._storage.last_refusal != "" else tr("image.insert.failed")

func snapshot() -> CanvasBackground:
	return CanvasBackground.from_dict(_ws._canvas_background.to_dict())

func replace(background: CanvasBackground) -> void:
	_ws._canvas_background = background
	apply()
	save()

func set_image(vault_path: String) -> bool:
	if InlineImages.texture_for(vault_path) == null:
		return false
	_ws._canvas_background.image = vault_path
	apply()
	save()
	return true

func clear() -> void:
	_ws._canvas_background.image = ""
	apply()
	save()

func set_opacity(value: float, persist: bool) -> void:
	_ws._canvas_background.opacity = CanvasBackground.sanitize_opacity(value)
	apply()
	if persist:
		save()

func save() -> void:
	_ws._storage.save_canvas_background(_ws._canvas_background)

func _texture() -> Texture2D:
	if not _ws._canvas_background.is_set():
		return null
	return InlineImages.texture_for(_ws._canvas_background.image)
