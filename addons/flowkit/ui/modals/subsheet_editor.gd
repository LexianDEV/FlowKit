@tool
extends Window

signal actions_updated(subsheet_id: String)

var current_subsheet: FKSubsheet = null
var current_sheet: FKEventSheet = null  # For scene root context
var editor_interface: EditorInterface
var registry: Node

# Workflow state
var pending_action_node_path: String = ""
var pending_action_id: String = ""
var pending_action_index: int = -1  # -1 for new, >= 0 for edit

@onready var actions_list := $VBoxContainer/ScrollContainer/ActionsList
@onready var add_action_button := $VBoxContainer/ButtonContainer/AddActionButton
@onready var close_button := $VBoxContainer/ButtonContainer/CloseButton
@onready var subsheet_name_label := $VBoxContainer/SubsheetNameLabel

# Modals (will be created programmatically)
var select_node_modal = null
var select_action_modal = null
var expression_modal = null

func _ready() -> void:
	if add_action_button:
		add_action_button.pressed.connect(_on_add_action_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_pressed)
	
	# Set window properties
	title = "Edit Subsheet Actions"
	size = Vector2i(600, 500)
	min_size = Vector2i(500, 400)

func set_editor_interface(interface: EditorInterface) -> void:
	editor_interface = interface

func set_registry(reg: Node) -> void:
	registry = reg

func set_subsheet(subsheet: FKSubsheet, sheet: FKEventSheet) -> void:
	current_subsheet = subsheet
	current_sheet = sheet
	_refresh_actions()
	if subsheet_name_label:
		subsheet_name_label.text = "Editing: %s" % subsheet.name

func _refresh_actions() -> void:
	"""Refresh the actions list display."""
	# Clear existing items
	for child in actions_list.get_children():
		child.queue_free()
	
	if not current_subsheet:
		return
	
	# Add actions
	for i in range(current_subsheet.actions.size()):
		var action = current_subsheet.actions[i]
		var item = _create_action_item(action, i)
		actions_list.add_child(item)

func _create_action_item(action: FKEventAction, index: int) -> HBoxContainer:
	## Create a UI item for an action.
	var container = HBoxContainer.new()
	container.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	
	# Action label
	var label = Label.new()
	label.text = "%d. %s (%s)" % [index + 1, action.action_id, action.target_node]
	label.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	container.add_child(label)
	
	# Edit button
	var edit_btn = Button.new()
	edit_btn.text = "Edit"
	edit_btn.pressed.connect(func(): _on_edit_action(index))
	container.add_child(edit_btn)
	
	# Delete button
	var delete_btn = Button.new()
	delete_btn.text = "Delete"
	delete_btn.pressed.connect(func(): _on_delete_action(index))
	container.add_child(delete_btn)
	
	# Move up button
	if index > 0:
		var up_btn = Button.new()
		up_btn.text = "↑"
		up_btn.pressed.connect(func(): _on_move_action(index, index - 1))
		container.add_child(up_btn)
	
	# Move down button
	if index < current_subsheet.actions.size() - 1:
		var down_btn = Button.new()
		down_btn.text = "↓"
		down_btn.pressed.connect(func(): _on_move_action(index, index + 1))
		container.add_child(down_btn)
	
	return container

func _on_add_action_pressed() -> void:
	## Start the workflow to add a new action.
	pending_action_index = -1
	_show_select_node_modal()

func _on_edit_action(index: int) -> void:
	## Edit an existing action.
	pending_action_index = index
	var action = current_subsheet.actions[index]
	pending_action_node_path = str(action.target_node)
	pending_action_id = action.action_id
	_show_expression_modal(action.inputs)

func _on_delete_action(index: int) -> void:
	## Delete an action.
	if index >= 0 and index < current_subsheet.actions.size():
		var new_actions: Array[FKEventAction] = []
		for i in range(current_subsheet.actions.size()):
			if i != index:
				new_actions.append(current_subsheet.actions[i])
		current_subsheet.actions = new_actions
		_refresh_actions()
		emit_signal("actions_updated", current_subsheet.subsheet_id)

func _on_move_action(from_index: int, to_index: int) -> void:
	## Move an action in the list.
	if from_index < 0 or from_index >= current_subsheet.actions.size():
		return
	if to_index < 0 or to_index >= current_subsheet.actions.size():
		return
	
	var temp = current_subsheet.actions[from_index]
	current_subsheet.actions[from_index] = current_subsheet.actions[to_index]
	current_subsheet.actions[to_index] = temp
	_refresh_actions()
	emit_signal("actions_updated", current_subsheet.subsheet_id)

func _show_select_node_modal() -> void:
	"""Show modal to select target node."""
	# Create modal if needed
	if not select_node_modal:
		var select_scene = load("res://addons/flowkit/ui/modals/select.tscn")
		select_node_modal = select_scene.instantiate()
		select_node_modal.set_editor_interface(editor_interface)
		select_node_modal.node_selected.connect(_on_node_selected)
		add_child(select_node_modal)
	
	select_node_modal.popup_centered(Vector2i(600, 500))

func _on_node_selected(node_path: String, node_class: String) -> void:
	"""Handle node selection."""
	pending_action_node_path = node_path
	_show_select_action_modal(node_class)

func _show_select_action_modal(node_class: String) -> void:
	## Show modal to select action.
	# Create modal if needed
	if not select_action_modal:
		var select_scene = load("res://addons/flowkit/ui/modals/select_action.tscn")
		select_action_modal = select_scene.instantiate()
		select_action_modal.set_editor_interface(editor_interface)
		select_action_modal.set_registry(registry)
		select_action_modal.action_selected.connect(_on_action_selected)
		add_child(select_action_modal)
	
	select_action_modal.populate(node_class)
	select_action_modal.popup_centered(Vector2i(600, 500))

func _on_action_selected(action_id: String, inputs: Array) -> void:
	## Handle action selection.
	pending_action_id = action_id
	
	if inputs.size() > 0:
		_show_expression_modal({})
	else:
		_create_or_update_action({})

func _show_expression_modal(existing_inputs: Dictionary) -> void:
	"""Show modal to edit action inputs."""
	# Create modal if needed
	if not expression_modal:
		var expr_scene = load("res://addons/flowkit/ui/modals/expression_editor.tscn")
		expression_modal = expr_scene.instantiate()
		expression_modal.set_editor_interface(editor_interface)
		expression_modal.expressions_confirmed.connect(_on_expressions_confirmed)
		add_child(expression_modal)
	
	# Get action provider to get input definitions
	var provider = _get_action_provider(pending_action_id)
	if provider:
		var inputs = provider.get_inputs()
		expression_modal.populate_inputs(inputs, existing_inputs)
		expression_modal.popup_centered(Vector2i(600, 400))
	else:
		_create_or_update_action({})

func _on_expressions_confirmed(expressions: Dictionary) -> void:
	"""Handle expression confirmation."""
	_create_or_update_action(expressions)

func _create_or_update_action(inputs: Dictionary) -> void:
	## Create a new action or update existing one.
	if pending_action_index == -1:
		# Create new action
		var action = FKEventAction.new()
		action.action_id = pending_action_id
		action.target_node = NodePath(pending_action_node_path)
		action.inputs = inputs
		
		if not current_subsheet.actions:
			current_subsheet.actions = [] as Array[FKEventAction]
		current_subsheet.actions.append(action)
	else:
		# Update existing action
		if pending_action_index >= 0 and pending_action_index < current_subsheet.actions.size():
			current_subsheet.actions[pending_action_index].inputs = inputs
	
	_refresh_actions()
	emit_signal("actions_updated", current_subsheet.subsheet_id)

func _get_action_provider(action_id: String) -> Variant:
	"""Get action provider by ID."""
	if not registry:
		return null
	
	for provider in registry.action_providers:
		if provider.has_method("get_id") and provider.get_id() == action_id:
			return provider
	return null

func _on_close_pressed() -> void:
	hide()
