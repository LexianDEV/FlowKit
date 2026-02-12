@tool
extends VBoxContainer

## FlowKit Inspector Section
## Displays node behaviors in the inspector with Godot-style UI

var node: Node = null
var registry: FKRegistry = null
var editor_interface: EditorInterface = null

# UI Components
var header_container: HBoxContainer = null
var icon: TextureRect = null
var title_label: Label = null
var content_container: VBoxContainer = null

# Behavior UI Components
var behavior_section: VBoxContainer = null
var behavior_dropdown: OptionButton = null
var behavior_params_container: VBoxContainer = null
var available_behaviors: Array = []

func _ready() -> void:
	_build_ui()

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

func _notify_property_changed() -> void:
	# Mark the scene as modified in the editor
	if editor_interface:
		editor_interface.mark_scene_as_unsaved()
