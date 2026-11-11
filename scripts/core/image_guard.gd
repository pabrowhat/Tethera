class_name ImageGuard
extends RefCounted

const MAX_SIDE: int = 8000
const MAX_FILE_BYTES: int = ZipLimits.MAX_IMAGE_BYTES

const FORMAT_PNG: String = "png"
const FORMAT_JPEG: String = "jpeg"
const FORMAT_WEBP: String = "webp"

const REASON_TOO_LARGE: String = "image.refused.too_large"
const REASON_FILE_TOO_LARGE: String = "image.refused.file_too_large"
const REASON_MISMATCH: String = "image.refused.mismatch"
const REASON_UNREADABLE: String = "image.refused.unreadable"

const PNG_SIGNATURE_HEX: String = "89504e470d0a1a0a"

static func format_for_extension(extension: String) -> String:
	match extension.to_lower():
		"png":
			return FORMAT_PNG
		"jpg", "jpeg":
			return FORMAT_JPEG
		"webp":
			return FORMAT_WEBP
	return ""

static func inspect(bytes: PackedByteArray, extension: String, max_side: int = MAX_SIDE, max_bytes: int = MAX_FILE_BYTES) -> Dictionary:
	if bytes.is_empty():
		return _refuse(REASON_UNREADABLE)
	if bytes.size() > max_bytes:
		return _refuse(REASON_FILE_TOO_LARGE)
	var expected: String = format_for_extension(extension)
	var detected: String = _detect(bytes)
	if expected == "" or detected != expected:
		return _refuse(REASON_MISMATCH)

	var size: PackedInt64Array = PackedInt64Array()
	match detected:
		FORMAT_PNG:
			size = _png_size(bytes)
		FORMAT_JPEG:
			size = _jpeg_size(bytes)
		FORMAT_WEBP:
			size = _webp_size(bytes)
	if size.size() != 2 or size[0] <= 0 or size[1] <= 0:
		return _refuse(REASON_UNREADABLE)
	if size[0] > max_side or size[1] > max_side:
		return _refuse(REASON_TOO_LARGE)
	return {"ok": true, "format": detected, "width": int(size[0]), "height": int(size[1]), "reason": ""}

static func inspect_file(path: String, max_side: int = MAX_SIDE, max_bytes: int = MAX_FILE_BYTES) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _refuse(REASON_UNREADABLE)
	var length: int = file.get_length()
	if length > max_bytes:
		file.close()
		return _refuse(REASON_FILE_TOO_LARGE)
	var bytes: PackedByteArray = file.get_buffer(length)
	file.close()
	var result: Dictionary = inspect(bytes, path.get_extension(), max_side, max_bytes)
	if bool(result["ok"]):
		result["bytes"] = bytes
	return result

static func load_image(path: String) -> Image:
	var file_path: String = InlineImages.disk_path(path)
	if file_path == "" or not FileAccess.file_exists(file_path):
		return null
	return load_file(file_path)

static func load_file(file_path: String) -> Image:
	var checked: Dictionary = inspect_file(file_path)
	if not bool(checked["ok"]):
		return null

	var bytes: PackedByteArray = checked["bytes"]
	var image: Image = Image.new()
	var error: Error = FAILED
	match str(checked["format"]):
		FORMAT_PNG:
			error = image.load_png_from_buffer(bytes)
		FORMAT_JPEG:
			error = image.load_jpg_from_buffer(bytes)
		FORMAT_WEBP:
			error = image.load_webp_from_buffer(bytes)
	if error != OK or image.is_empty():
		return null
	return image

static func describe(result: Dictionary, file_name: String) -> String:
	var reason: String = str(result.get("reason", REASON_UNREADABLE))
	return str(TranslationServer.translate(reason)).replace("%s", file_name.get_file())

static func _detect(bytes: PackedByteArray) -> String:
	if bytes.size() >= 8 and bytes.slice(0, 8).hex_encode() == PNG_SIGNATURE_HEX:
		return FORMAT_PNG
	if bytes.size() >= 3 and bytes[0] == 0xFF and bytes[1] == 0xD8 and bytes[2] == 0xFF:
		return FORMAT_JPEG
	if bytes.size() >= 12 and _ascii(bytes, 0, 4) == "RIFF" and _ascii(bytes, 8, 4) == "WEBP":
		return FORMAT_WEBP
	return ""

static func _png_size(bytes: PackedByteArray) -> PackedInt64Array:
	if bytes.size() < 24 or _ascii(bytes, 12, 4) != "IHDR":
		return PackedInt64Array()
	return PackedInt64Array([_be32(bytes, 16), _be32(bytes, 20)])

static func _jpeg_size(bytes: PackedByteArray) -> PackedInt64Array:
	var cursor: int = 2
	var length: int = bytes.size()
	while cursor + 4 <= length:
		if bytes[cursor] != 0xFF:
			return PackedInt64Array()
		var marker: int = bytes[cursor + 1]
		if marker == 0xFF:
			cursor += 1
			continue
		if marker == 0xD8 or marker == 0x01 or (marker >= 0xD0 and marker <= 0xD7):
			cursor += 2
			continue
		if marker == 0xD9 or marker == 0xDA:
			return PackedInt64Array()
		var segment_length: int = _be16(bytes, cursor + 2)
		if segment_length < 2:
			return PackedInt64Array()
		var is_frame: bool = marker >= 0xC0 and marker <= 0xCF and marker != 0xC4 and marker != 0xC8 and marker != 0xCC
		if is_frame:
			if cursor + 9 > length:
				return PackedInt64Array()
			return PackedInt64Array([_be16(bytes, cursor + 7), _be16(bytes, cursor + 5)])
		cursor += 2 + segment_length
	return PackedInt64Array()

static func _webp_size(bytes: PackedByteArray) -> PackedInt64Array:
	if bytes.size() < 30:
		return PackedInt64Array()
	match _ascii(bytes, 12, 4):
		"VP8 ":
			if bytes[23] != 0x9D or bytes[24] != 0x01 or bytes[25] != 0x2A:
				return PackedInt64Array()
			return PackedInt64Array([bytes.decode_u16(26) & 0x3FFF, bytes.decode_u16(28) & 0x3FFF])
		"VP8L":
			if bytes[20] != 0x2F:
				return PackedInt64Array()
			var bits: int = bytes.decode_u32(21)
			return PackedInt64Array([(bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1])
		"VP8X":
			var width: int = 1 + (bytes[24] | (bytes[25] << 8) | (bytes[26] << 16))
			var height: int = 1 + (bytes[27] | (bytes[28] << 8) | (bytes[29] << 16))
			return PackedInt64Array([width, height])
	return PackedInt64Array()

static func _ascii(bytes: PackedByteArray, from: int, count: int) -> String:
	return bytes.slice(from, from + count).get_string_from_ascii()

static func _be16(bytes: PackedByteArray, at: int) -> int:
	return (bytes[at] << 8) | bytes[at + 1]

static func _be32(bytes: PackedByteArray, at: int) -> int:
	return (bytes[at] << 24) | (bytes[at + 1] << 16) | (bytes[at + 2] << 8) | bytes[at + 3]

static func _refuse(reason: String) -> Dictionary:
	return {"ok": false, "format": "", "width": 0, "height": 0, "reason": reason}
