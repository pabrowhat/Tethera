class_name LinkReconciler
extends RefCounted

const ROW_STALE: String = "stale_link"
const ROW_UNLINKED: String = "unlinked_text"
const KIND_WIKI: String = "wiki"

static func title_key(title: String) -> String:
	return title.strip_edges().to_lower()

static func pair_key(id_a: String, id_b: String) -> String:
	return id_a + "|" + id_b if id_a < id_b else id_b + "|" + id_a

static func is_drawn(link: Dictionary) -> bool:
	return str(link.get("kind", "manual")) != KIND_WIKI

static func marks(link: Dictionary, supported: bool) -> Dictionary:
	return {"from_text": supported, "drawn": is_drawn(link)}

static func supported_pairs(notes: Array[Dictionary], links: Array[Dictionary]) -> Dictionary:
	var title_of: Dictionary = {}
	var keys_in_text: Dictionary = {}
	for note: Dictionary in notes:
		var id: String = str(note.get("id", ""))
		title_of[id] = title_key(str(note.get("title", "")))
		var keys: Dictionary = {}
		for title: String in WikiLink.titles_in(str(note.get("content", ""))):
			keys[title_key(title)] = true
		keys_in_text[id] = keys
	var result: Dictionary = {}
	for link: Dictionary in links:
		var from_id: String = str(link.get("from", ""))
		var to_id: String = str(link.get("to", ""))
		if not title_of.has(from_id) or not title_of.has(to_id):
			continue
		var from_keys: Dictionary = keys_in_text[from_id]
		var to_keys: Dictionary = keys_in_text[to_id]
		if from_keys.has(title_of[to_id]) or to_keys.has(title_of[from_id]):
			result[pair_key(from_id, to_id)] = true
	return result

static func text_links_missing(notes: Array[Dictionary], links: Array[Dictionary]) -> Array[Dictionary]:
	var ids_by_key: Dictionary = {}
	for note: Dictionary in notes:
		var key: String = title_key(str(note.get("title", "")))
		if key == "":
			continue
		if not ids_by_key.has(key):
			ids_by_key[key] = [] as Array[String]
		(ids_by_key[key] as Array[String]).append(str(note.get("id", "")))
	var linked: Dictionary = {}
	for link: Dictionary in links:
		linked[pair_key(str(link.get("from", "")), str(link.get("to", "")))] = true
	var found: Array[Dictionary] = []
	var seen: Dictionary = {}
	for note: Dictionary in notes:
		var source_id: String = str(note.get("id", ""))
		for title: String in WikiLink.titles_in(str(note.get("content", ""))):
			var key: String = title_key(title)
			if not ids_by_key.has(key):
				continue
			var targets: Array[String] = []
			for candidate: String in (ids_by_key[key] as Array[String]):
				if candidate != source_id:
					targets.append(candidate)
			if targets.is_empty():
				continue
			var already: bool = false
			for target: String in targets:
				if linked.has(pair_key(source_id, target)):
					already = true
					break
			if already:
				continue
			var pk: String = pair_key(source_id, targets[0])
			if seen.has(pk):
				continue
			seen[pk] = true
			found.append({"kind": ROW_UNLINKED, "from": source_id, "to": targets[0], "title": title.strip_edges()})
	return found

static func stale_links(notes: Array[Dictionary], links: Array[Dictionary]) -> Array[Dictionary]:
	var supported: Dictionary = supported_pairs(notes, links)
	var known: Dictionary = {}
	for note: Dictionary in notes:
		known[str(note.get("id", ""))] = true
	var found: Array[Dictionary] = []
	for link: Dictionary in links:
		if is_drawn(link):
			continue
		var from_id: String = str(link.get("from", ""))
		var to_id: String = str(link.get("to", ""))
		if not known.has(from_id) or not known.has(to_id):
			continue
		if supported.has(pair_key(from_id, to_id)):
			continue
		found.append({"kind": ROW_STALE, "from": from_id, "to": to_id, "title": ""})
	return found

static func mismatches(notes: Array[Dictionary], links: Array[Dictionary], only_ids: Array[String] = []) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	rows.append_array(stale_links(notes, links))
	rows.append_array(text_links_missing(notes, links))
	if only_ids.is_empty():
		return rows
	var kept: Array[Dictionary] = []
	for row: Dictionary in rows:
		if only_ids.has(str(row["from"])) or only_ids.has(str(row["to"])):
			kept.append(row)
	return kept

static func row_key(row: Dictionary) -> String:
	return pair_key(str(row["from"]), str(row["to"]))

static func plan(notes: Array[Dictionary], links: Array[Dictionary], skip_pairs: Dictionary = {}) -> Dictionary:
	return plan_rows(mismatches(notes, links), skip_pairs)

static func plan_rows(rows: Array[Dictionary], skip_pairs: Dictionary = {}) -> Dictionary:
	var add: Array[Dictionary] = []
	var remove: Array[Dictionary] = []
	for row: Dictionary in rows:
		if skip_pairs.has(pair_key(str(row["from"]), str(row["to"]))):
			continue
		if str(row["kind"]) == ROW_UNLINKED:
			add.append({"from": row["from"], "to": row["to"]})
		else:
			remove.append({"from": row["from"], "to": row["to"]})
	return {"add": add, "remove": remove}
