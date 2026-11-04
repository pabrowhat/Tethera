class_name WorkspaceHistory
extends RefCounted

const MOVE_EPSILON: float = 0.5
const UNDO_GLIDE_DURATION: float = 0.12

var _ws: AppWorkspace = null

func _init(workspace: AppWorkspace) -> void:
	_ws = workspace

func run_history_command(redo: bool) -> void:
	if _ws._is_interaction_in_flight():
		return
	_ws._cancel_link_source()

	var label: String = _ws._history.redo() if redo else _ws._history.undo()
	if label == "":
		_ws._toast.show_message(tr("history.nothing_to_redo") if redo else tr("history.nothing_to_undo"), false, 1.2)
		return

	if redo:
		_ws._toast.show_message(tr("history.redone") % label, false, 1.6)
	else:
		_ws._toast.show_message(tr("history.undone") % label, false, 1.6)

func record_move(before: Dictionary, label: String = "", decor_before: Dictionary = {}) -> void:
	var step_label: String = label if label != "" else tr("history.move")
	var from_positions: Dictionary = {}
	var to_positions: Dictionary = {}
	for id: String in before:
		var card: GraphCard = _ws._cards_by_id.get(id, null)
		if not is_instance_valid(card):
			continue
		var origin: Vector2 = before[id]
		if card.position.distance_to(origin) > MOVE_EPSILON:
			from_positions[id] = origin
			to_positions[id] = card.position

	var from_decor: Dictionary = {}
	var to_decor: Dictionary = {}
	for id: String in decor_before:
		var node: DecorNode = _ws._decor_by_id.get(id, null)
		if not is_instance_valid(node):
			continue
		var origin_state: Dictionary = decor_before[id]
		var current_state: Dictionary = node.get_state()
		if _decor_state_differs(origin_state, current_state):
			from_decor[id] = origin_state
			to_decor[id] = current_state

	if from_positions.is_empty() and from_decor.is_empty():
		return
	if from_decor.is_empty():
		_ws._history.record(step_label, apply_positions.bind(from_positions), apply_positions.bind(to_positions))
	else:
		_ws._history.record(step_label, apply_move.bind(from_positions, from_decor), apply_move.bind(to_positions, to_decor))

func _decor_state_differs(a: Dictionary, b: Dictionary) -> bool:
	return (a["pos"] as Vector2).distance_to(b["pos"] as Vector2) > MOVE_EPSILON \
		or (a["size"] as Vector2).distance_to(b["size"] as Vector2) > MOVE_EPSILON \
		or absf(angle_difference(deg_to_rad(float(a["rot"])), deg_to_rad(float(b["rot"])))) > deg_to_rad(0.1)

func apply_move(positions: Dictionary, decor_states: Dictionary) -> void:
	apply_positions(positions)
	apply_decor_states(decor_states)

func apply_decor_states(states: Dictionary) -> void:
	for id: String in states:
		var node: DecorNode = _ws._decor_by_id.get(id, null)
		if is_instance_valid(node):
			node.apply_state(states[id] as Dictionary)
	_ws._decor.save()

func apply_positions(positions: Dictionary) -> void:
	for id: String in positions:
		var card: GraphCard = _ws._cards_by_id.get(id, null)
		if not is_instance_valid(card):
			continue
		var tween: Tween = card.glide_to(positions[id] as Vector2, UNDO_GLIDE_DURATION)
		tween.finished.connect(on_glide_finished.bind(id))

func on_glide_finished(id: String) -> void:
	var card: GraphCard = _ws._cards_by_id.get(id, null)
	if is_instance_valid(card):
		_ws._save_card(card)

func record_color_change(before: Dictionary, after: Dictionary, overrides_before: Dictionary = {}, overrides_after: Dictionary = {}) -> void:
	if before.is_empty():
		return
	_ws._history.record(tr("history.recolor"), apply_colors.bind(before, overrides_before), apply_colors.bind(after, overrides_after))

func apply_colors(colors: Dictionary, overrides: Dictionary = {}) -> void:
	for id: String in colors:
		var card: GraphCard = _ws._cards_by_id.get(id, null)
		if not is_instance_valid(card):
			continue
		if overrides.has(id):
			card.color_overridden = bool(overrides[id])
		var color: Color = colors[id]
		var entity_type: EntityType = _ws._types.find(card.entity_type_id)
		if entity_type != null and not card.color_overridden:
			color = entity_type.color
		card.set_category_color(color)
		card.play_capture_punch()
		_ws._saved_colors[id] = color
		_ws._touch_card(card)

	if not _ws.sidebar_editor.is_open:
		return
	var current: GraphCard = _ws.sidebar_editor.current_card
	if is_instance_valid(current) and colors.has(current.card_id):
		_ws.sidebar_editor.apply_external_color(current.card_color)
		_ws.sidebar_editor.refresh_type_section()
	elif _ws._selection.count() > 1:
		for card: GraphCard in _ws._selection.get_cards():
			if colors.has(card.card_id):
				_ws.sidebar_editor.show_batch(_ws._selection.get_cards())
				break

func remove_cards(ids: Array[String]) -> void:
	var doomed: Array[GraphCard] = []
	var doomed_ids: Array[String] = []
	for id: String in ids:
		var card: GraphCard = _ws._cards_by_id.get(id, null)
		if is_instance_valid(card):
			doomed.append(card)
			doomed_ids.append(id)
	if doomed.is_empty():
		return

	var remaining: Array[GraphCard] = []
	for card: GraphCard in _ws._selection.get_cards():
		if not doomed.has(card):
			remaining.append(card)
	_ws._selection.set_cards(remaining)

	for card: GraphCard in doomed:
		_ws._carried_cards.erase(card)
		_ws._carry_before.erase(card.card_id)
		if _ws._link_source_card == card:
			_ws._cancel_link_source()

	_ws._graph.remove_nodes(doomed_ids)

	for i: int in doomed.size():
		_ws._storage.delete_note(doomed_ids[i])
		_ws._cards_by_id.erase(doomed_ids[i])
		_ws._last_titles.erase(doomed_ids[i])
		_ws._last_contents.erase(doomed_ids[i])
		_ws._saved_colors.erase(doomed_ids[i])
		doomed[i].queue_free()

func capture(ids: Array[String]) -> Dictionary:
	var notes: Array[Dictionary] = []
	for id: String in ids:
		var card: GraphCard = _ws._cards_by_id.get(id, null)
		if is_instance_valid(card):
			notes.append(_ws._snapshot_card(card))
	return {"notes": notes, "links": _ws._graph.get_links_of(ids)}

func restore(state: Dictionary) -> void:
	var notes: Array[Dictionary] = state.get("notes", [])
	var created: Array[Dictionary] = []
	for note: Dictionary in notes:
		if _ws._cards_by_id.has(str(note["id"])):
			continue
		var card: GraphCard = _ws._instantiate_card(note)
		card.play_spawn_animation()
		_ws._save_card(card)
		created.append(note)

	var links: Array[Dictionary] = state.get("links", [])
	_ws._graph.restore_links(links)
	_ws._pin_positions(created)
	if _ws._active_search_query != "":
		_ws._search.on_search_text_changed(_ws._active_search_query)

func remove_with_holder(holder: Dictionary) -> void:
	var ids: Array[String] = holder["ids"]
	holder["state"] = capture(ids)
	remove_cards(ids)
	var decor_ids: Array[String] = []
	decor_ids.assign(holder.get("decor_ids", []))
	if not decor_ids.is_empty():
		holder["decor_state"] = capture_decor(decor_ids)
		remove_decor(decor_ids)

func restore_with_holder(holder: Dictionary) -> void:
	restore(holder["state"] as Dictionary)
	var decor_states: Array[Dictionary] = []
	decor_states.assign(holder.get("decor_state", []))
	restore_decor(decor_states)


func capture_decor(ids: Array[String]) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for id: String in ids:
		var node: DecorNode = _ws._decor_by_id.get(id, null)
		if is_instance_valid(node):
			states.append(node.to_item().to_dict())
	return states

func remove_decor(ids: Array[String]) -> void:
	var doomed: Array[DecorNode] = []
	for id: String in ids:
		var node: DecorNode = _ws._decor_by_id.get(id, null)
		if is_instance_valid(node):
			doomed.append(node)
	if doomed.is_empty():
		return

	var remaining: Array = []
	for item: Variant in _ws._selection.get_items():
		if not doomed.has(item):
			remaining.append(item)
	_ws._selection.set_items(remaining)

	for node: DecorNode in doomed:
		_ws._storage.trash_decor(node.to_item().to_dict())
		_ws._decor_by_id.erase(node.decor_id)
		node.queue_free()
	_ws._decor.save()

func restore_decor(states: Array[Dictionary]) -> void:
	var restored: bool = false
	for state: Dictionary in states:
		var item: DecorItem = DecorItem.from_dict(state)
		var node: DecorNode = _ws._decor.create_node(item) if item != null else null
		if node != null:
			node.play_spawn_animation()
			restored = true
	if restored:
		_ws._decor.save()
