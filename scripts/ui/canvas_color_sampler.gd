class_name CanvasColorSampler
extends RefCounted

enum Target { CARD_COLOR, BODY, BODY_END }

var _ws: AppWorkspace = null

func _init(workspace: AppWorkspace) -> void:
	_ws = workspace

func begin_sampling() -> void:
	begin_sampling_for(Target.CARD_COLOR)

func begin_sampling_for_background(gradient_end: bool) -> void:
	begin_sampling_for(Target.BODY_END if gradient_end else Target.BODY)

func begin_sampling_for(target: Target) -> void:
	if _ws._eyedropper.is_active() or _ws._screen_grab.is_busy() or _ws._zen_active or _ws._lightbox.is_open() or _ws._is_modal_open():
		return
	if not _has_target(target):
		return
	_ws._sampling_target = target
	_ws._sampling_card_id = _ws.sidebar_editor.current_card.card_id if is_instance_valid(_ws.sidebar_editor.current_card) else ""

	_ws._cancel_link_source()
	_ws._is_panning = false
	_ws.get_viewport().gui_release_focus()
	await _ws._screen_grab.capture(_ws.get_viewport(), _ws._eyedropper)
	if _ws._eyedropper.is_active() or _ws._is_modal_open() or not _has_target(_ws._sampling_target as Target):
		return
	if not _ws._screen_grab.has_image():
		_ws._toast.show_message(tr("eyedropper.unavailable"), true)
		return
	_ws._eyedropper.begin(_sample_color_at)

func _has_target(target: Target) -> bool:
	if target == Target.CARD_COLOR:
		return _ws._selection.count() > 0
	return is_instance_valid(_ws.sidebar_editor.current_card)

func _end_sampling() -> void:
	_ws._eyedropper.end()
	_ws._screen_grab.release()

func handle_sampling_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and not key.is_echo() and key.keycode == KEY_ESCAPE:
			_end_sampling()
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_RIGHT:
				_end_sampling()
			elif mb.button_index == MOUSE_BUTTON_LEFT:
				var picked: Variant = _sample_color_at(mb.position)
				if picked != null:
					_apply_sampled_color(picked as Color, mb.position)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and not _is_over_ui(mb.position):
				_ws.navigator.zoom_towards(_ws.navigator.zoom_factor, mb.position)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and not _is_over_ui(mb.position):
				_ws.navigator.zoom_towards(1.0 / _ws.navigator.zoom_factor, mb.position)
	_ws.get_viewport().set_input_as_handled()

func _is_over_ui(screen_pos: Vector2) -> bool:
	return _ws._is_mouse_over_sidebar(screen_pos) or _ws._is_mouse_over_topbar(screen_pos) or _ws._is_mouse_over_minimap(screen_pos)

func _sample_color_at(screen_pos: Vector2) -> Variant:
	if Input.is_key_pressed(KEY_SHIFT) and not _is_over_ui(screen_pos):
		var card: GraphCard = _card_at(screen_pos)
		if card != null:
			return Color(card.card_color, 1.0)
	return _ws._screen_grab.color_at(screen_pos)

func _card_at(screen_pos: Vector2) -> GraphCard:
	var children: Array[Node] = _ws.canvas.get_children()
	for i: int in range(children.size() - 1, -1, -1):
		var card: GraphCard = children[i] as GraphCard
		if card == null or not card.visible:
			continue
		var local_pos: Vector2 = card.get_global_transform().affine_inverse() * screen_pos
		if Rect2(Vector2.ZERO, card.size).has_point(local_pos):
			return card
	return null

func _apply_sampled_color(color: Color, screen_pos: Vector2) -> void:
	if _ws._sampling_target != Target.CARD_COLOR:
		_apply_body_color(color, screen_pos)
		return
	var targets: Array[GraphCard] = _ws._selection.get_cards()
	var before: Dictionary = {}
	var after: Dictionary = {}
	var overrides_before: Dictionary = {}
	var overrides_after: Dictionary = {}
	for card: GraphCard in targets:
		var previous: Color = _ws._saved_colors.get(card.card_id, card.card_color)
		if not previous.is_equal_approx(color):
			before[card.card_id] = previous
			after[card.card_id] = color
			overrides_before[card.card_id] = card.color_overridden
			overrides_after[card.card_id] = true
			card.color_overridden = true
		card.set_category_color(color)
		card.play_capture_punch()
		_ws._saved_colors[card.card_id] = color
		_ws._touch_card(card)
	_ws._undo.record_color_change(before, after, overrides_before, overrides_after)

	PaletteStore.instance().add_color(color)
	_ws._eyedropper.confirm_sample(screen_pos, color)
	_end_sampling()

	if targets.size() == 1:
		_ws.sidebar_editor.apply_external_color(color)
		_ws.sidebar_editor.refresh_type_section()
	elif targets.size() > 1:
		_ws.sidebar_editor.show_batch(targets)

func _apply_body_color(color: Color, screen_pos: Vector2) -> void:
	var card_id: String = _ws._sampling_card_id
	PaletteStore.instance().add_color(color, NoteBackgroundSection.BODY_PALETTE)
	if _ws._sampling_target == Target.BODY_END:
		_ws._on_sidebar_background_color2_changed(card_id, color)
	else:
		_ws._on_sidebar_background_color_changed(card_id, color)
	_ws._eyedropper.confirm_sample(screen_pos, color)
	_end_sampling()
