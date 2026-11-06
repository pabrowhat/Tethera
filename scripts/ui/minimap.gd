class_name Minimap
extends Control

signal fit_requested

const ICON_MAXIMIZE: Texture2D = preload("res://assets/icons/maximize.svg")
const ICON_PLUS: Texture2D = preload("res://assets/icons/plus.svg")
const ICON_MINUS: Texture2D = preload("res://assets/icons/minus.svg")
const HEADER_ICON_SIZE: int = 14
const MAP_SIZE: Vector2 = Vector2(220.0, 150.0)
const HEADER_HEIGHT: float = 24.0
const SCREEN_MARGIN: float = 16.0
const MIN_DOT_SIZE: Vector2 = Vector2(3.0, 2.0)
const MIN_WORLD_PADDING: float = 100.0
const WORLD_PADDING_RATIO: float = 0.1
const WORLD_SMOOTHING: float = 10.0
const OUTLIER_MIN_SPREAD: float = 300.0
const OUTLIER_SPREAD_FACTOR: float = 1.5
const OUTLIER_MARKER_SIZE: float = 5.0
const BG_ALPHA_IDLE: float = 0.4
const BG_ALPHA_HOVER: float = 0.8
const BG_ALPHA_SPEED: float = 4.0
const CLICK_DRAG_THRESHOLD: float = 3.0
const GRID_SPACING: float = 16.0
const TOOLTIP_FONT_SIZE: int = 11
const COLLAPSE_DURATION: float = 0.22

const ACCENT_COLOR: StringName = &"accent"
const FRAME_FILL_COLOR: StringName = &"minimap.frame_fill"
const FRAME_BORDER_COLOR: StringName = &"minimap.frame_border"
const GRID_COLOR: StringName = &"minimap.grid"
const TEXT_COLOR: StringName = &"text.caption"
const BACKGROUND_COLOR: StringName = &"minimap.background"
const BORDER_COLOR: StringName = &"border"
const TOOLTIP_BACKGROUND_COLOR: StringName = &"minimap.tooltip_background"
const TOOLTIP_TEXT_COLOR: StringName = &"text.strong"
const DARK_DOT_LIMIT: float = 0.3
const LIGHT_DOT_LIMIT: float = 0.75

var _navigator: CanvasNavigator = null
var _cards: Dictionary = {}
var _selection: SelectionController = null

var _panel_style: StyleBoxFlat = StyleBoxFlat.new()
var _fit_button: Button = null
var _collapse_button: Button = null

var _collapsed: bool = false
var _open_amount: float = 1.0
var _collapse_tween: Tween = null
var _bg_alpha: float = BG_ALPHA_IDLE
var _is_hovered: bool = false

var _dots: Array[GraphCard] = []
var _outliers: Array[GraphCard] = []
var _world_rect: Rect2 = Rect2()
var _world_ready: bool = false
var _map_scale: float = 1.0
var _hover_card: GraphCard = null

var _drag_active: bool = false
var _drag_follow: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_press_pos: Vector2 = Vector2.ZERO

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	ThemeColors.watch(queue_redraw)

func _ready() -> void:
	_panel_style.set_corner_radius_all(8)
	_panel_style.set_border_width_all(1)
	ThemeColors.bind(_panel_style, &"border_color", BORDER_COLOR)

	_fit_button = _make_header_button(ICON_MAXIMIZE, "minimap.fit")
	_fit_button.pressed.connect(func() -> void: fit_requested.emit())
	_collapse_button = _make_header_button(ICON_MINUS, "minimap.collapse")
	_collapse_button.pressed.connect(toggle_collapsed)

	get_viewport().size_changed.connect(_update_layout)
	_update_layout()

func setup(navigator: CanvasNavigator, cards_by_id: Dictionary, selection: SelectionController) -> void:
	_navigator = navigator
	_cards = cards_by_id
	_selection = selection

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()

func toggle_collapsed() -> void:
	_collapsed = not _collapsed
	_collapse_button.icon = ICON_PLUS if _collapsed else ICON_MINUS
	_collapse_button.tooltip_text = "minimap.expand" if _collapsed else "minimap.collapse"
	_drag_active = false
	_drag_follow = false

	if _collapse_tween != null and _collapse_tween.is_valid():
		_collapse_tween.kill()
	clip_contents = true
	_collapse_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_collapse_tween.tween_method(_set_open_amount, _open_amount, 0.0 if _collapsed else 1.0, COLLAPSE_DURATION)
	_collapse_tween.tween_callback(func() -> void: clip_contents = false)

func _set_open_amount(amount: float) -> void:
	_open_amount = amount
	_update_layout()

func is_point_over(global_pos: Vector2) -> bool:
	return visible and get_global_rect().has_point(global_pos)

func _process(delta: float) -> void:
	if not visible or not is_instance_valid(_navigator):
		return

	_is_hovered = Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position())
	var target_alpha: float = BG_ALPHA_HOVER if (_is_hovered or _drag_active) else BG_ALPHA_IDLE
	_bg_alpha = move_toward(_bg_alpha, target_alpha, BG_ALPHA_SPEED * delta)

	if not _collapsed:
		_update_world(delta)
		_update_hover()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		accept_event()
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if not _collapsed and _map_rect().has_point(mb.position):
					_begin_drag(mb.position)
			else:
				_drag_active = false
				_drag_follow = false
	elif event is InputEventMouseMotion and _drag_active:
		accept_event()
		_update_drag((event as InputEventMouseMotion).position)

func _begin_drag(pos: Vector2) -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var canvas_pos: Vector2 = _to_canvas(pos)
	var visible_rect: Rect2 = _navigator.get_visible_canvas_rect(viewport_size)

	_drag_active = true
	_drag_press_pos = pos
	if _frame_map_rect(visible_rect).has_point(pos):
		_drag_follow = true
		_drag_offset = canvas_pos - visible_rect.get_center()
	else:
		_drag_follow = false
		_drag_offset = Vector2.ZERO
		_navigator.glide_center_to(canvas_pos, viewport_size)

func _update_drag(pos: Vector2) -> void:
	if not _drag_follow:
		if pos.distance_to(_drag_press_pos) < CLICK_DRAG_THRESHOLD:
			return
		_drag_follow = true

	var map_rect: Rect2 = _map_rect()
	var clamped: Vector2 = Vector2(
		clampf(pos.x, map_rect.position.x, map_rect.end.x),
		clampf(pos.y, map_rect.position.y, map_rect.end.y)
	)
	_navigator.follow_center(_to_canvas(clamped) - _drag_offset, get_viewport_rect().size)


func _map_rect() -> Rect2:
	return Rect2(Vector2(0.0, HEADER_HEIGHT), MAP_SIZE)

func _to_map(canvas_pos: Vector2) -> Vector2:
	return _map_rect().position + (canvas_pos - _world_rect.position) * _map_scale

func _to_canvas(map_pos: Vector2) -> Vector2:
	return _world_rect.position + (map_pos - _map_rect().position) / _map_scale

func _card_map_rect(card: GraphCard) -> Rect2:
	return Rect2(_to_map(card.position), (card.size * _map_scale).max(MIN_DOT_SIZE))

func _frame_map_rect(visible_rect: Rect2) -> Rect2:
	return Rect2(_to_map(visible_rect.position), visible_rect.size * _map_scale)

func _outlier_marker_pos(card: GraphCard) -> Vector2:
	var map_rect: Rect2 = _map_rect().grow(-OUTLIER_MARKER_SIZE - 1.0)
	var center: Vector2 = _to_map(card.position + card.size / 2.0)
	return Vector2(
		clampf(center.x, map_rect.position.x, map_rect.end.x),
		clampf(center.y, map_rect.position.y, map_rect.end.y)
	)

func _update_world(delta: float) -> void:
	var visible_rect: Rect2 = _navigator.get_visible_canvas_rect(get_viewport_rect().size)
	var target: Rect2 = _compute_target_world(visible_rect)

	if not _world_ready:
		_world_rect = target
		_world_ready = true
	elif not (_drag_active and _drag_follow):
		var weight: float = 1.0 - exp(-WORLD_SMOOTHING * delta)
		_world_rect = Rect2(
			_world_rect.position.lerp(target.position, weight),
			_world_rect.size.lerp(target.size, weight)
		)

	_map_scale = MAP_SIZE.x / maxf(_world_rect.size.x, 1.0)

func _compute_target_world(visible_rect: Rect2) -> Rect2:
	_dots.clear()
	_outliers.clear()

	var cards: Array[GraphCard] = []
	for entry: Variant in _cards.values():
		if is_instance_valid(entry):
			cards.append(entry as GraphCard)

	var lo: Vector2 = Vector2(-INF, -INF)
	var hi: Vector2 = Vector2(INF, INF)
	if cards.size() >= 4:
		var xs: Array[float] = []
		var ys: Array[float] = []
		for card: GraphCard in cards:
			var center: Vector2 = card.position + card.size / 2.0
			xs.append(center.x)
			ys.append(center.y)
		xs.sort()
		ys.sort()
		var last: int = cards.size() - 1
		var i_lo: int = int(floor(last * 0.1))
		var i_hi: int = int(ceil(last * 0.9))
		var spread: Vector2 = Vector2(
			maxf(xs[i_hi] - xs[i_lo], OUTLIER_MIN_SPREAD),
			maxf(ys[i_hi] - ys[i_lo], OUTLIER_MIN_SPREAD)
		) * OUTLIER_SPREAD_FACTOR
		lo = Vector2(xs[i_lo], ys[i_lo]) - spread
		hi = Vector2(xs[i_hi], ys[i_hi]) + spread

	var core: Rect2 = Rect2()
	var has_core: bool = false
	for card: GraphCard in cards:
		var center: Vector2 = card.position + card.size / 2.0
		if center.x < lo.x or center.x > hi.x or center.y < lo.y or center.y > hi.y:
			_outliers.append(card)
			continue
		_dots.append(card)
		var card_rect: Rect2 = Rect2(card.position, card.size)
		core = card_rect if not has_core else core.merge(card_rect)
		has_core = true

	var world: Rect2 = core.merge(visible_rect) if has_core else visible_rect
	var pad: Vector2 = Vector2(
		maxf(world.size.x * WORLD_PADDING_RATIO, MIN_WORLD_PADDING),
		maxf(world.size.y * WORLD_PADDING_RATIO, MIN_WORLD_PADDING)
	)
	world = world.grow_individual(pad.x, pad.y, pad.x, pad.y)

	var aspect: float = MAP_SIZE.x / MAP_SIZE.y
	var center_point: Vector2 = world.get_center()
	var fitted: Vector2 = world.size
	if fitted.x / maxf(fitted.y, 1.0) < aspect:
		fitted.x = fitted.y * aspect
	else:
		fitted.y = fitted.x / aspect
	return Rect2(center_point - fitted / 2.0, fitted)

func _update_hover() -> void:
	_hover_card = null
	if not _is_hovered or _drag_active:
		return

	var mouse: Vector2 = get_local_mouse_position()
	if not _map_rect().has_point(mouse):
		return

	for i: int in range(_dots.size() - 1, -1, -1):
		if _card_map_rect(_dots[i]).grow(2.0).has_point(mouse):
			_hover_card = _dots[i]
			return
	for card: GraphCard in _outliers:
		if _outlier_marker_pos(card).distance_to(mouse) <= OUTLIER_MARKER_SIZE + 2.0:
			_hover_card = card
			return


func _make_header_button(icon: Texture2D, tip: String) -> Button:
	var button: Button = Button.new()
	button.icon = icon
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", HEADER_ICON_SIZE)
	button.tooltip_text = tip
	button.flat = true
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.size = Vector2(24.0, 20.0)
	add_child(button)
	return button

func _update_layout() -> void:
	var panel_height: float = HEADER_HEIGHT + MAP_SIZE.y * _open_amount
	size = Vector2(MAP_SIZE.x, panel_height)

	var viewport_height: float = get_viewport_rect().size.y
	position = Vector2(SCREEN_MARGIN, viewport_height - SCREEN_MARGIN - panel_height)

	_collapse_button.position = Vector2(MAP_SIZE.x - 28.0, 1.0)
	_fit_button.position = Vector2(MAP_SIZE.x - 56.0, 1.0)
	queue_redraw()

func _draw() -> void:
	_panel_style.bg_color = ThemeColors.faded(BACKGROUND_COLOR, _bg_alpha)
	draw_style_box(_panel_style, Rect2(Vector2.ZERO, size))

	var font: Font = get_theme_default_font()
	draw_string(font, Vector2(10.0, 16.0), tr("minimap.title"), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, ThemeColors.color(TEXT_COLOR))

	if _open_amount <= 0.0 or not _world_ready or not is_instance_valid(_navigator):
		return

	var map_rect: Rect2 = _map_rect()
	if _dots.is_empty() and _outliers.is_empty():
		_draw_empty_grid(map_rect)

	var pulse: float = 0.55 + 0.45 * sin(Time.get_ticks_msec() / 1000.0 * 5.0)
	for card: GraphCard in _dots:
		var dot_rect: Rect2 = _card_map_rect(card).intersection(map_rect)
		if dot_rect.size.x <= 0.0 or dot_rect.size.y <= 0.0:
			continue
		draw_rect(dot_rect, _dot_color(card), true)
		if _selection != null and _selection.has(card):
			draw_rect(dot_rect.grow(2.0), ThemeColors.faded(ACCENT_COLOR, pulse), false, 1.5)

	for card: GraphCard in _outliers:
		_draw_outlier_marker(card, map_rect, pulse)

	var visible_rect: Rect2 = _navigator.get_visible_canvas_rect(get_viewport_rect().size)
	var frame: Rect2 = _frame_map_rect(visible_rect).intersection(map_rect)
	if frame.size.x > 0.0 and frame.size.y > 0.0:
		draw_rect(frame, ThemeColors.color(FRAME_FILL_COLOR), true)
		draw_rect(frame, ThemeColors.color(FRAME_BORDER_COLOR), false, 1.0)

	if is_instance_valid(_hover_card):
		_draw_tooltip(font, _hover_card.title_label.text)

func _dot_color(card: GraphCard) -> Color:
	var col: Color = card.display_color
	var on_dark: bool = ThemeColors.color(BACKGROUND_COLOR).get_luminance() < 0.5
	if on_dark and col.get_luminance() < DARK_DOT_LIMIT:
		col = col.lightened(0.45)
	elif not on_dark and col.get_luminance() > LIGHT_DOT_LIMIT:
		col = col.darkened(0.3)
	return col

func _draw_empty_grid(map_rect: Rect2) -> void:
	var x: float = map_rect.position.x + GRID_SPACING / 2.0
	while x < map_rect.end.x:
		var y: float = map_rect.position.y + GRID_SPACING / 2.0
		while y < map_rect.end.y:
			draw_circle(Vector2(x, y), 1.0, ThemeColors.color(GRID_COLOR))
			y += GRID_SPACING
		x += GRID_SPACING

func _draw_outlier_marker(card: GraphCard, map_rect: Rect2, pulse: float) -> void:
	var pos: Vector2 = _outlier_marker_pos(card)
	var direction: Vector2 = (_to_map(card.position + card.size / 2.0) - map_rect.get_center()).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	var side: Vector2 = direction.orthogonal()
	var tip: Vector2 = pos + direction * OUTLIER_MARKER_SIZE
	var base_a: Vector2 = pos - direction * OUTLIER_MARKER_SIZE * 0.5 + side * OUTLIER_MARKER_SIZE * 0.7
	var base_b: Vector2 = pos - direction * OUTLIER_MARKER_SIZE * 0.5 - side * OUTLIER_MARKER_SIZE * 0.7
	draw_colored_polygon(PackedVector2Array([tip, base_a, base_b]), _dot_color(card))
	if _selection != null and _selection.has(card):
		draw_circle(pos, OUTLIER_MARKER_SIZE + 2.0, ThemeColors.faded(ACCENT_COLOR, pulse * 0.5))

func _draw_tooltip(font: Font, text: String) -> void:
	var max_width: float = MAP_SIZE.x - 16.0
	var label: String = text if text != "" else tr("note.title_fallback")
	var text_size: Vector2 = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, TOOLTIP_FONT_SIZE)
	var box_width: float = minf(text_size.x, max_width) + 12.0
	var box_height: float = text_size.y + 6.0

	var mouse: Vector2 = get_local_mouse_position()
	var box_x: float = clampf(mouse.x - box_width / 2.0, 4.0, size.x - box_width - 4.0)
	var box_y: float = maxf(mouse.y - box_height - 8.0, HEADER_HEIGHT + 2.0)
	var box: Rect2 = Rect2(Vector2(box_x, box_y), Vector2(box_width, box_height))

	draw_rect(box, ThemeColors.color(TOOLTIP_BACKGROUND_COLOR), true)
	draw_rect(box, ThemeColors.color(BORDER_COLOR), false, 1.0)
	draw_string(font, box.position + Vector2(6.0, box_height - 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, max_width, TOOLTIP_FONT_SIZE, ThemeColors.color(TOOLTIP_TEXT_COLOR))
