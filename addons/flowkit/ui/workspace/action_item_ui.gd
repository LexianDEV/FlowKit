@tool
extends MarginContainer
class_name ActionItemUi

signal selected(item)
signal edit_requested(item)
signal delete_requested(item)
signal reorder_requested(source_item, target_item, drop_above: bool)

var action_data: FKEventAction
var registry: Node
var is_selected: bool = false

var label: Label
var icon_label: Label
var panel: PanelContainer
var context_menu: PopupMenu
var normal_stylebox: StyleBox
var selected_stylebox: StyleBox

# Drop indicator
var drop_indicator: ColorRect
var is_drop_target: bool = false
var drop_above: bool = true

func _ready() -> void:
	_setup_references()
	_setup_styles()
	_setup_drop_indicator()
	gui_input.connect(_on_gui_input)
	call_deferred("_setup_context_menu")

func _setup_references() -> void:
	panel = get_node_or_null("Panel")
	label = get_node_or_null("Panel/Margin/HBox/Label")
	icon_label = get_node_or_null("Panel/Margin/HBox/Icon")
	context_menu = get_node_or_null("ContextMenu")

func _setup_styles() -> void:
	if panel:
		normal_stylebox = panel.get_theme_stylebox("panel")
		if normal_stylebox:
			selected_stylebox = normal_stylebox.duplicate()
			if selected_stylebox is StyleBoxFlat:
				selected_stylebox.border_color = Color(0.5, 0.7, 1.0, 1.0)
				selected_stylebox.border_width_left = 2
				selected_stylebox.border_width_top = 1
				selected_stylebox.border_width_right = 1
				selected_stylebox.border_width_bottom = 1

func _setup_context_menu() -> void:
	if context_menu:
		context_menu.id_pressed.connect(_on_context_menu_id_pressed)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click:
				edit_requested.emit(self)
			else:
				selected.emit(self)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			selected.emit(self)
			if context_menu:
				context_menu.position = DisplayServer.mouse_get_position()
				context_menu.popup()
			get_viewport().set_input_as_handled()

func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		0: # Edit
			edit_requested.emit(self)
		1: # Delete
			delete_requested.emit(self)

func set_action_data(data: FKEventAction) -> void:
	action_data = data
	call_deferred("_update_label")

func set_registry(reg: Node) -> void:
	registry = reg
	call_deferred("_update_label")

func get_action_data() -> FKEventAction:
	return action_data

func _update_label() -> void:
	if not label:
		label = get_node_or_null("Panel/Margin/HBox/Label")
	
	if label and action_data:
		var display_name = action_data.action_id
		
		if registry:
			for provider in registry.action_providers:
				if provider.has_method("get_id") and provider.get_id() == action_data.action_id:
					if provider.has_method("get_name"):
						display_name = provider.get_name()
					break
		
		var node_name = String(action_data.target_node).get_file()
		var params_text = ""
		if not action_data.inputs.is_empty():
			var param_pairs = []
			for key in action_data.inputs:
				param_pairs.append(str(action_data.inputs[key]))
			params_text = ": " + ", ".join(param_pairs)
		
		# Format: "Action on NodeName: params"
		label.text = "%s %s%s" % [display_name, node_name, params_text]

func update_display() -> void:
	_update_label()

func set_selected(value: bool) -> void:
	is_selected = value
	if panel and normal_stylebox and selected_stylebox:
		if is_selected:
			panel.add_theme_stylebox_override("panel", selected_stylebox)
		else:
			panel.add_theme_stylebox_override("panel", normal_stylebox)

func _setup_drop_indicator() -> void:
	drop_indicator = ColorRect.new()
	drop_indicator.color = Color(0.5, 0.7, 1.0, 0.8)
	drop_indicator.custom_minimum_size = Vector2(0, 2)
	drop_indicator.visible = false
	drop_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(drop_indicator)

func _show_drop_indicator(above: bool) -> void:
	if not drop_indicator:
		return
	drop_above = above
	is_drop_target = true
	drop_indicator.visible = true
	drop_indicator.size = Vector2(size.x, 2)
	if above:
		drop_indicator.position = Vector2(0, 0)
	else:
		drop_indicator.position = Vector2(0, size.y - 2)

func _hide_drop_indicator() -> void:
	if drop_indicator:
		drop_indicator.visible = false
	is_drop_target = false

func _get_drag_data(at_position: Vector2):
	if not action_data:
		return null
	
	var preview_label := Label.new()
	preview_label.text = label.text if label else "Action"
	preview_label.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0, 0.9))
	
	var preview_margin := MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 8)
	preview_margin.add_theme_constant_override("margin_top", 4)
	preview_margin.add_theme_constant_override("margin_right", 8)
	preview_margin.add_theme_constant_override("margin_bottom", 4)
	preview_margin.add_child(preview_label)
	
	set_drag_preview(preview_margin)
	
	return {
		"type": "action_item",
		"node": self,
		"data": action_data
	}

func _can_drop_data(at_position: Vector2, data) -> bool:
	if not data is Dictionary:
		_hide_drop_indicator()
		return false
	
	var drag_type = data.get("type", "")
	if drag_type != "action_item":
		_hide_drop_indicator()
		return false
	
	var source_node = data.get("node")
	if source_node == self:
		_hide_drop_indicator()
		return false
	
	# Prevent dropping a parent onto its own descendant
	if _is_descendant_of(source_node):
		_hide_drop_indicator()
		return false
	
	# Check if source is adjacent and prevent indicator on the shared edge
	var above = at_position.y < size.y / 2.0
	if _is_adjacent_to_source(source_node, above):
		_hide_drop_indicator()
		return false
	
	_show_drop_indicator(above)
	return true

func _is_descendant_of(node: Node) -> bool:
	"""Check if this item is a descendant of the given node."""
	var current = get_parent()
	while current:
		if current == node:
			return true
		current = current.get_parent()
	return false

func _is_adjacent_to_source(source_node: Node, drop_above: bool) -> bool:
	"""Check if dropping would result in no actual movement (adjacent items)."""
	var parent = get_parent()
	if not parent:
		return false
	
	var my_index = get_index()
	var source_index = -1
	
	for i in parent.get_child_count():
		if parent.get_child(i) == source_node:
			source_index = i
			break
	
	if source_index < 0:
		return false
	
	# If dropping above and source is directly above us, no movement needed
	if drop_above and source_index == my_index - 1:
		return true
	
	# If dropping below and source is directly below us, no movement needed
	if not drop_above and source_index == my_index + 1:
		return true
	
	return false

func _drop_data(at_position: Vector2, data) -> void:
	_hide_drop_indicator()
	
	if not data is Dictionary:
		return
	
	var drag_type = data.get("type", "")
	if drag_type != "action_item":
		return
	
	var source_node = data.get("node")
	if not source_node or source_node == self:
		return
	
	var above = at_position.y < size.y / 2.0
	reorder_requested.emit(source_node, self, above)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_hide_drop_indicator()
