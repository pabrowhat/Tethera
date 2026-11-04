class_name BookmarkStore
extends RefCounted

const SLOT_COUNT: int = 5
const SETTINGS_SECTION: String = "bookmarks"
const KEY_SLOTS: String = "slots"
const KEY_WORLD_PREFIX: String = "slots_"

static func get_all(world_id: String) -> Array[String]:
	var stored: Variant = AppSettings.get_value(SETTINGS_SECTION, _key(world_id), null)
	if stored == null:
		stored = AppSettings.get_value(SETTINGS_SECTION, KEY_SLOTS, [])
	var slots: Array[String] = []
	if stored is Array:
		for entry: Variant in (stored as Array):
			if slots.size() >= SLOT_COUNT:
				break
			slots.append(entry if entry is String else "")
	while slots.size() < SLOT_COUNT:
		slots.append("")
	return slots

static func get_slot(world_id: String, index: int) -> String:
	if index < 0 or index >= SLOT_COUNT:
		return ""
	return get_all(world_id)[index]

static func set_slot(world_id: String, index: int, card_id: String) -> void:
	if index < 0 or index >= SLOT_COUNT or world_id == "":
		return
	var slots: Array[String] = get_all(world_id)
	slots[index] = card_id
	AppSettings.set_value(SETTINGS_SECTION, _key(world_id), slots)

static func clear_slot(world_id: String, index: int) -> void:
	set_slot(world_id, index, "")

static func _key(world_id: String) -> String:
	return KEY_WORLD_PREFIX + world_id
