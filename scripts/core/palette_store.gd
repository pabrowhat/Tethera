class_name PaletteStore
extends RefCounted

signal changed
signal duplicate_rejected

const SLOT_COUNT: int = 6
const SETTINGS_SECTION: String = "palette"
const KEY_SLOTS: String = "slots"
const KEY_COUNTER: String = "counter"
const KEY_PRESETS: String = "presets"
const DEFAULT_PRESETS: Array[Color] = [
	Color("313549"),
	Color("3498db"),
	Color("2ecc71"),
	Color("f1c40f"),
	Color("9b59b6"),
	Color("e74c3c")
]

static var _instance: PaletteStore = null

var _hex: PackedStringArray = PackedStringArray()
var _preset_hex: PackedStringArray = PackedStringArray()
var _stamps: PackedInt32Array = PackedInt32Array()
var _counter: int = 0

static func instance() -> PaletteStore:
	if _instance == null:
		_instance = PaletteStore.new()
	return _instance

func _init() -> void:
	_hex.resize(SLOT_COUNT)
	_preset_hex.resize(SLOT_COUNT)
	_stamps.resize(SLOT_COUNT)
	_load()

func get_slot(index: int) -> Variant:
	if index < 0 or index >= SLOT_COUNT or _hex[index] == "":
		return null
	return Color(_hex[index])

func presets() -> Array[Color]:
	var colors: Array[Color] = []
	for i: int in SLOT_COUNT:
		colors.append(Color(_preset_hex[i]) if _preset_hex[i] != "" else DEFAULT_PRESETS[i])
	return colors

func is_preset_overridden(index: int) -> bool:
	return index >= 0 and index < SLOT_COUNT and _preset_hex[index] != ""

func set_preset(index: int, color: Color) -> bool:
	if index < 0 or index >= SLOT_COUNT:
		return false
	return _store_edit(color, index, -1)

func reset_preset(index: int) -> bool:
	if not is_preset_overridden(index):
		return false
	return _store_edit(DEFAULT_PRESETS[index], index, -1)

func set_slot(index: int, color: Color) -> bool:
	if index < 0 or index >= SLOT_COUNT or _hex[index] == "":
		return false
	return _store_edit(color, -1, index)

func is_taken(color: Color, except_preset: int = -1, except_slot: int = -1) -> bool:
	var wanted: String = color.to_html(false)
	var effective: Array[Color] = presets()
	for i: int in SLOT_COUNT:
		if i != except_preset and effective[i].to_html(false) == wanted:
			return true
		if i != except_slot and _hex[i] == wanted:
			return true
	return false

func find_color(color: Color) -> int:
	var wanted: String = color.to_html(false)
	for i: int in SLOT_COUNT:
		if _hex[i] == wanted:
			return i
	return -1

func add_color(color: Color, extra_presets: Array[Color] = []) -> int:
	var wanted: String = color.to_html(false)
	var shown: Array[Color] = presets()
	shown.append_array(extra_presets)
	for preset: Color in shown:
		if preset.to_html(false) == wanted:
			return -1
	var existing: int = find_color(color)
	if existing != -1:
		return existing

	var target: int = _first_free_slot()
	if target == -1:
		target = _oldest_slot()

	_counter += 1
	_hex[target] = color.to_html(false)
	_stamps[target] = _counter
	_save()
	changed.emit()
	return target

func clear_slot(index: int) -> void:
	if index < 0 or index >= SLOT_COUNT or _hex[index] == "":
		return
	_hex[index] = ""
	_stamps[index] = 0
	_save()
	changed.emit()

func _store_edit(color: Color, preset_index: int, slot_index: int) -> bool:
	var hex: String = color.to_html(false)
	var current: String = _hex[slot_index] if slot_index >= 0 else presets()[preset_index].to_html(false)
	if hex == current:
		return true
	if is_taken(color, preset_index, slot_index):
		duplicate_rejected.emit()
		return false
	if slot_index >= 0:
		_hex[slot_index] = hex
	else:
		_preset_hex[preset_index] = "" if hex == DEFAULT_PRESETS[preset_index].to_html(false) else hex
	_save()
	changed.emit()
	return true

func _first_free_slot() -> int:
	for i: int in SLOT_COUNT:
		if _hex[i] == "":
			return i
	return -1

func _oldest_slot() -> int:
	var oldest: int = 0
	for i: int in range(1, SLOT_COUNT):
		if _stamps[i] < _stamps[oldest]:
			oldest = i
	return oldest

func _load() -> void:
	_counter = int(AppSettings.get_value(SETTINGS_SECTION, KEY_COUNTER, 0))
	var stored_presets: Variant = AppSettings.get_value(SETTINGS_SECTION, KEY_PRESETS, [])
	if stored_presets is Array:
		var overrides: Array = stored_presets as Array
		for i: int in mini(overrides.size(), SLOT_COUNT):
			if overrides[i] is String and (overrides[i] as String).is_valid_html_color():
				_preset_hex[i] = Color(overrides[i] as String).to_html(false)
	var stored: Variant = AppSettings.get_value(SETTINGS_SECTION, KEY_SLOTS, [])
	if not (stored is Array):
		return
	var entries: Array = stored as Array
	for i: int in mini(entries.size(), SLOT_COUNT):
		if not (entries[i] is Dictionary):
			continue
		var entry: Dictionary = entries[i] as Dictionary
		var hex: String = str(entry.get("c", ""))
		if hex.is_valid_html_color():
			_hex[i] = Color(hex).to_html(false)
			_stamps[i] = int(entry.get("n", 0))
			_counter = maxi(_counter, _stamps[i])

func _save() -> void:
	var entries: Array = []
	for i: int in SLOT_COUNT:
		entries.append({"c": _hex[i], "n": _stamps[i]} if _hex[i] != "" else {})
	AppSettings.set_value(SETTINGS_SECTION, KEY_SLOTS, entries)
	AppSettings.set_value(SETTINGS_SECTION, KEY_COUNTER, _counter)
	AppSettings.set_value(SETTINGS_SECTION, KEY_PRESETS, Array(_preset_hex))
