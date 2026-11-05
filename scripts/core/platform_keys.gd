class_name PlatformKeys
extends RefCounted


const MAC_COMMAND: String = "⌘"
const MAC_SHIFT: String = "⇧"
const MAC_ALT: String = "⌥"

static func is_macos() -> bool:
	return OS.get_name() == "macOS"

static func is_primary(event: InputEventWithModifiers) -> bool:
	if is_macos():
		return event.meta_pressed
	return event.ctrl_pressed

static func primary_down() -> bool:
	return Input.is_key_pressed(KEY_META if is_macos() else KEY_CTRL)

static func hint(shortcut: String) -> String:
	return _mac_hint(shortcut, is_macos())

static func localize(text: String) -> String:
	return _mac_text(text, is_macos())

static func _mac_hint(shortcut: String, mac: bool) -> String:
	if not mac:
		return shortcut
	return shortcut.replace("Ctrl+", MAC_COMMAND).replace("Shift+", MAC_SHIFT).replace("Alt+", MAC_ALT)

static func _mac_text(text: String, mac: bool) -> String:
	if not mac or not text.contains("Ctrl+"):
		return text
	var re: RegEx = RegEx.create_from_string("Ctrl\\+(?:Shift\\+|Alt\\+)*[A-Za-z0-9,.](?![\\p{L}\\p{N}])")
	var result: String = ""
	var cursor: int = 0
	for m: RegExMatch in re.search_all(text):
		result += text.substr(cursor, m.get_start() - cursor)
		result += _mac_hint(m.get_string(), true)
		cursor = m.get_end()
	return (result + text.substr(cursor)).replace("Ctrl+", MAC_COMMAND + "+")
