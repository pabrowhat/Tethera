class_name WorkspaceLayout
extends RefCounted

enum Template { TREE_DOWN, TREE_RIGHT, ORBIT, ORBIT_BY_TYPE }

const GLIDE_DURATION: float = 0.35

const MENU_WIDTH: float = 220.0

var _ws: AppWorkspace = null
var _button: Button = null
var _popup: PopupList = null

func _init(workspace: AppWorkspace) -> void:
	_ws = workspace

func build_menu() -> void:
	_button = Button.new()
	_button.text = "layout.button"
	_button.focus_mode = Control.FOCUS_NONE
	_button.custom_minimum_size = Vector2(110.0, 36.0)
	_button.add_theme_font_size_override("font_size", 13)
	ThemeColors.bind_override(_button, &"font_color", &"text.primary")
	var bar: HBoxContainer = _ws.get_node("UI/TopBar")
	bar.add_child(_button)
	bar.move_child(_button, _ws._filter_panel.get_index())

	_popup = PopupList.new()
	_button.add_child(_popup)
	_popup.item_chosen.connect(_on_template_chosen)
	_button.pressed.connect(_open_menu)

func _open_menu() -> void:
	_popup.clear()
	_popup.add_item(tr("layout.tree_down"), Template.TREE_DOWN)
	_popup.add_item(tr("layout.tree_right"), Template.TREE_RIGHT)
	_popup.add_item(tr("layout.orbit"), Template.ORBIT)
	_popup.add_item(tr("layout.orbit_by_type"), Template.ORBIT_BY_TYPE)
	_popup.open_below(_button.get_global_rect(), MENU_WIDTH)

func _on_template_chosen(template: int) -> void:
	var selected: int = _ws._selection.count()
	if selected == 0:
		_ws._toast.show_message(tr("layout.no_selection"), true, 2.4)
	elif selected == 1:
		_ws._toast.show_message(tr("layout.single"), true, 2.4)
	else:
		apply(template)

func apply(template: int) -> int:
	if _ws._is_interaction_in_flight() or _ws._zen_active or _ws._lightbox.is_open() or _ws._eyedropper.is_active() or _ws._is_modal_open():
		return 0
	var cards: Array[GraphCard] = _ws._selection.get_cards()
	if cards.size() < 2:
		return 0
	_ws._cancel_link_source()

	var ids: Array[String] = []
	var sizes: Dictionary = {}
	var types: Dictionary = {}
	for card: GraphCard in cards:
		ids.append(card.card_id)
		sizes[card.card_id] = card.size
		types[card.card_id] = card.entity_type_id
	var anchor: Vector2 = cards[0].position + cards[0].size / 2.0

	var targets: Dictionary = _compute(template, ids, sizes, types, anchor)
	var from_positions: Dictionary = {}
	var to_positions: Dictionary = {}
	for card: GraphCard in cards:
		var target: Vector2 = targets[card.card_id]
		if card.position.distance_to(target) > WorkspaceHistory.MOVE_EPSILON:
			from_positions[card.card_id] = card.position
			to_positions[card.card_id] = target
	if not to_positions.is_empty():
		_move(to_positions)
		_ws._history.record(tr("layout.history"), _ws._undo.apply_positions.bind(from_positions), _ws._undo.apply_positions.bind(to_positions))

	var others: Array[Rect2] = []
	for card: GraphCard in _ws._cards_by_id.values():
		if is_instance_valid(card) and card.visible and not cards.has(card):
			others.append(Rect2(card.position, card.size))
	var overlaps: int = LayoutTemplates.count_overlaps(targets, sizes, others)
	if overlaps > 0:
		_ws._toast.show_message(tr("layout.done_overlaps") % [cards.size(), overlaps], true, 3.0)
	else:
		_ws._toast.show_message(tr("layout.done") % cards.size(), false, 2.0)
	return cards.size()

func _compute(template: int, ids: Array[String], sizes: Dictionary, types: Dictionary, anchor: Vector2) -> Dictionary:
	match template:
		Template.TREE_DOWN:
			return LayoutTemplates.tree(ids, _ws._graph.get_all_connections(), sizes, anchor, false)
		Template.TREE_RIGHT:
			return LayoutTemplates.tree(ids, _ws._graph.get_all_connections(), sizes, anchor, true)
		Template.ORBIT_BY_TYPE:
			var order: Array[String] = []
			for entity_type: EntityType in _ws._types.get_all():
				order.append(entity_type.id)
			return LayoutTemplates.orbit_by_type(ids, sizes, types, order, anchor)
		_:
			return LayoutTemplates.orbit(ids, sizes, anchor)

func _move(positions: Dictionary) -> void:
	var jump: bool = Preferences.reduce_motion()
	for id: String in positions:
		var card: GraphCard = _ws._cards_by_id.get(id, null)
		if not is_instance_valid(card):
			continue
		var target: Vector2 = positions[id]
		if jump:
			card.position = target
			_ws._save_card(card)
		else:
			var tween: Tween = card.glide_to(target, GLIDE_DURATION)
			tween.finished.connect(_ws._undo.on_glide_finished.bind(id))
	_ws.connection_renderer.queue_redraw()
