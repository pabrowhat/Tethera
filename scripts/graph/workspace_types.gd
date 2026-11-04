class_name WorkspaceTypes
extends RefCounted

var _ws: AppWorkspace = null

func _init(workspace: AppWorkspace) -> void:
	_ws = workspace

func apply_background(card: GraphCard) -> void:
	if not is_instance_valid(card):
		return
	var effective: Dictionary = NoteBackground.resolve(card.bg_color_hex, card.bg_color2_hex, card.bg_image_path, _ws._types.find(card.entity_type_id))
	var image: String = str(effective["image"])
	var texture: Texture2D = null
	if image != "":
		texture = InlineImages.texture_for(image)
		if texture == null:
			InlineImages.report_missing(image)
	card.set_body_background(effective["color"], effective["color2"], texture)

func set_type_background_color(type_id: String, color: Color) -> void:
	var entity_type: EntityType = _ws._types.find(type_id)
	if entity_type != null:
		_ws._types.set_background(type_id, color.to_html(false), entity_type.bg_color2, entity_type.bg_image)

func set_type_background_color2(type_id: String, color: Color) -> void:
	var entity_type: EntityType = _ws._types.find(type_id)
	if entity_type != null:
		_ws._types.set_background(type_id, entity_type.bg_color, color.to_html(false), entity_type.bg_image)

func clear_type_gradient(type_id: String) -> void:
	var entity_type: EntityType = _ws._types.find(type_id)
	if entity_type != null:
		_ws._types.set_background(type_id, entity_type.bg_color, "", entity_type.bg_image)

func set_type_background_image(type_id: String, source_path: String) -> void:
	var entity_type: EntityType = _ws._types.find(type_id)
	if entity_type == null:
		return
	var vault_path: String = _ws._storage.copy_image_to_vault(source_path)
	if vault_path == "":
		var reason: String = _ws._storage.last_refusal
		_ws._toast.show_message(reason if reason != "" else tr("image.insert.failed"), true)
		return
	_ws._types.set_background(type_id, entity_type.bg_color, entity_type.bg_color2, vault_path)

func clear_type_background(type_id: String) -> void:
	_ws._types.set_background(type_id, "", "", "")

func refresh_all_backgrounds() -> void:
	for card: GraphCard in _ws._cards_by_id.values():
		apply_background(card)

func open_manager() -> void:
	_ws._cancel_link_source()
	_ws._selection.clear()
	_ws.sidebar_editor.show_type_manager()

func count_notes_of_type(type_id: String) -> int:
	var total: int = 0
	for card: GraphCard in _ws._cards_by_id.values():
		if is_instance_valid(card) and card.entity_type_id == type_id:
			total += 1
	return total

func create_type(type_name: String) -> void:
	if _ws._types.has_name(type_name):
		_ws._toast.show_message(tr("type.create.duplicate") % type_name.strip_edges(), true)
		return
	var created: EntityType = _ws._types.create(type_name, _ws._types.suggest_color())
	if created == null:
		return
	_ws.sidebar_editor.type_manager.expand(created.id)

func rename_type(type_id: String, type_name: String) -> void:
	if _ws._types.has_name(type_name, type_id):
		_ws._toast.show_message(tr("type.rename.duplicate") % type_name.strip_edges(), true)
		_ws.sidebar_editor.type_manager.refresh()
		return
	_ws._types.rename(type_id, type_name)

func recolor_type(type_id: String, color: Color) -> void:
	if not _ws._types.set_color(type_id, color):
		return
	var followers: Array[GraphCard] = []
	for card: GraphCard in _ws._cards_by_id.values():
		if is_instance_valid(card) and card.entity_type_id == type_id and not card.color_overridden:
			followers.append(card)
	for card: GraphCard in followers:
		_paint_card(card, color)
		_ws._save_card(card)
	if not followers.is_empty():
		_ws._refresh_flipped_back_faces()
		_sync_sidebar_with(followers)

func assign_type(card_id: String, type_id: String) -> void:
	var card: GraphCard = _ws._cards_by_id.get(card_id, null)
	if not is_instance_valid(card) or card.entity_type_id == type_id:
		return
	var entity_type: EntityType = _ws._types.find(type_id)
	if type_id != "" and entity_type == null:
		return

	card.entity_type_id = type_id
	if entity_type != null and not card.color_overridden:
		_paint_card(card, entity_type.color)
	apply_background(card)
	_ws._touch_card(card)
	var changed_cards: Array[GraphCard] = [card]
	_sync_sidebar_with(changed_cards)

func follow_type_color(card_id: String) -> void:
	var card: GraphCard = _ws._cards_by_id.get(card_id, null)
	if not is_instance_valid(card) or not card.color_overridden:
		return
	var entity_type: EntityType = _ws._types.find(card.entity_type_id)
	if entity_type == null:
		return

	var previous: Color = card.card_color
	card.color_overridden = false
	_paint_card(card, entity_type.color)
	_ws._touch_card(card)
	if not previous.is_equal_approx(entity_type.color):
		_ws._undo.record_color_change({card_id: previous}, {card_id: entity_type.color}, {card_id: true}, {card_id: false})
	var changed_cards: Array[GraphCard] = [card]
	_sync_sidebar_with(changed_cards)

func _paint_card(card: GraphCard, color: Color) -> void:
	card.set_category_color(color)
	card.play_capture_punch()
	_ws._saved_colors[card.card_id] = color

func _sync_sidebar_with(cards: Array[GraphCard]) -> void:
	var sidebar: SidebarEditor = _ws.sidebar_editor
	if not sidebar.is_open or not is_instance_valid(sidebar.current_card) or not cards.has(sidebar.current_card):
		return
	sidebar.apply_external_color(sidebar.current_card.card_color)
	sidebar.refresh_type_section()

func request_delete_type(type_id: String) -> void:
	var entity_type: EntityType = _ws._types.find(type_id)
	if entity_type == null:
		return
	_ws._pending_confirm = delete_type.bind(type_id)
	_ws.confirm_modal.prompt(
		tr("type.delete.title"),
		tr("type.delete.confirm") % [entity_type.name, count_notes_of_type(type_id)],
		tr("type.delete.button")
	)

func delete_type(type_id: String) -> void:
	if _ws._types.find(type_id) == null:
		return
	for card: GraphCard in _ws._cards_by_id.values():
		if is_instance_valid(card) and card.entity_type_id == type_id:
			card.entity_type_id = ""
			apply_background(card)
			_ws._save_card(card)
	_ws._types.remove(type_id)
	_ws.sidebar_editor.refresh_type_section()

func add_field(type_id: String, field_label: String, kind: int) -> void:
	var field: FieldDef = _ws._types.add_field(type_id, field_label, kind as FieldDef.Kind)
	if field == null:
		_ws._toast.show_message(tr("type.field.duplicate") % field_label.strip_edges(), true)

func remove_field(type_id: String, field_key: String) -> void:
	_ws._types.remove_field(type_id, field_key)
