class_name WorkspaceLinks
extends RefCounted

var _ws: AppWorkspace = null
var _shown: Array[Dictionary] = []

func _init(workspace: AppWorkspace) -> void:
	_ws = workspace

func note_views() -> Array[Dictionary]:
	var views: Array[Dictionary] = []
	for id: String in _ws._cards_by_id:
		var card: GraphCard = _ws._cards_by_id[id]
		if is_instance_valid(card):
			views.append({"id": id, "title": card.title_label.text, "content": card.content_text})
	return views

func reset() -> void:
	_ws._link_mismatch_pending.clear()
	_shown.clear()
	if is_instance_valid(_ws._link_dialog) and _ws._link_dialog.is_open():
		_ws._link_dialog.close()

func reconcile() -> void:
	if _ws._storage == null:
		return
	var rows: Array[Dictionary] = LinkReconciler.mismatches(note_views(), _ws._graph.get_all_connections())
	_prune_pending(rows)
	var plan: Dictionary = LinkReconciler.plan_rows(rows, _ws._link_mismatch_pending)
	var added: Array[Dictionary] = plan["add"]
	var removed: Array[Dictionary] = plan["remove"]
	if added.is_empty() and removed.is_empty():
		return
	_ws._saving_links_paused = true
	for link: Dictionary in removed:
		_ws._graph.remove_link(str(link["from"]), str(link["to"]))
	for link: Dictionary in added:
		_ws._graph.add_directed_link(str(link["from"]), str(link["to"]), GraphNetwork.KIND_WIKI)
	_ws._saving_links_paused = false
	_ws._storage.save_connections(_ws._graph.get_all_connections())

func _prune_pending(rows: Array[Dictionary]) -> void:
	var live: Dictionary = {}
	for row: Dictionary in rows:
		live[LinkReconciler.row_key(row)] = true
	for key: String in _ws._link_mismatch_pending.keys():
		if not live.has(key):
			_ws._link_mismatch_pending.erase(key)

func rewrite_after_rename(card_id: String, old_title: String, new_title: String) -> void:
	var renamed: GraphCard = _ws._cards_by_id.get(card_id, null)
	if not is_instance_valid(renamed):
		return
	var old_key: String = LinkReconciler.title_key(old_title)
	var homonym: bool = false
	for id: String in _ws._cards_by_id:
		var other: GraphCard = _ws._cards_by_id[id]
		if id != card_id and is_instance_valid(other) and LinkReconciler.title_key(other.title_label.text) == old_key:
			homonym = true
			break

	var edits: Array[Dictionary] = []
	var failed: int = 0
	for id: String in _ws._cards_by_id:
		if id == card_id:
			continue
		var card: GraphCard = _ws._cards_by_id[id]
		if not is_instance_valid(card):
			continue
		if homonym and not _ws._graph.are_connected(card_id, id):
			continue
		var before: String = card.content_text
		var after: String = WikiLink.replace_title(before, old_title, new_title)
		if after == before:
			continue
		if _write_text(card, after):
			edits.append({"id": id, "before": before, "after": after})
		else:
			failed += 1
			_ws._link_mismatch_pending[LinkReconciler.pair_key(card_id, id)] = true

	if not edits.is_empty():
		var state: Dictionary = {"id": card_id, "old": old_title, "new": new_title, "edits": edits}
		_ws._history.record(tr("history.rename_links") % edits.size(), _apply_rename.bind(state, true), _apply_rename.bind(state, false))
	if failed > 0:
		_ws._toast.show_message(tr("links.rename.failed") % failed, true, AppWorkspace.VAULT_WARNING_HOLD)
	reconcile()

func _apply_rename(state: Dictionary, undo: bool) -> void:
	_set_title(str(state["id"]), str(state["old"]) if undo else str(state["new"]))
	for edit: Dictionary in (state["edits"] as Array[Dictionary]):
		var card: GraphCard = _ws._cards_by_id.get(str(edit["id"]), null)
		if is_instance_valid(card):
			_write_text(card, str(edit["before"]) if undo else str(edit["after"]))
	reconcile()

func _set_title(card_id: String, title: String) -> void:
	var card: GraphCard = _ws._cards_by_id.get(card_id, null)
	if not is_instance_valid(card):
		return
	card.title_label.text = title
	card.title_edit.text = title
	card.refresh_compact_layout()
	_ws._last_titles[card_id] = title
	_ws.sidebar_editor.update_card_title_from_external(card, title)
	_ws._save_card(card)
	_ws._refresh_flipped_back_faces()

func _write_text(card: GraphCard, text: String) -> bool:
	var previous: String = card.content_text
	var previous_modified: int = card.modified_at
	card.set_content(text)
	card.modified_at = _ws._now()
	if not _ws._save_card(card):
		card.set_content(previous)
		card.modified_at = previous_modified
		return false
	_ws._last_contents[card.card_id] = text
	if card.is_flipped:
		_ws._refresh_back_face(card)
	card.refresh_compact_layout()
	_ws.sidebar_editor.refresh_content(card)
	return true

func toggle_drawn(id_a: String, id_b: String) -> void:
	var graph: GraphNetwork = _ws._graph
	var existing: Dictionary = graph.get_link(id_a, id_b)
	if existing.is_empty():
		if not graph.toggle_connection(id_a, id_b):
			return
		var created: Array[Dictionary] = [graph.get_link(id_a, id_b)]
		_ws._history.record(tr("history.link.create"), graph.remove_link.bind(id_a, id_b), graph.restore_links.bind(created))
		return
	if not GraphNetwork.is_drawn(existing):
		graph.set_drawn(id_a, id_b, true)
		_ws._history.record(tr("links.history.draw"), graph.set_drawn.bind(id_a, id_b, false), graph.set_drawn.bind(id_a, id_b, true))
		return
	var one: Array[Dictionary] = [existing]
	if LinkReconciler.supported_pairs(note_views(), one).has(LinkReconciler.pair_key(id_a, id_b)):
		graph.set_drawn(id_a, id_b, false)
		_ws._history.record(tr("links.history.undraw"), graph.set_drawn.bind(id_a, id_b, true), graph.set_drawn.bind(id_a, id_b, false))
		return
	graph.remove_link(id_a, id_b)
	var removed: Array[Dictionary] = [existing]
	_ws._history.record(tr("history.link.delete"), graph.restore_links.bind(removed), graph.remove_link.bind(id_a, id_b))

func scan_world(only_ids: Array[String] = []) -> void:
	var rows: Array[Dictionary] = LinkReconciler.mismatches(note_views(), _ws._graph.get_all_connections(), only_ids)
	for row: Dictionary in rows:
		_ws._link_mismatch_pending[LinkReconciler.row_key(row)] = true
	show_dialog_if_ready()

func pending_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for row: Dictionary in LinkReconciler.mismatches(note_views(), _ws._graph.get_all_connections()):
		if _ws._link_mismatch_pending.has(LinkReconciler.row_key(row)):
			rows.append(row)
	return rows

func show_dialog_if_ready() -> void:
	if _ws._link_mismatch_pending.is_empty() or _ws._storage == null:
		return
	if _ws._is_modal_open():
		return
	var rows: Array[Dictionary] = pending_rows()
	if rows.is_empty():
		_ws._link_mismatch_pending.clear()
		return
	var titles: Dictionary = {}
	for view: Dictionary in note_views():
		titles[str(view["id"])] = str(view["title"])
	_shown = rows
	_ws._link_dialog.open_rows(rows, titles)

func on_dialog_closed() -> void:
	_ws._world_flow.show_whats_new_if_due.call_deferred()

func apply_choices(choices: Dictionary) -> void:
	var graph: GraphNetwork = _ws._graph
	var links_before: Array[Dictionary] = _snapshot_links()
	var text_edits: Dictionary = {}
	var resolved: Array[String] = []
	var failed: int = 0
	_ws._saving_links_paused = true
	for index_value: Variant in choices:
		var index: int = int(index_value)
		if index < 0 or index >= _shown.size():
			continue
		var row: Dictionary = _shown[index]
		var keep: bool = bool(choices[index_value])
		var from_id: String = str(row["from"])
		var to_id: String = str(row["to"])
		var is_stale: bool = str(row["kind"]) == LinkReconciler.ROW_STALE
		if is_stale and keep:
			graph.set_drawn(from_id, to_id, true)
		elif is_stale:
			graph.remove_link(from_id, to_id)
		elif keep:
			graph.add_directed_link(from_id, to_id, GraphNetwork.KIND_WIKI)
		else:
			var card: GraphCard = _ws._cards_by_id.get(from_id, null)
			if not is_instance_valid(card):
				continue
			var before: String = card.content_text
			var after: String = WikiLink.unlink_title(before, str(row["title"]))
			if after != before:
				if not _write_text(card, after):
					failed += 1
					continue
				if text_edits.has(from_id):
					(text_edits[from_id] as Dictionary)["after"] = after
				else:
					text_edits[from_id] = {"id": from_id, "before": before, "after": after}
		resolved.append(LinkReconciler.row_key(row))
	_ws._saving_links_paused = false
	for key: String in resolved:
		_ws._link_mismatch_pending.erase(key)

	var links_after: Array[Dictionary] = _snapshot_links()
	_ws._storage.save_connections(graph.get_all_connections())
	if not resolved.is_empty():
		var edits: Array[Dictionary] = []
		for edit: Variant in text_edits.values():
			edits.append(edit as Dictionary)
		var state: Dictionary = {"links_before": links_before, "links_after": links_after, "edits": edits, "keys": resolved}
		_ws._history.record(tr("history.link_mismatch") % resolved.size(), _apply_mismatch_state.bind(state, true), _apply_mismatch_state.bind(state, false))
		_ws._toast.show_message(tr("links.mismatch.done") % resolved.size())
	if failed > 0:
		_ws._toast.show_message(tr("links.mismatch.failed") % failed, true, AppWorkspace.VAULT_WARNING_HOLD)
	on_dialog_closed()

func _apply_mismatch_state(state: Dictionary, undo: bool) -> void:
	_ws._saving_links_paused = true
	_ws._graph.load_from_data((state["links_before"] if undo else state["links_after"]) as Array[Dictionary])
	_ws._saving_links_paused = false
	for edit: Dictionary in (state["edits"] as Array[Dictionary]):
		var card: GraphCard = _ws._cards_by_id.get(str(edit["id"]), null)
		if is_instance_valid(card):
			_write_text(card, str(edit["before"]) if undo else str(edit["after"]))
	for key: String in (state["keys"] as Array[String]):
		if undo:
			_ws._link_mismatch_pending[key] = true
		else:
			_ws._link_mismatch_pending.erase(key)
	_ws._storage.save_connections(_ws._graph.get_all_connections())

func _snapshot_links() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for link: Dictionary in _ws._graph.get_all_connections():
		copy.append(link.duplicate())
	return copy
