@tool
extends PopupPanel
class_name FKExpressionEditorModal

signal expressions_confirmed(node_path: String, action_id: String, expressions: Dictionary)

var editor_interface: EditorInterface
var selected_node_path: String = ""
var selected_action_id: String = ""
var action_inputs: Array = []
var current_param_index: int = 0
var param_values: Dictionary = {}

@export var param_label: Label
@export var expression_input: LineEdit 
@export var description_label: Label
@export var description_panel: Control
@export var node_tree: Tree 
@export var item_list: ItemList 
@export var prev_button: Button
@export var next_button: Button 
@export var confirm_button: Button

var selected_tree_node: Node = null

func _enter_tree() -> void:
	_toggle_subs(true)
	if editor_interface:
		call_deferred("_setup_node_tree")

func _toggle_subs(on: bool):
	if on:
		node_tree.item_selected.connect(_on_node_selected)
		item_list.item_activated.connect(_on_item_activated)
		if editor_interface:
			call_deferred("_setup_node_tree")
	
func set_editor_interface(interface: EditorInterface) -> void:
	editor_interface = interface
	# Setup tree if we're already ready
	if is_node_ready():
		call_deferred("_setup_node_tree")

func populate_inputs(node_path: String, action_id: String, inputs: Array, \
current_values: Dictionary = {}) -> void:
	selected_node_path = node_path
	selected_action_id = action_id
	action_inputs = inputs
	current_param_index = 0
	param_values = current_values.duplicate()

	_show_current_parameter()
	
	# Setup node tree if editor interface is available
	if editor_interface:
		_setup_node_tree()

func _setup_node_tree() -> void:
	if not editor_interface:
		return
	
	node_tree.clear()
	
	if not _scene_root:
		return
	
	# Add System node as first entry (runtime autoload)
	var system_item: TreeItem = node_tree.create_item()
	system_item.set_text(0, "System (FlowKitSystem)")
	system_item.set_metadata(0, null)  # No actual node in editor
	system_item.set_icon(0, editor_interface.get_base_control().get_theme_icon("Node", "EditorIcons"))
	
	# Create root item
	var root_item: TreeItem = node_tree.create_item()
	root_item.set_text(0, _scene_root.name)
	root_item.set_metadata(0, _scene_root)
	root_item.set_icon(0, editor_interface.get_base_control().get_theme_icon("Node", "EditorIcons"))
	
	# Recursively add children
	_add_node_children(_scene_root, root_item)

func _add_node_children(node: Node, tree_item: TreeItem) -> void:
	for child in node.get_children():
		var child_item: TreeItem = tree_item.create_child()
		child_item.set_text(0, child.name)
		child_item.set_metadata(0, child)
		
		# Get node icon from editor
		var icon_name: String = child.get_class()
		var base_control := editor_interface.get_base_control()
		var icon: Texture2D = base_control.get_theme_icon(icon_name, "EditorIcons")
		if icon:
			child_item.set_icon(0, icon)
		
		# Recursively add this node's children
		if child.get_child_count() > 0:
			_add_node_children(child, child_item)

func _show_current_parameter() -> void:
	print("In show current param")
	if action_inputs.is_empty():
		print("Action inputs are empty. Doing nothing.")
		return
	
	print("Action inputs:\n" + str(action_inputs))
	var current_input = action_inputs[current_param_index]
	var param_name: String; var param_type: String; var param_description: String;
	var fk_action_input: FKActionInput
	if current_input is Dictionary:
		print("Current input is dict")
		var param_dict: Dictionary = action_inputs[current_param_index]
		param_name = param_dict.get("name", "Unknown")
		param_type = param_dict.get("type", "Variant")
		param_description = param_dict.get("description", "")
		
	elif current_input is FKActionInput:
		print("Current input is FKActionInput")
		fk_action_input = current_input
		param_name = fk_action_input.name
		param_type = fk_action_input.type
		param_description = fk_action_input.description
		
	
	param_label.text = "%s (%s)" % [param_name, param_type]
	# ^For some reason, this doesn't work when we assign the format to a var...
	_update_desc(param_description)
	_update_expr_input(param_name)
	_update_nav_buttons()
	
func _update_desc(param_description: String):
	description_label.text = param_description
	var is_there_desc_to_show: bool = param_description.length() > 0
	description_panel.visible = is_there_desc_to_show

func _update_expr_input(param_name: String):
	expression_input.text = param_values.get(param_name, "")
	expression_input.grab_focus()
	expression_input.caret_column = expression_input.text.length()

func _update_nav_buttons():
	prev_button.disabled = current_param_index == 0
	next_button.disabled = current_param_index >= action_inputs.size() - 1
	confirm_button.text = "Confirm" if current_param_index >= action_inputs.size() - 1 else "Next"
	
func _on_node_selected() -> void:
	var selected_item: TreeItem = node_tree.get_selected()
	if not selected_item:
		return
	
	selected_tree_node = selected_item.get_metadata(0)
	_populate_item_list_for_selected_node()

func _populate_item_list_for_selected_node() -> void:
	item_list.clear()
	
	# Special handling for System node (null metadata)
	if selected_tree_node == null:
		# System node - show scene variables
		item_list.add_item("system.get_var(\"variable_name\")")
		return
	
	var target_node: Node = _scene_root.get_node_or_null(selected_node_path) if _scene_root \
	else null
	
	_add_var_items(target_node)
	_add_prop_items(target_node)
	_add_math_op_section()

var _scene_root: Node:
	get:
		return editor_interface.get_edited_scene_root() if editor_interface else null
		
func _add_var_items(target_node: Node):
	if not selected_tree_node.has_meta("flowkit_variables"):
		return
	
	var vars: Dictionary = selected_tree_node.get_meta("flowkit_variables", {})
	
	if _is_target_node(selected_tree_node):
		_add_targ_var_items(vars)
	else:
		_add_other_node_var_items(vars, target_node)

func _add_targ_var_items(vars: Dictionary):
	for var_name in vars.keys():
		item_list.add_item("n_" + var_name)


func _add_other_node_var_items(vars: Dictionary, target_node: Node) -> void:
	for var_name in vars.keys():
		var ref := _build_cross_node_var_ref(var_name, target_node)
		item_list.add_item(ref)
		
		
func _build_cross_node_var_ref(var_name: String, target_node: Node) -> String:
	# Since we want to make sure (when possible) that the inputs for things _not_ targeting 
	# the System node are evaluated using the target node as the ref point.
	# Case 1: path from target → selected
	if target_node and _scene_root:
		var path_from_target: String = str(target_node.get_path_to(selected_tree_node))
		return 'system.get_node_var(node.get_node("' + path_from_target + '"), "' + var_name + '")'
	
	# Case 2: fallback path from root → selected
	if _scene_root:
		var path_from_root: String = str(_scene_root.get_path_to(selected_tree_node))
		if path_from_root == ".":
			# Selected node IS the scene root
			return 'system.get_node_var(node.get_tree().current_scene, "' + var_name + '")'
		else:
			return 'system.get_node_var(node.get_tree().current_scene.get_node("' + path_from_root + '"), "' + var_name + '")'
	
	# Extremely defensive fallback (shouldn’t normally hit)
	return 'system.get_node_var(node.get_tree().current_scene, "' + var_name + '")'
	
func _add_prop_items(target_node: Node):
	var properties = []
	
	# Check if this is the target node for property references
	if _is_target_node(selected_tree_node):
		# Target node - use 'node.' prefix
		properties = [
			"node.name",
			"node.position",
			"node.position.x",
			"node.position.y",
			"node.rotation",
			"node.scale",
			"node.scale.x",
			"node.scale.y",
			"node.visible",
			"node.modulate"
		]
		
		# Add type-specific properties
		if selected_tree_node is CharacterBody2D:
			properties.append_array([
				"node.velocity",
				"node.velocity.x",
				"node.velocity.y"
			])
		elif selected_tree_node is Camera2D:
			properties.append_array([
				"node.zoom",
				"node.offset"
			])
	else:
		# Different node - use get_node() reference
		if _scene_root:
			var absolute_path: String = str(_scene_root.get_path_to(selected_tree_node))
			var node_ref: String = 'get_node("' + absolute_path + '")'
			
			properties = [
				node_ref + ".name",
				node_ref + ".position",
				node_ref + ".position.x",
				node_ref + ".position.y",
				node_ref + ".rotation",
				node_ref + ".scale.x",
				node_ref + ".scale.y",
				node_ref + ".visible"
			]
			
			if selected_tree_node is CharacterBody2D:
				properties.append_array([
					node_ref + ".velocity",
					node_ref + ".velocity.x",
					node_ref + ".velocity.y"
				])
	
	for prop in properties:
		item_list.add_item(prop)

func _is_target_node(node: Node) -> bool:
	if not _scene_root:
		return false
	return node == _scene_root.get_node_or_null(selected_node_path)
	
func _add_math_op_section():
	item_list.add_item("─────────────────")
	item_list.set_item_disabled(item_list.item_count - 1, true)
	item_list.add_item("+ (Add)")
	item_list.add_item("- (Subtract)")
	item_list.add_item("* (Multiply)")
	item_list.add_item("/ (Divide)")
	item_list.add_item("% (Modulo)")
	item_list.add_item("abs(x)")
	item_list.add_item("ceil(x)")
	item_list.add_item("floor(x)")
	item_list.add_item("round(x)")
	item_list.add_item("sqrt(x)")
	item_list.add_item("min(a, b)")
	item_list.add_item("max(a, b)")
	item_list.add_item("clamp(val, min, max)")
	
func _on_item_activated(index: int) -> void:
	var item_text: String = item_list.get_item_text(index)
	_insert_at_cursor(item_text)

func _insert_at_cursor(text: String) -> void:
	# Extract just the value part (before any description in parentheses)
	var insert_text: String = text.split(" (")[0]
	
	# Get cursor position
	var cursor_pos: int = expression_input.caret_column
	var current_text: String = expression_input.text
	
	# Insert at cursor
	var before: String = current_text.substr(0, cursor_pos)
	var after: String = current_text.substr(cursor_pos)
	
	expression_input.text = before + insert_text + after
	expression_input.caret_column = cursor_pos + insert_text.length()
	expression_input.grab_focus()

func _save_current_parameter() -> void:
	if action_inputs.is_empty():
		return
	
	var param_data = action_inputs[current_param_index]
	var param_name: String
	if param_data is Dictionary:
		param_name = param_data.get("name", "")
	elif param_data is FKActionInput:
		param_name = param_data.name
		
	if expression_input:
		param_values[param_name] = expression_input.text

func _on_prev_button_pressed() -> void:
	_save_current_parameter()
	if current_param_index > 0:
		current_param_index -= 1
		_show_current_parameter()

func _on_next_button_pressed() -> void:
	_save_current_parameter()
	if current_param_index < action_inputs.size() - 1:
		current_param_index += 1
		_show_current_parameter()
	else:
		_confirm()

func _on_confirm_button_pressed() -> void:
	_save_current_parameter()
	
	if current_param_index < action_inputs.size() - 1:
		# Move to next parameter
		current_param_index += 1
		_show_current_parameter()
	else:
		# Confirm all
		_confirm()

func _confirm() -> void:
	_save_current_parameter()
	expressions_confirmed.emit(selected_node_path, selected_action_id, param_values)
	hide()

func _on_cancel_button_pressed() -> void:
	hide()
	
func _exit_tree() -> void:
	_toggle_subs(false)
