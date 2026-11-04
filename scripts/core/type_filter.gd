class_name TypeFilter
extends RefCounted

signal changed

const DIM_ALPHA: float = 0.2

var _hidden: Dictionary = {}

func is_shown(type_id: String) -> bool:
	return not _hidden.has(type_id)

func is_all_shown() -> bool:
	return _hidden.is_empty()

func toggle(type_id: String) -> void:
	if _hidden.has(type_id):
		_hidden.erase(type_id)
	else:
		_hidden[type_id] = true
	changed.emit()

func show_all() -> void:
	if _hidden.is_empty():
		return
	_hidden.clear()
	changed.emit()

func hide_all(type_ids: Array[String]) -> void:
	var before: int = _hidden.size()
	for type_id: String in type_ids:
		_hidden[type_id] = true
	if _hidden.size() != before:
		changed.emit()

func alpha_for(type_id: String) -> float:
	return 1.0 if is_shown(type_id) else DIM_ALPHA

func prune(valid_ids: Array[String]) -> bool:
	var dropped: bool = false
	for type_id: String in _hidden.keys():
		if type_id != "" and not valid_ids.has(type_id):
			_hidden.erase(type_id)
			dropped = true
	return dropped
