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
const KIND_IMAGE: String = "image"
const KIND_TEXT: String = "text"
const MAX_TEXT_LENGTH: int = 2000
const TEXT_DEFAULT_WIDTH: float = 320.0
const TEXT_MIN_WIDTH: float = 64.0
const TEXT_MAX_WIDTH: float = 4000.0
const TEXT_DEFAULT_FONT_SIZE: int = 24
const TEXT_MIN_FONT_SIZE: int = 8
const TEXT_MAX_FONT_SIZE: int = 200
const ALIGN_LEFT: String = "left"
const ALIGN_CENTER: String = "center"
const ALIGN_RIGHT: String = "right"

var id: String = ""
var kind: String = KIND_IMAGE
var text: String = ""
var color: String = ""
var font_size: int = TEXT_DEFAULT_FONT_SIZE
var text_width: float = TEXT_DEFAULT_WIDTH
var align: String = ALIGN_LEFT
var image: String = ""
var pos: Vector2 = Vector2.ZERO
var size: Vector2 = Vector2(200.0, 200.0)
var rotation_deg: float = 0.0
var layer: String = LAYER_BELOW
var flip_h: bool = false
var flip_v: bool = false

func is_text() -> bool:
	return kind == KIND_TEXT

func to_dict() -> Dictionary:
	var result: Dictionary = {
		"id": id,
		"kind": kind,
		"image": image,
		"pos": [pos.x, pos.y],
		"size": [size.x, size.y],
		"rotation": rotation_deg,
		"layer": layer,
	}
	if flip_h:
		result["flip_h"] = true
	if flip_v:
		result["flip_v"] = true
	if is_text():
		result["text"] = text
		result["color"] = color
		result["font_size"] = font_size
		result["text_width"] = text_width
		result["align"] = align
	return result

static func from_dict(value: Variant) -> DecorItem:
	if not (value is Dictionary):
		return null
	var data: Dictionary = value as Dictionary
	var item: DecorItem = DecorItem.new()
	var raw_id: String = str(data.get("id", ""))
	item.id = raw_id if ProjectBundle.is_safe_id(raw_id) else UuidUtil.generate_v4()
	item.kind = kind_or_default(str(data.get("kind", KIND_IMAGE)))
	item.image = str(data.get("image", ""))
	if not item.is_text():
		item.flip_h = _read_flag(data.get("flip_h", false))
		item.flip_v = _read_flag(data.get("flip_v", false))
	if item.is_text():
		item.image = ""
		item.text = clip_text(str(data.get("text", "")))
		item.color = NoteBackground.sanitize_hex(data.get("color", ""))
		item.font_size = clampi(int(_number_or(data.get("font_size", null), float(TEXT_DEFAULT_FONT_SIZE))), TEXT_MIN_FONT_SIZE, TEXT_MAX_FONT_SIZE)
		item.text_width = clampf(_number_or(data.get("text_width", null), TEXT_DEFAULT_WIDTH), TEXT_MIN_WIDTH, TEXT_MAX_WIDTH)
		item.align = align_or_default(str(data.get("align", ALIGN_LEFT)))
	item.pos = read_vector(data.get("pos", null), Vector2.ZERO, -ProjectBundle.MAX_COORDINATE, ProjectBundle.MAX_COORDINATE)
	item.size = read_vector(data.get("size", null), Vector2(200.0, 200.0), MIN_SIZE, MAX_SIZE)
	item.rotation_deg = normalize_angle(_read_number(data.get("rotation", 0.0)))
	item.layer = layer_or_default(str(data.get("layer", LAYER_BELOW)))
	return item

static func kind_or_default(value: String) -> String:
	return KIND_TEXT if value == KIND_TEXT else KIND_IMAGE

static func align_or_default(value: String) -> String:
	return value if value == ALIGN_CENTER or value == ALIGN_RIGHT else ALIGN_LEFT

static func clip_text(value: String) -> String:
	return value.substr(0, MAX_TEXT_LENGTH)

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

static func _number_or(value: Variant, fallback: float) -> float:
	if (value is int or value is float) and is_finite(float(value)):
		return float(value)
	return fallback

static func _read_flag(value: Variant) -> bool:
	return value is bool and value
