class_name TextContextMenu
extends Node

enum Action { UNDO, REDO, CUT, COPY, PASTE, SELECT_ALL }

const ATTACHED_META: String = "text_context_menu_attached"
const MENU_OPTIONS: Dictionary = {
	Action.UNDO: TextEdit.MENU_UNDO,
	Action.REDO: TextEdit.MENU_REDO,
	Action.CUT: TextEdit.MENU_CUT,
	Action.COPY: TextEdit.MENU_COPY,
	Action.PASTE: TextEdit.MENU_PASTE,
	Action.SELECT_ALL: TextEdit.MENU_SELECT_ALL,
}
const MIN_WIDTH: float = 200.0

var _popup: PopupList = null
var _target: Control = null

func _ready() -> void:
	_popup = PopupList.new()
	add_child(_popup)
	_popup.item_chosen.connect(_on_item_chosen)

	get_tree().node_added.connect(_on_node_added)
	_attach_below(get_tree().root)

func _attach_below(node: Node) -> void:
	_on_node_added(node)
	for child: Node in node.get_children():
		_attach_below(child)

func _on_node_added(node: Node) -> void:
	if (node is LineEdit or node is TextEdit) and node.get_viewport() == get_viewport():
		attach(node as Control)

func attach(field: Control) -> void:
	if field.has_meta(ATTACHED_META):
		return
	field.set_meta(ATTACHED_META, true)
	field.set("context_menu_enabled", false)
	field.gui_input.connect(_on_field_gui_input.bind(field))

func _on_field_gui_input(event: InputEvent, field: Control) -> void:
	if not (event is InputEventMouseButton):
		return
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_RIGHT or not click.pressed:
		return
	_target = field
	field.grab_focus()
	_open_at.call_deferred(click.global_position)

func _open_at(position: Vector2) -> void:
	if not is_instance_valid(_target) or not _target.is_visible_in_tree():
		return

	var editable: bool = bool(_target.get("editable"))
	var has_selection: bool = bool(_target.call("has_selection"))
	_popup.clear()
	_popup.add_item(tr("menu.text.undo"), Action.UNDO, "Ctrl+Z")
	_popup.add_item(tr("menu.text.redo"), Action.REDO, "Ctrl+Y")
	_popup.add_separator()
	_popup.add_item(tr("menu.text.cut"), Action.CUT, "Ctrl+X")
	_popup.add_item(tr("menu.text.copy"), Action.COPY, "Ctrl+C")
	_popup.add_item(tr("menu.text.paste"), Action.PASTE, "Ctrl+V")
	_popup.add_separator()
	_popup.add_item(tr("menu.text.select_all"), Action.SELECT_ALL, "Ctrl+A")

	_popup.set_item_disabled(Action.UNDO, not editable or not bool(_target.call("has_undo")))
	_popup.set_item_disabled(Action.REDO, not editable or not bool(_target.call("has_redo")))
	_popup.set_item_disabled(Action.CUT, not editable or not has_selection)
	_popup.set_item_disabled(Action.COPY, not has_selection)
	_popup.set_item_disabled(Action.PASTE, not editable or not DisplayServer.clipboard_has())
	_popup.open_at(position, MIN_WIDTH)

func _on_item_chosen(id: int) -> void:
	if not is_instance_valid(_target):
		return
	_target.grab_focus()
	_target.call("menu_option", int(MENU_OPTIONS[id]))
