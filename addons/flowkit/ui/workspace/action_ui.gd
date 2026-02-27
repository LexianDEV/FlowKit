@tool
extends MarginContainer
class_name ActionUi

signal insert_action_requested(action_node)
signal replace_action_requested(action_node)
signal delete_action_requested(action_node)
signal edit_action_requested(action_node)
signal selected(block_node)

var action_data: FKEventAction
var registry: Node
var is_selected: bool = false

@export_category("Controls")
@export var context_menu: PopupMenu
@export var label: Label
@export var panel: PanelContainer

@export_category("Styles")
@export var normal_stylebox: StyleBox
@export var selected_stylebox: StyleBox

func _enter_tree() -> void:
	_toggle_subs(true)
	
func _toggle_subs(on: bool):
	if on:
		gui_input.connect(_on_gui_input)
		context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	else:
		gui_input.disconnect(_on_gui_input)
		context_menu.id_pressed.disconnect(_on_context_menu_id_pressed)
		
func _on_gui_input(event: InputEvent) -> void:
	var we_want_to_respond: bool = event is InputEventMouseButton and event.pressed
	if not we_want_to_respond:
		return
		
	if event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(self)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		selected.emit(self)
		context_menu.position = DisplayServer.mouse_get_position()
		context_menu.popup()

func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		0: # Add Action Below
			insert_action_requested.emit(self)
		1: # Replace Action
			replace_action_requested.emit(self)
		2: # Edit Action
			edit_action_requested.emit(self)
		3: # Delete Action
			delete_action_requested.emit(self)

func set_action_data(data: FKEventAction) -> void:
	action_data = data
	_update_label()

func _update_label() -> void:
	if not action_data:
		return
		
	var display_name = action_data.action_id
	
	if registry:
		var provider_name := _try_get_provider_display_name()
		if provider_name.length() > 0:
			display_name = provider_name
	
	var params_text = _decide_params_text()
	
	var node_name = String(action_data.target_node).get_file()
	label.text = label_text_format % [display_name, node_name, params_text]

var label_text_format: String = "%s on %s%s"

func _try_get_provider_display_name() -> String:
	var result: String = ""
	for provider in registry.action_providers:
		if provider.has_method("get_id") and provider.get_id() == action_data.action_id:
			if provider.has_method("get_name"):
				result = provider.get_name()
			break
	return result

func _decide_params_text() -> String:
	var params_text = ""
	
	if not action_data.inputs.is_empty():
		var param_pairs = []
		for key in action_data.inputs:
			param_pairs.append("%s: %s" % [key, action_data.inputs[key]])
		params_text = " (" + ", ".join(param_pairs) + ")"
	
	print("Decided on params text: " + params_text)
	return params_text
	
func set_registry(reg: Node) -> void:
	registry = reg
	_update_label()

func get_action_data() -> FKEventAction:
	"""Return the internal action data."""
	return action_data



func update_display() -> void:
	"""Refresh the label display."""
	_update_label()

func set_selected(value: bool) -> void:
	"""Set the selection state with visual feedback."""
	is_selected = value
	_update_panel_style()

func _update_panel_style():
	var theme = normal_stylebox
	if is_selected:
		theme = selected_stylebox
	
	panel.add_theme_stylebox_override("panel", theme)
	
func _get_drag_data(at_position: Vector2):
	var preview_margin := _create_drag_preview()
	set_drag_preview(preview_margin)
	
	# Return drag data with type information
	return \
	{
		"type": "action",
		"node": self
	}

func _create_drag_preview() -> Control:
	var preview_label := Label.new()
	preview_label.text = label.text if label else "Action"
	preview_label.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95, 0.7))
	
	var preview_margin := MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 8)
	preview_margin.add_theme_constant_override("margin_top", 4)
	preview_margin.add_theme_constant_override("margin_right", 8)
	preview_margin.add_theme_constant_override("margin_bottom", 4)
	preview_margin.add_child(preview_label)
	
	return preview_margin
	
func _can_drop_data(at_position: Vector2, data) -> bool:
	return false  # VBoxContainer handles drops

func _drop_data(at_position: Vector2, data) -> void:
	pass  # VBoxContainer handles drops

func _exit_tree() -> void:
	_toggle_subs(false)
