class_name GraphCard
extends MarginContainer

signal drag_started(card: GraphCard)
signal drag_moved(card: GraphCard, delta: Vector2, velocity_x: float)
signal drag_ended(card: GraphCard)
signal card_clicked(card: GraphCard, is_ctrl: bool)
signal card_clean_clicked(card: GraphCard)
signal carried_toggled(card: GraphCard)
signal title_changed(card: GraphCard, new_title: String)
signal flip_started(card: GraphCard, to_back: bool)
signal flip_finished(card: GraphCard)
signal status_changed(card: GraphCard, new_status: String)
signal backlink_pressed(target_id: String)
signal cover_clicked(card: GraphCard)

@export_group("Physics & Wobble")
@export var max_tilt_angle_deg: float = 18.0
@export var tilt_responsiveness: float = 0.04
@export var spring_stiffness: float = 220.0
@export var spring_damping: float = 14.0

@export_group("Lift Settings")
@export var lift_scale: Vector2 = Vector2(1.08, 1.08)
@export var lift_duration: float = 0.15

@export_group("Flip")
@export var flip_in_duration: float = 0.09
@export var flip_out_duration: float = 0.13
@export var flip_shadow_alpha: float = 0.55

@export_group("Semantic Zoom")
@export var compact_fade_duration: float = 0.08
@export var compact_morph_duration: float = 0.12

@export_group("Color & Cover")
@export var color_tween_duration: float = 0.22
@export var cover_hint_duration: float = 0.12

@onready var flip_shadow: Panel = $FlipShadow
@onready var face_root: MarginContainer = $FaceHost/FaceRoot
@onready var background_rect: ColorRect = $FaceHost/FaceRoot/BackgroundRect
@onready var front_margin: MarginContainer = $FaceHost/FaceRoot/ContentMargin
@onready var image_rect: TextureRect = $FaceHost/FaceRoot/ContentMargin/VBoxContainer/ImageRect
@onready var zoom_hint: Label = $FaceHost/FaceRoot/ContentMargin/VBoxContainer/ImageRect/ZoomHint
@onready var status_dot: Control = $FaceHost/FaceRoot/ContentMargin/VBoxContainer/TitleRow/StatusDot
@onready var title_label: Label = $FaceHost/FaceRoot/ContentMargin/VBoxContainer/TitleRow/TitleContainer/TitleLabel
@onready var title_edit: LineEdit = $FaceHost/FaceRoot/ContentMargin/VBoxContainer/TitleRow/TitleContainer/TitleEdit
@onready var flip_button: Button = $FaceHost/FaceRoot/ContentMargin/VBoxContainer/TitleRow/FlipButton
@onready var content_label: RichTextLabel = $FaceHost/FaceRoot/ContentMargin/VBoxContainer/ContentLabel
@onready var back_margin: MarginContainer = $FaceHost/FaceRoot/BackMargin
@onready var back_flip_button: Button = $FaceHost/FaceRoot/BackMargin/BackBox/BackHeader/BackFlipButton
@onready var back_title_label: Label = $FaceHost/FaceRoot/BackMargin/BackBox/BackHeader/BackTitle
@onready var backlinks_title_label: Label = $FaceHost/FaceRoot/BackMargin/BackBox/BacklinksTitle
@onready var dates_label: RichTextLabel = $FaceHost/FaceRoot/BackMargin/BackBox/DatesLabel
@onready var todo_chip: Button = $FaceHost/FaceRoot/BackMargin/BackBox/StatusChips/TodoChip
@onready var progress_chip: Button = $FaceHost/FaceRoot/BackMargin/BackBox/StatusChips/ProgressChip
@onready var done_chip: Button = $FaceHost/FaceRoot/BackMargin/BackBox/StatusChips/DoneChip
@onready var backlinks_box: VBoxContainer = $FaceHost/FaceRoot/BackMargin/BackBox/BacklinksBox
@onready var type_box: VBoxContainer = $FaceHost/FaceRoot/BackMargin/BackBox/TypeBox
@onready var manual_title_label: Label = $FaceHost/FaceRoot/BackMargin/BackBox/ManualTitle
@onready var manual_box: VBoxContainer = $FaceHost/FaceRoot/BackMargin/BackBox/ManualBox
@onready var outgoing_title_label: Label = $FaceHost/FaceRoot/BackMargin/BackBox/OutgoingTitle
@onready var outgoing_box: VBoxContainer = $FaceHost/FaceRoot/BackMargin/BackBox/OutgoingBox

var card_id: String = ""
var card_color: Color = Color(Preferences.DEFAULT_NOTE_COLOR_HEX)
var content_text: String = ""
var display_color: Color = ThemeColors.color(&"card.border")
var display_line_color: Color = ThemeColors.color(&"card.line")
var image_path: String = ""
var status: String = STATUS_NONE
var entity_type_id: String = ""
var field_values: Dictionary = {}
var color_overridden: bool = false
var bg_color_hex: String = ""
var bg_color2_hex: String = ""
var bg_image_path: String = ""
var created_at: int = 0
var modified_at: int = 0
var is_dragging: bool = false
var is_carried: bool = false
var is_group_following: bool = false
var is_link_source: bool = false
var is_selected: bool = false
var is_renaming: bool = false
var is_flipped: bool = false
var is_compact: bool = false
var drag_offset: Vector2 = Vector2.ZERO

var _angular_velocity: float = 0.0
var _current_angle: float = 0.0
var _prev_mouse_pos: Vector2 = Vector2.ZERO
var _external_velocity_x: float = 0.0
var _lift_tween: Tween = null
var _flash_tween: Tween = null
var _punch_tween: Tween = null
var _flip_tween: Tween = null
var _lod_tween: Tween = null
var _color_tween: Tween = null
var _hint_tween: Tween = null
var _search_tween: Tween = null
var _search_alpha: float = 1.0
var _filter_alpha: float = 1.0
var _glide_tween: Tween = null
var _shader_material: ShaderMaterial = null
var _status_shape: RoundedShape = null
var _body_color: Color = ThemeColors.color(FRONT_BG)
var _body_color2: Color = ThemeColors.color(FRONT_BG)
var _body_input_color: Variant = null
var _body_input_color2: Variant = null
var _body_has_gradient: bool = false
var _body_texture: Texture2D = null
var _pill_color: Color = ThemeColors.color(FRONT_BG)

var _border_rest_color: Color = ThemeColors.color(&"card.border")
var _border_active_color: Color = ThemeColors.color(&"accent")
var _color_from: PackedColorArray = PackedColorArray()
var _color_to: PackedColorArray = PackedColorArray()
var _is_hovering_cover: bool = false
var _press_on_hint: bool = false

var _is_flipping: bool = false
var _has_cover: bool = false
var _press_global: Vector2 = Vector2.ZERO
var _last_press_moved: bool = false

var _ellipsis_label: Label = null
var _measured_width: float = -1.0
var _image_render_width: int = 0
var _has_inline_images: bool = false

var _base_min_size: Vector2 = BASE_MIN_SIZE
var _full_size: Vector2 = BASE_MIN_SIZE
var _compact_font_px: int = TITLE_FONT_SIZE
var _compact_amount: float = 0.0
var _body_alpha: float = 1.0

const STATUS_NONE: String = ""
const STATUS_TODO: String = "todo"
const STATUS_IN_PROGRESS: String = "in_progress"
const STATUS_DONE: String = "done"

const CARRIED_COLOR: StringName = &"card.carried"
const MUTED_INK_FACTOR: float = 0.7
const FLIP_ICON_ITEMS: Array[String] = ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]
const BORDER_THICKNESS: float = 2.0
const REMOVE_DURATION: float = 0.15
const REMOVE_SCALE: float = 0.85
const BORDER_THICKNESS_SELECTED: float = 3.0

const CARD_WIDTH: float = 240.0
const CARD_MAX_HEIGHT: float = 320.0
const BASE_MIN_SIZE: Vector2 = Vector2(CARD_WIDTH, 100.0)
const TEXT_WIDTH_FALLBACK: float = CARD_WIDTH - 24.0
const MIN_TEXT_HEIGHT: float = 24.0
const FADE_HEIGHT: float = 36.0
const ELLIPSIS_COLOR: StringName = &"text.caption"
const TITLE_FONT_SIZE: int = 14
const FACE_MARGIN: Vector2 = Vector2(12.0, 10.0)
const DOT_SIZE: float = 12.0
const ROW_GAP: float = 6.0
const BASE_CORNER_RADIUS: float = 8.0
const FRONT_BG: StringName = &"card.body"
const PICTURE_OVERLAY_ALPHA: float = 0.55
const FLIP_MIN_SCALE: float = 0.02
const DOUBLE_CLICK_DRAG_SLOP: float = 4.0
const MAX_BACKLINK_ROWS: int = 5
const HINT_ALPHA: float = 0.6

const SEARCH_FADE_DURATION: float = 0.18
const TEXT_CLIP_SHADER: Shader = preload("res://shaders/text_clip.gdshader")

const CHIP_BG: StringName = &"control.normal"
const CHIP_BG_HOVER: StringName = &"control.hover"
const CHIP_BORDER: StringName = &"border"
const CHIP_ACCENT: StringName = &"accent"
const STATUS_RING_WIDTH: float = 1.7
const STATUS_HALF_INSET: float = 2.6
const CHIP_RADIUS: float = 10.0
const CHIP_MARGIN_X: float = 7.0
const CHIP_MARGIN_Y: float = 2.0

const STATUS_COLORS: Dictionary = {
	STATUS_TODO: &"card.status.todo",
	STATUS_IN_PROGRESS: &"card.status.in_progress",
	STATUS_DONE: &"card.status.done",
}

static func is_default_color(color: Color) -> bool:
	return color.is_equal_approx(Color(Preferences.DEFAULT_NOTE_COLOR_HEX))

func _ready() -> void:
	pivot_offset = size / 2.0
	_sync_min_size()
	resized.connect(_on_resized)
	face_root.resized.connect(_on_face_resized)
	face_root.minimum_size_changed.connect(_sync_min_size)

	if is_instance_valid(background_rect) and background_rect.material:
		_shader_material = background_rect.material.duplicate() as ShaderMaterial
		background_rect.material = _shader_material
		background_rect.resized.connect(_update_shader_size)
		_update_shader_size()
		_update_border_display()
		_update_surface_colors()

	image_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	AppFonts.apply_note_fonts(content_label)
	_build_ellipsis_label()
	content_label.resized.connect(_on_content_label_resized)
	_setup_text_clip()

	title_edit.visible = false
	title_edit.text_submitted.connect(_on_title_submitted)
	title_edit.focus_exited.connect(_on_title_focus_exited)

	_status_shape = RoundedShape.new()
	_status_shape.show_behind_parent = true
	_status_shape.visible = false
	status_dot.add_child(_status_shape)
	status_dot.draw.connect(_on_status_dot_draw)
	for chip: Button in [todo_chip, progress_chip, done_chip]:
		RoundedShape.attach_to_button(chip, {
			BaseButton.DRAW_NORMAL: [CHIP_BG, CHIP_BORDER],
			BaseButton.DRAW_HOVER: [CHIP_BG_HOVER, CHIP_ACCENT],
			BaseButton.DRAW_PRESSED: [CHIP_ACCENT, CHIP_ACCENT],
			BaseButton.DRAW_HOVER_PRESSED: [CHIP_ACCENT, CHIP_ACCENT],
		}, 1.0, CHIP_RADIUS, CHIP_MARGIN_X, CHIP_MARGIN_Y)
	flip_button.pressed.connect(toggle_flip)
	back_flip_button.pressed.connect(toggle_flip)
	todo_chip.pressed.connect(_on_chip_pressed.bind(STATUS_TODO))
	progress_chip.pressed.connect(_on_chip_pressed.bind(STATUS_IN_PROGRESS))
	done_chip.pressed.connect(_on_chip_pressed.bind(STATUS_DONE))
	_sync_status_chips()
	_bind_scene_colors()
	ThemeColors.watch(_on_theme_changed)

func _bind_scene_colors() -> void:
	ThemeColors.bind(title_edit.get_theme_stylebox(&"normal"), &"bg_color", UiStyle.BG_NORMAL)
	ThemeColors.bind(title_edit.get_theme_stylebox(&"normal"), &"border_color", UiStyle.ACCENT)
	ThemeColors.bind_override(title_edit, &"font_color", &"text.strong")
	ThemeColors.bind_override(zoom_hint, &"font_color", &"ink.on_dark")
	_apply_back_text_colors()

func _on_theme_changed() -> void:
	set_category_color(card_color, false)
	set_body_background(_body_input_color, _body_input_color2, _body_texture)
	if _back_filled:
		_repopulate_back()
	status_dot.queue_redraw()

func _front_ink() -> Array[Color]:
	if not _body_input_color is Color and _body_texture == null:
		return [ThemeColors.color(&"card.text"), ThemeColors.color(&"card.text_muted")]
	var ink: Color = ThemeColors.ink_for(_pill_color)
	return [ink, Color(ink, ink.a * MUTED_INK_FACTOR)]

func _apply_front_text_colors() -> void:
	var ink: Array[Color] = _front_ink()
	title_label.add_theme_color_override("font_color", ink[0])
	content_label.add_theme_color_override("default_color", ink[1])
	for item: String in FLIP_ICON_ITEMS:
		flip_button.add_theme_color_override(item, ink[0])
		back_flip_button.add_theme_color_override(item, ink[0])
	_apply_back_text_colors()

func _apply_back_text_colors() -> void:
	var ink: Array[Color] = _front_ink()
	back_title_label.add_theme_color_override("font_color", ink[0])
	dates_label.add_theme_color_override("default_color", ink[1])
	for label: Label in [backlinks_title_label, outgoing_title_label, manual_title_label]:
		label.add_theme_color_override("font_color", ink[0])
		label.add_theme_font_override("font", AppFonts.note_bold())

func setup(id: String, initial_title: String, initial_content: String = "", color_hex: String = "313549", img_path: String = "") -> void:
	card_id = id
	set_category_color(Color(color_hex), false)
	title_label.text = initial_title
	title_edit.text = initial_title
	set_content(initial_content)
	set_cover_image(img_path)

func apply_meta(new_status: String, created: int, modified: int) -> void:
	created_at = created
	modified_at = modified
	set_status(new_status)

func apply_type_data(type_id: String, values: Dictionary, is_color_overridden: bool) -> void:
	entity_type_id = type_id
	field_values = values.duplicate(true)
	color_overridden = is_color_overridden

func apply_background_data(color_hex: String, color2_hex: String, image: String) -> void:
	bg_color_hex = NoteBackground.sanitize_hex(color_hex)
	bg_color2_hex = NoteBackground.sanitize_hex(color2_hex)
	bg_image_path = image

func set_content(text: String) -> void:
	content_text = text
	_render_content()
	_update_content_clamp()

func _render_content() -> void:
	_image_render_width = int(content_label.size.x) if content_label.size.x >= 1.0 else int(TEXT_WIDTH_FALLBACK)
	_has_inline_images = not NoteImages.find_inline(content_text).is_empty()
	var heading: String = ""
	if _body_input_color is Color or _body_texture != null:
		heading = "#" + _front_ink()[0].to_html(false)
	content_label.text = MarkdownBBCode.to_bbcode(content_text, MarkdownBBCode.Profile.CARD, _image_render_width, heading)

func _build_ellipsis_label() -> void:
	_ellipsis_label = Label.new()
	_ellipsis_label.text = "…"
	_ellipsis_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ellipsis_label.add_theme_font_size_override("font_size", 14)
	ThemeColors.bind_override(_ellipsis_label, &"font_color", ELLIPSIS_COLOR)
	_ellipsis_label.visible = false
	content_label.add_child(_ellipsis_label)
	_ellipsis_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_ellipsis_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ellipsis_label.grow_vertical = Control.GROW_DIRECTION_BEGIN

func _update_content_clamp() -> void:
	if not is_node_ready() or is_compact or not content_label.visible:
		return
	if content_label.size.x < 1.0:
		return

	_measured_width = content_label.size.x
	var full_height: float = ceilf(float(content_label.get_content_height()))
	var chrome: float = front_margin.get_combined_minimum_size().y - content_label.get_combined_minimum_size().y
	var max_text: float = maxf(CARD_MAX_HEIGHT - chrome, MIN_TEXT_HEIGHT)
	var overflows: bool = full_height > max_text

	content_label.custom_minimum_size.y = minf(full_height, max_text)
	_set_text_fade(overflows)
	_ellipsis_label.visible = overflows

	if not is_flipped and not _is_flipping:
		_refit_size(false)

func _setup_text_clip() -> void:
	var clip_material: ShaderMaterial = ShaderMaterial.new()
	clip_material.shader = TEXT_CLIP_SHADER
	content_label.material = clip_material
	_update_text_clip()

func _set_text_fade(on: bool) -> void:
	var clip_material: ShaderMaterial = content_label.material as ShaderMaterial
	if clip_material:
		clip_material.set_shader_parameter("fade_on", on)
		clip_material.set_shader_parameter("fade_height", FADE_HEIGHT)

func _update_text_clip() -> void:
	var clip_material: ShaderMaterial = content_label.material as ShaderMaterial
	if clip_material:
		clip_material.set_shader_parameter("clip_size", content_label.size)

func _on_content_label_resized() -> void:
	_update_text_clip()
	if _has_inline_images and content_label.size.x >= 1.0 and int(content_label.size.x) != _image_render_width:
		_render_content()
	if not is_equal_approx(content_label.size.x, _measured_width):
		_update_content_clamp()

func set_cover_image(path: String) -> void:
	image_path = path
	_has_cover = false
	image_rect.texture = null
	if image_path != "":
		var img: Image = ImageGuard.load_image(image_path)
		if img:
			img.generate_mipmaps()
			var tex: ImageTexture = ImageTexture.create_from_image(img)
			image_rect.texture = tex
			_has_cover = true
	image_rect.visible = _has_cover and not is_compact
	_set_cover_hover(false)
	_update_content_clamp()

func get_screen_rect() -> Rect2:
	var xform: Transform2D = get_global_transform()
	return Rect2(xform.origin, size * xform.get_scale())

func get_cover_texture() -> Texture2D:
	return image_rect.texture if _has_cover else null

func get_cover_screen_rect() -> Rect2:
	var xform: Transform2D = image_rect.get_global_transform()
	return Rect2(xform.origin, image_rect.size * xform.get_scale())

func set_category_color(new_color: Color, animate: bool = true) -> void:
	card_color = new_color
	_kill_tween(_color_tween)

	var targets: PackedColorArray = _color_targets(new_color)
	if not animate or not is_inside_tree():
		_apply_color_channels(targets)
		return

	_color_from = _current_color_channels()
	_color_to = targets
	_color_tween = create_tween()
	_color_tween.tween_method(_on_color_mix, 0.0, 1.0, color_tween_duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _color_targets(base: Color) -> PackedColorArray:
	if is_default_color(base):
		var slate: Color = ThemeColors.color(&"card.border")
		return PackedColorArray([slate, ThemeColors.color(&"card.line"), slate, ThemeColors.color(&"accent")])
	return PackedColorArray([base, base, base, base.lightened(0.4)])

func _current_color_channels() -> PackedColorArray:
	return PackedColorArray([display_color, display_line_color, _border_rest_color, _border_active_color])

func _apply_color_channels(channels: PackedColorArray) -> void:
	display_color = channels[0]
	display_line_color = channels[1]
	_border_rest_color = channels[2]
	_border_active_color = channels[3]
	_update_border_display()
	_update_surface_colors()
	status_dot.queue_redraw()

func _on_color_mix(weight: float) -> void:
	var mixed: PackedColorArray = PackedColorArray()
	for i: int in _color_to.size():
		mixed.append(_color_from[i].lerp(_color_to[i], weight))
	_apply_color_channels(mixed)

func set_status(new_status: String, notify: bool = false) -> void:
	status = new_status
	_sync_status_chips()
	status_dot.queue_redraw()
	if notify:
		status_changed.emit(self, status)

func get_card_center() -> Vector2:
	return position + (size / 2.0)

func contains_global_point(point: Vector2) -> bool:
	return get_global_rect().has_point(point)


var _back_created: String = ""
var _back_modified: String = ""
var _back_links: Array[Dictionary] = []
var _back_outgoing: Array[Dictionary] = []
var _back_manual: Array[Dictionary] = []
var _back_type: Dictionary = {}
var _back_words: int = -1
var _back_filled: bool = false

func populate_back(created_text: String, modified_text: String, backlinks: Array[Dictionary], outgoing: Array[Dictionary] = [], type_info: Dictionary = {}, word_count: int = -1, manual: Array[Dictionary] = []) -> void:
	_back_created = created_text
	_back_modified = modified_text
	_back_links = backlinks
	_back_outgoing = outgoing
	_back_manual = manual
	_back_type = type_info
	_back_words = word_count
	_back_filled = true
	_repopulate_back()

func _repopulate_back() -> void:
	if not _back_filled:
		return
	var dates: String = tr("card.dates") % [_back_created, _back_modified]
	if _back_words >= 0:
		dates += "\n" + tr("card.words") % _back_words
	dates_label.text = _emphasise_heads(dates, _front_ink()[0])
	_fill_type_box()
	_fill_link_box(backlinks_box, _back_links, "card.backlinks.none")
	_fill_link_box(outgoing_box, _back_outgoing, "card.outgoing.none")
	manual_title_label.visible = not _back_manual.is_empty()
	manual_box.visible = not _back_manual.is_empty()
	if not _back_manual.is_empty():
		_fill_link_box(manual_box, _back_manual, "")

	if is_flipped and not is_compact and not _is_flipping:
		_refit_size(true)

func _emphasise_heads(text: String, head_color: Color) -> String:
	var rows: PackedStringArray = PackedStringArray()
	for row: String in text.split("
"):
		var cut: int = row.find(": ")
		rows.append(row.replace("[", "[lb]") if cut < 0 else "[color=#%s]%s[/color]%s" % [head_color.to_html(false), row.substr(0, cut + 1).replace("[", "[lb]"), row.substr(cut + 1).replace("[", "[lb]")])
	return "
".join(rows)

func _clear_box(box: Container) -> void:
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()

func _fill_link_box(box: VBoxContainer, rows: Array[Dictionary], none_key: String) -> void:
	_clear_box(box)
	if rows.is_empty():
		box.add_child(_make_hint_label(none_key))
		return
	var shown: int = mini(rows.size(), MAX_BACKLINK_ROWS)
	for i: int in shown:
		box.add_child(_make_backlink_button(rows[i]))
	if rows.size() > shown:
		box.add_child(_make_hint_label(tr("card.backlinks.more") % (rows.size() - shown)))

func _fill_type_box() -> void:
	_clear_box(type_box)
	type_box.visible = not _back_type.is_empty()
	if _back_type.is_empty():
		return
	var name_label: Label = _make_value_label(str(_back_type["name"]))
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_font_override("font", AppFonts.note_bold())
	name_label.add_theme_color_override("font_color", _backlink_tint(_back_type["color"] as Color))
	type_box.add_child(name_label)
	for row: Dictionary in _back_type["fields"]:
		var line: Label = _make_value_label(tr("card.type.field") % [str(row["label"]), str(row["value"])])
		line.clip_text = true
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		type_box.add_child(line)
	if int(_back_type.get("more", 0)) > 0:
		type_box.add_child(_make_hint_label(tr("card.backlinks.more") % int(_back_type["more"])))

func _make_hint_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(_front_ink()[1], HINT_ALPHA))
	return label

func _make_value_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", _front_ink()[0])
	return label

func _make_backlink_button(info: Dictionary) -> Button:
	var target_id: String = str(info.get("id", ""))
	var tint: Color = _backlink_tint(info.get("color", Color.WHITE) as Color)

	var button: Button = Button.new()
	button.text = str(info.get("title", ""))
	button.tooltip_text = "card.backlink.tooltip"
	button.flat = true
	button.clip_text = true
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_color_override("font_color", tint)
	button.add_theme_color_override("font_hover_color", tint.lightened(0.3))
	button.pressed.connect(func() -> void: backlink_pressed.emit(target_id))
	return button

func _backlink_tint(color: Color) -> Color:
	var on_dark: bool = _front_ink()[0].get_luminance() > 0.5
	if on_dark and color.get_luminance() < 0.4:
		return color.lightened(0.55)
	if not on_dark and color.get_luminance() > 0.5:
		return color.darkened(0.45)
	return color

func _sync_status_chips() -> void:
	todo_chip.set_pressed_no_signal(status == STATUS_TODO)
	progress_chip.set_pressed_no_signal(status == STATUS_IN_PROGRESS)
	done_chip.set_pressed_no_signal(status == STATUS_DONE)

func _on_chip_pressed(key: String) -> void:
	set_status(STATUS_NONE if status == key else key, true)

func _on_status_dot_draw() -> void:
	var dot_size: Vector2 = status_dot.size
	var radius: float = minf(dot_size.x, dot_size.y) * 0.5 - 1.0
	_status_shape.visible = radius > 1.0
	if radius <= 1.0:
		return

	var center: Vector2 = dot_size / 2.0
	var tint: Color = Color.TRANSPARENT
	if STATUS_COLORS.has(status):
		tint = ThemeColors.color(STATUS_COLORS[status] as StringName)
	if status == STATUS_NONE:
		tint = display_color.lightened(0.35) if display_color.get_luminance() < 0.5 and ThemeColors.color(FRONT_BG).get_luminance() < 0.5 else display_color

	var clear: Color = Color(tint, 0.0)
	_status_shape.clear_inner()
	_status_shape.clear_tick()
	match status:
		STATUS_TODO:
			_status_shape.place_centered(center, (radius + 0.05) * 2.0)
			_status_shape.set_style(clear, tint, STATUS_RING_WIDTH)
		STATUS_IN_PROGRESS:
			_status_shape.place_centered(center, (radius + 0.05) * 2.0)
			_status_shape.set_style(clear, tint, STATUS_RING_WIDTH)
			_status_shape.set_inner(tint, STATUS_HALF_INSET, true)
		STATUS_DONE:
			_status_shape.place_centered(center, radius * 2.0)
			_status_shape.set_style(tint, tint, 0.0)
			var tick: PackedVector2Array = PackedVector2Array([
				Vector2(-0.45, 0.0) * radius,
				Vector2(-0.1, 0.38) * radius,
				Vector2(0.5, -0.36) * radius,
			])
			_status_shape.set_tick(tick, _body_color, maxf(1.4, radius * 0.22))
		_:
			_status_shape.place_centered(center, radius * 0.8 * 2.0)
			_status_shape.set_style(tint, tint, 0.0)


func toggle_flip() -> void:
	set_flipped(not is_flipped, true)

func set_flipped(value: bool, animate: bool = true) -> void:
	if value == is_flipped:
		return
	if animate and (is_compact or is_renaming or _is_flipping):
		return

	_kill_tween(_flip_tween)
	_set_cover_hover(false)
	is_flipped = value

	if not animate or is_compact:
		_is_flipping = false
		face_root.scale = Vector2.ONE
		flip_shadow.modulate.a = 0.0
		if not is_compact:
			_show_face(is_flipped)
			_refit_size(false)
		return

	_is_flipping = true
	flip_started.emit(self, is_flipped)

	if Preferences.reduce_motion():
		_on_flip_midpoint()
		_on_flip_finished()
		return

	_flip_tween = create_tween()
	_flip_tween.tween_property(face_root, "scale:x", FLIP_MIN_SCALE, flip_in_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_flip_tween.parallel().tween_property(flip_shadow, "modulate:a", flip_shadow_alpha, flip_in_duration)
	_flip_tween.tween_callback(_on_flip_midpoint)
	_flip_tween.tween_property(face_root, "scale:x", 1.0, flip_out_duration) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_flip_tween.parallel().tween_property(flip_shadow, "modulate:a", 0.0, flip_out_duration)
	_flip_tween.tween_callback(_on_flip_finished)

func _on_flip_midpoint() -> void:
	_show_face(is_flipped)
	_refit_size(true)

func _on_flip_finished() -> void:
	_is_flipping = false
	if not is_flipped:
		_update_content_clamp()
	face_root.scale = Vector2.ONE
	flip_shadow.modulate.a = 0.0
	flip_finished.emit(self)

func _snap_flip() -> void:
	if not _is_flipping:
		return
	_kill_tween(_flip_tween)
	_is_flipping = false
	face_root.scale = Vector2.ONE
	flip_shadow.modulate.a = 0.0
	flip_finished.emit(self)

func _show_face(show_back: bool) -> void:
	front_margin.visible = not show_back
	back_margin.visible = show_back
	if not show_back:
		_update_content_clamp()
	_update_surface_colors()

func _refit_size(keep_center: bool) -> void:
	_sync_min_size()
	var old_size: Vector2 = size
	size = Vector2.ZERO
	if keep_center:
		position += (old_size - size) * 0.5


func set_compact_font(px: int) -> void:
	if px == _compact_font_px:
		return
	_compact_font_px = px
	refresh_compact_layout()

func refresh_compact_layout() -> void:
	if is_compact and _compact_amount >= 1.0 and not _is_tween_running(_lod_tween):
		_apply_compact_amount(1.0)

func set_compact(value: bool, animate: bool = true) -> void:
	if is_compact == value:
		return

	if is_renaming:
		_finish_rename()
	_snap_flip()
	_set_cover_hover(false)

	var interrupted: bool = _is_tween_running(_lod_tween)
	_kill_tween(_lod_tween)
	is_compact = value

	if value:
		if not interrupted:
			_full_size = size.max(get_combined_minimum_size())
		if animate:
			_play_collapse()
		else:
			_enter_compact_layout()
			_apply_compact_amount(1.0)
	else:
		if animate:
			_play_expand()
		else:
			_apply_compact_amount(0.0)
			_leave_compact_layout()
			_set_body_alpha(1.0)

func _play_collapse() -> void:
	_lod_tween = create_tween()
	_lod_tween.tween_method(_set_body_alpha, _body_alpha, 0.0, maxf(compact_fade_duration * _body_alpha, 0.001))
	_lod_tween.tween_callback(_enter_compact_layout)
	if Preferences.reduce_motion():
		_lod_tween.tween_callback(_apply_compact_amount.bind(1.0))
		return
	_lod_tween.tween_method(_apply_compact_amount, _compact_amount, 1.0, compact_morph_duration) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _play_expand() -> void:
	_lod_tween = create_tween()
	var start: float = _compact_amount
	if Preferences.reduce_motion():
		_lod_tween.tween_callback(_apply_compact_amount.bind(0.0))
	else:
		_lod_tween.tween_method(_apply_compact_amount, start, 0.0, maxf(compact_morph_duration * start, 0.001)) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_lod_tween.tween_callback(_leave_compact_layout)
	_lod_tween.tween_method(_set_body_alpha, _body_alpha, 1.0, compact_fade_duration)

func _enter_compact_layout() -> void:
	image_rect.visible = false
	content_label.visible = false
	flip_button.visible = false
	back_margin.visible = false
	front_margin.visible = true
	face_root.scale = Vector2.ONE
	_set_body_alpha(0.0)
	_base_min_size = Vector2.ZERO
	_sync_min_size()

func _leave_compact_layout() -> void:
	image_rect.visible = _has_cover
	content_label.visible = true
	flip_button.visible = true
	_base_min_size = BASE_MIN_SIZE
	_show_face(is_flipped)
	_update_content_clamp()
	_refit_size(false)

func _set_body_alpha(alpha: float) -> void:
	_body_alpha = alpha
	image_rect.modulate.a = alpha
	content_label.modulate.a = alpha
	flip_button.modulate.a = alpha
	back_margin.modulate.a = alpha

func _apply_compact_amount(amount: float) -> void:
	_compact_amount = amount
	var pill: Vector2 = _compute_pill_size()
	var pad: Vector2 = _pill_padding()

	title_label.add_theme_font_size_override("font_size", roundi(lerpf(float(TITLE_FONT_SIZE), float(_compact_font_px), amount)))
	front_margin.add_theme_constant_override("margin_left", roundi(lerpf(FACE_MARGIN.x, pad.x, amount)))
	front_margin.add_theme_constant_override("margin_right", roundi(lerpf(FACE_MARGIN.x, pad.x, amount)))
	front_margin.add_theme_constant_override("margin_top", roundi(lerpf(FACE_MARGIN.y, pad.y, amount)))
	front_margin.add_theme_constant_override("margin_bottom", roundi(lerpf(FACE_MARGIN.y, pad.y, amount)))

	var dot: float = lerpf(DOT_SIZE, _pill_dot_size(), amount)
	status_dot.custom_minimum_size = Vector2(dot, dot)

	_set_corner_radius(lerpf(BASE_CORNER_RADIUS, pill.y * 0.5, amount))
	_update_surface_colors()
	size = _full_size.lerp(pill, amount)

func _pill_padding() -> Vector2:
	var px: float = float(_compact_font_px)
	return Vector2(roundf(px * 0.7), roundf(px * 0.4))

func _pill_dot_size() -> float:
	return roundf(float(_compact_font_px) * 0.75)

func _compute_pill_size() -> Vector2:
	var px: int = _compact_font_px
	var font: Font = title_label.get_theme_font("font")
	var text_width: float = font.get_string_size(title_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, px).x
	var pad: Vector2 = _pill_padding()
	var width: float = text_width + _pill_dot_size() + ROW_GAP + pad.x * 2.0 + 2.0
	width = clampf(width, float(px) * 5.0, float(px) * 14.0)
	var height: float = font.get_height(px) + pad.y * 2.0
	return Vector2(ceilf(width), ceilf(height))


func _sync_min_size() -> void:
	custom_minimum_size = face_root.get_combined_minimum_size().max(_base_min_size)

func _update_shader_size() -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("rect_size", background_rect.size)

func _set_corner_radius(radius: float) -> void:
	if _shader_material:
		_shader_material.set_shader_parameter("corner_radius", radius)

func _update_surface_colors() -> void:
	if not _shader_material:
		return
	_shader_material.set_shader_parameter("bg_color", _body_color.lerp(_pill_color, _compact_amount))
	var face_bg2: Color = _body_color2 if _body_has_gradient else _body_color
	_shader_material.set_shader_parameter("bg_color2", face_bg2.lerp(_pill_color, _compact_amount))
	var picture_amount: float = (1.0 - _compact_amount) if _body_texture != null else 0.0
	_shader_material.set_shader_parameter("bg_image_amount", picture_amount)

func set_body_background(color: Variant, color2: Variant, texture: Texture2D) -> void:
	_body_input_color = color
	_body_input_color2 = color2
	_body_color = color as Color if color is Color else ThemeColors.color(FRONT_BG)
	_body_has_gradient = color2 is Color
	_body_color2 = color2 as Color if color2 is Color else _body_color
	_body_texture = texture
	if color is Color:
		_pill_color = color as Color
	elif texture != null:
		_pill_color = InlineImages.average_color_of(texture, ThemeColors.color(FRONT_BG)).lerp(Color.BLACK, PICTURE_OVERLAY_ALPHA)
	else:
		_pill_color = ThemeColors.color(FRONT_BG)
	if _shader_material:
		_shader_material.set_shader_parameter("bg_texture", texture)
		if texture != null:
			_shader_material.set_shader_parameter("bg_texture_size", Vector2(texture.get_width(), texture.get_height()))
	_update_surface_colors()
	if is_node_ready():
		_apply_front_text_colors()
		_render_content()
		_repopulate_back()

func _is_tween_running(tween: Tween) -> bool:
	return tween != null and tween.is_valid() and tween.is_running()

func _kill_tween(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()

func _process(delta: float) -> void:
	if delta <= 0.0:
		return

	var target_tilt: float = 0.0

	if (is_dragging or is_carried or is_group_following) and Preferences.reduce_motion():
		_current_angle = 0.0
		_angular_velocity = 0.0
		_external_velocity_x = 0.0
		rotation = 0.0
		return

	if is_dragging:
		var current_mouse_pos: Vector2 = get_global_mouse_position()
		var mouse_delta_x: float = (current_mouse_pos.x - _prev_mouse_pos.x) / delta
		_prev_mouse_pos = current_mouse_pos
		target_tilt = clampf(-mouse_delta_x * tilt_responsiveness, -max_tilt_angle_deg, max_tilt_angle_deg)
	elif (is_carried or is_group_following) and absf(_external_velocity_x) > 0.1:
		target_tilt = clampf(-_external_velocity_x * tilt_responsiveness, -max_tilt_angle_deg, max_tilt_angle_deg)
		_external_velocity_x = lerpf(_external_velocity_x, 0.0, 10.0 * delta)

	var spring_force: float = (deg_to_rad(target_tilt) - _current_angle) * spring_stiffness
	var damping_force: float = -_angular_velocity * spring_damping

	_angular_velocity += (spring_force + damping_force) * delta
	_current_angle += _angular_velocity * delta

	if not is_dragging and not is_carried and absf(_current_angle) < 0.001 and absf(_angular_velocity) < 0.001:
		rotation = 0.0
		_current_angle = 0.0
		_angular_velocity = 0.0
	else:
		rotation = _current_angle

func _gui_input(event: InputEvent) -> void:
	if is_renaming:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var is_ctrl: bool = PlatformKeys.primary_down()
				var is_shift: bool = Input.is_key_pressed(KEY_SHIFT)
				var is_space: bool = Input.is_key_pressed(KEY_SPACE)

				if mb.double_click and not _last_press_moved and not is_ctrl and not is_shift and not is_space:
					if _is_over_cover(mb.position):
						cover_clicked.emit(self)
					else:
						toggle_flip()
					accept_event()
					return

				_last_press_moved = false
				_press_global = mb.global_position
				card_clicked.emit(self, is_ctrl)

				if is_space:
					carried_toggled.emit(self)
					accept_event()
					return

				if not is_ctrl and not is_shift:
					_press_on_hint = _is_over_zoom_hint(mb.position)
					_start_drag(mb.global_position)
				accept_event()
			else:
				if is_dragging:
					_stop_drag()
					if _press_on_hint and not _last_press_moved:
						cover_clicked.emit(self)
					elif not _press_on_hint and not _last_press_moved:
						card_clean_clicked.emit(self)
					_press_on_hint = false
					accept_event()

	elif event is InputEventMouseMotion and not is_dragging:
		var hover_pos: Vector2 = (event as InputEventMouseMotion).position
		_set_cover_hover(_is_over_cover(hover_pos))
		_update_cover_cursor(_is_over_zoom_hint(hover_pos))

	elif event is InputEventMouseMotion and is_dragging:
		var motion: InputEventMouseMotion = event as InputEventMouseMotion
		if not _last_press_moved and motion.global_position.distance_to(_press_global) > DOUBLE_CLICK_DRAG_SLOP:
			_last_press_moved = true
			_set_cover_hover(false)

		var parent_control: Control = get_parent_control()
		if parent_control:
			var previous_position: Vector2 = position
			position = parent_control.get_local_mouse_position() - drag_offset
			drag_moved.emit(self, position - previous_position, motion.velocity.x)

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_set_cover_hover(false)
	elif what == NOTIFICATION_TRANSLATION_CHANGED and _back_filled and dates_label != null:
		_repopulate_back()

func _is_over_cover(local_pos: Vector2) -> bool:
	if not _has_cover or is_compact or is_flipped or _is_flipping or is_renaming:
		return false
	if not image_rect.is_visible_in_tree():
		return false
	var origin: Vector2 = get_global_transform().affine_inverse() * image_rect.get_global_position()
	return Rect2(origin, image_rect.size).has_point(local_pos)

func _is_over_zoom_hint(local_pos: Vector2) -> bool:
	if not _is_over_cover(local_pos):
		return false
	var origin: Vector2 = get_global_transform().affine_inverse() * zoom_hint.get_global_position()
	return Rect2(origin, zoom_hint.size).has_point(local_pos)

func _update_cover_cursor(over_hint: bool) -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if over_hint else Control.CURSOR_ARROW

func _set_cover_hover(hovering: bool) -> void:
	if hovering == _is_hovering_cover:
		return
	_is_hovering_cover = hovering
	if not hovering:
		_update_cover_cursor(false)
	_kill_tween(_hint_tween)
	_hint_tween = create_tween()
	_hint_tween.tween_property(zoom_hint, "modulate:a", 1.0 if hovering else 0.0, cover_hint_duration)

func set_link_source(active: bool) -> void:
	is_link_source = active
	_update_border_display()

func set_group_following(active: bool) -> void:
	if is_group_following == active:
		return
	is_group_following = active
	if active:
		move_to_front()
	_animate_lift(active or is_carried)
	_update_border_display()

func set_carried(carried: bool) -> void:
	is_carried = carried
	if is_carried:
		move_to_front()
	_animate_lift(is_carried)
	_update_border_display()

func set_selected(active: bool, punch: bool = false) -> void:
	if is_selected == active:
		return
	is_selected = active
	_update_border_display()
	if active and punch:
		play_capture_punch()

func play_capture_punch() -> void:
	if Preferences.reduce_motion() or is_dragging or is_carried or is_group_following:
		return
	if _lift_tween and _lift_tween.is_valid():
		_lift_tween.kill()
	if _punch_tween and _punch_tween.is_valid():
		_punch_tween.kill()

	_punch_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_punch_tween.tween_property(self, "scale", Vector2(1.03, 1.03), 0.08)
	_punch_tween.tween_property(self, "scale", Vector2.ONE, 0.1)

func _update_border_display() -> void:
	var target_color: Color = _border_rest_color
	if is_carried:
		target_color = ThemeColors.color(CARRIED_COLOR)
	elif is_dragging or is_link_source or is_selected:
		target_color = _border_active_color

	if _shader_material:
		_shader_material.set_shader_parameter("border_color", target_color)
		_shader_material.set_shader_parameter("border_thickness", BORDER_THICKNESS_SELECTED if is_selected else BORDER_THICKNESS)

func apply_carrier_shift(delta_pos: Vector2, velocity_x: float) -> void:
	position += delta_pos
	_external_velocity_x = velocity_x

func glide_to(target: Vector2, duration: float = 0.12) -> Tween:
	_kill_tween(_glide_tween)
	_glide_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_glide_tween.tween_property(self, "position", target, duration)
	return _glide_tween

func _start_drag(mouse_global: Vector2) -> void:
	_kill_tween(_glide_tween)
	is_dragging = true
	drag_offset = get_local_mouse_position()
	_prev_mouse_pos = mouse_global
	move_to_front()
	_animate_lift(true)
	_update_border_display()
	drag_started.emit(self)

func _stop_drag() -> void:
	is_dragging = false
	_animate_lift(is_carried)
	_update_border_display()
	drag_ended.emit(self)

func _animate_lift(lifting: bool) -> void:
	if _lift_tween and _lift_tween.is_valid():
		_lift_tween.kill()

	var target_scale: Vector2 = lift_scale if lifting else Vector2.ONE
	if Preferences.reduce_motion():
		scale = target_scale
		return
	_lift_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_lift_tween.tween_property(self, "scale", target_scale, lift_duration)

func start_rename() -> void:
	if is_compact or is_flipped or _is_flipping or is_renaming:
		return
	is_renaming = true
	title_label.visible = false
	title_edit.visible = true
	title_edit.text = title_label.text
	title_edit.grab_focus()
	title_edit.select_all()

func _finish_rename() -> void:
	if not is_renaming:
		return
	is_renaming = false
	var new_title: String = title_edit.text.strip_edges()
	if new_title != "":
		title_label.text = new_title
		title_changed.emit(self, new_title)
	title_edit.visible = false
	title_label.visible = true

func _on_title_submitted(_new_text: String) -> void:
	_finish_rename()

func _on_title_focus_exited() -> void:
	_finish_rename()

func flash_highlight() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	background_rect.self_modulate = Color(1.9, 1.9, 1.9)
	_flash_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_flash_tween.tween_property(background_rect, "self_modulate", Color.WHITE, 0.45)

func set_search_alpha(alpha: float, immediate: bool = false) -> void:
	if not immediate and is_equal_approx(alpha, _search_alpha):
		return
	_search_alpha = alpha
	_fade_to_dim_alpha(immediate)

func set_filter_alpha(alpha: float, immediate: bool = false) -> void:
	if not immediate and is_equal_approx(alpha, _filter_alpha):
		return
	_filter_alpha = alpha
	_fade_to_dim_alpha(immediate)

func _dim_alpha() -> float:
	return minf(_search_alpha, _filter_alpha)

func _fade_to_dim_alpha(immediate: bool) -> void:
	_kill_tween(_search_tween)
	if immediate:
		modulate.a = _dim_alpha()
		return
	_search_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_search_tween.tween_property(self, "modulate:a", _dim_alpha(), SEARCH_FADE_DURATION)

func play_spawn_animation() -> void:
	if Preferences.reduce_motion():
		scale = Vector2.ONE
		modulate.a = _dim_alpha()
		return
	scale = Vector2(0.3, 0.3)
	modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, 0.3)
	tween.tween_property(self, "modulate:a", _dim_alpha(), 0.2)

func play_remove_animation() -> void:
	if not is_inside_tree() or Preferences.reduce_motion():
		queue_free()
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)
	pivot_offset = size / 2.0
	_kill_tween(_search_tween)
	_kill_tween(_lift_tween)
	_kill_tween(_punch_tween)
	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(REMOVE_SCALE, REMOVE_SCALE), REMOVE_DURATION)
	tween.tween_property(self, "modulate:a", 0.0, REMOVE_DURATION)
	tween.chain().tween_callback(queue_free)

func _on_resized() -> void:
	pivot_offset = size / 2.0

func _on_face_resized() -> void:
	face_root.pivot_offset = face_root.size / 2.0
