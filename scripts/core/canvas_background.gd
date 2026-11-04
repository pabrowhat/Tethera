class_name CanvasBackground
extends RefCounted

const MAX_SIDE: int = 4000
const MAX_FILE_BYTES: int = 20 * 1024 * 1024
const DEFAULT_OPACITY: float = 1.0

var image: String = ""
var opacity: float = DEFAULT_OPACITY

func is_set() -> bool:
	return image != ""

func to_dict() -> Dictionary:
	return {"image": image, "opacity": opacity}

static func from_dict(value: Variant) -> CanvasBackground:
	var result: CanvasBackground = CanvasBackground.new()
	if not (value is Dictionary):
		return result
	var data: Dictionary = value as Dictionary
	var raw_image: Variant = data.get("image", "")
	result.image = raw_image if raw_image is String else ""
	result.opacity = sanitize_opacity(data.get("opacity", DEFAULT_OPACITY))
	return result

static func sanitize_opacity(value: Variant) -> float:
	if not (value is int or value is float):
		return DEFAULT_OPACITY
	var number: float = float(value)
	if not is_finite(number):
		return DEFAULT_OPACITY
	return clampf(number, 0.0, 1.0)
