@tool
extends MarginContainer
class_name ConditionUi

signal insert_condition_requested(condition_node)
signal replace_condition_requested(condition_node)
signal delete_condition_requested(condition_node)
signal negate_condition_requested(condition_node)
signal edit_condition_requested(condition_node)
signal selected(block_node)

var condition_data: FKEventCondition
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
	# Connect gui_input for click detection
	_toggle_subs(true)
	_update_negation_checkmark()

func _toggle_subs(on: bool):
	if on:
		gui_input.connect(_on_gui_input)
		context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	else:
		gui_input.disconnect(_on_gui_input)
		context_menu.id_pressed.disconnect(_on_context_menu_id_pressed)
		
func _update_negation_checkmark() -> void:
	var is_cond_negated: bool = condition_data.negated if condition_data else false
	context_menu.set_item_checked(4, is_cond_negated)

func _on_gui_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton or not event.pressed:
		return
		
	if event.button_index == MOUSE_BUTTON_LEFT:
		# Left-click to select
		selected.emit(self)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		selected.emit(self)
		context_menu.position = DisplayServer.mouse_get_position()
		context_menu.popup()

func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		0: # Insert Condition Below
			insert_condition_requested.emit(self)
		1: # Replace Condition
			replace_condition_requested.emit(self)
		2: # Edit Condition
			edit_condition_requested.emit(self)
		3: # Delete Condition
			delete_condition_requested.emit(self)
		4: # Negate
			negate_condition_requested.emit(self)
			print("Negate condition requested for: ", condition_data.condition_id if condition_data else "unknown")

func set_condition_data(data: FKEventCondition) -> void:
	condition_data = data
	_update_label()

func set_registry(reg: Node) -> void:
	registry = reg
	_update_label()

func get_condition_data() -> FKEventCondition:
	"""Return the internal condition data."""
	return condition_data

func _update_label() -> void:
	if condition_data:
		var display_name = _decide_display_name()
		var params_text = _create_params_text()
		
		var negation_prefix = "NOT " if condition_data.negated else ""
		label.text = "%s%s%s" % [negation_prefix, display_name, params_text]
	
	_update_negation_checkmark()

func _decide_display_name() -> String:
	var display_name := condition_data.condition_id
		
	if registry:
		for provider in registry.condition_providers:
			if provider.has_method("get_id") and provider.get_id() == condition_data.condition_id:
				if provider.has_method("get_name"):
					display_name = provider.get_name()
				break
				
	return display_name
	
func _create_params_text() -> String:
	var params_text = ""
	
	if not condition_data.inputs.is_empty():
		var param_pairs = []
		for key in condition_data.inputs:
			param_pairs.append("%s: %s" % [key, condition_data.inputs[key]])
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
	var style = normal_stylebox
	if is_selected:
		style = selected_stylebox
		
	panel.add_theme_stylebox_override("panel", style)
	
func _get_drag_data(at_position: Vector2):
	var drag_preview := _create_drag_preview()
	set_drag_preview(drag_preview)
	
	# Return drag data with type information
	return {
		"type": "condition",
		"node": self
	}

func _create_drag_preview() -> Control:
	var preview_label := Label.new()
	preview_label.text = label.text
	preview_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.85, 0.7))
	
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
