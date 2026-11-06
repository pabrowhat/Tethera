class_name WorkspaceImport
extends RefCounted

const MODE_NEW: String = "new"
const MODE_MERGE: String = "merge"
const MODE_SKIP: String = "skip"

var _ws: AppWorkspace = null

func _init(workspace: AppWorkspace) -> void:
	_ws = workspace

func import_selection(bundle: Dictionary, ids: Array[String], include_linked: bool, path: String) -> void:
	var file_notes: Array[Dictionary] = bundle["notes"]
	var file_links: Array[Dictionary] = bundle["connections"]
	var file_types: Array[Dictionary] = bundle["types"]
	var selection: Dictionary = ProjectSelection.select(file_notes, file_links, file_types, ids, include_linked)
	var chosen: Array[Dictionary] = selection["notes"]
	if chosen.is_empty():
		_ws._toast.show_message(tr("import.none_selected"), true)
		return

	var planned: Dictionary = await _plan_types(selection["types"] as Array[Dictionary])
	if not bool(planned["ok"]):
		_ws._toast.show_message(tr("import.canceled"), false)
		return
	var plans: Dictionary = planned["plans"]
	var assets: Dictionary = bundle["assets"]
	var vault_images: Dictionary = {}
	var lost_images: int = 0
	for plan: Dictionary in plans.values():
		if str(plan["mode"]) != MODE_NEW:
			continue
		var new_type: EntityType = plan["type"]
		var type_asset: String = new_type.bg_image
		new_type.bg_image = NoteImages.localize_asset(type_asset, assets, _ws._storage, vault_images)
		if type_asset != "" and new_type.bg_image == "":
			lost_images += 1
	var created_types: Array[Dictionary] = _apply_type_plans(plans)

	var taken: Dictionary = {}
	for existing_id: String in _ws._cards_by_id:
		taken[existing_id] = true
	var rekeyed: Dictionary = ProjectBundle.rekey_ids(chosen, selection["connections"] as Array[Dictionary], taken)
	var new_notes: Array[Dictionary] = rekeyed["notes"]
	var new_links: Array[Dictionary] = rekeyed["connections"]

	var renamed_titles: int = _rename_clashing_titles(new_notes)
	var offset: Vector2 = _centering_offset(new_notes)
	var inline_stored: Dictionary = {}
	var created_ids: Array[String] = []
	var placed_notes: Array[Dictionary] = []
	var write_failed: bool = false
	for note: Dictionary in new_notes:
		var asset_name: String = str(note.get("image", ""))
		var vault_path: String = ""
		if asset_name != "" and assets.has(asset_name):
			if not vault_images.has(asset_name):
				vault_images[asset_name] = _ws._storage.store_image_bytes(asset_name, assets[asset_name] as PackedByteArray)
			vault_path = str(vault_images[asset_name])
		if asset_name != "" and vault_path == "":
			lost_images += 1
		note["image"] = vault_path
		var bg_asset: String = str(note.get("bg_image", ""))
		note["bg_image"] = NoteImages.localize_asset(bg_asset, assets, _ws._storage, vault_images)
		if bg_asset != "" and str(note["bg_image"]) == "":
			lost_images += 1
		note["content"] = NoteImages.localize_inline(str(note.get("content", "")), assets, _ws._storage, inline_stored)
		note["pos"] = (note.get("pos", Vector2.ZERO) as Vector2) + offset
		_remap_type(note, plans)

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
	write_failed = not _ws._storage.save_connections(_ws._graph.get_all_connections()) or write_failed
	write_failed = not _ws._storage.save_types(_ws._types.to_array()) or write_failed
	_ws._pin_positions(placed_notes)
	if _ws._active_search_query != "":
		_ws._search.on_search_text_changed(_ws._active_search_query)

	if not created_ids.is_empty() or not created_types.is_empty():
		var holder: Dictionary = {"ids": created_ids, "state": _ws._undo.capture(created_ids), "types": created_types}
		_ws._history.record(tr("import.history") % created_ids.size(), undo_import.bind(holder), redo_import.bind(holder))
	if write_failed:
		_ws._toast.show_message(tr("import.failed_partial") % created_ids.size(), true, AppWorkspace.VAULT_WARNING_HOLD)
		return

	var problems: PackedStringArray = PackedStringArray()
	if int(bundle["skipped_notes"]) > 0:
		problems.append(tr("import.problem.skipped") % int(bundle["skipped_notes"]))
	if lost_images > 0:
		problems.append(tr("import.problem.images") % lost_images)
	var refused: Dictionary = bundle["refused_assets"]
	var lost_inline: int = NoteImages.failed_count(inline_stored, refused)
	if lost_inline > 0:
		problems.append(tr("import.problem.inline_images") % lost_inline)
	if not refused.is_empty():
		problems.append(tr("import.problem.refused_images") % refused.size())
	if renamed_titles > 0:
		problems.append(tr("import.problem.renamed") % renamed_titles)
	var message: String = tr("import.done") % [created_ids.size(), path.get_file()]
	if problems.is_empty():
		_ws._toast.show_message(message)
	else:
		_ws._toast.show_message("%s — %s" % [message, ", ".join(problems)], true)


func _plan_types(file_types: Array[Dictionary]) -> Dictionary:
	var parsed: Array[EntityType] = []
	for entry: Dictionary in file_types:
		var parsed_type: EntityType = EntityType.from_dict(entry)
		if parsed_type != null:
			parsed.append(parsed_type)

	var conflicts_total: int = 0
	for file_type: EntityType in parsed:
		if _ws._types.find_by_name(file_type.name) != null:
			conflicts_total += 1

	var plans: Dictionary = {}
	var claimed: Dictionary = {}
	var asked: int = 0
	for file_type: EntityType in parsed:
		var existing: EntityType = _ws._types.find_by_name(file_type.name)
		var wanted: String = file_type.name.strip_edges().to_lower()
		if existing == null and not claimed.has(wanted):
			plans[file_type.id] = _new_plan(file_type)
			claimed[wanted] = true
			continue

		asked += 1
		var is_taken: Callable = func(candidate: String) -> bool:
			return _ws._types.find_by_name(candidate) != null or claimed.has(candidate.strip_edges().to_lower())
		_ws._type_conflict.ask(file_type.name, asked, maxi(conflicts_total, asked), _free_name(file_type.name, is_taken), is_taken, existing != null)
		var decision: Dictionary = await _ws._type_conflict.resolved

		match int(decision["choice"]):
			TypeConflictDialog.Choice.CANCEL:
				return {"ok": false, "plans": {}}
			TypeConflictDialog.Choice.SKIP:
				plans[file_type.id] = {"mode": MODE_SKIP, "type": null, "field_map": {}, "to_add": []}
			TypeConflictDialog.Choice.RENAME:
				var renamed: EntityType = EntityType.from_dict(file_type.to_dict())
				renamed.name = str(decision["name"])
				plans[file_type.id] = _new_plan(renamed)
				claimed[renamed.name.to_lower()] = true
			TypeConflictDialog.Choice.MERGE:
				plans[file_type.id] = _merge_plan(file_type, existing)
	return {"ok": true, "plans": plans}

func _new_plan(entity_type: EntityType) -> Dictionary:
	return {"mode": MODE_NEW, "type": entity_type, "field_map": {}, "to_add": []}

func _merge_plan(file_type: EntityType, target: EntityType) -> Dictionary:
	var field_map: Dictionary = {}
	var to_add: Array[FieldDef] = []
	for field: FieldDef in file_type.fields:
		var match_field: FieldDef = _matching_field(target, field)
		if match_field != null:
			field_map[field.key] = match_field.key
		elif not field.removed:
			to_add.append(field)
	return {"mode": MODE_MERGE, "type": target, "field_map": field_map, "to_add": to_add}

func _matching_field(target: EntityType, field: FieldDef) -> FieldDef:
	var by_label: FieldDef = null
	for candidate: FieldDef in target.fields:
		if candidate.removed and not field.removed:
			continue
		if candidate.kind != field.kind:
			continue
		if candidate.key == field.key:
			return candidate
		if by_label == null and candidate.label.to_lower() == field.label.to_lower():
			by_label = candidate
	return by_label

func _free_name(base: String, is_taken: Callable) -> String:
	var counter: int = 2
	var candidate: String = "%s (%d)" % [base, counter]
	while bool(is_taken.call(candidate)):
		counter += 1
		candidate = "%s (%d)" % [base, counter]
	return candidate

func _apply_type_plans(plans: Dictionary) -> Array[Dictionary]:
	var created: Array[Dictionary] = []
	for file_type_id: String in plans:
		var plan: Dictionary = plans[file_type_id]
		var plan_type: EntityType = plan["type"]
		match str(plan["mode"]):
			MODE_NEW:
				if _ws._types.find(plan_type.id) != null:
					plan_type.id = UuidUtil.generate_v4()
				if _ws._types.add_type(plan_type):
					created.append(plan_type.to_dict())
			MODE_MERGE:
				var field_map: Dictionary = plan["field_map"]
				for field: FieldDef in (plan["to_add"] as Array[FieldDef]):
					var added: FieldDef = _ws._types.add_field(plan_type.id, field.label, field.kind)
					if added != null:
						field_map[field.key] = added.key
	return created

func _remap_type(note: Dictionary, plans: Dictionary) -> void:
	var file_type_id: String = str(note.get("type", ""))
	if file_type_id == "":
		return
	if not plans.has(file_type_id):
		note["type"] = ""
		return
	var plan: Dictionary = plans[file_type_id]
	if str(plan["mode"]) == MODE_SKIP:
		note["type"] = ""
		return

	var plan_type: EntityType = plan["type"]
	note["type"] = plan_type.id
	if str(plan["mode"]) == MODE_MERGE:
		var field_map: Dictionary = plan["field_map"]
		var values: Dictionary = note.get("fields", {})
		var mapped: Dictionary = {}
		for key: Variant in values:
			mapped[str(field_map.get(str(key), str(key)))] = values[key]
		note["fields"] = mapped


func _rename_clashing_titles(notes: Array[Dictionary]) -> int:
	var existing: Dictionary = {}
	for card: GraphCard in _ws._cards_by_id.values():
		if is_instance_valid(card):
			existing[card.title_label.text.strip_edges().to_lower()] = true

	return NoteClipboard.rename_clashing_titles(notes, existing)


func undo_import(holder: Dictionary) -> void:
	_ws._undo.remove_with_holder(holder)
	for type_data: Dictionary in (holder["types"] as Array[Dictionary]):
		var type_id: String = str(type_data.get("id", ""))
		if _ws._types.find(type_id) != null and _ws._type_ops.count_notes_of_type(type_id) == 0:
			_ws._types.remove(type_id)
	_ws.sidebar_editor.refresh_type_section()

func redo_import(holder: Dictionary) -> void:
	for type_data: Dictionary in (holder["types"] as Array[Dictionary]):
		if _ws._types.find(str(type_data.get("id", ""))) == null:
			_ws._types.add_type(EntityType.from_dict(type_data))
	_ws._undo.restore_with_holder(holder)


func _centering_offset(notes: Array[Dictionary]) -> Vector2:
	var low: Vector2 = Vector2(INF, INF)
	var high: Vector2 = Vector2(-INF, -INF)
	for note: Dictionary in notes:
		var pos: Vector2 = note.get("pos", Vector2.ZERO)
		low = low.min(pos)
		high = high.max(pos + GraphCard.BASE_MIN_SIZE)
	var now_center: Vector2 = (low + high) / 2.0
	var view_center: Vector2 = _ws.navigator.screen_to_canvas(_ws.get_viewport_rect().size / 2.0)
	return view_center - now_center
