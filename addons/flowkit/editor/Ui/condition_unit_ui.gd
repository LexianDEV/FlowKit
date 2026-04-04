@tool
extends FKUnitUi
class_name FKConditionUnitUi

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

func _validate_block(to_set: FKUnit) -> bool:
	return to_set == null or to_set is FKConditionUnit

func _on_block_changed() -> void:
	update_display()

func get_block() -> FKConditionUnit:
	return _block as FKConditionUnit

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

	var style := selected_stylebox if is_selected \
	else normal_stylebox
	panel.add_theme_stylebox_override("panel", style)

func _update_label() -> void:
	if not _block:
		return
	
	_update_label_text()
	_update_icon_color()

func _update_label_text():
	var display_name := _get_display_name_from_registry()
	var params_text := _get_params_text()
	var neg_prefix := "NOT " if _cond_block.negated else ""

	label.text = "%s%s%s" % [neg_prefix, display_name, params_text]
			
## If none is found from the registry, this returns the condition's id
func _get_display_name_from_registry() -> String:
	var display_name := _cond_block.condition_id
	if registry:
		for provider in registry.condition_providers:
			if provider.has_method("get_id") and provider.get_id() == _cond_block.condition_id:
				if provider.has_method("get_name"):
					display_name = provider.get_name()
				break
	return display_name

var _cond_block: FKConditionUnit:
	get:
		if _block is FKConditionUnit:
			return _block as FKConditionUnit
		else:
			return null
			
func _get_params_text() -> String:
	var params_text := ""
	if not _cond_block.inputs.is_empty():
		var param_pairs := []
		for key in _cond_block.inputs:
			var current_input = _cond_block.inputs[key]
			var pair = str(current_input)
			param_pairs.append(pair)
			
		params_text = ": " + ", ".join(param_pairs)
		
	return params_text

func _update_icon_color():
	var color = _negated_color if _cond_block.negated \
	else _pos_color
	icon_label.add_theme_color_override("font_color", color)

var _negated_color := Color(1.0, 0.4, 0.4, 1)
var _pos_color := Color(1.0, 0.7, 0.3, 1)

# ---------------------------------------------------------
# Context Menu
# ---------------------------------------------------------

func show_context_menu(global_pos: Vector2) -> void:
	if not context_menu:
		return
	
	var c := get_block()
	if c:
		context_menu.set_item_checked(2, c.negated)

	context_menu.position = global_pos
	context_menu.popup()

func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		0: edit_requested.emit(self)
		1: delete_requested.emit(self)
		2: negate_requested.emit(self)

signal edit_requested(node)
signal delete_requested(node)
signal negate_requested(node)

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
	if event.button_index == MOUSE_BUTTON_LEFT:
		_on_left_click(event)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_on_right_click()
	
	if left_click or right_click:
		get_viewport().set_input_as_handled()

func _on_left_click(event: InputEventMouseButton):
	if event.double_click:
		edit_requested.emit(self)
	else:
		set_selected(true)
	
func _on_right_click():
	set_selected(true)
	var mouse_pos := DisplayServer.mouse_get_position()
	show_context_menu(mouse_pos)
			
func _on_mouse_exited() -> void:
	_hide_drop_indicator()

# ---------------------------------------------------------
# Drag & Drop
# ---------------------------------------------------------

func _get_drag_data(at_position: Vector2) -> FKDragData:
	if not _block:
		return null

	var preview := _create_drag_preview()
	set_drag_preview(preview)

	return FKDragData.new(DragTarget.Type.CONDITION_ITEM, self, _block)

func _create_drag_preview() -> Control:
	var preview_label := Label.new()
	preview_label.text = label.text if label else "Condition"
	preview_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4, 0.9))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.add_child(preview_label)

	return margin

func _can_drop_data(at_position: Vector2, data) -> bool:
	var drag_data := data as FKDragData
	if not drag_data or drag_data.type != DragTarget.Type.CONDITION_ITEM:
		_hide_drop_indicator()
		return false

	var source_node := drag_data.node
	if source_node == self:
		_hide_drop_indicator()
		return false

	var above := at_position.y < size.y / 2.0
	if _is_adjacent_to_source(source_node, above):
		_hide_drop_indicator()
		return false

	_show_drop_indicator(above)
	return true

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
	if not drag_data or drag_data.type != DragTarget.Type.CONDITION_ITEM:
		return

	var source_node := drag_data.node
	if not source_node or source_node == self:
		return
	
	var above := at_position.y < size.y / 2.0
	reorder_requested.emit(source_node, self, above)

signal reorder_requested(source_item, target_item, drop_above: bool)

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
	var result := "FKConditionUnitUi"
	
	if _block != null:
		result += "\nhas block: true"
	return result

func get_class() -> String:
	return "FKConditionUnitUi"
