@tool
extends MarginContainer
class_name EventUi

signal insert_condition_requested(event_node)
signal replace_event_requested(event_node)
signal delete_event_requested(event_node)
signal edit_event_requested(event_node)
signal selected(block_node)

var event_data: FKEventBlock
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
	if event is not InputEventMouseButton or not event.pressed:
		return
		
	if event.button_index == MOUSE_BUTTON_LEFT:
		# Left-click to select
		selected.emit(self)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		# Right-click for context menu
		selected.emit(self)
		context_menu.position = DisplayServer.mouse_get_position()
		context_menu.popup()

func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		0: # Insert Condition
			insert_condition_requested.emit(self)
		1: # Replace Event
			replace_event_requested.emit(self)
		2: # Edit Event
			edit_event_requested.emit(self)
		3: # Delete Event
			delete_event_requested.emit(self)

func set_event_data(data: FKEventBlock) -> void:
	event_data = data
	_update_label()

func set_registry(reg: Node) -> void:
	registry = reg
	_update_label()

func get_event_data() -> FKEventBlock:
	"""Return the internal event data."""
	return event_data

func _update_label() -> void:
	if event_data:
		var display_name := _decide_display_name()
		var params_text := _create_params_text()
		
		var node_name = String(event_data.target_node).get_file()
		label.text = "%s (%s)%s" % [display_name, node_name, params_text]

func _decide_display_name() -> String:
	var display_name: String = event_data.event_id
		
	# Try to get the provider's display name
	if registry:
		for provider in registry.event_providers:
			if provider.has_method("get_id") and provider.get_id() == event_data.event_id:
				if provider.has_method("get_name"):
					display_name = provider.get_name()
				break
	
	return display_name
	
func _create_params_text() -> String:
	var params_text = ""
	
	if not event_data.inputs.is_empty():
		var param_pairs = []
		for key in event_data.inputs:
			param_pairs.append("%s: %s" % [key, event_data.inputs[key]])
		params_text = " (" + ", ".join(param_pairs) + ")"
		
	return params_text
	
func update_display() -> void:
	"""Refresh the label display."""
	_update_label()

func set_selected(value: bool) -> void:
	"""Set the selection state with visual feedback."""
	is_selected = value
	_update_panel_style()

func _update_panel_style():
	var style := normal_stylebox
	
	if is_selected:
		style = selected_stylebox
		
	panel.add_theme_stylebox_override("panel", style)
	
func _get_drag_data(at_position: Vector2):
	var drag_preview := _create_drag_preview()
	set_drag_preview(drag_preview)
	
	# Return drag data with type information
	return {
		"type": "event",
		"node": self
	}

func _create_drag_preview() -> Control:
	var preview_label := Label.new()
	preview_label.text = label.text if label else "Event"
	preview_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9, 0.7))
	
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
