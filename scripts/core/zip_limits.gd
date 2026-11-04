class_name ZipLimits
extends RefCounted

const MAX_TOTAL_BYTES: int = 2 * 1024 * 1024 * 1024
const MAX_IMAGE_BYTES: int = 50 * 1024 * 1024
const MAX_JSON_BYTES: int = 50 * 1024 * 1024
const MAX_RATIO: float = 100.0
const RATIO_MIN_BYTES: int = 1024 * 1024
const IMAGE_PREFIX: String = "assets/"

const REASON_DAMAGED: String = "bundle.refused.damaged"
const REASON_TOO_LARGE: String = "bundle.refused.too_large"
const REASON_ENTRY_TOO_LARGE: String = "bundle.refused.entry_too_large"
const REASON_RATIO: String = "bundle.refused.ratio"

const SIG_EOCD: int = 0x06054b50
const SIG_ZIP64_LOCATOR: int = 0x07064b50
const SIG_ZIP64_EOCD: int = 0x06064b50
const SIG_ENTRY: int = 0x02014b50
const EOCD_SIZE: int = 22
const ZIP64_LOCATOR_SIZE: int = 20
const ZIP64_EOCD_SIZE: int = 56
const ENTRY_HEADER_SIZE: int = 46
const MAX_COMMENT: int = 65535
const ZIP64_EXTRA_ID: int = 0x0001
const U16_MAX: int = 0xFFFF
const U32_MAX: int = 0xFFFFFFFF

static func read_entries(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _damaged()
	var result: Dictionary = _read_directory(file)
	file.close()
	return result

static func check(entries: Array[Dictionary]) -> Dictionary:
	var total: int = 0
	for entry: Dictionary in entries:
		var entry_name: String = str(entry["name"])
		var compressed: int = int(entry["compressed"])
		var uncompressed: int = int(entry["uncompressed"])
		if uncompressed >= RATIO_MIN_BYTES and (compressed <= 0 or float(uncompressed) / float(compressed) > MAX_RATIO):
			return {"reason": REASON_RATIO, "entry": entry_name}
		var limit: int = MAX_IMAGE_BYTES if entry_name.begins_with(IMAGE_PREFIX) else MAX_JSON_BYTES
		if uncompressed > limit:
			return {"reason": REASON_ENTRY_TOO_LARGE, "entry": entry_name}
		total += uncompressed
		if total > MAX_TOTAL_BYTES:
			return {"reason": REASON_TOO_LARGE, "entry": ""}
	return {"reason": "", "entry": ""}

static func describe(reason: String, entry_name: String) -> String:
	var text: String = str(TranslationServer.translate(reason))
	return text.replace("%s", entry_name.get_file()) if text.contains("%s") else text

static func _read_directory(file: FileAccess) -> Dictionary:
	var length: int = file.get_length()
	if length < EOCD_SIZE:
		return _damaged()

	var tail_size: int = mini(length, EOCD_SIZE + MAX_COMMENT)
	var tail_start: int = length - tail_size
	file.seek(tail_start)
	var tail: PackedByteArray = file.get_buffer(tail_size)
	if tail.size() != tail_size:
		return _damaged()
	var eocd_in_tail: int = -1
	var probe: int = tail_size - EOCD_SIZE
	while probe >= 0:
		if tail.decode_u32(probe) == SIG_EOCD:
			eocd_in_tail = probe
			break
		probe -= 1
	if eocd_in_tail < 0:
		return _damaged()

	var eocd_pos: int = tail_start + eocd_in_tail
	var entry_count: int = tail.decode_u16(eocd_in_tail + 10)
	var directory_size: int = tail.decode_u32(eocd_in_tail + 12)
	var directory_offset: int = tail.decode_u32(eocd_in_tail + 16)
	var directory_end: int = eocd_pos

	if entry_count == U16_MAX or directory_size == U32_MAX or directory_offset == U32_MAX:
		if eocd_pos < ZIP64_LOCATOR_SIZE:
			return _damaged()
		file.seek(eocd_pos - ZIP64_LOCATOR_SIZE)
		var locator: PackedByteArray = file.get_buffer(ZIP64_LOCATOR_SIZE)
		if locator.size() != ZIP64_LOCATOR_SIZE or locator.decode_u32(0) != SIG_ZIP64_LOCATOR:
			return _damaged()
		var record_pos: int = eocd_pos - ZIP64_LOCATOR_SIZE - ZIP64_EOCD_SIZE
		var record: PackedByteArray = _read_at(file, record_pos, ZIP64_EOCD_SIZE)
		if record.size() != ZIP64_EOCD_SIZE or record.decode_u32(0) != SIG_ZIP64_EOCD:
			record_pos = locator.decode_u64(8)
			record = _read_at(file, record_pos, ZIP64_EOCD_SIZE)
			if record.size() != ZIP64_EOCD_SIZE or record.decode_u32(0) != SIG_ZIP64_EOCD:
				return _damaged()
		entry_count = record.decode_u64(32)
		directory_size = record.decode_u64(40)
		directory_end = record_pos

	if entry_count < 0 or directory_size < 0 or directory_size > directory_end:
		return _damaged()
	var directory_start: int = directory_end - directory_size

	var entries: Array[Dictionary] = []
	var cursor: int = directory_start
	for _index: int in entry_count:
		if cursor + ENTRY_HEADER_SIZE > directory_end:
			return _damaged()
		var header: PackedByteArray = _read_at(file, cursor, ENTRY_HEADER_SIZE)
		if header.size() != ENTRY_HEADER_SIZE or header.decode_u32(0) != SIG_ENTRY:
			return _damaged()
		var compressed: int = header.decode_u32(20)
		var uncompressed: int = header.decode_u32(24)
		var name_length: int = header.decode_u16(28)
		var extra_length: int = header.decode_u16(30)
		var comment_length: int = header.decode_u16(32)
		var entry_end: int = cursor + ENTRY_HEADER_SIZE + name_length + extra_length + comment_length
		if entry_end > directory_end:
			return _damaged()

		var entry_name: String = _read_at(file, cursor + ENTRY_HEADER_SIZE, name_length).get_string_from_utf8()
		if uncompressed == U32_MAX or compressed == U32_MAX:
			var extra: PackedByteArray = _read_at(file, cursor + ENTRY_HEADER_SIZE + name_length, extra_length)
			var sizes: PackedInt64Array = _zip64_sizes(extra, uncompressed == U32_MAX, compressed == U32_MAX)
			if sizes.is_empty():
				return _damaged()
			if uncompressed == U32_MAX:
				uncompressed = sizes[0]
			if compressed == U32_MAX:
				compressed = sizes[1]
		if uncompressed < 0 or compressed < 0:
			return _damaged()

		entries.append({"name": entry_name, "compressed": compressed, "uncompressed": uncompressed})
		cursor = entry_end
	return {"ok": true, "entries": entries}

static func _zip64_sizes(extra: PackedByteArray, want_uncompressed: bool, want_compressed: bool) -> PackedInt64Array:
	var cursor: int = 0
	while cursor + 4 <= extra.size():
		var block_id: int = extra.decode_u16(cursor)
		var block_size: int = extra.decode_u16(cursor + 2)
		var data_start: int = cursor + 4
		if data_start + block_size > extra.size():
			break
		if block_id == ZIP64_EXTRA_ID:
			var read_at: int = data_start
			var sizes: PackedInt64Array = PackedInt64Array([0, 0])
			if want_uncompressed:
				if read_at + 8 > data_start + block_size:
					return PackedInt64Array()
				sizes[0] = extra.decode_u64(read_at)
				read_at += 8
			if want_compressed:
				if read_at + 8 > data_start + block_size:
					return PackedInt64Array()
				sizes[1] = extra.decode_u64(read_at)
			return sizes
		cursor = data_start + block_size
	return PackedInt64Array()

static func _read_at(file: FileAccess, position: int, count: int) -> PackedByteArray:
	if position < 0 or count <= 0:
		return PackedByteArray()
	file.seek(position)
	return file.get_buffer(count)

static func _damaged() -> Dictionary:
	return {"ok": false, "reason": REASON_DAMAGED}
