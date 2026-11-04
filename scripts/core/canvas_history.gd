class_name CanvasHistory
extends RefCounted

signal changed

const MAX_STEPS: int = 50

class Step extends RefCounted:
	var label: String = ""
	var undo_fn: Callable = Callable()
	var redo_fn: Callable = Callable()

var _undo_stack: Array[Step] = []
var _redo_stack: Array[Step] = []
var _applying: bool = false

func record(label: String, undo_fn: Callable, redo_fn: Callable) -> void:
	if _applying:
		return

	var step: Step = Step.new()
	step.label = label
	step.undo_fn = undo_fn
	step.redo_fn = redo_fn
	_undo_stack.append(step)
	if _undo_stack.size() > MAX_STEPS:
		_undo_stack.pop_front()
	_redo_stack.clear()
	changed.emit()

func can_undo() -> bool:
	return not _undo_stack.is_empty()

func can_redo() -> bool:
	return not _redo_stack.is_empty()

func peek_undo_label() -> String:
	if _undo_stack.is_empty():
		return ""
	var top: Step = _undo_stack.back()
	return top.label

func peek_redo_label() -> String:
	if _redo_stack.is_empty():
		return ""
	var top: Step = _redo_stack.back()
	return top.label

func undo() -> String:
	if _undo_stack.is_empty():
		return ""
	var step: Step = _undo_stack.pop_back()
	_run(step.undo_fn)
	_redo_stack.append(step)
	changed.emit()
	return step.label

func redo() -> String:
	if _redo_stack.is_empty():
		return ""
	var step: Step = _redo_stack.pop_back()
	_run(step.redo_fn)
	_undo_stack.append(step)
	changed.emit()
	return step.label

func clear() -> void:
	if _undo_stack.is_empty() and _redo_stack.is_empty():
		return
	_undo_stack.clear()
	_redo_stack.clear()
	changed.emit()

func _run(action: Callable) -> void:
	_applying = true
	if action.is_valid():
		action.call()
	_applying = false
