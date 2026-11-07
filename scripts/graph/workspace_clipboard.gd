class_name WorkspaceClipboard
extends RefCounted

const PASTE_STEP: Vector2 = Vector2(40.0, 40.0)

var _ws: AppWorkspace = null
var _clipboard: NoteClipboard = NoteClipboard.new()

func _init(workspace: AppWorkspace) -> void:
	_ws = workspace

func is_empty() -> bool:
	return _clipboard.is_empty()

func clear() -> void:
	_clipboard.clear()

func copy() -> bool:
	if _ws._is_interaction_in_flight():
		return false
	if not _fill(_clipboard):
		return false
	_ws._toast.show_message(tr("clipboard.copied") % _clipboard.item_count(), false, 1.2)
	return true

func cut() -> void:
	if _ws._is_interaction_in_flight():
		return
	if not _fill(_clipboard):
		return
	var count: int = _clipboard.item_count()
	_ws._delete_cards(_ws._selection.get_cards(), _ws._selection.get_decor(), tr("history.cut") % count)
	_ws._toast.show_message(tr("clipboard.cut") % count, false, 1.2)

func paste() -> void:
	if _ws._is_interaction_in_flight() or _clipboard.is_empty():
		return
	_clipboard.paste_count += 1
	_paste_from(_clipboard, PASTE_STEP * float(_clipboard.paste_count), tr("history.paste"), "clipboard.pasted")

func duplicate() -> void:
	if _ws._is_interaction_in_flight():
		return
	var temp: NoteClipboard = NoteClipboard.new()
	if not _fill(temp):
		return
	_paste_from(temp, PASTE_STEP, tr("history.duplicate"), "clipboard.duplicated")

func select_all() -> void:
	var all_cards: Array[GraphCard] = []
	for card: GraphCard in _ws._cards_by_id.values():
		if is_instance_valid(card):
			all_cards.append(card)
	if all_cards.is_empty():
		return
	_ws._selection.set_cards(all_cards)

func _fill(target: NoteClipboard) -> bool:
	var cards: Array[GraphCard] = _ws._selection.get_cards()
	var decor_nodes: Array[DecorNode] = _ws._selection.get_decor()
	if cards.is_empty() and decor_nodes.is_empty():
		return false
	var ids: Array[String] = []
	var notes: Array[Dictionary] = []
	for card: GraphCard in cards:
		ids.append(card.card_id)
		notes.append(_ws._snapshot_card(card))
	var links: Array[Dictionary] = []
	for conn: Dictionary in _ws._graph.get_links_of(ids):
		if ids.has(str(conn.get("from", ""))) and ids.has(str(conn.get("to", ""))):
			links.append(conn)
	var decor_ids: Array[String] = []
	for node: DecorNode in decor_nodes:
		decor_ids.append(node.decor_id)
	target.set_content(notes, links, _ws._undo.capture_decor(decor_ids))
	return true

func _paste_from(source: NoteClipboard, offset: Vector2, history_label: String, toast_key: String) -> void:
	var taken: Dictionary = {}
	var existing_titles: Dictionary = {}
	for existing_id: String in _ws._cards_by_id:
		taken[existing_id] = true
		var existing: GraphCard = _ws._cards_by_id[existing_id]
		if is_instance_valid(existing):
			existing_titles[existing.title_label.text.strip_edges().to_lower()] = true
	var built: Dictionary = source.build_paste(taken, offset, existing_titles, int(Time.get_unix_time_from_system()))
	var new_notes: Array[Dictionary] = built["notes"]
	var new_links: Array[Dictionary] = built["connections"]
	var new_decor: Array[Dictionary] = built["decor"]
	if new_notes.is_empty() and new_decor.is_empty():
		return

	var created_ids: Array[String] = []
	var placed_notes: Array[Dictionary] = []
	var write_failed: bool = false
	for note: Dictionary in new_notes:
		var card: GraphCard = _ws._instantiate_card(note)
		if not _ws._save_card(card):
			_ws._cards_by_id.erase(card.card_id)
			card.queue_free()
			write_failed = true
			break
		card.play_spawn_animation()
		_ws._note_counter += 1
		created_ids.append(card.card_id)
		placed_notes.append(note)

	var placed: Dictionary = {}
	for created_id: String in created_ids:
		placed[created_id] = true
	var placed_links: Array[Dictionary] = []
	for conn: Dictionary in new_links:
		if placed.has(str(conn.get("from", ""))) and placed.has(str(conn.get("to", ""))):
			placed_links.append(conn)
	_ws._graph.restore_links(placed_links)
	_ws._pin_positions(placed_notes)

	var decor_ids: Array[String] = []
	for entry: Dictionary in new_decor:
		if _ws._decor.is_full():
			break
		var item: DecorItem = DecorItem.from_dict(entry)
		var node: DecorNode = _ws._decor.create_node(item) if item != null else null
		if node != null:
			node.play_spawn_animation()
			decor_ids.append(node.decor_id)
	if not decor_ids.is_empty():
		_ws._decor.save()
	if not created_ids.is_empty():
		write_failed = not _ws._storage.save_connections(_ws._graph.get_all_connections()) or write_failed
	if _ws._active_search_query != "":
		_ws._search.on_search_text_changed(_ws._active_search_query)

	if created_ids.is_empty() and decor_ids.is_empty():
		_ws._toast.show_message(tr("import.failed_partial") % 0, true, AppWorkspace.VAULT_WARNING_HOLD)
		return

	var holder: Dictionary = {"ids": created_ids, "state": _ws._undo.capture(created_ids), "decor_ids": decor_ids, "decor_state": _ws._undo.capture_decor(decor_ids)}
	var total: int = created_ids.size() + decor_ids.size()
	_ws._history.record(history_label % total,_ws._undo.remove_with_holder.bind(holder), _ws._undo.restore_with_holder.bind(holder))

	var items: Array = []
	for created_id: String in created_ids:
		items.append(_ws._cards_by_id[created_id])
	for decor_id: String in decor_ids:
		items.append(_ws._decor_by_id[decor_id])
	_ws._selection.set_items(items, true)

	if write_failed:
		_ws._toast.show_message(tr("import.failed_partial") % created_ids.size(), true, AppWorkspace.VAULT_WARNING_HOLD)
	else:
		_ws._toast.show_message(tr(toast_key) % total, false, 1.2)
