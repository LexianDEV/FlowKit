@tool
extends VBoxContainer

## FlowKit Inspector Section
## Displays node variables and behaviors in the inspector with Godot-style UI

var node: Node = null
var registry: FKRegistry = null
var editor_interface: EditorInterface = null

# UI Components
var header_container: HBoxContainer = null
var icon: TextureRect = null
var title_label: Label = null
var content_container: VBoxContainer = null
var variable_list: VBoxContainer = null
var add_variable_button: Button = null

# Behavior UI Components
var behavior_section: VBoxContainer = null
var behavior_dropdown: OptionButton = null
var behavior_params_container: VBoxContainer = null
var available_behaviors: Array = []

func _ready() -> void:
	_build_ui()
	_load_node_data()

func set_node(p_node: Node) -> void:
	node = p_node

func set_registry(p_registry: FKRegistry) -> void:
	registry = p_registry

func set_editor_interface(p_editor_interface: EditorInterface) -> void:
	editor_interface = p_editor_interface

func _build_ui() -> void:
	# Main container styling
	add_theme_constant_override("separation", 0)
	
	# Header section (Godot-style category header)
	header_container = HBoxContainer.new()
	header_container.add_theme_constant_override("separation", 4)
	add_child(header_container)
	
	# Add top margin/separator
	var top_separator: Control = Control.new()
	top_separator.custom_minimum_size = Vector2(0, 8)
	header_container.add_sibling(top_separator)
	header_container.move_to_front()
	
	# Content container
	content_container = VBoxContainer.new()
	content_container.add_theme_constant_override("separation", 4)
	add_child(content_container)
	
	# Add margin to content
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 8)
	content_container.add_child(margin)
	
	var inner_vbox: VBoxContainer = VBoxContainer.new()
	inner_vbox.add_theme_constant_override("separation", 8)
	margin.add_child(inner_vbox)
	
	# === Behavior Section ===
	_build_behavior_section(inner_vbox)
	
	# === Variables Section ===
	var variables_label: Label = Label.new()
	variables_label.text = "Variables"
	variables_label.add_theme_font_size_override("font_size", 13)
	inner_vbox.add_child(variables_label)
	
	# Variable list
	variable_list = VBoxContainer.new()
	variable_list.add_theme_constant_override("separation", 2)
	inner_vbox.add_child(variable_list)
	
	# Add Variable button
	add_variable_button = Button.new()
	add_variable_button.text = "Add Variable"
	add_variable_button.pressed.connect(_on_add_variable)
	inner_vbox.add_child(add_variable_button)
	
	# Set icon after adding to tree (when theme is available)
	call_deferred("_set_header_icon")

func _build_behavior_section(parent: VBoxContainer) -> void:
	behavior_section = VBoxContainer.new()
	behavior_section.add_theme_constant_override("separation", 4)
	parent.add_child(behavior_section)
	
	# Behavior label
	var behavior_label: Label = Label.new()
	behavior_label.text = "Behavior"
	behavior_label.add_theme_font_size_override("font_size", 13)
	behavior_section.add_child(behavior_label)
	
	# Behavior dropdown
	behavior_dropdown = OptionButton.new()
	behavior_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	behavior_dropdown.item_selected.connect(_on_behavior_selected)
	behavior_section.add_child(behavior_dropdown)
	
	# Behavior parameters container
	behavior_params_container = VBoxContainer.new()
	behavior_params_container.add_theme_constant_override("separation", 2)
	behavior_section.add_child(behavior_params_container)
	
	# Populate behaviors after UI is built
	call_deferred("_populate_behaviors")

func _populate_behaviors() -> void:
	if not behavior_dropdown:
		return
	
	behavior_dropdown.clear()
	available_behaviors.clear()
	
	# Add "None" option first
	behavior_dropdown.add_item("None", 0)
	
	if not registry:
		return
	
	# Get the node's class name to filter behaviors
	var node_class: String = ""
	if node:
		node_class = node.get_class()
	
	# Get available behaviors for this node type
	var idx: int = 1
	for provider in registry.behavior_providers:
		if not provider.has_method("get_supported_types"):
			continue
		
		var supported_types: Array = provider.get_supported_types()
		var is_supported: bool = false
		
		# Check if this behavior supports the current node type
		for supported_type in supported_types:
			if node_class == supported_type or (node and node.is_class(supported_type)):
				is_supported = true
				break
		
		if is_supported:
			var behavior_name: String = provider.get_name() if provider.has_method("get_name") else provider.get_id()
			behavior_dropdown.add_item(behavior_name, idx)
			available_behaviors.append(provider)
			idx += 1
	
	# Load the current behavior if set
	_load_current_behavior()

func _load_current_behavior() -> void:
	if not node or not behavior_dropdown:
		return
	
	# Check if node has a behavior set
	if not node.has_meta("flowkit_behavior"):
		behavior_dropdown.select(0)  # Select "None"
		_clear_behavior_params()
		return
	
	var behavior_data: Dictionary = node.get_meta("flowkit_behavior", {})
	var behavior_id: String = behavior_data.get("id", "")
	
	if behavior_id.is_empty():
		behavior_dropdown.select(0)
		_clear_behavior_params()
		return
	
	# Find and select the behavior in dropdown
	for i in range(available_behaviors.size()):
		var provider = available_behaviors[i]
		if provider.has_method("get_id") and provider.get_id() == behavior_id:
			behavior_dropdown.select(i + 1)  # +1 because of "None" option
			_show_behavior_params(provider, behavior_data.get("inputs", {}))
			return
	
	# If behavior not found, select "None"
	behavior_dropdown.select(0)
	_clear_behavior_params()

func _on_behavior_selected(index: int) -> void:
	if not node:
		return
	
	if index == 0:
		# "None" selected - remove behavior
		if node.has_meta("flowkit_behavior"):
			node.remove_meta("flowkit_behavior")
		_clear_behavior_params()
		_notify_property_changed()
		return
	
	# Get the selected behavior provider
	var behavior_index: int = index - 1  # -1 because of "None" option
	if behavior_index < 0 or behavior_index >= available_behaviors.size():
		return
	
	var provider = available_behaviors[behavior_index]
	var behavior_id: String = provider.get_id() if provider.has_method("get_id") else ""
	
	# Get default inputs
	var default_inputs: Dictionary = {}
	if provider.has_method("get_inputs"):
		for input_def in provider.get_inputs():
			var input_name: String = input_def.get("name", "")
			var default_value: Variant = input_def.get("default", "")
			if not input_name.is_empty():
				default_inputs[input_name] = default_value
	
	# Save behavior to node metadata
	var behavior_data: Dictionary = {
		"id": behavior_id,
		"inputs": default_inputs
	}
	node.set_meta("flowkit_behavior", behavior_data)
	
	# Show behavior parameters
	_show_behavior_params(provider, default_inputs)
	_notify_property_changed()

func _clear_behavior_params() -> void:
	if not behavior_params_container:
		return
	
	for child in behavior_params_container.get_children():
		child.queue_free()

func _show_behavior_params(provider: Variant, current_inputs: Dictionary) -> void:
	_clear_behavior_params()
	
	if not provider.has_method("get_inputs"):
		return
	
	var inputs: Array = provider.get_inputs()
	if inputs.is_empty():
		return
	
	for input_def in inputs:
		var input_name: String = input_def.get("name", "")
		var input_type: String = input_def.get("type", "String")
		var default_value: Variant = input_def.get("default", "")
		var current_value: Variant = current_inputs.get(input_name, default_value)
		
		_add_behavior_param_row(input_name, input_type, current_value)

func _add_behavior_param_row(param_name: String, param_type: String, value: Variant) -> void:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	behavior_params_container.add_child(hbox)
	
	# Store the param name and type as metadata on the hbox
	hbox.set_meta("param_name", param_name)
	hbox.set_meta("param_type", param_type)
	
	# Parameter name label
	var name_label: Label = Label.new()
	name_label.text = param_name.capitalize().replace("_", " ")
	name_label.custom_minimum_size = Vector2(100, 0)
	hbox.add_child(name_label)
	
	# Parameter value field
	var value_edit: LineEdit = LineEdit.new()
	value_edit.text = str(value)
	value_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_edit.placeholder_text = param_type
	value_edit.text_changed.connect(_on_behavior_param_text_changed.bind(hbox))
	hbox.add_child(value_edit)

func _on_behavior_param_text_changed(new_text: String, hbox: HBoxContainer) -> void:
	var param_name: String = hbox.get_meta("param_name", "")
	var param_type: String = hbox.get_meta("param_type", "String")
	_on_behavior_param_changed(param_name, new_text, param_type)

func _on_behavior_param_changed(param_name: String, new_value: String, param_type: String) -> void:
	if not node:
		return
	
	if not node.has_meta("flowkit_behavior"):
		return
	
	var behavior_data: Dictionary = node.get_meta("flowkit_behavior", {}).duplicate(true)
	var inputs: Dictionary = behavior_data.get("inputs", {}).duplicate()
	
	# Convert value based on type
	var typed_value: Variant = new_value
	match param_type:
		"float":
			typed_value = float(new_value) if new_value.is_valid_float() else 0.0
		"int":
			typed_value = int(new_value) if new_value.is_valid_int() else 0
		"bool":
			typed_value = new_value.to_lower() == "true"
	
	inputs[param_name] = typed_value
	behavior_data["inputs"] = inputs
	node.set_meta("flowkit_behavior", behavior_data)
	_notify_property_changed()

func _set_header_icon() -> void:
	if icon and is_inside_tree():
		# Try to get the FlowKit icon or use a generic one
		var theme_icon: Texture2D = get_theme_icon("Script", "EditorIcons")
		if theme_icon:
			icon.texture = theme_icon

func _load_node_data() -> void:
	if not node:
		return
	
	_refresh_variables()

func _refresh_variables() -> void:
	if not node or not variable_list:
		return
	
	# Clear existing variable widgets
	for child in variable_list.get_children():
		child.queue_free()
	
	# Get node variables from metadata
	var vars: Dictionary = {}
	if node.has_meta("flowkit_variables"):
		vars = node.get_meta("flowkit_variables", {})
	
	# Get node variable types from metadata
	var var_types: Dictionary = {}
	if node.has_meta("flowkit_variable_types"):
		var_types = node.get_meta("flowkit_variable_types", {})
	
	# Display existing variables
	for var_name in vars.keys():
		var var_type: String = var_types.get(var_name, "String")
		_add_variable_row(var_name, vars[var_name], var_type)

func _add_variable_row(var_name: String, value: Variant, var_type: String = "String") -> void:
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	variable_list.add_child(hbox)
	
	# Store the current var_name and type as metadata on the hbox for reference
	hbox.set_meta("var_name", var_name)
	hbox.set_meta("var_type", var_type)
	
	# Name field
	var name_edit: LineEdit = LineEdit.new()
	name_edit.text = var_name
	name_edit.custom_minimum_size = Vector2(120, 0)
	name_edit.placeholder_text = "name"
	name_edit.text_changed.connect(func(new_text: String): _on_variable_name_changed(hbox, new_text))
	hbox.add_child(name_edit)
	
	# Type dropdown
	var type_dropdown: OptionButton = OptionButton.new()
	type_dropdown.custom_minimum_size = Vector2(100, 0)
	type_dropdown.add_item("String", 0)
	type_dropdown.add_item("int", 1)
	type_dropdown.add_item("float", 2)
	type_dropdown.add_item("bool", 3)
	
	# Set current type
	match var_type:
		"int":
			type_dropdown.select(1)
		"float":
			type_dropdown.select(2)
		"bool":
			type_dropdown.select(3)
		_:
			type_dropdown.select(0)
	
	type_dropdown.item_selected.connect(func(index: int): _on_variable_type_changed(hbox, type_dropdown.get_item_text(index)))
	hbox.add_child(type_dropdown)
	
	# Value field
	var value_edit: LineEdit = LineEdit.new()
	value_edit.text = str(value)
	value_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_edit.placeholder_text = "value"
	value_edit.text_changed.connect(func(new_text: String): _on_variable_value_changed(hbox, new_text))
	hbox.add_child(value_edit)
	
	# Delete button
	var delete_btn: Button = Button.new()
	delete_btn.text = "×"
	delete_btn.custom_minimum_size = Vector2(24, 0)
	delete_btn.tooltip_text = "Remove variable"
	delete_btn.pressed.connect(func(): _on_delete_variable(hbox))
	hbox.add_child(delete_btn)

func _on_add_variable() -> void:
	if not node:
		return
	
	# Get existing variables
	var vars: Dictionary = {}
	if node.has_meta("flowkit_variables"):
		vars = node.get_meta("flowkit_variables", {})
	
	# Get existing variable types
	var var_types: Dictionary = {}
	if node.has_meta("flowkit_variable_types"):
		var_types = node.get_meta("flowkit_variable_types", {})
	
	# Find unique name
	var var_name: String = "variable"
	var counter: int = 1
	while vars.has(var_name):
		var_name = "variable" + str(counter)
		counter += 1
	
	# Add new variable with String type as default
	vars[var_name] = ""
	var_types[var_name] = "String"
	node.set_meta("flowkit_variables", vars)
	node.set_meta("flowkit_variable_types", var_types)
	
	# Add the row at the bottom
	_add_variable_row(var_name, "", "String")

func _on_variable_name_changed(hbox: HBoxContainer, new_name: String) -> void:
	if not node or not hbox:
		return
	
	var old_name: String = hbox.get_meta("var_name", "")
	var var_type: String = hbox.get_meta("var_type", "String")
	
	new_name = new_name.strip_edges()
	
	# If empty, just return - don't refresh yet
	if new_name.is_empty():
		return
	
	if old_name == new_name:
		return
	
	var vars: Dictionary = {}
	if node.has_meta("flowkit_variables"):
		vars = node.get_meta("flowkit_variables", {}).duplicate()
	
	var var_types: Dictionary = {}
	if node.has_meta("flowkit_variable_types"):
		var_types = node.get_meta("flowkit_variable_types", {}).duplicate()
	
	# Check if new name already exists - if so, just return without refreshing
	if vars.has(new_name):
		return
	
	# Rename variable - preserve the value and type
	var value: Variant = ""
	if vars.has(old_name):
		value = vars[old_name]
		vars.erase(old_name)
	
	if var_types.has(old_name):
		var_types[new_name] = var_types[old_name]
		var_types.erase(old_name)
	else:
		var_types[new_name] = var_type
	
	vars[new_name] = value
	node.set_meta("flowkit_variables", vars)
	node.set_meta("flowkit_variable_types", var_types)
	hbox.set_meta("var_name", new_name)
	_notify_property_changed()

func _on_variable_type_changed(hbox: HBoxContainer, new_type: String) -> void:
	if not node or not hbox:
		return
	
	var var_name: String = hbox.get_meta("var_name", "")
	if var_name.is_empty():
		return
	
	var var_types: Dictionary = {}
	if node.has_meta("flowkit_variable_types"):
		var_types = node.get_meta("flowkit_variable_types", {}).duplicate()
	
	var_types[var_name] = new_type
	node.set_meta("flowkit_variable_types", var_types)
	hbox.set_meta("var_type", new_type)
	_notify_property_changed()

func _on_variable_value_changed(hbox: HBoxContainer, new_value: String) -> void:
	if not node or not hbox:
		return
	
	var var_name: String = hbox.get_meta("var_name", "")
	if var_name.is_empty():
		return
	
	var var_type: String = hbox.get_meta("var_type", "String")
	
	var vars: Dictionary = {}
	if node.has_meta("flowkit_variables"):
		vars = node.get_meta("flowkit_variables", {}).duplicate()
	
	# Store the value (conversion happens at runtime when accessed)
	vars[var_name] = new_value
	node.set_meta("flowkit_variables", vars)
	_notify_property_changed()

func _on_delete_variable(hbox: HBoxContainer) -> void:
	if not node or not hbox:
		return
	
	var var_name: String = hbox.get_meta("var_name", "")
	if var_name.is_empty():
		return
	
	var vars: Dictionary = {}
	if node.has_meta("flowkit_variables"):
		vars = node.get_meta("flowkit_variables", {}).duplicate()
	
	var var_types: Dictionary = {}
	if node.has_meta("flowkit_variable_types"):
		var_types = node.get_meta("flowkit_variable_types", {}).duplicate()
	
	vars.erase(var_name)
	var_types.erase(var_name)
	node.set_meta("flowkit_variables", vars)
	node.set_meta("flowkit_variable_types", var_types)
	_notify_property_changed()
	
	_refresh_variables()

func _notify_property_changed() -> void:
	# Mark the scene as modified in the editor
	if editor_interface:
		editor_interface.mark_scene_as_unsaved()
