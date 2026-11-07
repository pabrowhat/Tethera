class_name LayoutTemplates
extends RefCounted

const LEVEL_GAP: float = 60.0
const SIBLING_GAP: float = 40.0
const ROW_LIMIT: int = 12
const BLOCK_GAP: float = 120.0
const RING_START: float = 300.0
const RING_STEP: float = 220.0
const RING_MARGIN: float = 40.0
const DEFAULT_SIZE: Vector2 = Vector2(200.0, 120.0)

static func tree(ids: Array[String], links: Array[Dictionary], sizes: Dictionary, anchor: Vector2, horizontal: bool, spacing: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {}
	if ids.is_empty():
		return result
	var computed: Dictionary = {}
	var cursor_x: float = 0.0
	for levels: Array in _components(ids, links):
		var block: Dictionary = _layout_levels(levels, sizes, horizontal, _gap(spacing, "level_gap", LEVEL_GAP), _gap(spacing, "sibling_gap", SIBLING_GAP))
		var shift: float = cursor_x - float(block["min_x"])
		var block_pos: Dictionary = block["pos"]
		for id: String in block_pos:
			computed[id] = (block_pos[id] as Vector2) + Vector2(shift, 0.0)
		cursor_x += float(block["max_x"]) - float(block["min_x"]) + _gap(spacing, "block_gap", BLOCK_GAP)
	var root_center: Vector2 = (computed[ids[0]] as Vector2) + _size(sizes, ids[0], horizontal) / 2.0
	for id: String in computed:
		var local: Vector2 = (computed[id] as Vector2) - root_center
		result[id] = (Vector2(local.y, local.x) if horizontal else local) + anchor
	return result

static func orbit(ids: Array[String], sizes: Dictionary, anchor: Vector2, spacing: Dictionary = {}) -> Dictionary:
	var group: Array[String] = []
	group.assign(ids.slice(1))
	return _orbit_groups(ids, sizes, anchor, [group], _gap(spacing, "ring_step", RING_STEP))

static func orbit_by_type(ids: Array[String], sizes: Dictionary, types: Dictionary, type_order: Array[String], anchor: Vector2, spacing: Dictionary = {}) -> Dictionary:
	var by_type: Dictionary = {}
	var seen_unknown: Array[String] = []
	for i: int in range(1, ids.size()):
		var type_id: String = str(types.get(ids[i], ""))
		if not by_type.has(type_id):
			by_type[type_id] = [] as Array[String]
		(by_type[type_id] as Array[String]).append(ids[i])
		if type_id != "" and not type_order.has(type_id) and not seen_unknown.has(type_id):
			seen_unknown.append(type_id)
	var order: Array[String] = []
	order.append_array(type_order)
	order.append_array(seen_unknown)
	order.append("")
	var groups: Array = []
	for type_id: String in order:
		if by_type.has(type_id):
			groups.append(by_type[type_id])
	return _orbit_groups(ids, sizes, anchor, groups, _gap(spacing, "ring_step", RING_STEP))

static func count_overlaps(targets: Dictionary, sizes: Dictionary, others: Array[Rect2]) -> int:
	var count: int = 0
	for other: Rect2 in others:
		for id: String in targets:
			if other.intersects(Rect2(targets[id] as Vector2, sizes.get(id, DEFAULT_SIZE) as Vector2)):
				count += 1
				break
	return count


static func _gap(spacing: Dictionary, key: String, fallback: float) -> float:
	return float(spacing.get(key, fallback))

static func _size(sizes: Dictionary, id: String, horizontal: bool) -> Vector2:
	var size: Vector2 = sizes.get(id, DEFAULT_SIZE)
	return Vector2(size.y, size.x) if horizontal else size

static func _components(ids: Array[String], links: Array[Dictionary]) -> Array:
	var index: Dictionary = {}
	var adjacent: Dictionary = {}
	for i: int in ids.size():
		index[ids[i]] = i
		adjacent[ids[i]] = [] as Array[String]
	for link: Dictionary in links:
		var a: String = str(link.get("from", ""))
		var b: String = str(link.get("to", ""))
		if a == b or not index.has(a) or not index.has(b):
			continue
		if not (adjacent[a] as Array[String]).has(b):
			(adjacent[a] as Array[String]).append(b)
		if not (adjacent[b] as Array[String]).has(a):
			(adjacent[b] as Array[String]).append(a)
	for id: String in ids:
		(adjacent[id] as Array[String]).sort_custom(func(x: String, y: String) -> bool: return int(index[x]) < int(index[y]))

	var seen: Dictionary = {}
	var parts: Array = []
	for start: String in ids:
		if seen.has(start):
			continue
		seen[start] = true
		var levels: Array = []
		var frontier: Array[String] = [start]
		while not frontier.is_empty():
			levels.append(frontier)
			var next: Array[String] = []
			for id: String in frontier:
				for neighbour: String in (adjacent[id] as Array[String]):
					if not seen.has(neighbour):
						seen[neighbour] = true
						next.append(neighbour)
			frontier = next
		parts.append(levels)
	return parts

static func _layout_levels(levels: Array, sizes: Dictionary, horizontal: bool, level_gap: float, sibling_gap: float) -> Dictionary:
	var pos: Dictionary = {}
	var y: float = 0.0
	var min_x: float = 0.0
	var max_x: float = 0.0
	for level: Array in levels:
		var start: int = 0
		while start < level.size():
			var row: Array = level.slice(start, start + ROW_LIMIT)
			start += ROW_LIMIT
			var width: float = -sibling_gap
			var height: float = 0.0
			for id: String in row:
				var size: Vector2 = _size(sizes, id, horizontal)
				width += size.x + sibling_gap
				height = maxf(height, size.y)
			var x: float = -width / 2.0
			for id: String in row:
				var size: Vector2 = _size(sizes, id, horizontal)
				pos[id] = Vector2(x, y + (height - size.y) / 2.0)
				x += size.x + sibling_gap
			min_x = minf(min_x, -width / 2.0)
			max_x = maxf(max_x, width / 2.0)
			y += height + (sibling_gap if start < level.size() else level_gap)
	return {"pos": pos, "min_x": min_x, "max_x": max_x}


static func _orbit_groups(ids: Array[String], sizes: Dictionary, anchor: Vector2, groups: Array, ring_step_min: float) -> Dictionary:
	var result: Dictionary = {}
	if ids.is_empty():
		return result
	var root_size: Vector2 = sizes.get(ids[0], DEFAULT_SIZE)
	result[ids[0]] = anchor - root_size / 2.0

	var total: int = ids.size() - 1
	if total <= 0:
		return result
	var max_side: float = 0.0
	var max_half_diagonal: float = 0.0
	for i: int in range(1, ids.size()):
		var size: Vector2 = sizes.get(ids[i], DEFAULT_SIZE)
		max_side = maxf(max_side, maxf(size.x, size.y))
		max_half_diagonal = maxf(max_half_diagonal, size.length() / 2.0)
	var spacing: float = max_side + RING_MARGIN
	var first_radius: float = maxf(RING_START, root_size.length() / 2.0 + max_half_diagonal + RING_MARGIN)
	var ring_step: float = maxf(ring_step_min, spacing)
	var multi: bool = groups.size() > 1

	var done: Array[int] = []
	done.resize(groups.size())
	done.fill(0)
	var ring: int = 0
	var placed: int = 0
	while placed < total:
		var radius: float = first_radius + float(ring) * ring_step
		var sector_start: float = -PI / 2.0
		for g: int in groups.size():
			var members: Array = groups[g]
			var sector: float = TAU * float(members.size()) / float(total)
			var left: int = members.size() - done[g]
			if left > 0:
				var capacity: int = maxi(1, floori(sector * radius / spacing))
				var count: int = mini(capacity, left)
				for i: int in count:
					var angle: float = sector_start + sector * (float(i) + (0.5 if multi else 0.0)) / float(count)
					var id: String = members[done[g] + i]
					var size: Vector2 = sizes.get(id, DEFAULT_SIZE)
					result[id] = anchor + Vector2.from_angle(angle) * radius - size / 2.0
				done[g] += count
				placed += count
			sector_start += sector
		ring += 1
	return result
