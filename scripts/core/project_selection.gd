class_name ProjectSelection
extends RefCounted

const KIND_WIKI: String = "wiki"

static func select(notes: Array[Dictionary], connections: Array[Dictionary], types: Array[Dictionary], ids: Array[String], include_linked: bool) -> Dictionary:
	var known: Dictionary = {}
	for note: Dictionary in notes:
		known[str(note.get("id", ""))] = true

	var wanted: Dictionary = {}
	for id: String in ids:
		if known.has(id):
			wanted[id] = true

	var linked: Array[String] = []
	if include_linked:
		var selected_ids: Array[String] = []
		selected_ids.assign(wanted.keys())
		for linked_id: String in linked_ids(connections, selected_ids):
			if known.has(linked_id) and not wanted.has(linked_id):
				wanted[linked_id] = true
				linked.append(linked_id)

	var result_notes: Array[Dictionary] = []
	var result_ids: Array[String] = []
	var used_types: Dictionary = {}
	var image_seen: Dictionary = {}
	var images: PackedStringArray = PackedStringArray()
	for note: Dictionary in notes:
		var note_id: String = str(note.get("id", ""))
		if not wanted.has(note_id):
			continue
		result_notes.append(note)
		result_ids.append(note_id)

		var type_id: String = str(note.get("type", ""))
		if type_id != "":
			used_types[type_id] = true
		for image: String in NoteImages.used_paths(note):
			if not image_seen.has(image.get_file()):
				image_seen[image.get_file()] = true
				images.append(image)

	var result_types: Array[Dictionary] = []
	for entity_type: Dictionary in types:
		if used_types.has(str(entity_type.get("id", ""))):
			result_types.append(entity_type)

	for image: String in NoteImages.type_paths(result_types):
		if not image_seen.has(image.get_file()):
			image_seen[image.get_file()] = true
			images.append(image)

	var result_links: Array[Dictionary] = []
	for conn: Dictionary in connections:
		if wanted.has(str(conn.get("from", ""))) and wanted.has(str(conn.get("to", ""))):
			result_links.append(conn)

	return {
		"ids": result_ids,
		"linked_ids": linked,
		"notes": result_notes,
		"connections": result_links,
		"types": result_types,
		"images": images,
	}

static func linked_ids(connections: Array[Dictionary], ids: Array[String]) -> Array[String]:
	var inside: Dictionary = {}
	for id: String in ids:
		inside[id] = true

	var result: Array[String] = []
	var seen: Dictionary = {}
	for conn: Dictionary in connections:
		var from_id: String = str(conn.get("from", ""))
		var to_id: String = str(conn.get("to", ""))
		var is_wiki: bool = str(conn.get("kind", "manual")) == KIND_WIKI

		var other: String = ""
		if inside.has(from_id) and not inside.has(to_id):
			other = to_id
		elif inside.has(to_id) and not inside.has(from_id) and not is_wiki:
			other = from_id
		if other != "" and not seen.has(other):
			seen[other] = true
			result.append(other)
	return result
