class_name ProjectBundle
extends RefCounted

const APP_NAME: String = "Tethera"
const FORMAT_VERSION: int = 3
const EXTENSION: String = "tether"

const MANIFEST_PATH: String = "manifest.json"
const GRAPH_PATH: String = "graph_data.json"
const ASSETS_DIR: String = "assets/"

const IMAGE_EXTENSIONS: PackedStringArray = ["png", "jpg", "jpeg", "webp"]
const KNOWN_STATUSES: PackedStringArray = ["", "todo", "in_progress", "done"]
const KNOWN_KINDS: PackedStringArray = ["manual", "wiki"]
const DEFAULT_COLOR: String = "313549"
const MAX_ID_LENGTH: int = 80
const MAX_COORDINATE: float = 10000000.0

static func write(path: String, notes: Array[Dictionary], connections: Array[Dictionary], types: Array[Dictionary], created: int, decor: Array[Dictionary] = [], canvas_background: CanvasBackground = null, project_name: String = "", extras: Array[Dictionary] = []) -> Dictionary:
	var asset_by_source: Dictionary = {}
	var asset_bytes: Dictionary = {}
	var used_names: Dictionary = {}
	var missing_images: int = 0
	var missing_inline: Dictionary = {}
	var note_entries: Array[Dictionary] = []

	for note: Dictionary in notes:
		var image_ref: String = ""
		var source: String = str(note.get("image", ""))
		if source != "":
			image_ref = _register_asset(source, true, asset_by_source, asset_bytes, used_names)
			if image_ref == "":
				missing_images += 1

		var bg_ref: String = ""
		var bg_source: String = str(note.get("bg_image", ""))
		if bg_source != "":
			bg_ref = _register_asset(bg_source, false, asset_by_source, asset_bytes, used_names)
			if bg_ref == "":
				missing_images += 1

		var content: String = NoteImages.rewrite_inline(str(note.get("content", "")), func(picture_path: String) -> String:
			if picture_path.begins_with(ASSETS_DIR):
				return ""
			var asset_ref: String = _register_asset(picture_path, false, asset_by_source, asset_bytes, used_names)
			if asset_ref == "":
				missing_inline[picture_path] = true
			return asset_ref
		)

		var pos: Vector2 = note.get("pos", Vector2.ZERO)
		note_entries.append({
			"id": str(note.get("id", "")),
			"title": str(note.get("title", "")),
			"content": content,
			"pos": [pos.x, pos.y],
			"color": str(note.get("color", DEFAULT_COLOR)),
			"image": image_ref,
			"status": str(note.get("status", "")),
			"created": int(note.get("created", 0)),
			"modified": int(note.get("modified", 0)),
			"flipped": bool(note.get("flipped", false)),
			"type": str(note.get("type", "")),
			"fields": FieldDef.sanitize_values(note.get("fields", {})),
			"color_overridden": bool(note.get("color_overridden", false)),
			"bg_color": NoteBackground.sanitize_hex(note.get("bg_color", "")),
			"bg_color2": NoteBackground.sanitize_hex(note.get("bg_color2", "")),
			"bg_image": bg_ref,
		})

	var type_entries: Array[Dictionary] = []
	for type_data: Dictionary in types:
		var type_entry: Dictionary = type_data.duplicate()
		var type_source: String = str(type_entry.get("bg_image", ""))
		if type_source != "":
			type_entry["bg_image"] = _register_asset(type_source, false, asset_by_source, asset_bytes, used_names)
			if str(type_entry["bg_image"]) == "":
				missing_images += 1
		type_entries.append(type_entry)

	var decor_entries: Array[Dictionary] = []
	for decor_data: Dictionary in decor:
		var decor_item: DecorItem = DecorItem.from_dict(decor_data)
		if decor_item == null:
			continue
		if decor_item.is_text():
			continue
		var decor_ref: String = _register_asset(decor_item.image, false, asset_by_source, asset_bytes, used_names)
		if decor_ref == "":
			missing_images += 1
			continue
		decor_item.image = decor_ref
		decor_entries.append(decor_item.to_dict())

	var extra_entries: Array[Dictionary] = []
	for extra_data: Dictionary in extras:
		var normalized: Dictionary = _normalize_extra(extra_data)
		if not normalized.is_empty() and decor_entries.size() + extra_entries.size() < DecorItem.MAX_PER_CANVAS:
			extra_entries.append(normalized)

	var background_entry: Dictionary = {}
	if canvas_background != null and canvas_background.is_set():
		var background_ref: String = _register_asset(canvas_background.image, false, asset_by_source, asset_bytes, used_names)
		if background_ref == "":
			missing_images += 1
		else:
			background_entry = {"image": background_ref, "opacity": canvas_background.opacity}

	var link_entries: Array[Dictionary] = []
	var adjacency: Dictionary = {}
	for conn: Dictionary in connections:
		var from_id: String = str(conn.get("from", ""))
		var to_id: String = str(conn.get("to", ""))
		var link_kind: String = str(conn.get("kind", "manual"))
		link_entries.append({"from": from_id, "to": to_id, "kind": link_kind, "style": GraphNetwork.sanitize_style(conn.get("style", null), link_kind)})
		_adjacency_add(adjacency, from_id, to_id)
		_adjacency_add(adjacency, to_id, from_id)

	var saved: int = int(Time.get_unix_time_from_system())
	var manifest: Dictionary = {
		"app": APP_NAME,
		"format_version": FORMAT_VERSION,
		"created": created if created > 0 else saved,
		"saved": saved,
		"created_iso": Time.get_datetime_string_from_unix_time(created if created > 0 else saved),
		"saved_iso": Time.get_datetime_string_from_unix_time(saved),
		"notes": note_entries.size(),
		"connections": link_entries.size(),
		"types": types.size(),
		"decor": decor_entries.size(),
		"extras": extra_entries.size(),
		"assets": asset_bytes.size(),
	}
	if sanitize_name(project_name) != "":
		manifest["name"] = sanitize_name(project_name)
	var graph: Dictionary = {
		"notes": note_entries,
		"types": type_entries,
		"connections": link_entries,
		"adjacency": adjacency,
		"decor": decor_entries,
	}
	if not extra_entries.is_empty():
		graph["extras"] = extra_entries
	if not background_entry.is_empty():
		graph["canvas_background"] = background_entry

	var temp_path: String = path + ".tmp"
	var zip: ZIPPacker = ZIPPacker.new()
	if zip.open(temp_path) != OK:
		return _failure(TranslationServer.translate("error.bundle.create"))

	var packed_ok: bool = _zip_add(zip, MANIFEST_PATH, JSON.stringify(manifest, "\t").to_utf8_buffer())
	packed_ok = packed_ok and _zip_add(zip, GRAPH_PATH, JSON.stringify(graph, "\t").to_utf8_buffer())
	for asset_name: String in asset_bytes:
		packed_ok = packed_ok and _zip_add(zip, ASSETS_DIR + asset_name, asset_bytes[asset_name] as PackedByteArray)
	zip.close()

	if not packed_ok:
		DirAccess.remove_absolute(temp_path)
		return _failure(TranslationServer.translate("error.bundle.write"))
	if DirAccess.rename_absolute(temp_path, path) != OK:
		DirAccess.remove_absolute(temp_path)
		return _failure(TranslationServer.translate("error.bundle.save"))

	return {"ok": true, "message": "", "assets": asset_bytes.size(), "missing_images": missing_images, "missing_inline": missing_inline.size()}

static func read(path: String) -> Dictionary:
	var listing: Dictionary = ZipLimits.read_entries(path)
	if not bool(listing["ok"]):
		return _failure(ZipLimits.describe(str(listing["reason"]), ""))
	var entries: Array[Dictionary] = listing["entries"]
	var verdict: Dictionary = ZipLimits.check(entries)
	if str(verdict["reason"]) != "":
		return _failure(ZipLimits.describe(str(verdict["reason"]), str(verdict["entry"])))
	var declared: Dictionary = {}
	for entry: Dictionary in entries:
		declared[str(entry["name"])] = int(entry["uncompressed"])

	var reader: ZIPReader = ZIPReader.new()
	if reader.open(path) != OK:
		return _failure(TranslationServer.translate("error.bundle.corrupt"))
	if reader.get_files().size() != entries.size():
		reader.close()
		return _failure(ZipLimits.describe(ZipLimits.REASON_DAMAGED, ""))

	var result: Dictionary = _read_opened(reader, declared)
	reader.close()
	return result

static func _read_entry(reader: ZIPReader, entry_name: String, declared: Dictionary) -> PackedByteArray:
	var bytes: PackedByteArray = reader.read_file(entry_name)
	if declared.has(entry_name) and bytes.size() != int(declared[entry_name]):
		return PackedByteArray()
	return bytes

static func _read_opened(reader: ZIPReader, declared: Dictionary) -> Dictionary:
	var files: PackedStringArray = reader.get_files()
	if not files.has(MANIFEST_PATH) or not files.has(GRAPH_PATH):
		return _failure(TranslationServer.translate("error.bundle.no_data"))

	var manifest_data: Variant = _parse_json(_read_entry(reader, MANIFEST_PATH, declared))
	if not (manifest_data is Dictionary):
		return _failure(TranslationServer.translate("error.bundle.manifest"))
	var manifest: Dictionary = manifest_data as Dictionary
	if str(manifest.get("app", "")) != APP_NAME:
		return _failure(TranslationServer.translate("error.bundle.foreign"))

	var version_value: Variant = manifest.get("format_version", null)
	if not (version_value is int or version_value is float) or int(version_value) < 1:
		return _failure(TranslationServer.translate("error.bundle.version_unknown"))
	var version: int = int(version_value)
	if version > FORMAT_VERSION:
		return _failure(TranslationServer.translate("error.bundle.version_newer") % [version, FORMAT_VERSION])

	var graph_data: Variant = _parse_json(_read_entry(reader, GRAPH_PATH, declared))
	if not (graph_data is Dictionary):
		return _failure(TranslationServer.translate("error.bundle.graph"))
	var graph: Dictionary = graph_data as Dictionary
	if not (graph.get("notes", null) is Array):
		return _failure(TranslationServer.translate("error.bundle.notes_missing"))

	var type_registry: EntityTypeRegistry = EntityTypeRegistry.new()
	type_registry.load_array(graph.get("types", []))
	var types: Array[Dictionary] = type_registry.to_array()
	var known_type_ids: Dictionary = {}
	for entity_type: EntityType in type_registry.get_all():
		known_type_ids[entity_type.id] = true

	var notes: Array[Dictionary] = []
	var assets: Dictionary = {}
	var known_ids: Dictionary = {}
	var id_remap: Dictionary = {}
	var skipped_notes: int = 0
	var dropped_images: int = 0
	var refused_assets: Dictionary = {}

	for type_entry: Dictionary in types:
		var type_ref: String = str(type_entry.get("bg_image", ""))
		if type_ref == "":
			continue
		var type_asset: String = _load_asset(reader, files, type_ref, assets, declared, refused_assets)
		if type_asset == "" and not refused_assets.has(type_ref.trim_prefix(ASSETS_DIR)):
			dropped_images += 1
		type_entry["bg_image"] = type_asset

	for entry_value: Variant in (graph["notes"] as Array):
		if not (entry_value is Dictionary):
			skipped_notes += 1
			continue
		var entry: Dictionary = entry_value as Dictionary

		var raw_id: String = str(entry.get("id", ""))
		var note_id: String = raw_id
		if not is_safe_id(note_id) or known_ids.has(note_id):
			note_id = UuidUtil.generate_v4()
			if raw_id != "" and not id_remap.has(raw_id) and not known_ids.has(raw_id):
				id_remap[raw_id] = note_id
		known_ids[note_id] = true

		var title: String = str(entry.get("title", "")).strip_edges()
		var color_hex: String = str(entry.get("color", DEFAULT_COLOR)).strip_edges().trim_prefix("#")
		if not Color.html_is_valid(color_hex):
			color_hex = DEFAULT_COLOR
		var status: String = str(entry.get("status", ""))
		if not KNOWN_STATUSES.has(status):
			status = ""

		var note_type: String = str(entry.get("type", ""))
		if not known_type_ids.has(note_type):
			note_type = ""

		var asset_name: String = ""
		var image_ref: String = str(entry.get("image", ""))
		if image_ref != "":
			asset_name = _load_asset(reader, files, image_ref, assets, declared, refused_assets)
			if asset_name == "" and not refused_assets.has(image_ref.trim_prefix(ASSETS_DIR)):
				dropped_images += 1

		var bg_asset: String = ""
		var bg_ref: String = str(entry.get("bg_image", ""))
		if bg_ref != "":
			bg_asset = _load_asset(reader, files, bg_ref, assets, declared, refused_assets)
			if bg_asset == "" and not refused_assets.has(bg_ref.trim_prefix(ASSETS_DIR)):
				dropped_images += 1

		var content: String = str(entry.get("content", ""))
		for picture: Dictionary in NoteImages.find_inline(content):
			var inline_ref: String = str(picture["path"])
			if inline_ref.begins_with(ASSETS_DIR):
				_load_asset(reader, files, inline_ref, assets, declared, refused_assets)

		notes.append({
			"id": note_id,
			"title": title if title != "" else TranslationServer.translate("note.title_fallback"),
			"content": content,
			"pos": _read_position(entry.get("pos", null)),
			"color": color_hex,
			"image": asset_name,
			"status": status,
			"created": maxi(int(entry.get("created", 0)), 0),
			"modified": maxi(int(entry.get("modified", 0)), 0),
			"flipped": bool(entry.get("flipped", false)),
			"type": note_type,
			"fields": FieldDef.sanitize_values(entry.get("fields", {})),
			"color_overridden": bool(entry.get("color_overridden", false)),
			"bg_color": NoteBackground.sanitize_hex(entry.get("bg_color", "")),
			"bg_color2": NoteBackground.sanitize_hex(entry.get("bg_color2", "")),
			"bg_image": bg_asset,
		})

	var decor: Array[Dictionary] = []
	var skipped_decor: int = 0
	var raw_decor: Variant = graph.get("decor", [])
	if raw_decor is Array:
		var decor_ids: Dictionary = {}
		for decor_value: Variant in (raw_decor as Array):
			var decor_item: DecorItem = DecorItem.from_dict(decor_value)
			if decor_item == null or decor.size() >= DecorItem.MAX_PER_CANVAS:
				skipped_decor += 1
				continue
			while decor_ids.has(decor_item.id):
				decor_item.id = UuidUtil.generate_v4()
			if decor_item.is_text():
				skipped_decor += 1
				continue
			var decor_asset: String = _load_asset(reader, files, decor_item.image, assets, declared, refused_assets)
			if decor_asset != "" and not bool(ImageGuard.inspect(assets[decor_asset] as PackedByteArray, decor_asset.get_extension(), DecorItem.MAX_SIDE, DecorItem.MAX_FILE_BYTES)["ok"]):
				decor_asset = ""
			if decor_asset == "":
				skipped_decor += 1
				continue
			decor_ids[decor_item.id] = true
			decor_item.image = decor_asset
			decor.append(decor_item.to_dict())

	var extras: Array[Dictionary] = []
	var raw_extras: Variant = graph.get("extras", [])
	if raw_extras is Array:
		var extra_ids: Dictionary = {}
		for extra_value: Variant in (raw_extras as Array):
			var normalized: Dictionary = _normalize_extra(extra_value)
			if normalized.is_empty() or decor.size() + extras.size() >= DecorItem.MAX_PER_CANVAS:
				skipped_decor += 1
				continue
			if str(normalized.get("kind", "")) == DecorItem.KIND_TEXT:
				while extra_ids.has(str(normalized["id"])):
					normalized["id"] = UuidUtil.generate_v4()
				extra_ids[str(normalized["id"])] = true
			extras.append(normalized)

	var canvas_background: Dictionary = {}
	var lost_canvas_background: bool = false
	var raw_background: Variant = graph.get("canvas_background", null)
	if raw_background is Dictionary:
		var parsed_background: CanvasBackground = CanvasBackground.from_dict(raw_background)
		var background_asset: String = _load_asset(reader, files, parsed_background.image, assets, declared, refused_assets)
		if background_asset != "" and not bool(ImageGuard.inspect(assets[background_asset] as PackedByteArray, background_asset.get_extension(), CanvasBackground.MAX_SIDE, CanvasBackground.MAX_FILE_BYTES)["ok"]):
			background_asset = ""
		if background_asset == "":
			lost_canvas_background = parsed_background.is_set()
		else:
			parsed_background.image = background_asset
			canvas_background = parsed_background.to_dict()

	var connections: Array[Dictionary] = []
	var seen_pairs: Dictionary = {}
	var raw_links: Variant = graph.get("connections", [])
	if raw_links is Array:
		for link_value: Variant in (raw_links as Array):
			if not (link_value is Dictionary):
				continue
			var link: Dictionary = link_value as Dictionary
			var from_id: String = _remap(id_remap, str(link.get("from", "")))
			var to_id: String = _remap(id_remap, str(link.get("to", "")))
			if from_id == to_id or not known_ids.has(from_id) or not known_ids.has(to_id):
				continue
			var pair_key: String = from_id + "|" + to_id if from_id < to_id else to_id + "|" + from_id
			if seen_pairs.has(pair_key):
				continue
			seen_pairs[pair_key] = true
			var kind: String = str(link.get("kind", "manual"))
			var safe_kind: String = kind if KNOWN_KINDS.has(kind) else "manual"
			connections.append({"from": from_id, "to": to_id, "kind": safe_kind, "style": GraphNetwork.sanitize_style(link.get("style", null), safe_kind)})

	return {
		"ok": true,
		"message": "",
		"notes": notes,
		"connections": connections,
		"types": types,
		"assets": assets,
		"created": maxi(int(manifest.get("created", 0)), 0),
		"name": sanitize_name(manifest.get("name", "")),
		"skipped_notes": skipped_notes,
		"dropped_images": dropped_images,
		"refused_assets": refused_assets,
		"decor": decor,
		"extras": extras,
		"skipped_decor": skipped_decor,
		"canvas_background": canvas_background,
		"lost_canvas_background": lost_canvas_background,
	}

static func sanitize_name(value: Variant) -> String:
	if not (value is String) or WorldRegistry.check_name(value as String) != "":
		return ""
	return (value as String).strip_edges()

static func rekey_ids(notes: Array[Dictionary], connections: Array[Dictionary], taken: Dictionary) -> Dictionary:
	var used: Dictionary = taken.duplicate()
	var id_map: Dictionary = {}
	var rekeyed_notes: Array[Dictionary] = []
	for note: Dictionary in notes:
		var old_id: String = str(note.get("id", ""))
		var new_id: String = old_id
		while used.has(new_id) or not is_safe_id(new_id):
			new_id = UuidUtil.generate_v4()
		used[new_id] = true
		id_map[old_id] = new_id
		var entry: Dictionary = note.duplicate(true)
		entry["id"] = new_id
		rekeyed_notes.append(entry)

	var rekeyed_links: Array[Dictionary] = []
	for conn: Dictionary in connections:
		var from_id: String = str(conn.get("from", ""))
		var to_id: String = str(conn.get("to", ""))
		if not id_map.has(from_id) or not id_map.has(to_id):
			continue
		var link: Dictionary = conn.duplicate()
		link["from"] = _remap(id_map, from_id)
		link["to"] = _remap(id_map, to_id)
		rekeyed_links.append(link)
	return {"notes": rekeyed_notes, "connections": rekeyed_links}

static func _register_asset(source: String, as_cover: bool, asset_by_source: Dictionary, asset_bytes: Dictionary, used_names: Dictionary) -> String:
	if asset_by_source.has(source):
		return ASSETS_DIR + str(asset_by_source[source])
	if not NoteImages.is_vault_image(source):
		return ""

	var bytes: PackedByteArray = PackedByteArray()
	var file_path: String = InlineImages.disk_path(source)
	if file_path != "" and FileAccess.file_exists(file_path):
		bytes = FileAccess.get_file_as_bytes(file_path)
	if bytes.is_empty():
		return ""

	var wanted: String = source.get_file() if as_cover else VaultStorage.hashed_image_name(source.get_file(), bytes)
	if not as_cover and asset_bytes.has(wanted) and (asset_bytes[wanted] as PackedByteArray) == bytes:
		asset_by_source[source] = wanted
		return ASSETS_DIR + wanted
	var asset_name: String = _unique_asset_name(wanted, used_names)
	asset_by_source[source] = asset_name
	asset_bytes[asset_name] = bytes
	return ASSETS_DIR + asset_name

static func _load_asset(reader: ZIPReader, files: PackedStringArray, image_ref: String, assets: Dictionary, declared: Dictionary, refused: Dictionary) -> String:
	if not image_ref.begins_with(ASSETS_DIR):
		return ""
	var asset_name: String = image_ref.trim_prefix(ASSETS_DIR)
	if asset_name == "" or asset_name != asset_name.get_file() or asset_name.begins_with("."):
		return ""
	if not IMAGE_EXTENSIONS.has(asset_name.get_extension().to_lower()):
		return ""
	if not files.has(image_ref):
		return ""
	if refused.has(asset_name):
		return ""
	if not assets.has(asset_name):
		var bytes: PackedByteArray = _read_entry(reader, image_ref, declared)
		if bytes.is_empty():
			return ""
		if not bool(ImageGuard.inspect(bytes, asset_name.get_extension())["ok"]):
			refused[asset_name] = true
			return ""
		assets[asset_name] = bytes

	return asset_name

static func is_safe_id(id: String) -> bool:
	return id != "" and id.length() <= MAX_ID_LENGTH and id == id.strip_edges() \
		and id.is_valid_filename() and not id.begins_with(".")

static func _read_position(value: Variant) -> Vector2:
	if not (value is Array):
		return Vector2.ZERO
	var coords: Array = value as Array
	if coords.size() < 2:
		return Vector2.ZERO
	var x_value: Variant = coords[0]
	var y_value: Variant = coords[1]
	if not ((x_value is int or x_value is float) and (y_value is int or y_value is float)):
		return Vector2.ZERO
	var x: float = float(x_value)
	var y: float = float(y_value)
	if not (is_finite(x) and is_finite(y)):
		return Vector2.ZERO
	return Vector2(clampf(x, -MAX_COORDINATE, MAX_COORDINATE), clampf(y, -MAX_COORDINATE, MAX_COORDINATE))

static func _remap(id_remap: Dictionary, id: String) -> String:
	return str(id_remap[id]) if id_remap.has(id) else id

static func _parse_json(bytes: PackedByteArray) -> Variant:
	if bytes.is_empty():
		return null
	var json: JSON = JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK:
		return null
	return json.data

static func _zip_add(zip: ZIPPacker, path_in_zip: String, bytes: PackedByteArray) -> bool:
	if zip.start_file(path_in_zip) != OK:
		return false
	var ok: bool = zip.write_file(bytes) == OK
	zip.close_file()
	return ok

static func _unique_asset_name(source_name: String, used: Dictionary) -> String:
	var base: String = source_name.validate_filename()
	if base == "":
		base = "image.png"
	var candidate: String = base
	var counter: int = 2
	while used.has(candidate.to_lower()):
		candidate = "%s_%d.%s" % [base.get_basename(), counter, base.get_extension()]
		counter += 1
	used[candidate.to_lower()] = true
	return candidate

static func _adjacency_add(adjacency: Dictionary, from_id: String, to_id: String) -> void:
	if not adjacency.has(from_id):
		adjacency[from_id] = []
	var neighbors: Array = adjacency[from_id] as Array
	if not neighbors.has(to_id):
		neighbors.append(to_id)

static func _failure(message: String) -> Dictionary:
	return {"ok": false, "message": message}

static func _normalize_extra(value: Variant) -> Dictionary:
	if not (value is Dictionary):
		return {}
	var data: Dictionary = value as Dictionary
	var kind: Variant = data.get("kind", null)
	if not (kind is String) or (kind as String) == "":
		return {}
	if kind == DecorItem.KIND_TEXT:
		var item: DecorItem = DecorItem.from_dict(data)
		return item.to_dict() if item != null else {}
	return data.duplicate(true)
