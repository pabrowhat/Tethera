class_name NoteClipboard
extends RefCounted


var _notes: Array[Dictionary] = []
var _links: Array[Dictionary] = []
var _decor: Array[Dictionary] = []
var paste_count: int = 0

func set_content(notes: Array[Dictionary], links: Array[Dictionary], decor: Array[Dictionary]) -> void:
	_notes.clear()
	_links.clear()
	_decor.clear()
	for note: Dictionary in notes:
		_notes.append(note.duplicate(true))
	for link: Dictionary in links:
		_links.append(link.duplicate(true))
	for item: Dictionary in decor:
		_decor.append(item.duplicate(true))
	paste_count = 0

func is_empty() -> bool:
	return _notes.is_empty() and _decor.is_empty()

func clear() -> void:
	set_content([], [], [])

func note_count() -> int:
	return _notes.size()

func item_count() -> int:
	return _notes.size() + _decor.size()

func build_paste(taken_ids: Dictionary, offset: Vector2, existing_titles: Dictionary, now: int) -> Dictionary:
	if is_empty():
		return {"notes": [] as Array[Dictionary], "connections": [] as Array[Dictionary], "decor": [] as Array[Dictionary], "renamed": 0}
	var rekeyed: Dictionary = ProjectBundle.rekey_ids(_notes, _links, taken_ids)
	var new_notes: Array[Dictionary] = rekeyed["notes"]
	var renamed: int = rename_clashing_titles(new_notes, existing_titles)
	for note: Dictionary in new_notes:
		note["pos"] = (note.get("pos", Vector2.ZERO) as Vector2) + offset
		note["created"] = now
		note["modified"] = now

	var new_decor: Array[Dictionary] = []
	for item: Dictionary in _decor:
		var copy: Dictionary = item.duplicate(true)
		copy["id"] = UuidUtil.generate_v4()
		var pos: Variant = copy.get("pos", [0.0, 0.0])
		if pos is Array and (pos as Array).size() >= 2:
			copy["pos"] = [float((pos as Array)[0]) + offset.x, float((pos as Array)[1]) + offset.y]
		new_decor.append(copy)
	return {"notes": new_notes, "connections": rekeyed["connections"], "decor": new_decor, "renamed": renamed}

static func rename_clashing_titles(notes: Array[Dictionary], existing: Dictionary) -> int:
	var taken: Dictionary = existing.duplicate()
	for note: Dictionary in notes:
		taken[str(note.get("title", "")).strip_edges().to_lower()] = true

	var renames: Dictionary = {}
	var renamed: int = 0
	for note: Dictionary in notes:
		var title: String = str(note.get("title", "")).strip_edges()
		var key: String = title.to_lower()
		if not existing.has(key):
			continue
		var counter: int = 2
		var candidate: String = "%s (%d)" % [title, counter]
		while taken.has(candidate.to_lower()):
			counter += 1
			candidate = "%s (%d)" % [title, counter]
		taken[candidate.to_lower()] = true
		note["title"] = candidate
		if not renames.has(key):
			renames[key] = candidate
		renamed += 1

	if renames.is_empty():
		return 0
	for note: Dictionary in notes:
		var content: String = str(note.get("content", ""))
		for old_key: String in renames:
			content = WikiLink.replace_title(content, old_key, str(renames[old_key]))
		note["content"] = content
	return renamed
