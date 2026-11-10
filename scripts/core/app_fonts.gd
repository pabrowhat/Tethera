class_name AppFonts
extends RefCounted

const NOTE_FONTS_MSDF: bool = true
const NOTE_FONT_NAMES: PackedStringArray = ["Segoe UI", "Inter", "SF Pro Text", "Helvetica Neue", "Noto Sans", "DejaVu Sans", "Arial", "Liberation Sans", "sans-serif"]
const MONO_FONT_PATH: String = "res://assets/fonts/JetBrainsMono-Regular.ttf"

const TABLE_GAP: int = 2
const WEIGHT_REGULAR: int = 400
const WEIGHT_BOLD: int = 700

static var _cache: Dictionary = {}

static func note_regular() -> Font:
	return _note_face("regular", WEIGHT_REGULAR, false)

static func note_bold() -> Font:
	return _note_face("bold", WEIGHT_BOLD, false)

static func note_italic() -> Font:
	return _note_face("italic", WEIGHT_REGULAR, true)

static func note_bold_italic() -> Font:
	return _note_face("bold_italic", WEIGHT_BOLD, true)

static func mono() -> Font:
	if _cache.has("mono"):
		return _cache["mono"] as Font
	var font: FontFile = (load(MONO_FONT_PATH) as FontFile).duplicate() as FontFile
	font.multichannel_signed_distance_field = NOTE_FONTS_MSDF
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_cache["mono"] = font
	return font

static func apply_note_fonts(label: RichTextLabel) -> void:
	label.add_theme_font_override("normal_font", note_regular())
	label.add_theme_font_override("bold_font", note_bold())
	label.add_theme_font_override("italics_font", note_italic())
	label.add_theme_font_override("bold_italics_font", note_bold_italic())
	label.add_theme_font_override("mono_font", mono())
	label.add_theme_constant_override("table_h_separation", TABLE_GAP)
	label.add_theme_constant_override("table_v_separation", TABLE_GAP)

static func _note_face(key: String, weight: int, italic: bool) -> Font:
	if _cache.has(key):
		return _cache[key] as Font
	var font: SystemFont = SystemFont.new()
	font.font_names = NOTE_FONT_NAMES
	font.font_weight = weight
	font.font_italic = italic
	font.multichannel_signed_distance_field = NOTE_FONTS_MSDF
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	_cache[key] = font
	return font
