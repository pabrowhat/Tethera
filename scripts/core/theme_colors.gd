class_name ThemeColors
extends RefCounted

class Notifier:
	extends RefCounted
	signal changed

const DEFAULT_ID: String = "dark"
const AUTO: String = "auto"
const BUILT_IN: Array[String] = ["dark", "light"]
const CHOICES: Array[String] = ["auto", "dark", "light"]
const PATH: String = "res://themes/%s.json"
const FORMAT: int = 1
const MISSING_COLOR: Color = Color.MAGENTA

const STYLEBOX_COLORS: Dictionary = {
	"Button": {
		"normal": ["control.normal", "border"],
		"hover": ["control.hover", "accent.soft"],
		"pressed": ["accent", "accent"],
		"hover_pressed": ["accent", "accent"],
		"disabled": ["control.disabled", "control.disabled_border"],
	},
	"HScrollBar": {
		"grabber": ["scrollbar.grabber", ""],
		"grabber_highlight": ["scrollbar.grabber_hover", ""],
		"grabber_pressed": ["accent", ""],
	},
	"VScrollBar": {
		"grabber": ["scrollbar.grabber", ""],
		"grabber_highlight": ["scrollbar.grabber_hover", ""],
		"grabber_pressed": ["accent", ""],
	},
	"HSlider": {
		"slider": ["control.normal", "border"],
		"grabber_area": ["accent.fill", ""],
		"grabber_area_highlight": ["accent", ""],
	},
	"LineEdit": {
		"normal": ["control.normal", "border"],
		"focus": ["control.normal", "accent"],
		"read_only": ["control.disabled", "control.disabled_border"],
	},
	"TextEdit": {
		"normal": ["control.normal", "border"],
		"focus": ["control.normal", "accent"],
		"read_only": ["control.disabled", "control.disabled_border"],
	},
	"TooltipPanel": {
		"panel": ["surface.panel", "border"],
	},
}

const THEME_COLORS: Dictionary = {
	"Button": {
		"font_color": "text.primary",
		"font_disabled_color": "text.disabled",
		"font_focus_color": "text.primary",
		"font_hover_color": "text.strong",
		"font_hover_pressed_color": "text.on_accent",
		"font_pressed_color": "text.on_accent",
		"icon_disabled_color": "text.disabled",
		"icon_focus_color": "text.primary",
		"icon_hover_color": "text.strong",
		"icon_hover_pressed_color": "text.on_accent",
		"icon_normal_color": "text.primary",
		"icon_pressed_color": "text.on_accent",
	},
	"CheckButton": {
		"font_color": "text.primary",
		"font_disabled_color": "text.disabled",
		"font_focus_color": "text.primary",
		"font_hover_color": "text.strong",
		"font_hover_pressed_color": "text.strong",
		"font_pressed_color": "text.strong",
	},
	"Label": {
		"font_color": "text.primary",
	},
	"RichTextLabel": {
		"default_color": "text.primary",
		"font_selected_color": "text.strong",
		"selection_color": "accent.selection",
	},
	"LineEdit": {
		"caret_color": "text.primary",
		"clear_button_color": "text.muted",
		"clear_button_color_pressed": "text.strong",
		"font_color": "text.primary",
		"font_placeholder_color": "text.disabled",
		"font_readonly_color": "text.muted",
		"font_selected_color": "text.strong",
		"selection_color": "accent.selection",
	},
	"TextEdit": {
		"caret_color": "text.primary",
		"font_color": "text.primary",
		"font_placeholder_color": "text.disabled",
		"font_readonly_color": "text.muted",
		"font_selected_color": "text.strong",
		"selection_color": "accent.selection",
	},
	"TooltipLabel": {
		"font_color": "text.primary",
	},
}

const BINDINGS_META: StringName = &"theme_bindings"
const PRUNE_START: int = 256

static var _notifier: Notifier = Notifier.new()
static var _bound: Array[WeakRef] = []
static var _prune_at: int = PRUNE_START
static var _base: Dictionary = {}
static var _colors: Dictionary = {}
static var _active_id: String = ""

static func parse(text: String) -> Dictionary:
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		return {}
	var source: Dictionary = data as Dictionary
	if int(source.get("format", 0)) != FORMAT or not source.get("colors") is Dictionary:
		return {}
	var colors: Dictionary = {}
	for key: Variant in (source["colors"] as Dictionary):
		var value: Variant = (source["colors"] as Dictionary)[key]
		if not key is String or not value is String or not is_valid_hex(value as String):
			return {}
		colors[StringName(key as String)] = Color(value as String)
	return colors

static func is_valid_hex(value: String) -> bool:
	if not value.begins_with("#"):
		return false
	var digits: String = value.trim_prefix("#")
	return (digits.length() == 6 or digits.length() == 8) and digits.is_valid_hex_number()

static func load_file(theme_id: String) -> Dictionary:
	if not BUILT_IN.has(theme_id):
		return {}
	return parse(FileAccess.get_file_as_string(PATH % theme_id))

static func apply_saved() -> void:
	apply_theme(Preferences.theme())

static func resolve_choice(choice: String) -> String:
	if choice != AUTO:
		return choice if BUILT_IN.has(choice) else DEFAULT_ID
	if not DisplayServer.is_dark_mode_supported():
		return DEFAULT_ID
	return "dark" if DisplayServer.is_dark_mode() else "light"

static func apply_theme(choice: String) -> void:
	var theme_id: String = resolve_choice(choice)
	_ensure_base()
	if theme_id == _active_id and not _colors.is_empty():
		return
	var merged: Dictionary = _base.duplicate()
	if theme_id != DEFAULT_ID:
		merged.merge(load_file(theme_id), true)
	_colors = merged
	_active_id = theme_id
	_write_project_theme()
	RenderingServer.set_default_clear_color(color(&"canvas.background"))
	_refresh_bound()
	_notifier.changed.emit()

static func active_id() -> String:
	_ensure_loaded()
	return _active_id

static func color(key: StringName) -> Color:
	_ensure_loaded()
	var value: Variant = _colors.get(key)
	if value is Color:
		return value as Color
	push_error("theme colour missing: " + String(key))
	return MISSING_COLOR

static func faded(key: StringName, alpha: float) -> Color:
	return Color(color(key), alpha)

static func ink_for(background: Color) -> Color:
	if background.get_luminance() > 0.5:
		return color(&"ink.on_light")
	return color(&"ink.on_dark")

static func watch(apply: Callable) -> void:
	_ensure_loaded()
	apply.call()
	_notifier.changed.connect(apply)

static func bind(target: Object, property: StringName, key: StringName, alpha: float = -1.0) -> void:
	_remember(target, [false, property, key, alpha])
	target.set(property, resolve(key, alpha))

static func unbind(target: Object, property: StringName) -> void:
	if not target.has_meta(BINDINGS_META):
		return
	var list: Array = target.get_meta(BINDINGS_META) as Array
	for index: int in range(list.size() - 1, -1, -1):
		var entry: Array = list[index] as Array
		if not bool(entry[0]) and entry[1] == property:
			list.remove_at(index)
	target.set_meta(BINDINGS_META, list)

static func bind_override(control: Control, item: StringName, key: StringName, alpha: float = -1.0) -> void:
	_remember(control, [true, item, key, alpha])
	control.add_theme_color_override(item, resolve(key, alpha))

static func resolve(key: StringName, alpha: float = -1.0) -> Color:
	if key == &"":
		return Color.TRANSPARENT
	var resolved: Color = color(key)
	return resolved if alpha < 0.0 else Color(resolved, alpha)

static func _remember(target: Object, binding: Array) -> void:
	var list: Array = []
	if target.has_meta(BINDINGS_META):
		list = target.get_meta(BINDINGS_META) as Array
	else:
		_bound.append(weakref(target))
		if _bound.size() > _prune_at:
			_prune()
	for index: int in list.size():
		var existing: Array = list[index] as Array
		if existing[0] == binding[0] and existing[1] == binding[1]:
			list[index] = binding
			target.set_meta(BINDINGS_META, list)
			return
	list.append(binding)
	target.set_meta(BINDINGS_META, list)

static func _prune() -> void:
	var live: Array[WeakRef] = []
	for reference: WeakRef in _bound:
		if reference.get_ref() != null:
			live.append(reference)
	_bound = live
	_prune_at = maxi(PRUNE_START, live.size() * 2)

static func _refresh_bound() -> void:
	var live: Array[WeakRef] = []
	for reference: WeakRef in _bound:
		var target: Object = reference.get_ref() as Object
		if target == null:
			continue
		live.append(reference)
		for binding: Variant in (target.get_meta(BINDINGS_META, []) as Array):
			var entry: Array = binding as Array
			var resolved: Color = resolve(entry[2] as StringName, float(entry[3]))
			if bool(entry[0]):
				(target as Control).add_theme_color_override(entry[1] as StringName, resolved)
			else:
				target.set(entry[1] as StringName, resolved)
	_bound = live

static func _ensure_base() -> void:
	if _base.is_empty():
		_base = load_file(DEFAULT_ID)

static func _ensure_loaded() -> void:
	if _colors.is_empty():
		apply_theme(Preferences.theme())

static func _write_project_theme() -> void:
	var project_theme: Theme = ThemeDB.get_project_theme()
	if project_theme == null:
		return
	for type_name: String in STYLEBOX_COLORS:
		var styles: Dictionary = STYLEBOX_COLORS[type_name]
		for style_name: String in styles:
			var keys_for_style: Array = styles[style_name]
			var style: StyleBoxFlat = _flat_style(project_theme, style_name, type_name)
			if keys_for_style[0] != "":
				style.bg_color = color(StringName(keys_for_style[0] as String))
			if keys_for_style[1] != "":
				style.border_color = color(StringName(keys_for_style[1] as String))
	for type_name: String in THEME_COLORS:
		var entries: Dictionary = THEME_COLORS[type_name]
		for entry_name: String in entries:
			project_theme.set_color(entry_name, type_name, color(StringName(entries[entry_name] as String)))
	project_theme.emit_changed()

static func _flat_style(project_theme: Theme, style_name: String, type_name: String) -> StyleBoxFlat:
	if project_theme.has_stylebox(style_name, type_name):
		var existing: StyleBox = project_theme.get_stylebox(style_name, type_name)
		if existing is StyleBoxFlat:
			return existing as StyleBoxFlat
	var created: StyleBoxFlat = StyleBoxFlat.new()
	created.set_border_width_all(1)
	created.set_corner_radius_all(6)
	created.content_margin_left = 8.0
	created.content_margin_right = 8.0
	created.content_margin_top = 6.0
	created.content_margin_bottom = 6.0
	project_theme.set_stylebox(style_name, type_name, created)
	return created
