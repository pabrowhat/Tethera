class_name WorkspaceDecor
extends RefCounted

var _ws: AppWorkspace = null

func _init(workspace: AppWorkspace) -> void:
	_ws = workspace

func create_node(item: DecorItem) -> DecorNode:
	if _ws._decor_by_id.has(item.id):
		return null
	var node: DecorNode = DecorNode.new()
	node.apply_item(item)
	layer_container(item.layer).add_child(node)
	_ws._decor_by_id[item.id] = node
	return node

func layer_container(layer: String) -> Node2D:
	return _ws._decor_above if layer == DecorItem.LAYER_ABOVE else _ws._decor_below

func object_count() -> int:
	return _ws._decor_by_id.size() + _ws._extras_kept.size()

func load_all() -> void:
	_ws._extras_kept.clear()
	for entry: Dictionary in _ws._storage.load_decor():
		if object_count() >= DecorItem.MAX_PER_CANVAS:
			break
		var item: DecorItem = DecorItem.from_dict(entry)
		if item != null:
			create_node(item)
	for extra: Dictionary in _ws._storage.load_extras():
		if object_count() >= DecorItem.MAX_PER_CANVAS:
			break
		if str(extra.get("kind", "")) == DecorItem.KIND_TEXT:
			var text_item: DecorItem = DecorItem.from_dict(extra)
			if text_item != null:
				create_node(text_item)
		else:
			_ws._extras_kept.append(extra)

func snapshot_all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node: DecorNode in all_nodes():
		if not node.is_text():
			result.append(node.to_item().to_dict())
	return result

func snapshot_extras() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for node: DecorNode in all_nodes():
		if node.is_text():
			result.append(node.to_item().to_dict())
	for kept: Dictionary in _ws._extras_kept:
		result.append(kept)
	return result

func all_nodes() -> Array[DecorNode]:
	var result: Array[DecorNode] = []
	for value: Variant in _ws._decor_by_id.values():
		if is_instance_valid(value):
			result.append(value as DecorNode)
	return result

func save() -> bool:
	var pictures_saved: bool = _ws._storage.save_decor(snapshot_all())
	var extras_saved: bool = _ws._storage.save_extras(snapshot_extras())
	return pictures_saved and extras_saved


func node_at(canvas_point: Vector2, container: Node2D) -> DecorNode:
	var children: Array[Node] = container.get_children()
	for i: int in range(children.size() - 1, -1, -1):
		var node: DecorNode = children[i] as DecorNode
		if node != null and not node.is_queued_for_deletion() and node.hit_test(canvas_point):
			return node
	return null

func sole_selected() -> DecorNode:
	if _ws._selection.item_count() != 1:
		return null
	var picked: Array[DecorNode] = _ws._selection.get_decor()
	return picked[0] if picked.size() == 1 else null

func refresh_selection_visuals() -> void:
	var sole: DecorNode = sole_selected()
	for node: DecorNode in all_nodes():
		node.set_handles_visible(node == sole)

func on_zoom_changed() -> void:
	for node: DecorNode in all_nodes():
		if node.is_selected or node.shows_empty_frame():
			node.queue_redraw()


const MENU_BELOW: int = 0
const MENU_ABOVE: int = 1
const MENU_DELETE: int = 2
const MENU_FLIP_H: int = 3
const MENU_FLIP_V: int = 4
const MENU_WIDTH: float = 190.0

func note_right_press(mb: InputEventMouseButton) -> void:
	_ws._decor_right_press = {}
	var canvas_pos: Vector2 = _ws.navigator.screen_to_canvas(mb.position)
	var node: DecorNode = node_at(canvas_pos, _ws._decor_above)
	if node == null and not is_instance_valid(_ws._find_card_under_mouse(mb.global_position)):
		node = node_at(canvas_pos, _ws._decor_below)
	if node != null:
		_ws._decor_right_press = {"node": node, "origin": mb.position}

func note_right_release(mb: InputEventMouseButton) -> void:
	var pending: Dictionary = _ws._decor_right_press
	_ws._decor_right_press = {}
	if pending.is_empty():
		return
	var node: DecorNode = pending["node"] as DecorNode
	if not is_instance_valid(node) or mb.position.distance_to(pending["origin"] as Vector2) >= AppWorkspace.MARQUEE_DRAG_THRESHOLD:
		return
	open_menu(node, mb.global_position)

func open_menu(node: DecorNode, global_pos: Vector2) -> void:
	if _ws._decor_menu == null:
		_ws._decor_menu = PopupList.new()
		_ws.get_node("UI").add_child(_ws._decor_menu)
		_ws._decor_menu.item_chosen.connect(_on_menu_chosen)
	_ws._decor_menu_target = node
	if not _ws._selection.has(node):
		_ws._selection.select_only(node)
	var menu: PopupList = _ws._decor_menu
	menu.clear()
	menu.add_item(tr("decor.layer.below"), MENU_BELOW)
	menu.add_item(tr("decor.layer.above"), MENU_ABOVE)
	menu.set_item_disabled(MENU_BELOW, node.layer == DecorItem.LAYER_BELOW)
	menu.set_item_disabled(MENU_ABOVE, node.layer == DecorItem.LAYER_ABOVE)
	menu.add_separator()
	if not node.is_text():
		menu.add_item(tr("decor.flip_h"), MENU_FLIP_H)
		menu.add_item(tr("decor.flip_v"), MENU_FLIP_V)
		menu.add_separator()
	menu.add_item(tr("decor.delete"), MENU_DELETE)
	menu.open_at(global_pos, MENU_WIDTH)

func _on_menu_chosen(id: int) -> void:
	var node: DecorNode = _ws._decor_menu_target
	_ws._decor_menu_target = null
	if not is_instance_valid(node):
		return
	match id:
		MENU_BELOW:
			change_layer(node, DecorItem.LAYER_BELOW)
		MENU_ABOVE:
			change_layer(node, DecorItem.LAYER_ABOVE)
		MENU_FLIP_H:
			flip(node, true)
		MENU_FLIP_V:
			flip(node, false)
		MENU_DELETE:
			var no_cards: Array[GraphCard] = []
			var doomed: Array[DecorNode] = [node]
			_ws._delete_cards(no_cards, doomed)

func flip(node: DecorNode, horizontal: bool) -> void:
	apply_flip(node.decor_id, horizontal)
	_ws._history.record(tr("decor.history.flip"), apply_flip.bind(node.decor_id, horizontal), apply_flip.bind(node.decor_id, horizontal))

func apply_flip(decor_id: String, horizontal: bool) -> void:
	var node: DecorNode = _ws._decor_by_id.get(decor_id, null)
	if not is_instance_valid(node):
		return
	if horizontal:
		node.flip_h = not node.flip_h
	else:
		node.flip_v = not node.flip_v
	save()

func change_layer(node: DecorNode, layer: String) -> void:
	var before: String = node.layer
	if before == layer:
		return
	apply_layer(node.decor_id, layer)
	_ws._history.record(tr("decor.history.layer"), apply_layer.bind(node.decor_id, before), apply_layer.bind(node.decor_id, layer))

func apply_layer(decor_id: String, layer: String) -> void:
	var node: DecorNode = _ws._decor_by_id.get(decor_id, null)
	if not is_instance_valid(node) or node.layer == layer:
		return
	node.layer = layer
	node.reparent(layer_container(layer))
	save()


const KIND_MOVE: String = "move"
const KIND_RESIZE: String = "resize"
const KIND_ROTATE: String = "rotate"

func is_over_blocking_ui(global_pos: Vector2) -> bool:
	return _ws._is_mouse_over_sidebar(global_pos) or _ws._is_mouse_over_topbar(global_pos) or _ws._is_mouse_over_minimap(global_pos) \
		or _ws._is_mouse_over_search_popup(global_pos) or PopupList.is_point_over_open(global_pos)

func try_begin_from_press(mb: InputEventMouseButton) -> bool:
	if is_instance_valid(_ws._link_source_card) or Input.is_key_pressed(KEY_SPACE) or is_over_blocking_ui(mb.global_position):
		return false
	var canvas_pos: Vector2 = _ws.navigator.screen_to_canvas(mb.position)
	var sole: DecorNode = sole_selected()
	if sole != null:
		var handle: int = sole.handle_at(canvas_pos)
		if handle == DecorNode.HANDLE_ROTATE:
			_begin_rotate(sole)
			return true
		if handle != DecorNode.HANDLE_NONE:
			_begin_resize(sole, handle)
			return true
	var hit: DecorNode = node_at(canvas_pos, _ws._decor_above)
	if hit == null:
		return false
	press(hit, mb)
	return true

func press(node: DecorNode, mb: InputEventMouseButton) -> void:
	_ws._finish_carry()
	if mb.double_click and node.is_text() and not Input.is_key_pressed(KEY_SHIFT):
		_ws._selection.select_only(node)
		open_text_editor(node)
		return
	if Input.is_key_pressed(KEY_SHIFT):
		_ws._selection.toggle(node)
		return
	if not _ws._selection.has(node):
		_ws._selection.select_only(node)
	_begin_move(node, mb)

func _begin_move(node: DecorNode, mb: InputEventMouseButton) -> void:
	var movers: Array[DecorNode] = _ws._selection.get_decor()
	var cards: Array[GraphCard] = _ws._selection.get_cards()
	var decor_before: Dictionary = {}
	for mover: DecorNode in movers:
		decor_before[mover.decor_id] = mover.get_state()
	var card_before: Dictionary = {}
	for card: GraphCard in cards:
		card_before[card.card_id] = card.position
		card.set_group_following(true)
	_ws._decor_gesture = {
		"kind": KIND_MOVE, "node": node, "moved": false,
		"start_canvas": _ws.navigator.screen_to_canvas(mb.position), "start_screen": mb.position,
		"decor": movers, "cards": cards, "decor_before": decor_before, "card_before": card_before,
	}

func _begin_resize(node: DecorNode, handle: int) -> void:
	_ws._decor_gesture = make_resize_gesture(node, handle)

func make_resize_gesture(node: DecorNode, handle: int) -> Dictionary:
	var anchor_sign: Vector2 = _anchor_sign(node, handle)
	var half: Vector2 = node.box_size / 2.0
	var anchor_local: Vector2 = Vector2(anchor_sign.x * half.x, anchor_sign.y * half.y)
	var movers: Array[DecorNode] = [node]
	var no_cards: Array[GraphCard] = []
	return {
		"kind": KIND_RESIZE, "node": node, "moved": false, "handle": handle,
		"anchor_sign": anchor_sign, "anchor_local": anchor_local, "anchor_canvas": node.position + anchor_local.rotated(node.rotation),
		"start_size": node.box_size, "start_scale": node.text_scale() if node.is_text() else 1.0,
		"decor": movers, "cards": no_cards,
		"decor_before": {node.decor_id: node.get_state()}, "card_before": {},
	}

func _anchor_sign(node: DecorNode, handle: int) -> Vector2:
	var side_anchor_y: float = -1.0 if node.is_text() else 0.0
	match handle:
		DecorNode.HANDLE_TOP_LEFT:
			return Vector2(1.0, 1.0)
		DecorNode.HANDLE_TOP_RIGHT:
			return Vector2(-1.0, 1.0)
		DecorNode.HANDLE_BOTTOM_RIGHT:
			return Vector2(-1.0, -1.0)
		DecorNode.HANDLE_BOTTOM_LEFT:
			return Vector2(1.0, -1.0)
		DecorNode.HANDLE_LEFT:
			return Vector2(1.0, side_anchor_y)
		DecorNode.HANDLE_RIGHT:
			return Vector2(-1.0, side_anchor_y)
		DecorNode.HANDLE_TOP:
			return Vector2(0.0, 1.0)
	return Vector2(0.0, -1.0)

func resize_to(gesture: Dictionary, node: DecorNode, canvas_pos: Vector2) -> void:
	var handle: int = int(gesture["handle"])
	var anchor_sign: Vector2 = gesture["anchor_sign"]
	var anchor_canvas: Vector2 = gesture["anchor_canvas"]
	var start_size: Vector2 = gesture["start_size"]
	var local_mouse: Vector2 = (canvas_pos - anchor_canvas).rotated(-node.rotation)
	var is_corner: bool = handle < DecorNode.HANDLE_ROTATE
	if is_corner and not PlatformKeys.primary_down():
		var anchor_local: Vector2 = gesture["anchor_local"]
		var diagonal: Vector2 = -anchor_local * 2.0
		var factor: float = local_mouse.dot(diagonal) / diagonal.dot(diagonal)
		var low: float = maxf(DecorItem.MIN_SIZE / start_size.x, DecorItem.MIN_SIZE / start_size.y)
		var high: float = minf(DecorItem.MAX_SIZE / start_size.x, DecorItem.MAX_SIZE / start_size.y)
		node.box_size = start_size * clampf(factor, low, maxf(low, high))
	else:
		var new_size: Vector2 = start_size
		var direction: Vector2 = Vector2.ONE
		var flips: bool = not node.is_text()
		if anchor_sign.x != 0.0:
			var raw_x: float = local_mouse.x * -anchor_sign.x
			direction.x = -1.0 if flips and raw_x < 0.0 else 1.0
			new_size.x = clampf(absf(raw_x) if flips else raw_x, DecorItem.MIN_SIZE, DecorItem.MAX_SIZE)
		if anchor_sign.y != 0.0 and flips:
			var raw_y: float = local_mouse.y * -anchor_sign.y
			direction.y = -1.0 if raw_y < 0.0 else 1.0
			new_size.y = clampf(absf(raw_y), DecorItem.MIN_SIZE, DecorItem.MAX_SIZE)
		if node.is_text():
			node.fit_text_to_width(new_size.x, float(gesture["start_scale"]))
		else:
			node.box_size = new_size
			var before: Dictionary = (gesture["decor_before"] as Dictionary)[node.decor_id]
			node.flip_h = bool(before.get("flip_h", false)) != (direction.x < 0.0)
			node.flip_v = bool(before.get("flip_v", false)) != (direction.y < 0.0)
		var half_extent: Vector2 = node.box_size / 2.0
		var centre_offset: Vector2 = Vector2(-anchor_sign.x * direction.x * half_extent.x, -anchor_sign.y * direction.y * half_extent.y)
		node.position = anchor_canvas + centre_offset.rotated(node.rotation)
		return
	var half: Vector2 = node.box_size / 2.0
	node.position = anchor_canvas - Vector2(anchor_sign.x * half.x, anchor_sign.y * half.y).rotated(node.rotation)

func _begin_rotate(node: DecorNode) -> void:
	var movers: Array[DecorNode] = [node]
	var no_cards: Array[GraphCard] = []
	_ws._decor_gesture = {
		"kind": KIND_ROTATE, "node": node, "moved": false,
		"decor": movers, "cards": no_cards,
		"decor_before": {node.decor_id: node.get_state()}, "card_before": {},
	}

func update_gesture(canvas_pos: Vector2, screen_pos: Vector2, velocity_x: float) -> void:
	var gesture: Dictionary = _ws._decor_gesture
	if gesture.is_empty():
		return
	var node: DecorNode = gesture["node"] as DecorNode
	if not is_instance_valid(node):
		_ws._decor_gesture = {}
		return

	match str(gesture["kind"]):
		KIND_MOVE:
			if not bool(gesture["moved"]):
				if screen_pos.distance_to(gesture["start_screen"] as Vector2) < AppWorkspace.MARQUEE_DRAG_THRESHOLD:
					return
				gesture["moved"] = true
			var delta: Vector2 = canvas_pos - (gesture["start_canvas"] as Vector2)
			var decor_before: Dictionary = gesture["decor_before"]
			for mover: DecorNode in (gesture["decor"] as Array[DecorNode]):
				if is_instance_valid(mover):
					mover.position = (decor_before[mover.decor_id]["pos"] as Vector2) + delta
			var card_before: Dictionary = gesture["card_before"]
			for card: GraphCard in (gesture["cards"] as Array[GraphCard]):
				if is_instance_valid(card):
					card.apply_carrier_shift((card_before[card.card_id] as Vector2) + delta - card.position, velocity_x)
		KIND_RESIZE:
			gesture["moved"] = true
			resize_to(gesture, node, canvas_pos)
		KIND_ROTATE:
			gesture["moved"] = true
			var degrees: float = rad_to_deg((canvas_pos - node.position).angle() + PI / 2.0)
			if Input.is_key_pressed(KEY_SHIFT):
				degrees = snappedf(degrees, DecorItem.ROTATION_SNAP_DEG)
			node.rotation = deg_to_rad(degrees)

func finish_gesture() -> void:
	var gesture: Dictionary = _ws._decor_gesture
	_ws._decor_gesture = {}
	if gesture.is_empty():
		return
	for card: GraphCard in (gesture["cards"] as Array[GraphCard]):
		if is_instance_valid(card):
			card.set_group_following(false)
			_ws._save_card(card)
	save()

	var label: String = tr("decor.history.move")
	match str(gesture["kind"]):
		KIND_RESIZE:
			label = tr("decor.history.resize")
		KIND_ROTATE:
			label = tr("decor.history.rotate")
	_ws._undo.record_move(gesture["card_before"] as Dictionary, label, gesture["decor_before"] as Dictionary)

	var node: DecorNode = gesture["node"] as DecorNode
	if str(gesture["kind"]) == KIND_MOVE and not bool(gesture["moved"]) and is_instance_valid(node) and _ws._selection.item_count() > 1:
		_ws._selection.select_only(node)


func request_add() -> void:
	if _ws._snapshot_busy or _ws._file_dialog_open or _ws._is_modal_open() or _ws._zen_active or _ws._lightbox.is_open() or _ws._eyedropper.is_active():
		return
	if is_full():
		_ws._toast.show_message(tr("decor.limit") % DecorItem.MAX_PER_CANVAS, true)
		return
	_ws._file_dialog_open = true
	SystemFileDialog.open(
		tr("decor.dialog"),
		"",
		"",
		false,
		DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
		["*.png, *.jpg, *.jpeg, *.webp"],
		_on_add_dialog_result
	)

func is_full() -> bool:
	return object_count() >= DecorItem.MAX_PER_CANVAS

func _on_add_dialog_result(status: bool, selected_paths: PackedStringArray, _filter_index: int) -> void:
	_ws._file_dialog_open = false
	if status and not selected_paths.is_empty():
		add_from_file(selected_paths[0])

func add_from_file(source_path: String) -> DecorNode:
	if is_full():
		_ws._toast.show_message(tr("decor.limit") % DecorItem.MAX_PER_CANVAS, true)
		return null
	var vault_path: String = _ws._storage.copy_image_to_vault(source_path, DecorItem.MAX_SIDE, DecorItem.MAX_FILE_BYTES)
	if vault_path == "":
		_ws._toast.show_message(_refusal_message(source_path), true)
		return null
	var texture: Texture2D = InlineImages.texture_for(vault_path)
	if texture == null:
		_ws._toast.show_message(tr("image.insert.failed"), true)
		return null

	var natural: Vector2 = texture.get_size()
	var fit: float = minf(1.0, DecorItem.INITIAL_LONG_SIDE / maxf(maxf(natural.x, natural.y), 1.0))
	var item: DecorItem = DecorItem.new()
	item.id = UuidUtil.generate_v4()
	item.image = vault_path
	item.size = (natural * fit).max(Vector2(DecorItem.MIN_SIZE, DecorItem.MIN_SIZE))
	item.pos = _ws.navigator.screen_to_canvas(_ws.get_viewport_rect().size / 2.0)
	item.layer = DecorItem.LAYER_BELOW
	return _register_added(item)

func _register_added(item: DecorItem) -> DecorNode:
	var node: DecorNode = create_node(item)
	if node == null:
		return null
	node.play_spawn_animation()
	save()

	var no_notes: Array[String] = []
	var decor_ids: Array[String] = [item.id]
	var holder: Dictionary = {"ids": no_notes, "state": _ws._undo.capture(no_notes), "decor_ids": decor_ids, "decor_state": _ws._undo.capture_decor(decor_ids)}
	_ws._history.record(tr("decor.history.add"), _ws._undo.remove_with_holder.bind(holder), _ws._undo.restore_with_holder.bind(holder))
	return node

func request_add_text() -> void:
	if _ws._snapshot_busy or _ws._file_dialog_open or _ws._is_modal_open() or _ws._zen_active or _ws._lightbox.is_open() or _ws._eyedropper.is_active():
		return
	if is_full():
		_ws._toast.show_message(tr("decor.limit") % DecorItem.MAX_PER_CANVAS, true)
		return
	var item: DecorItem = DecorItem.new()
	item.id = UuidUtil.generate_v4()
	item.kind = DecorItem.KIND_TEXT
	item.size = Vector2(item.text_width, DecorNode.layout_height("", item.font_size, item.text_width))
	item.pos = _ws.navigator.screen_to_canvas(_ws.get_viewport_rect().size / 2.0)
	item.layer = DecorItem.LAYER_ABOVE
	var node: DecorNode = _register_added(item)
	if node != null:
		_ws._selection.select_only(node)

func open_text_editor(node: DecorNode) -> void:
	if not is_instance_valid(node) or not node.is_text():
		return
	_ws._decor_text_target_id = node.decor_id
	_ws._decor_text_dialog.open_for(node.text, node.text_color, node.font_size)

func text_state(node: DecorNode) -> Dictionary:
	return {"text": node.text, "color": node.text_color, "font_size": node.font_size, "size": node.box_size}

func apply_text_state(decor_id: String, state: Dictionary) -> void:
	var node: DecorNode = _ws._decor_by_id.get(decor_id, null)
	if not is_instance_valid(node):
		return
	node.set_text_content(str(state["text"]), str(state["color"]), int(state["font_size"]))
	node.box_size = state["size"] as Vector2
	save()

func on_text_applied(content: String, color_hex: String, font_size: int) -> void:
	var node: DecorNode = _ws._decor_by_id.get(_ws._decor_text_target_id, null)
	if not is_instance_valid(node):
		return
	var before: Dictionary = text_state(node)
	node.set_text_content(DecorItem.clip_text(content), NoteBackground.sanitize_hex(color_hex), clampi(font_size, DecorItem.TEXT_MIN_FONT_SIZE, DecorItem.TEXT_MAX_FONT_SIZE))
	var after: Dictionary = text_state(node)
	if before == after:
		return
	save()
	_ws._history.record(tr("decor.history.text"), apply_text_state.bind(node.decor_id, before), apply_text_state.bind(node.decor_id, after))

func _refusal_message(source_path: String) -> String:
	match _ws._storage.last_refusal_reason:
		ImageGuard.REASON_TOO_LARGE:
			return tr("decor.refused.too_large") % source_path.get_file()
		ImageGuard.REASON_FILE_TOO_LARGE:
			return tr("decor.refused.file_too_large") % source_path.get_file()
	return _ws._storage.last_refusal if _ws._storage.last_refusal != "" else tr("image.insert.failed")
