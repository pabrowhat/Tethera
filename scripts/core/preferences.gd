class_name Preferences
extends RefCounted

const SECTION: String = "preferences"

const KEY_REDUCE_MOTION: String = "reduce_motion"
const KEY_SHOW_GRID: String = "show_grid"
const KEY_LINE_WIDTH_SCALE: String = "line_width_scale"
const KEY_DEFAULT_NOTE_COLOR: String = "default_note_color"
const KEY_BACKUPS_KEPT: String = "backups_kept"
const KEY_EXPORT_INCLUDE_LINKED: String = "export_include_linked"
const KEY_LANGUAGE: String = "language"
const KEY_THEME: String = "theme"
const KEY_MINIMAP_DECOR: String = "minimap_decor"
const KEY_COLLAPSE_DISTANT_NOTES: String = "collapse_distant_notes"
const KEY_LAYOUT_LEVEL_GAP: String = "layout_level_gap"
const KEY_LAYOUT_SIBLING_GAP: String = "layout_sibling_gap"
const KEY_LAYOUT_BLOCK_GAP: String = "layout_block_gap"
const KEY_LAYOUT_RING_STEP: String = "layout_ring_step"
const KEY_OPEN_MODE: String = "open_mode"

const OPEN_SIDEBAR: String = "sidebar"
const OPEN_ZEN: String = "zen"
const OPEN_NONE: String = "none"
const OPEN_MODES: Array[String] = [OPEN_SIDEBAR, OPEN_ZEN, OPEN_NONE]

const LINE_WIDTH_MIN: float = 0.5
const LINE_WIDTH_MAX: float = 2.0
const BACKUPS_MIN: int = 0
const BACKUPS_MAX: int = 50
const DEFAULT_NOTE_COLOR_HEX: String = "313549"
const LAYOUT_GAP_MIN: int = 0
const LAYOUT_GAP_MAX: int = 1000
const LAYOUT_RING_STEP_MIN: int = 40
const LAYOUT_RING_STEP_MAX: int = 2000

static func defaults() -> Dictionary:
	return {
		KEY_REDUCE_MOTION: false,
		KEY_SHOW_GRID: true,
		KEY_LINE_WIDTH_SCALE: 1.0,
		KEY_DEFAULT_NOTE_COLOR: DEFAULT_NOTE_COLOR_HEX,
		KEY_BACKUPS_KEPT: VaultStorage.MAX_BACKUPS,
		KEY_EXPORT_INCLUDE_LINKED: false,
		KEY_LANGUAGE: Localization.AUTO,
		KEY_THEME: ThemeColors.AUTO,
		KEY_MINIMAP_DECOR: true,
		KEY_COLLAPSE_DISTANT_NOTES: true,
		KEY_LAYOUT_LEVEL_GAP: int(LayoutTemplates.LEVEL_GAP),
		KEY_LAYOUT_SIBLING_GAP: int(LayoutTemplates.SIBLING_GAP),
		KEY_LAYOUT_BLOCK_GAP: int(LayoutTemplates.BLOCK_GAP),
		KEY_LAYOUT_RING_STEP: int(LayoutTemplates.RING_STEP),
		KEY_OPEN_MODE: OPEN_SIDEBAR,
	}

static func get_pref(key: String) -> Variant:
	var fallback: Variant = defaults().get(key, null)
	var stored: Variant = AppSettings.get_value(SECTION, key, fallback)
	return sanitize(key, stored)

static func sanitize(key: String, value: Variant) -> Variant:
	var fallback: Variant = defaults().get(key, null)
	match key:
		KEY_REDUCE_MOTION, KEY_SHOW_GRID, KEY_EXPORT_INCLUDE_LINKED, KEY_MINIMAP_DECOR, KEY_COLLAPSE_DISTANT_NOTES:
			return value if value is bool else fallback
		KEY_LINE_WIDTH_SCALE:
			if value is float or value is int:
				return clampf(float(value), LINE_WIDTH_MIN, LINE_WIDTH_MAX)
			return fallback
		KEY_BACKUPS_KEPT:
			if value is int or value is float:
				return clampi(int(value), BACKUPS_MIN, BACKUPS_MAX)
			return fallback
		KEY_LAYOUT_LEVEL_GAP, KEY_LAYOUT_SIBLING_GAP, KEY_LAYOUT_BLOCK_GAP:
			if value is int or value is float:
				return clampi(int(value), LAYOUT_GAP_MIN, LAYOUT_GAP_MAX)
			return fallback
		KEY_LAYOUT_RING_STEP:
			if value is int or value is float:
				return clampi(int(value), LAYOUT_RING_STEP_MIN, LAYOUT_RING_STEP_MAX)
			return fallback
		KEY_DEFAULT_NOTE_COLOR:
			if value is String:
				var hex: String = (value as String).strip_edges().trim_prefix("#")
				if hex.length() == 6 and Color.html_is_valid(hex):
					return hex.to_lower()
			return fallback
		KEY_LANGUAGE:
			return value if value is String and Localization.CHOICES.has(value) else fallback
		KEY_THEME:
			return value if value is String and ThemeColors.CHOICES.has(value) else fallback
		KEY_OPEN_MODE:
			return value if value is String and OPEN_MODES.has(value) else fallback
	return fallback

static func save(values: Dictionary) -> void:
	var clean: Dictionary = {}
	for key: String in values:
		if defaults().has(key):
			clean[key] = sanitize(key, values[key])
	AppSettings.set_values(SECTION, clean)

static func reduce_motion() -> bool:
	return bool(get_pref(KEY_REDUCE_MOTION))

static func show_grid() -> bool:
	return bool(get_pref(KEY_SHOW_GRID))

static func line_width_scale() -> float:
	return float(get_pref(KEY_LINE_WIDTH_SCALE))

static func default_note_color() -> Color:
	return Color(str(get_pref(KEY_DEFAULT_NOTE_COLOR)))

static func backups_kept() -> int:
	return int(get_pref(KEY_BACKUPS_KEPT))

static func export_include_linked() -> bool:
	return bool(get_pref(KEY_EXPORT_INCLUDE_LINKED))

static func language() -> String:
	return str(get_pref(KEY_LANGUAGE))

static func theme() -> String:
	return str(get_pref(KEY_THEME))

static func open_mode() -> String:
	return str(get_pref(KEY_OPEN_MODE))

static func minimap_decor() -> bool:
	return bool(get_pref(KEY_MINIMAP_DECOR))

static func collapse_distant_notes() -> bool:
	return bool(get_pref(KEY_COLLAPSE_DISTANT_NOTES))

static func layout_spacing() -> Dictionary:
	return {
		"level_gap": float(int(get_pref(KEY_LAYOUT_LEVEL_GAP))),
		"sibling_gap": float(int(get_pref(KEY_LAYOUT_SIBLING_GAP))),
		"block_gap": float(int(get_pref(KEY_LAYOUT_BLOCK_GAP))),
		"ring_step": float(int(get_pref(KEY_LAYOUT_RING_STEP))),
	}
