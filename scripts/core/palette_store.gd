class_name PaletteStore
extends RefCounted

signal changed

const SLOT_COUNT: int = 6
const SETTINGS_SECTION: String = "palette"
const KEY_SLOTS: String = "slots"
const KEY_COUNTER: String = "counter"

static var _instance: PaletteStore = null

var _hex: PackedStringArray = PackedStringArray()
var _stamps: PackedInt32Array = PackedInt32Array()
var _counter: int = 0

static func instance() -> PaletteStore:
	if _instance == null:
		_instance = PaletteStore.new()
	return _instance

func _init() -> void:
	_hex.resize(SLOT_COUNT)
	_stamps.resize(SLOT_COUNT)
	_load()

func get_slot(index: int) -> Variant:
	if index < 0 or index >= SLOT_COUNT or _hex[index] == "":
		return null
	return Color(_hex[index])

func find_color(color: Color) -> int:
	var wanted: String = color.to_html(false)
	for i: int in SLOT_COUNT:
		if _hex[i] == wanted:
			return i
	return -1

func add_color(color: Color, presets: Array[Color] = []) -> int:
	var wanted: String = color.to_html(false)
	for preset: Color in presets:
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
