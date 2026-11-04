class_name CanvasSearch
extends RefCounted

var _ws: AppWorkspace = null

func _init(workspace: AppWorkspace) -> void:
	_ws = workspace

func _card_matches_search(card: GraphCard, query: String) -> bool:
	return FuzzyMatcher.score(query, card.title_label.text) >= 0 or card.content_text.to_lower().contains(query)

func on_search_text_changed(new_text: String) -> void:
	_ws._active_search_query = new_text.strip_edges().to_lower()

	for card: GraphCard in _ws._cards_by_id.values():
		if is_instance_valid(card):
			var matches: bool = _ws._active_search_query == "" or _card_matches_search(card, _ws._active_search_query)
			card.set_search_alpha(1.0 if matches else 0.2)

func on_search_input_changed(new_text: String) -> void:
	on_search_text_changed(new_text)
	_refresh_search_popup()

func build_search_popup() -> void:
	_ws._search_popup = LinkAutocompletePopup.new()
	_ws._search_popup.max_height = 300.0
	_ws.get_node("UI").add_child(_ws._search_popup)

func _refresh_search_popup() -> void:
	if _ws._active_search_query == "" or not _ws.search_input.has_focus():
		close_search_popup()
		return

	var candidates: Array[Dictionary] = []
	for card: GraphCard in _ws._cards_by_id.values():
		if is_instance_valid(card):
			candidates.append({"id": card.card_id, "title": card.title_label.text})
	var results: Array[Dictionary] = FuzzyMatcher.rank(_ws._active_search_query, candidates, candidates.size())

	var listed: Dictionary = {}
	for item: Dictionary in results:
		listed[item["id"]] = true
	for item: Dictionary in candidates:
		var card: GraphCard = _ws._cards_by_id.get(item["id"], null)
		if not listed.has(item["id"]) and is_instance_valid(card) and card.content_text.to_lower().contains(_ws._active_search_query):
			results.append({"id": item["id"], "title": item["title"]})
	for item: Dictionary in results:
		if str(item["title"]).strip_edges() == "":
			item["title"] = tr("note.untitled")

	var rect: Rect2 = _ws.search_input.get_global_rect()
	_ws._search_popup.set_popup_width(rect.size.x)
	_ws._search_popup.update_results(results)
	_ws._search_popup.open_at(rect.position, rect.size.y)

func close_search_popup() -> void:
	if is_instance_valid(_ws._search_popup) and _ws._search_popup.is_open():
		_ws._search_popup.close()

func on_search_input_gui_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not (event as InputEventKey).pressed or not _ws._search_popup.is_open():
		return
	match (event as InputEventKey).keycode:
		KEY_DOWN:
			_ws._search_popup.move_selection(1)
			_ws.search_input.accept_event()
		KEY_UP:
			_ws._search_popup.move_selection(-1)
			_ws.search_input.accept_event()

func on_search_result_chosen(card_id: String, _title: String) -> void:
	var card: GraphCard = _ws._cards_by_id.get(card_id, null)
	_ws.search_input.text = ""
	on_search_text_changed("")
	close_search_popup()
	_ws.search_input.release_focus()
	if not is_instance_valid(card):
		return
	_ws.focus_and_open_card(card)

func on_search_text_submitted(_text: String) -> void:
	if _ws._active_search_query == "":
		return
	if _ws._search_popup.is_open() and _ws._search_popup.has_items() and _ws._search_popup.confirm():
		return

	for card: GraphCard in _ws._cards_by_id.values():
		if is_instance_valid(card) and _card_matches_search(card, _ws._active_search_query):
			var viewport_size: Vector2 = _ws.get_viewport_rect().size
			var target_zoom: float = clampf(_ws.navigator.get_zoom(), 0.8, 1.4)
			_ws.navigator.focus_to_point(card.position + (card.size / 2.0), target_zoom, viewport_size / 2.0)
			break
