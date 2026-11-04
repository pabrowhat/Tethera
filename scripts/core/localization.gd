class_name Localization
extends RefCounted

const AUTO: String = "auto"
const FALLBACK: String = "en"
const SUPPORTED: Array[String] = ["en", "ru"]
const CHOICES: Array[String] = ["auto", "en", "ru"]

static var _applied: String = ""

static func resolve(choice: String, os_locale: String) -> String:
	if SUPPORTED.has(choice):
		return choice
	var language: String = os_locale.strip_edges().replace("-", "_").get_slice("_", 0).to_lower()
	return language if SUPPORTED.has(language) else FALLBACK

static func apply_saved() -> void:
	var wanted: String = resolve(Preferences.language(), OS.get_locale())
	if wanted == _applied and TranslationServer.get_locale() == wanted:
		return
	_applied = wanted
	TranslationServer.set_locale(wanted)

static func applied_locale() -> String:
	return _applied if _applied != "" else resolve(AUTO, OS.get_locale())
