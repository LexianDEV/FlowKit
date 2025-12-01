@tool
extends PopupPanel

signal expressions_confirmed(node_path: String, action_id: String, expressions: Dictionary)

var editor_interface: EditorInterface
var selected_node_path: String = ""
var selected_action_id: String = ""
var action_inputs: Array = []
var current_param_index: int = 0
var param_values: Dictionary = {}

# UI References
@onready var param_label := $MarginContainer/VBoxContainer/TopContainer/ParamLabel
@onready var expression_input := $MarginContainer/VBoxContainer/TopContainer/ExpressionInput
@onready var description_label := $MarginContainer/VBoxContainer/TopContainer/DescriptionPanel/DescriptionMargin/DescriptionLabel
@onready var description_panel := $MarginContainer/VBoxContainer/TopContainer/DescriptionPanel
@onready var node_tree := $MarginContainer/VBoxContainer/MainContainer/LeftPanel/NodeTree
@onready var item_list := $MarginContainer/VBoxContainer/MainContainer/RightPanel/ItemList
@onready var prev_button := $MarginContainer/VBoxContainer/ButtonContainer/PrevButton
@onready var next_button := $MarginContainer/VBoxContainer/ButtonContainer/NextButton
@onready var confirm_button := $MarginContainer/VBoxContainer/ButtonContainer/ConfirmButton

var selected_tree_node: Node = null

func _ready() -> void:
	if node_tree:
		node_tree.item_selected.connect(_on_node_selected)
	if item_list:
		item_list.item_activated.connect(_on_item_activated)
	
	# Setup tree if interface is already available
	if editor_interface:
		call_deferred("_setup_node_tree")

func set_editor_interface(interface: EditorInterface) -> void:
	editor_interface = interface
	# Setup tree if we're already ready
	if is_node_ready() and node_tree:
		call_deferred("_setup_node_tree")

func populate_inputs(node_path: String, action_id: String, inputs: Array, current_values: Dictionary = {}) -> void:
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
	if not node_tree or not editor_interface:
		return
	
	node_tree.clear()
	
	var scene_root = editor_interface.get_edited_scene_root()
	if not scene_root:
		return
	
	# Add System node as first entry (runtime autoload)
	var system_item: TreeItem = node_tree.create_item()
	system_item.set_text(0, "System (FlowKitSystem)")
	system_item.set_metadata(0, null)  # No actual node in editor
	system_item.set_icon(0, editor_interface.get_base_control().get_theme_icon("Node", "EditorIcons"))
	
	# Create root item
	var root_item: TreeItem = node_tree.create_item()
	root_item.set_text(0, scene_root.name)
	root_item.set_metadata(0, scene_root)
	root_item.set_icon(0, editor_interface.get_base_control().get_theme_icon("Node", "EditorIcons"))
	
	# Recursively add children
	_add_node_children(scene_root, root_item)

func _add_node_children(node: Node, tree_item: TreeItem) -> void:
	for child in node.get_children():
		var child_item: TreeItem = tree_item.create_child()
		child_item.set_text(0, child.name)
		child_item.set_metadata(0, child)
		
		# Get node icon from editor
		var icon_name: String = child.get_class()
		var icon: Texture2D = editor_interface.get_base_control().get_theme_icon(icon_name, "EditorIcons")
		if icon:
			child_item.set_icon(0, icon)
		
		# Recursively add this node's children
		if child.get_child_count() > 0:
			_add_node_children(child, child_item)

func _show_current_parameter() -> void:
	if action_inputs.is_empty():
		return
	
	var param_data: Dictionary = action_inputs[current_param_index]
	var param_name: String = param_data.get("name", "Unknown")
	var param_type: String = param_data.get("type", "Variant")
	var param_description: String = param_data.get("description", "")
	
	if param_label:
		param_label.text = "%s (%s)" % [param_name, param_type]
	
	# Update description
	if description_label:
		if param_description.is_empty():
			description_label.text = ""
			if description_panel:
				description_panel.visible = false
		else:
			description_label.text = param_description
			if description_panel:
				description_panel.visible = true
	
	if expression_input:
		expression_input.text = param_values.get(param_name, "")
		expression_input.grab_focus()
		expression_input.caret_column = expression_input.text.length()
	
	# Update navigation buttons
	if prev_button:
		prev_button.disabled = current_param_index == 0
	if next_button:
		next_button.disabled = current_param_index >= action_inputs.size() - 1
	if confirm_button:
		confirm_button.text = "Confirm" if current_param_index >= action_inputs.size() - 1 else "Next"

func _on_node_selected() -> void:
	var selected_item: TreeItem = node_tree.get_selected()
	if not selected_item:
		return
	
	selected_tree_node = selected_item.get_metadata(0)
	_populate_node_values()

func _populate_node_values() -> void:
	if not item_list:
		return
	
	item_list.clear()
	
	# Special handling for System node (null metadata)
	if selected_tree_node == null:
		# System node - show scene variables
		item_list.add_item("system.get_var(\"variable_name\")")
		return
	
	# Get scene root and target node
	var scene_root = editor_interface.get_edited_scene_root() if editor_interface else null
	var target_node = scene_root.get_node_or_null(selected_node_path) if scene_root else null
	
	# Add node variables
	if selected_tree_node.has_meta("flowkit_variables"):
		var vars: Dictionary = selected_tree_node.get_meta("flowkit_variables", {})
		for var_name in vars.keys():
			# Check if this is the target node
			if selected_tree_node == target_node:
				# Target node - use simple n_ prefix
				item_list.add_item("n_" + var_name)
			else:
				# Different node - calculate path from target node to selected node
				if target_node and scene_root:
					# Get path from target to selected node
					var path_from_target: String = str(target_node.get_path_to(selected_tree_node))
					item_list.add_item('system.get_node_var(node.get_node("' + path_from_target + '"), "' + var_name + '")')
				elif scene_root:
					# Fallback: use path from scene root
					var path_from_root: String = str(scene_root.get_path_to(selected_tree_node))
					if path_from_root == ".":
						# Selected node IS the scene root
						item_list.add_item('system.get_node_var(node.get_tree().current_scene, "' + var_name + '")')
					else:
						item_list.add_item('system.get_node_var(node.get_tree().current_scene.get_node("' + path_from_root + '"), "' + var_name + '")')
	
	# Add node properties
	var properties = []
	
	# Check if this is the target node for property references
	if selected_tree_node == target_node:
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
		var scene_root_ref = editor_interface.get_edited_scene_root() if editor_interface else null
		if scene_root_ref:
			var absolute_path: String = str(scene_root_ref.get_path_to(selected_tree_node))
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
	
	# Add math operators section
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
	if not expression_input:
		return
	
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
	
	var param_data: Dictionary = action_inputs[current_param_index]
	var param_name: String = param_data.get("name", "")
	
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
