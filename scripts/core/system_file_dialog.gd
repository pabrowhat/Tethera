class_name SystemFileDialog
extends RefCounted

static func open(title: String, current_dir: String, filename: String, show_hidden: bool, mode: int, filters: PackedStringArray, callback: Callable) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var dialog: FileDialog = FileDialog.new()
	dialog.use_native_dialog = true
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = mode as FileDialog.FileMode
	dialog.title = title
	dialog.filters = filters
	dialog.show_hidden_files = show_hidden

	var state: Dictionary = {"done": false}
	var finish: Callable = func(status: bool, paths: PackedStringArray) -> void:
		if bool(state["done"]):
			return
		state["done"] = true
		if is_instance_valid(dialog):
			dialog.queue_free()
		if callback.is_valid():
			callback.call(status, paths, 0)
	dialog.file_selected.connect(func(path: String) -> void: finish.call(true, PackedStringArray([path])))
	dialog.files_selected.connect(func(paths: PackedStringArray) -> void: finish.call(true, paths))
	dialog.dir_selected.connect(func(path: String) -> void: finish.call(true, PackedStringArray([path])))
	dialog.canceled.connect(func() -> void: finish.call(false, PackedStringArray()))

	tree.root.add_child(dialog)
	dialog.current_dir = _start_dir(current_dir)
	if filename != "":
		dialog.current_file = filename
	dialog.popup_centered()

static func _start_dir(current_dir: String) -> String:
	if current_dir != "" and DirAccess.dir_exists_absolute(current_dir):
		return current_dir
	var pictures: String = OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if pictures != "" and DirAccess.dir_exists_absolute(pictures):
		return pictures
	return OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
