class_name GraphNetwork
extends RefCounted

signal network_changed
signal link_created(from_id: String, to_id: String)
signal link_reinforced(from_id: String, to_id: String)
signal link_removed(from_id: String, to_id: String)

enum LinkResult { CREATED, ALREADY_EXISTS, INVALID }

const KIND_MANUAL: String = "manual"
const KIND_WIKI: String = "wiki"
const KIND_RELATED: String = "related"

const STYLE_SOLID: String = "solid"
const STYLE_DASHED: String = "dashed"
const STYLE_DOTTED: String = "dotted"
const STYLE_DASH_DOT: String = "dash_dot"
const STYLE_DOUBLE: String = "double"
const STYLES: PackedStringArray = ["solid", "dashed", "dotted", "dash_dot", "double"]

var _connections: Array[Dictionary] = []
var _adjacency: Dictionary = {}

static func default_style(kind: String) -> String:
	return STYLE_DASHED if kind == KIND_RELATED else STYLE_SOLID

static func sanitize_style(value: Variant, kind: String) -> String:
	var text: String = str(value) if value != null else ""
	return text if STYLES.has(text) else default_style(kind)

func load_from_data(data: Array[Dictionary]) -> void:
	_connections.clear()
	_adjacency.clear()
	for conn: Dictionary in data:
		var from_id: String = conn.get("from", "")
		var to_id: String = conn.get("to", "")
		var kind: String = str(conn.get("kind", KIND_MANUAL))
		if from_id != "" and to_id != "" and from_id != to_id:
			if not are_connected(from_id, to_id):
				_raw_add(from_id, to_id, kind, sanitize_style(conn.get("style", null), kind))
	network_changed.emit()

func get_all_connections() -> Array[Dictionary]:
	return _connections

func are_connected(id_a: String, id_b: String) -> bool:
	if not _adjacency.has(id_a):
		return false
	var neighbors: Dictionary = _adjacency[id_a] as Dictionary
	return neighbors.has(id_b)

func get_neighbors(node_id: String) -> Array[String]:
	var result: Array[String] = []
	if _adjacency.has(node_id):
		for neighbor_id: String in (_adjacency[node_id] as Dictionary):
			result.append(neighbor_id)
	return result

func get_outgoing(node_id: String, kind: String = "") -> Array[String]:
	var result: Array[String] = []
	for conn: Dictionary in _connections:
		if conn.get("from", "") == node_id and (kind == "" or conn.get("kind", KIND_MANUAL) == kind):
			result.append(conn.get("to", ""))
	return result

func get_backlinks(node_id: String, kind: String = "") -> Array[String]:
	var result: Array[String] = []
	for conn: Dictionary in _connections:
		if conn.get("to", "") == node_id and (kind == "" or conn.get("kind", KIND_MANUAL) == kind):
			result.append(conn.get("from", ""))
	return result

func get_inbound_links(node_id: String) -> Array[String]:
	var result: Array[String] = []
	for conn: Dictionary in _connections:
		var from_id: String = conn.get("from", "")
		var to_id: String = conn.get("to", "")
		var is_wiki: bool = conn.get("kind", KIND_MANUAL) == KIND_WIKI
		var other_id: String = ""
		if to_id == node_id:
			other_id = from_id
		elif from_id == node_id and not is_wiki:
			other_id = to_id
		if other_id != "" and not result.has(other_id):
			result.append(other_id)
	return result

func add_directed_link(from_id: String, to_id: String, kind: String = KIND_WIKI) -> LinkResult:
	if from_id == "" or to_id == "" or from_id == to_id:
		return LinkResult.INVALID

	if are_connected(from_id, to_id):
		link_reinforced.emit(from_id, to_id)
		return LinkResult.ALREADY_EXISTS

	_raw_add(from_id, to_id, kind, default_style(kind))
	network_changed.emit()
	link_created.emit(from_id, to_id)
	return LinkResult.CREATED

func toggle_connection(id_a: String, id_b: String) -> bool:
	if id_a == "" or id_b == "" or id_a == id_b:
		return false

	if remove_link(id_a, id_b):
		return false

	_raw_add(id_a, id_b, KIND_MANUAL, default_style(KIND_MANUAL))
	network_changed.emit()
	link_created.emit(id_a, id_b)
	return true

func get_link(id_a: String, id_b: String) -> Dictionary:
	for conn: Dictionary in _connections:
		var from_id: String = conn.get("from", "")
		var to_id: String = conn.get("to", "")
		if (from_id == id_a and to_id == id_b) or (from_id == id_b and to_id == id_a):
			return conn.duplicate()
	return {}

func get_links_of(node_ids: Array[String]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for conn: Dictionary in _connections:
		if node_ids.has(str(conn.get("from", ""))) or node_ids.has(str(conn.get("to", ""))):
			result.append(conn.duplicate())
	return result

func remove_link(id_a: String, id_b: String) -> bool:
	if not are_connected(id_a, id_b):
		return false
	_raw_remove(id_a, id_b)
	network_changed.emit()
	link_removed.emit(id_a, id_b)
	return true

func restore_links(links: Array[Dictionary]) -> void:
	var added: Array[Dictionary] = []
	for conn: Dictionary in links:
		var from_id: String = str(conn.get("from", ""))
		var to_id: String = str(conn.get("to", ""))
		if from_id == "" or to_id == "" or from_id == to_id or are_connected(from_id, to_id):
			continue
		var kind: String = str(conn.get("kind", KIND_MANUAL))
		_raw_add(from_id, to_id, kind, sanitize_style(conn.get("style", null), kind))
		added.append(conn)

	if added.is_empty():
		return
	network_changed.emit()
	for conn: Dictionary in added:
		link_created.emit(str(conn["from"]), str(conn["to"]))

func remove_node(node_id: String) -> void:
	if not _adjacency.has(node_id):
		return

	var neighbors_dict: Dictionary = (_adjacency[node_id] as Dictionary).duplicate()
	for neighbor_id: String in neighbors_dict:
		_raw_remove(node_id, neighbor_id)

	_adjacency.erase(node_id)
	network_changed.emit()

func remove_nodes(node_ids: Array[String]) -> void:
	var changed: bool = false
	for node_id: String in node_ids:
		if not _adjacency.has(node_id):
			continue
		var neighbors_dict: Dictionary = (_adjacency[node_id] as Dictionary).duplicate()
		for neighbor_id: String in neighbors_dict:
			_raw_remove(node_id, neighbor_id)
		_adjacency.erase(node_id)
		changed = true

	if changed:
		network_changed.emit()

static func is_drawn(link: Dictionary) -> bool:
	return LinkReconciler.is_drawn(link)

func set_drawn(id_a: String, id_b: String, drawn: bool) -> bool:
	for conn: Dictionary in _connections:
		var from_id: String = conn.get("from", "")
		var to_id: String = conn.get("to", "")
		if (from_id == id_a and to_id == id_b) or (from_id == id_b and to_id == id_a):
			if is_drawn(conn) == drawn:
				return false
			conn["kind"] = KIND_MANUAL if drawn else KIND_WIKI
			network_changed.emit()
			return true
	return false

func get_link_style(id_a: String, id_b: String) -> String:
	var link: Dictionary = get_link(id_a, id_b)
	if link.is_empty():
		return ""
	return sanitize_style(link.get("style", null), str(link.get("kind", KIND_MANUAL)))

func set_link_style(id_a: String, id_b: String, style: String) -> bool:
	if not STYLES.has(style):
		return false
	for conn: Dictionary in _connections:
		var from_id: String = conn.get("from", "")
		var to_id: String = conn.get("to", "")
		if (from_id == id_a and to_id == id_b) or (from_id == id_b and to_id == id_a):
			if conn.get("style", "") == style:
				return false
			conn["style"] = style
			network_changed.emit()
			return true
	return false

func _raw_add(id_a: String, id_b: String, kind: String = KIND_MANUAL, style: String = STYLE_SOLID) -> void:
	if not _adjacency.has(id_a):
		_adjacency[id_a] = {}
	if not _adjacency.has(id_b):
		_adjacency[id_b] = {}

	(_adjacency[id_a] as Dictionary)[id_b] = true
	(_adjacency[id_b] as Dictionary)[id_a] = true
	_connections.append({"from": id_a, "to": id_b, "kind": kind, "style": style})

func _raw_remove(id_a: String, id_b: String) -> void:
	if _adjacency.has(id_a):
		(_adjacency[id_a] as Dictionary).erase(id_b)
		if (_adjacency[id_a] as Dictionary).is_empty():
			_adjacency.erase(id_a)

	if _adjacency.has(id_b):
		(_adjacency[id_b] as Dictionary).erase(id_a)
		if (_adjacency[id_b] as Dictionary).is_empty():
			_adjacency.erase(id_b)

	for i: int in range(_connections.size() - 1, -1, -1):
		var conn: Dictionary = _connections[i]
		var f: String = conn.get("from", "")
		var t: String = conn.get("to", "")
		if (f == id_a and t == id_b) or (f == id_b and t == id_a):
			_connections.remove_at(i)
			break
