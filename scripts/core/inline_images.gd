class_name InlineImages
extends RefCounted

const CACHE_LIMIT_BYTES: int = 256 * 1024 * 1024
const AVERAGE_SAMPLES: int = 24
const AVERAGE_META: StringName = &"average_color"

static var missing_reporter: Callable = Callable()
static var defer_misses: bool = false

static var _images_dir: String = ""
static var _cache: Dictionary = {}
static var _latest_key: Dictionary = {}
static var _cache_bytes: int = 0
static var _cache_limit: int = CACHE_LIMIT_BYTES
static var _pending: Dictionary = {}
static var _reported: Dictionary = {}

static func set_images_dir(dir: String) -> void:
	_images_dir = dir
	_pending.clear()
	_reported.clear()

static func disk_path(reference: String) -> String:
	if _images_dir == "" or not NoteImages.is_vault_image(reference):
		return ""
	return _images_dir + reference.substr(VaultStorage.IMAGE_REF_PREFIX.length())

static func cache_key(file_path: String) -> String:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return ""
	var size: int = file.get_length()
	file.close()
	return "%s|%d|%d" % [file_path, FileAccess.get_modified_time(file_path), size]

static func peek(reference: String) -> Texture2D:
	var file_path: String = disk_path(reference)
	if file_path == "":
		return null
	var key: String = cache_key(file_path)
	var entry: Variant = _cache.get(key, null)
	if not (entry is Dictionary):
		return null
	_cache.erase(key)
	_cache[key] = entry
	_latest_key[file_path] = key
	var texture: Texture2D = (entry as Dictionary)["texture"] as Texture2D
	if texture.resource_path != reference:
		texture.take_over_path(reference)
	return texture

static func texture_for(reference: String) -> Texture2D:
	var file_path: String = disk_path(reference)
	if file_path == "" or not FileAccess.file_exists(file_path):
		return null
	var cached: Texture2D = peek(reference)
	if cached != null:
		return cached
	if defer_misses:
		_pending[reference] = true
		return null
	var decoded: Dictionary = decode_for_cache(file_path)
	if decoded.is_empty():
		return null
	_reported.erase(reference)
	return store(reference, file_path, cache_key(file_path), decoded)

static func decode_for_cache(file_path: String) -> Dictionary:
	var image: Image = ImageGuard.load_file(file_path)
	if image == null:
		return {}
	var average: Color = estimate_average_color(image)
	image.generate_mipmaps()
	return {"image": image, "average": average}

static func store(reference: String, file_path: String, key: String, decoded: Dictionary) -> Texture2D:
	var image: Image = decoded["image"] as Image
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	texture.set_meta(AVERAGE_META, decoded["average"])
	texture.take_over_path(reference)
	if key == "":
		return texture
	var previous_key: String = str(_latest_key.get(file_path, ""))
	if previous_key != key:
		_drop(previous_key)
	_drop(key)
	var bytes: int = image.get_data().size()
	_cache[key] = {"texture": texture, "bytes": bytes}
	_cache_bytes += bytes
	_latest_key[file_path] = key
	_evict()
	return texture

static func average_color_of(texture: Texture2D, fallback: Color) -> Color:
	if texture == null or not texture.has_meta(AVERAGE_META):
		return fallback
	var found: Variant = texture.get_meta(AVERAGE_META)
	return found as Color if found is Color else fallback

static func estimate_average_color(image: Image) -> Color:
	var width: int = image.get_width()
	var height: int = image.get_height()
	if width <= 0 or height <= 0 or image.is_compressed():
		return Color.BLACK
	var red: float = 0.0
	var green: float = 0.0
	var blue: float = 0.0
	var weight: float = 0.0
	for row: int in AVERAGE_SAMPLES:
		var y: int = clampi(int((float(row) + 0.5) / float(AVERAGE_SAMPLES) * float(height)), 0, height - 1)
		for column: int in AVERAGE_SAMPLES:
			var x: int = clampi(int((float(column) + 0.5) / float(AVERAGE_SAMPLES) * float(width)), 0, width - 1)
			var pixel: Color = image.get_pixel(x, y)
			red += pixel.r * pixel.a
			green += pixel.g * pixel.a
			blue += pixel.b * pixel.a
			weight += pixel.a
	if weight <= 0.0:
		return Color.BLACK
	return Color(red / weight, green / weight, blue / weight, 1.0)

static func forget(reference: String) -> void:
	var file_path: String = disk_path(reference)
	_drop(str(_latest_key.get(file_path, "")))
	_latest_key.erase(file_path)
	_pending.erase(reference)
	_reported.erase(reference)

static func set_cache_limit(bytes: int) -> void:
	_cache_limit = bytes
	_evict()

static func cache_bytes() -> int:
	return _cache_bytes

static func cache_count() -> int:
	return _cache.size()

static func clear_cache() -> void:
	_cache.clear()
	_latest_key.clear()
	_cache_bytes = 0

static func pending_references() -> Array[String]:
	var result: Array[String] = []
	for reference: Variant in _pending:
		result.append(str(reference))
	return result

static func is_pending(reference: String) -> bool:
	return _pending.has(reference)

static func settle(reference: String) -> void:
	_pending.erase(reference)

static func report_missing(reference: String) -> void:
	if _reported.has(reference) or _pending.has(reference) or not missing_reporter.is_valid():
		return
	_reported[reference] = true
	missing_reporter.call(reference)

static func _drop(key: String) -> void:
	var entry: Variant = _cache.get(key, null)
	if entry is Dictionary:
		_cache_bytes -= int((entry as Dictionary)["bytes"])
		_cache.erase(key)

static func _evict() -> void:
	while _cache_bytes > _cache_limit and not _cache.is_empty():
		for key: Variant in _cache:
			_drop(str(key))
			break
