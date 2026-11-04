class_name DecorItem
extends RefCounted

const MAX_PER_CANVAS: int = 300
const MAX_SIDE: int = 4000
const MAX_FILE_BYTES: int = 20 * 1024 * 1024
const MIN_SIZE: float = 16.0
const MAX_SIZE: float = 20000.0
const INITIAL_LONG_SIDE: float = 600.0
const LAYER_BELOW: String = "below"
const LAYER_ABOVE: String = "above"
const ROTATION_SNAP_DEG: float = 15.0

var id: String = ""
var image: String = ""
var pos: Vector2 = Vector2.ZERO
var size: Vector2 = Vector2(200.0, 200.0)
var rotation_deg: float = 0.0
var layer: String = LAYER_BELOW

func to_dict() -> Dictionary:
	return {
		"id": id,
		"image": image,
		"pos": [pos.x, pos.y],
		"size": [size.x, size.y],
		"rotation": rotation_deg,
		"layer": layer,
	}

static func from_dict(value: Variant) -> DecorItem:
	if not (value is Dictionary):
		return null
	var data: Dictionary = value as Dictionary
	var item: DecorItem = DecorItem.new()
	var raw_id: String = str(data.get("id", ""))
	item.id = raw_id if ProjectBundle.is_safe_id(raw_id) else UuidUtil.generate_v4()
	item.image = str(data.get("image", ""))
	item.pos = read_vector(data.get("pos", null), Vector2.ZERO, -ProjectBundle.MAX_COORDINATE, ProjectBundle.MAX_COORDINATE)
	item.size = read_vector(data.get("size", null), Vector2(200.0, 200.0), MIN_SIZE, MAX_SIZE)
	item.rotation_deg = normalize_angle(_read_number(data.get("rotation", 0.0)))
	item.layer = layer_or_default(str(data.get("layer", LAYER_BELOW)))
	return item

static func layer_or_default(value: String) -> String:
	return value if value == LAYER_BELOW or value == LAYER_ABOVE else LAYER_BELOW

static func normalize_angle(degrees: float) -> float:
	if not is_finite(degrees):
		return 0.0
	var wrapped: float = fposmod(degrees + 180.0, 360.0) - 180.0
	return 180.0 if is_equal_approx(wrapped, -180.0) else wrapped

static func read_vector(value: Variant, fallback: Vector2, low: float, high: float) -> Vector2:
	if not (value is Array):
		return fallback
	var parts: Array = value as Array
	if parts.size() < 2:
		return fallback
	var x_value: Variant = parts[0]
	var y_value: Variant = parts[1]
	if not ((x_value is int or x_value is float) and (y_value is int or y_value is float)):
		return fallback
	var x: float = float(x_value)
	var y: float = float(y_value)
	if not (is_finite(x) and is_finite(y)):
		return fallback
	return Vector2(clampf(x, low, high), clampf(y, low, high))

static func _read_number(value: Variant) -> float:
	if value is int or value is float:
		return float(value)
	return 0.0
