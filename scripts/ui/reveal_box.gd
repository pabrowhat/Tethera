class_name RevealBox
extends Container

const DURATION: float = 0.18

var is_open: bool = true
var _progress: float = 1.0
var _tween: Tween = null

func _init() -> void:
	clip_contents = true
	child_entered_tree.connect(_on_child_entered)

func set_open(open: bool, animate: bool) -> void:
	if open == is_open and (_tween == null or not _tween.is_running()):
		return
	is_open = open
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var target: float = 1.0 if open else 0.0
	if not animate or not _parent_shown() or Preferences.reduce_motion():
		_set_progress(target)
		visible = open
		return
	visible = true
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_progress, _progress, target, DURATION)
	_tween.tween_callback(func() -> void: visible = is_open)

func _parent_shown() -> bool:
	var parent: CanvasItem = get_parent() as CanvasItem
	return is_inside_tree() and (parent == null or parent.is_visible_in_tree())

func _set_progress(value: float) -> void:
	_progress = value
	update_minimum_size()
	queue_sort()

func _get_minimum_size() -> Vector2:
	var result: Vector2 = Vector2.ZERO
	for child: Node in get_children():
		if child is Control and (child as Control).visible:
			var minimum: Vector2 = (child as Control).get_combined_minimum_size()
			result = Vector2(maxf(result.x, minimum.x), maxf(result.y, minimum.y * _progress))
	return result

func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	for child: Node in get_children():
		if child is Control and (child as Control).visible:
			fit_child_in_rect(child as Control, Rect2(0.0, 0.0, size.x, (child as Control).get_combined_minimum_size().y))

func _on_child_entered(node: Node) -> void:
	if not (node is Control):
		return
	var control: Control = node as Control
	if not control.minimum_size_changed.is_connected(update_minimum_size):
		control.minimum_size_changed.connect(update_minimum_size)
	if not control.visibility_changed.is_connected(update_minimum_size):
		control.visibility_changed.connect(update_minimum_size)
