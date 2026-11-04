class_name SelectionController
extends RefCounted

signal selection_changed

var _selected: Array = []

func has(item: Object) -> bool:
	return _selected.has(item)

func count() -> int:
	_prune()
	var total: int = 0
	for entry: Variant in _selected:
		if entry is GraphCard:
			total += 1
	return total

func decor_count() -> int:
	_prune()
	return _selected.size() - count()

func item_count() -> int:
	_prune()
	return _selected.size()

func get_cards() -> Array[GraphCard]:
	_prune()
	var result: Array[GraphCard] = []
	for entry: Variant in _selected:
		if entry is GraphCard:
			result.append(entry as GraphCard)
	return result

func get_decor() -> Array[DecorNode]:
	_prune()
	var result: Array[DecorNode] = []
	for entry: Variant in _selected:
		if entry is DecorNode:
			result.append(entry as DecorNode)
	return result

func get_items() -> Array:
	_prune()
	return _selected.duplicate()

func select_only(item: Object) -> void:
	set_items([item])

func toggle(item: Object) -> void:
	if not is_instance_valid(item):
		return
	if has(item):
		remove(item)
	else:
		add(item)

func add(item: Object) -> void:
	if not _is_selectable(item) or has(item):
		return
	_selected.append(item)
	_paint(item, true, true)
	selection_changed.emit()

func remove(item: Object) -> void:
	if not _selected.has(item):
		return
	_selected.erase(item)
	if is_instance_valid(item):
		_paint(item, false)
	selection_changed.emit()

func clear() -> void:
	if _selected.is_empty():
		return
	for entry: Variant in _selected:
		if is_instance_valid(entry):
			_paint(entry as Object, false)
	_selected.clear()
	selection_changed.emit()

func clear_cards() -> void:
	var kept: Array = get_decor()
	if kept.size() == item_count():
		return
	set_items(kept)

func set_cards(cards: Array[GraphCard], punch_new: bool = false, silent: bool = false) -> void:
	var items: Array = []
	items.append_array(cards)
	items.append_array(get_decor())
	set_items(items, punch_new, silent)

func set_items(items: Array, punch_new: bool = false, silent: bool = false) -> void:
	var changed: bool = false

	for i: int in range(_selected.size() - 1, -1, -1):
		var existing: Variant = _selected[i]
		if not is_instance_valid(existing):
			_selected.remove_at(i)
			changed = true
		elif not items.has(existing):
			_paint(existing as Object, false)
			_selected.remove_at(i)
			changed = true

	for item: Variant in items:
		if _is_selectable(item as Object) and not _selected.has(item):
			_selected.append(item)
			_paint(item as Object, true, punch_new)
			changed = true

	if changed and not silent:
		selection_changed.emit()

func commit() -> void:
	selection_changed.emit()

func _is_selectable(item: Object) -> bool:
	return is_instance_valid(item) and (item is GraphCard or item is DecorNode)

func _paint(item: Object, active: bool, punch: bool = false) -> void:
	if item is GraphCard:
		(item as GraphCard).set_selected(active, punch)
	elif item is DecorNode:
		(item as DecorNode).set_selected(active)

func _prune() -> void:
	for i: int in range(_selected.size() - 1, -1, -1):
		if not is_instance_valid(_selected[i]):
			_selected.remove_at(i)
