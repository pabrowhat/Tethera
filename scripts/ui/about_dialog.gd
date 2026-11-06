class_name AboutDialog
extends ModalDialog

enum Tab { ABOUT, WHATS_NEW }

const DIALOG_WIDTH: float = 580.0
const LICENSE_HEIGHT: float = 200.0
const CONTENT_HEIGHT: float = 340.0
const AUTHOR: String = "pabrowhat"
const GITHUB_URL: String = "https://github.com/pabrowhat/tethera"
const SECTION_GAP: float = 8.0
const LUCIDE_LICENSE_PATH: String = "res://assets/icons/LICENSE-lucide.txt"

var _tab_buttons: Array[Button] = []
var _tab_group: ButtonGroup = null
var _about_page: ScrollContainer = null
var _whats_new_page: ScrollContainer = null
var _whats_new_box: VBoxContainer = null
var _guide_dialog: GuideDialog = null
var _expanded_versions: Dictionary = {}

func _init() -> void:
	super()
	_set_card_width(DIALOG_WIDTH)
	_guide_dialog = GuideDialog.new()
	add_child(_guide_dialog)
	_body.add_child(_make_label("about.title", 15, TITLE_COLOR))

	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	_body.add_child(tabs)
	_tab_group = ButtonGroup.new()
	for tab: Tab in [Tab.ABOUT, Tab.WHATS_NEW]:
		var button: Button = _make_button("about.tab.about" if tab == Tab.ABOUT else "about.tab.whats_new", false)
		button.toggle_mode = true
		button.button_group = _tab_group
		button.add_theme_stylebox_override("pressed", UiStyle.box(UiStyle.ACCENT_SOFT, UiStyle.ACCENT, 6, 16.0, 8.0))
		button.add_theme_stylebox_override("hover_pressed", UiStyle.box(UiStyle.ACCENT_SOFT, UiStyle.ACCENT, 6, 16.0, 8.0))
		button.pressed.connect(_show_tab.bind(tab))
		tabs.add_child(button)
		_tab_buttons.append(button)

	_about_page = _make_scroll()
	_build_about_page()
	_whats_new_page = _make_scroll()
	_whats_new_box = VBoxContainer.new()
	_whats_new_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_whats_new_box.add_theme_constant_override("separation", 8)
	_whats_new_page.add_child(_whats_new_box)
	_build_whats_new_page()

	var footer: HBoxContainer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_END
	_body.add_child(footer)
	var close_button: Button = _make_button("about.close", true)
	close_button.pressed.connect(close)
	footer.add_child(close_button)
	_show_tab(Tab.ABOUT)

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _about_page != null and _whats_new_box != null:
		for node: Node in _about_page.get_children():
			_about_page.remove_child(node)
			node.queue_free()
		for node: Node in _whats_new_box.get_children():
			_whats_new_box.remove_child(node)
			node.queue_free()
		_build_about_page()
		_build_whats_new_page()

func open_tab(tab: Tab) -> void:
	_show_tab(tab)
	open()

func _make_scroll() -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0.0, CONTENT_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	return scroll

func _show_tab(tab: Tab) -> void:
	_tab_buttons[tab].set_pressed_no_signal(true)
	_about_page.visible = tab == Tab.ABOUT
	_whats_new_page.visible = tab == Tab.WHATS_NEW


func _build_about_page() -> void:
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 8)
	_about_page.add_child(box)
	box.add_child(_make_label(str(ProjectSettings.get_setting("application/config/name", "Tethera")), 22, TITLE_COLOR))
	var version_row: HBoxContainer = HBoxContainer.new()
	version_row.add_theme_constant_override("separation", 8)
	box.add_child(version_row)
	var version_label: Label = _make_label(tr("about.version") % AppVersion.current(), 13, TEXT_COLOR)
	version_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	version_row.add_child(version_label)
	var guide_button: Button = _make_button("about.guide", false)
	guide_button.pressed.connect(_guide_dialog.open_guide)
	version_row.add_child(guide_button)
	var author_row: HBoxContainer = HBoxContainer.new()
	author_row.add_theme_constant_override("separation", 8)
	box.add_child(author_row)
	var author_label: Label = _make_label(tr("about.author") % AUTHOR, 13, TEXT_COLOR)
	author_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	author_row.add_child(author_label)
	var github_button: Button = _make_button("about.github", false)
	github_button.pressed.connect(func() -> void: OS.shell_open(GITHUB_URL))
	author_row.add_child(github_button)
	var section_gap: Control = Control.new()
	section_gap.custom_minimum_size = Vector2(0.0, SECTION_GAP)
	box.add_child(section_gap)
	box.add_child(_make_label("about.licenses", 15, TITLE_COLOR))
	_add_license(box, "about.license.godot", _godot_notice)
	_add_license(box, "about.license.lucide", _lucide_notice)

func _add_license(box: VBoxContainer, title: String, reader: Callable) -> void:
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	box.add_child(header)
	var name_label: Label = _make_label(title, 13, TEXT_COLOR)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	var toggle: Button = _make_button("about.license.show", false)
	header.add_child(toggle)
	var text_view: TextEdit = TextEdit.new()
	text_view.editable = false
	text_view.custom_minimum_size = Vector2(0.0, LICENSE_HEIGHT)
	text_view.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_view.visible = false
	box.add_child(text_view)
	toggle.pressed.connect(func() -> void:
		if not text_view.visible and text_view.text == "":
			text_view.text = str(reader.call())
		text_view.visible = not text_view.visible
		toggle.text = "about.license.hide" if text_view.visible else "about.license.show")

func _godot_notice() -> String:
	var parts: PackedStringArray = PackedStringArray([Engine.get_license_text()])
	var licenses: Dictionary = Engine.get_license_info()
	for license_name: Variant in licenses:
		parts.append("%s\n\n%s" % [str(license_name), str(licenses[license_name])])
	for component: Variant in Engine.get_copyright_info():
		if component is Dictionary:
			var entry: Dictionary = component as Dictionary
			var lines: PackedStringArray = PackedStringArray([str(entry.get("name", ""))])
			for part: Variant in entry.get("parts", []):
				if part is Dictionary:
					var copyright_lines: Variant = (part as Dictionary).get("copyright", [])
					if copyright_lines is Array:
						for copyright_line: Variant in (copyright_lines as Array):
							lines.append("  " + str(copyright_line))
					lines.append("  " + str((part as Dictionary).get("license", "")))
			parts.append("\n".join(lines))
	return "\n\n".join(parts)

func _lucide_notice() -> String:
	if not FileAccess.file_exists(LUCIDE_LICENSE_PATH):
		return tr("about.license.missing")
	return FileAccess.get_file_as_string(LUCIDE_LICENSE_PATH)


func _build_whats_new_page() -> void:
	var current: String = AppVersion.current()
	var keys: PackedStringArray = AppVersion.whats_new_keys(current)
	if keys.is_empty():
		_whats_new_box.add_child(_make_label("about.whats_new.none", 13, MUTED_COLOR, true))
	else:
		_whats_new_box.add_child(_make_label(tr("about.whats_new.heading") % current, 15, TITLE_COLOR))
		_add_note_lines(_whats_new_box, keys)
	var earlier: PackedStringArray = PackedStringArray()
	for version: String in AppVersion.all_versions():
		if AppVersion.compare_versions(version, current) < 0 and not AppVersion.whats_new_keys(version).is_empty():
			earlier.append(version)
	if earlier.is_empty():
		return
	_whats_new_box.add_child(_make_label("about.whats_new.earlier", 13, MUTED_COLOR))
	for version: String in earlier:
		_add_earlier_version(version)

func _add_earlier_version(version: String) -> void:
	var holder: VBoxContainer = VBoxContainer.new()
	holder.add_theme_constant_override("separation", 6)
	holder.visible = _expanded_versions.has(version)
	var toggle: Button = _make_button(tr("about.whats_new.heading") % version, false)
	toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	toggle.toggle_mode = true
	toggle.set_pressed_no_signal(holder.visible)
	toggle.add_theme_stylebox_override("pressed", UiStyle.box(UiStyle.ACCENT_SOFT, UiStyle.ACCENT, 6, 16.0, 8.0))
	toggle.add_theme_stylebox_override("hover_pressed", UiStyle.box(UiStyle.ACCENT_SOFT, UiStyle.ACCENT, 6, 16.0, 8.0))
	toggle.toggled.connect(func(open: bool) -> void:
		holder.visible = open
		if open:
			_expanded_versions[version] = true
		else:
			_expanded_versions.erase(version))
	_whats_new_box.add_child(toggle)
	_add_note_lines(holder, AppVersion.whats_new_keys(version))
	_whats_new_box.add_child(holder)

func _add_note_lines(box: VBoxContainer, keys: PackedStringArray) -> void:
	for key: String in keys:
		var line: Label = _make_label("- " + tr(key), 13, TEXT_COLOR, true)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_child(line)
