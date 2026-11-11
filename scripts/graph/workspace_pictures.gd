class_name WorkspacePictures
extends RefCounted

const FADE_SECONDS: float = 0.25
const APPLY_BUDGET_USEC: int = 4000

var _ws: AppWorkspace = null
var _generation: int = 0
var _jobs: Dictionary = {}
var _tasks: Array[int] = []
var _inbox: Array[Dictionary] = []
var _finished: Array[Dictionary] = []
var _mutex: Mutex = Mutex.new()

func _init(workspace: AppWorkspace) -> void:
	_ws = workspace

func begin(references: Array[String]) -> void:
	for reference: String in references:
		if _jobs.has(reference):
			continue
		var file_path: String = InlineImages.disk_path(reference)
		_jobs[reference] = true
		_tasks.append(WorkerThreadPool.add_task(_decode.bind(_generation, reference, file_path, InlineImages.cache_key(file_path))))

func is_loading() -> bool:
	return not _jobs.is_empty()

func close_world() -> void:
	_generation += 1
	_jobs.clear()
	_inbox.clear()
	_mutex.lock()
	_finished.clear()
	_mutex.unlock()

func shutdown() -> void:
	close_world()
	for task: int in _tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	_tasks.clear()

func finish_now() -> void:
	InlineImages.defer_misses = false
	for reference: String in _jobs.keys():
		InlineImages.texture_for(reference)
		_jobs.erase(reference)
		InlineImages.settle(reference)
		_refresh(reference, false)

func pump() -> void:
	for index: int in range(_tasks.size() - 1, -1, -1):
		if WorkerThreadPool.is_task_completed(_tasks[index]):
			WorkerThreadPool.wait_for_task_completion(_tasks[index])
			_tasks.remove_at(index)
	_mutex.lock()
	_inbox.append_array(_finished)
	_finished.clear()
	_mutex.unlock()
	var deadline: int = Time.get_ticks_usec() + APPLY_BUDGET_USEC
	while not _inbox.is_empty() and Time.get_ticks_usec() < deadline:
		_apply(_inbox.pop_front())

func _decode(generation: int, reference: String, file_path: String, key: String) -> void:
	var decoded: Dictionary = InlineImages.decode_for_cache(file_path)
	_mutex.lock()
	_finished.append({"generation": generation, "reference": reference, "file_path": file_path, "key": key, "decoded": decoded})
	_mutex.unlock()

func _apply(result: Dictionary) -> void:
	var reference: String = str(result["reference"])
	if int(result["generation"]) != _generation or not _jobs.has(reference):
		return
	var decoded: Dictionary = result["decoded"] as Dictionary
	if not decoded.is_empty():
		InlineImages.store(reference, str(result["file_path"]), str(result["key"]), decoded)
	_jobs.erase(reference)
	InlineImages.settle(reference)
	_refresh(reference, true)

func _refresh(reference: String, animate: bool) -> void:
	var file_name: String = reference.get_file()
	for card: GraphCard in _ws._cards_by_id.values():
		if not is_instance_valid(card):
			continue
		if card.image_path == reference:
			card.set_cover_image(reference)
			if animate and card.get_cover_texture() != null:
				_fade_in(card.image_rect)
		if card.content_text.contains(file_name) and _uses_inline(card.content_text, reference):
			card.set_content(card.content_text)
	_ws._type_ops.refresh_backgrounds_using(reference)
	for node: DecorNode in _ws._decor.all_nodes():
		if node.image_path == reference:
			node.set_image(reference)
			if animate:
				_fade_in(node)
	_ws._canvas_bg.picture_arrived(reference)

func _uses_inline(content: String, reference: String) -> bool:
	for entry: Dictionary in NoteImages.find_inline(content):
		if str(entry["path"]) == reference:
			return true
	return false

func _fade_in(item: CanvasItem) -> void:
	if Preferences.reduce_motion() or not item.is_inside_tree():
		return
	item.self_modulate.a = 0.0
	item.create_tween().tween_property(item, "self_modulate:a", 1.0, FADE_SECONDS)
