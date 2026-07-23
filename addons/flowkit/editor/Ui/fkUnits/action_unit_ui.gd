@tool
extends FKUnitUi
class_name FKActionUnitUi

@export_category("Controls")
@export var panel: PanelContainer
@export var label: Label
@export var icon_label: Label
@export var context_menu: PopupMenu
@export var drop_indicator: ColorRect

@export_category("Styles")
@export var normal_stylebox: StyleBox
@export var selected_stylebox: StyleBox

var is_drop_target := false
var drop_above := true

# ---------------------------------------------------------
# Block Handling
# ---------------------------------------------------------

func _validate_unit(to_set: FKUnit) -> bool:
	return to_set == null or to_set is FKActionUnit

func get_action() -> FKActionUnit:
	return _unit as FKActionUnit

func get_unit() -> FKActionUnit:
	if _unit is FKActionUnit:
		return _unit as FKActionUnit
	else:
		return null

# ---------------------------------------------------------
# Registry Handling
# ---------------------------------------------------------

func _on_registry_set() -> void:
	_update_label()

# ---------------------------------------------------------
# Display / Styling
# ---------------------------------------------------------

func update_display() -> void:
	_update_label()
	_update_styling()

func _update_styling() -> void:
	if not panel:
		return

	var style := selected_stylebox if is_selected else normal_stylebox
	panel.add_theme_stylebox_override("panel", style)

func _update_label() -> void:
	if not _action:
		return

	var display_name := _get_display_name_from_registry()
	var node_name := String(_action.target_node).get_file()
	var params_text := _get_params_text()

	label.text = "%s on %s%s" % [display_name, node_name, params_text]
	name = "%s on %s" % [display_name, node_name]

var _action: FKActionUnit:
	get:
		if _unit is FKActionUnit:
			return _unit as FKActionUnit
		else:
			return null

## If none is found, this returns the action id
func _get_display_name_from_registry() -> String:
	var id := _action.get_id()
	var display_name := id
	
	if registry:
		for provider in registry.action_providers:
			if provider.has_method("get_id") and provider.get_id() == id:
				if provider.has_method("get_name"):
					display_name = provider.get_name()
				break
				
	return display_name
	
func _get_params_text() -> String:
	var params_text := ""
	
	if not _action.inputs.is_empty():
		var param_pairs := []
		for key in _action.inputs:
			var input = _action.inputs[key]
			var pair = str(input)
			param_pairs.append(pair)
		params_text = ": " + ", ".join(param_pairs)
		
	return params_text
# ---------------------------------------------------------
# Context Menu
# ---------------------------------------------------------

func show_context_menu(global_pos: Vector2) -> void:
	print("Showing Action context menu")
	context_menu.position = global_pos
	context_menu.popup()

func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		_edit_requested_choice: edit_requested.emit(self)
		_delete_requested_choice: delete_requested.emit(self)

const _edit_requested_choice := 0
const _delete_requested_choice := 1

# ---------------------------------------------------------
# Input Handling
# ---------------------------------------------------------

func _toggle_subs(on: bool) -> void:
	if on && !_is_subbed:
		gui_input.connect(_on_gui_input)
		mouse_exited.connect(_on_mouse_exited)
		context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	elif !on && _is_subbed:
		gui_input.disconnect(_on_gui_input)
		mouse_exited.disconnect(_on_mouse_exited)
		context_menu.id_pressed.disconnect(_on_context_menu_id_pressed)
		
	super._toggle_subs(on)

func _on_gui_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton or not event.pressed:
		return
	
	var left_click: bool = event.button_index == MOUSE_BUTTON_LEFT
	var right_click: bool = event.button_index == MOUSE_BUTTON_RIGHT
	if left_click:
		_on_left_click(event)
	elif right_click:
		_on_right_click()
		
	if left_click or right_click:
		_on_either_click()

func _on_left_click(event: InputEventMouseButton):
	if event.double_click:
		edit_requested.emit(self)
	
func _on_right_click():
	var mouse_pos := DisplayServer.mouse_get_position()
	show_context_menu(mouse_pos)
	
## Should be called after the specific left and right click callbacks
func _on_either_click():
	set_selected(true)
	get_viewport().set_input_as_handled()
	
func _on_mouse_exited() -> void:
	_hide_drop_indicator()

# ---------------------------------------------------------
# Drag & Drop
# ---------------------------------------------------------

func _get_drag_data(at_position: Vector2) -> FKDragData:
	if not _action:
		return null

	var preview := _create_drag_preview()
	set_drag_preview(preview)

	return FKDragData.new(DragTarget.Type.ACTION_ITEM, self, _action)

func _create_drag_preview() -> Control:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 4)

	var preview_label := Label.new()
	preview_label.text = label.text if label else "Action"
	preview_label.add_theme_color_override("font_color", _preview_label_color)

	margin.add_child(preview_label)
	return margin

static var _preview_label_color := Color(0.5, 0.7, 1.0, 0.9)

func _can_drop_data(at_position: Vector2, data) -> bool:
	var drag_data := data as FKDragData
	if not drag_data or drag_data.type != DragTarget.Type.ACTION_ITEM:
		_hide_drop_indicator()
		return false

	var source_node := drag_data.node
	if source_node == self:
		_hide_drop_indicator()
		return false

	# Prevent dropping a parent onto its own descendant
	if _is_descendant_of(source_node):
		_hide_drop_indicator()
		return false

	var above := at_position.y < size.y / 2.0
	if _is_adjacent_to_source(source_node, above):
		_hide_drop_indicator()
		return false

	_show_drop_indicator(above)
	return true

func _is_descendant_of(node: Node) -> bool:
	var current := get_parent()
	while current:
		if current == node:
			return true
		current = current.get_parent()
	return false

func _is_adjacent_to_source(source_node: Node, drop_above: bool) -> bool:
	var parent := get_parent()
	if not parent:
		return false

	var my_index := get_index()
	var source_index := parent.get_children().find(source_node)

	if source_index < 0:
		return false

	if drop_above and source_index == my_index - 1:
		return true
	if not drop_above and source_index == my_index + 1:
		return true

	return false

func _drop_data(at_position: Vector2, data) -> void:
	_hide_drop_indicator()

	var drag_data := data as FKDragData
	if not drag_data or drag_data.type != DragTarget.Type.ACTION_ITEM:
		return

	var source_node := drag_data.node
	if not source_node or source_node == self:
		return

	var above := at_position.y < size.y / 2.0
	reorder_requested.emit(source_node, self, above)

func _show_drop_indicator(above: bool) -> void:
	if not drop_indicator:
		return

	drop_above = above
	is_drop_target = true
	drop_indicator.visible = true
	drop_indicator.size = Vector2(size.x, 2)
	drop_indicator.position = Vector2(0, 0 if above else size.y - 2)

func _hide_drop_indicator() -> void:
	if drop_indicator:
		drop_indicator.visible = false
	is_drop_target = false

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_hide_drop_indicator()

func _to_string() -> String:
	var result := "FKActionUnitUi"
	
	if _unit != null:
		result += "\nhas block: true"
	return result

func get_class() -> String:
	var result := "FKActionUnitUi"
	return result
