@tool
extends Control

var editor_interface: EditorInterface
var registry: Node
var generator
var current_scene_name: String = ""

# Scene preloads - GDevelop-style event rows
const EVENT_ROW_SCENE = preload("res://addons/flowkit/ui/workspace/event_row.tscn")

# UI References
@onready var blocks_container := $OuterVBox/ScrollContainer/MarginContainer/BlocksContainer
@onready var empty_label := $OuterVBox/ScrollContainer/MarginContainer/BlocksContainer/EmptyLabel
@onready var add_event_btn := $OuterVBox/BottomMargin/ButtonContainer/AddEventButton

# Modals
@onready var select_node_modal := $SelectNodeModal
@onready var select_event_modal := $SelectEventModal
@onready var select_condition_modal := $SelectConditionModal
@onready var select_action_modal := $SelectActionModal
@onready var expression_modal := $ExpressionModal

# Workflow state
var pending_block_type: String = ""  # "event", "condition", "action", "event_replace", etc.
var pending_node_path: String = ""
var pending_id: String = ""
var pending_target_row = null  # The event row being modified
var pending_target_item = null  # The specific condition/action item being edited
var selected_row = null  # Currently selected event row
var selected_item = null  # Currently selected condition/action item
var clipboard_events: Array = []  # Stores copied event data for paste

func _ready() -> void:
	_setup_ui()
	# Connect block_moved signal for autosave on drag-and-drop reorder
	if blocks_container.has_signal("block_moved"):
		blocks_container.block_moved.connect(_save_sheet)

func _setup_ui() -> void:
	"""Initialize UI state."""
	_show_empty_state()

func set_editor_interface(interface: EditorInterface) -> void:
	editor_interface = interface
	# Pass to modals (deferred in case they're not ready yet)
	if select_node_modal:
		select_node_modal.set_editor_interface(interface)
	if select_event_modal:
		select_event_modal.set_editor_interface(interface)
	if select_condition_modal:
		select_condition_modal.set_editor_interface(interface)
	if select_action_modal:
		select_action_modal.set_editor_interface(interface)
	if expression_modal:
		expression_modal.set_editor_interface(interface)
	else:
		# If modal isn't ready yet, defer it
		call_deferred("_set_expression_interface", interface)

func set_registry(reg: Node) -> void:
	registry = reg
	# Pass to modals (deferred in case they're not ready yet)
	if select_event_modal:
		select_event_modal.set_registry(reg)
	if select_condition_modal:
		select_condition_modal.set_registry(reg)
	if select_action_modal:
		select_action_modal.set_registry(reg)

func set_generator(gen) -> void:
	generator = gen

func _input(event: InputEvent) -> void:
	# Only handle key press (not echo/repeat)
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	
	# Safety: Only act if mouse is within our blocks area
	if not _is_mouse_in_blocks_area():
		return
	
	# Handle Delete key
	if event.keycode == KEY_DELETE:
		if selected_row and is_instance_valid(selected_row):
			_delete_selected_row()
	# Handle Ctrl+C (copy)
	elif event.keycode == KEY_C and event.ctrl_pressed:
		if selected_row and is_instance_valid(selected_row):
			_copy_selected_row()
	# Handle Ctrl+V (paste)
	elif event.keycode == KEY_V and event.ctrl_pressed:
		_paste_from_clipboard()

func _is_mouse_in_blocks_area() -> bool:
	"""Check if mouse is hovering over the blocks container."""
	var mouse_pos = get_global_mouse_position()
	return blocks_container.get_global_rect().has_point(mouse_pos)

func _delete_selected_row() -> void:
	"""Delete the currently selected event row."""
	var row_to_delete = selected_row
	
	# Clear selection first
	if row_to_delete.has_method("set_selected"):
		row_to_delete.set_selected(false)
	selected_row = null
	
	# Delete the row
	blocks_container.remove_child(row_to_delete)
	row_to_delete.queue_free()
	_save_sheet()

func _copy_selected_row() -> void:
	"""Copy selected event row to clipboard."""
	if not selected_row or not is_instance_valid(selected_row):
		return
	
	clipboard_events.clear()
	
	if selected_row.has_method("get_event_data"):
		var data = selected_row.get_event_data()
		if data:
			clipboard_events.append({
				"event_id": data.event_id,
				"target_node": data.target_node,
				"inputs": data.inputs.duplicate(),
				"conditions": _duplicate_conditions(data.conditions),
				"actions": _duplicate_actions(data.actions)
			})
	
	print("Copied %d event(s) to clipboard" % clipboard_events.size())

func _duplicate_conditions(conditions: Array) -> Array:
	var result = []
	for cond in conditions:
		result.append({
			"condition_id": cond.condition_id,
			"target_node": cond.target_node,
			"inputs": cond.inputs.duplicate(),
			"negated": cond.negated
		})
	return result

func _duplicate_actions(actions: Array) -> Array:
	var result = []
	for act in actions:
		result.append({
			"action_id": act.action_id,
			"target_node": act.target_node,
			"inputs": act.inputs.duplicate()
		})
	return result

func _paste_from_clipboard() -> void:
	"""Paste events from clipboard after selected row (or at end)."""
	if clipboard_events.is_empty():
		return
	
	# Calculate insert position
	var insert_idx = blocks_container.get_child_count()
	if selected_row and is_instance_valid(selected_row):
		insert_idx = selected_row.get_index() + 1
	
	# Create and insert event rows
	var first_new_row = null
	for event_data_dict in clipboard_events:
		var data = FKEventBlock.new()
		data.event_id = event_data_dict["event_id"]
		data.target_node = event_data_dict["target_node"]
		data.inputs = event_data_dict["inputs"].duplicate()
		data.conditions = [] as Array[FKEventCondition]
		data.actions = [] as Array[FKEventAction]
		
		# Restore conditions
		for cond_dict in event_data_dict["conditions"]:
			var cond = FKEventCondition.new()
			cond.condition_id = cond_dict["condition_id"]
			cond.target_node = cond_dict["target_node"]
			cond.inputs = cond_dict["inputs"].duplicate()
			cond.negated = cond_dict["negated"]
			data.conditions.append(cond)
		
		# Restore actions
		for act_dict in event_data_dict["actions"]:
			var act = FKEventAction.new()
			act.action_id = act_dict["action_id"]
			act.target_node = act_dict["target_node"]
			act.inputs = act_dict["inputs"].duplicate()
			data.actions.append(act)
		
		var new_row = _create_event_row(data)
		blocks_container.add_child(new_row)
		blocks_container.move_child(new_row, insert_idx)
		insert_idx += 1
		if not first_new_row:
			first_new_row = new_row
	
	_show_content_state()
	_save_sheet()
	
	# Select the first pasted row
	if first_new_row:
		_on_row_selected(first_new_row)
	
	print("Pasted %d event(s) from clipboard" % clipboard_events.size())
func _set_expression_interface(interface: EditorInterface) -> void:
	if expression_modal:
		expression_modal.set_editor_interface(interface)

func _process(_delta: float) -> void:
	if not editor_interface:
		return
	
	var scene_root = editor_interface.get_edited_scene_root()
	if not scene_root:
		if current_scene_name != "":
			current_scene_name = ""
			_clear_all_blocks()
			_show_empty_state()
		return
	
	var scene_path = scene_root.scene_file_path
	if scene_path == "":
		if current_scene_name != "":
			current_scene_name = ""
			_clear_all_blocks()
			_show_empty_state()
		return
	
	var scene_name = scene_path.get_file().get_basename()
	if scene_name != current_scene_name:
		current_scene_name = scene_name
		_load_scene_sheet()

# === Block Management ===

func _get_blocks() -> Array:
	"""Get all block nodes (excluding empty label)."""
	var blocks = []
	for child in blocks_container.get_children():
		if child != empty_label:
			blocks.append(child)
	return blocks

func _clear_all_blocks() -> void:
	"""Remove all blocks from the container."""
	for child in blocks_container.get_children():
		if child != empty_label:
			blocks_container.remove_child(child)
			child.queue_free()

func _show_empty_state() -> void:
	"""Show empty state UI (no scene loaded)."""
	empty_label.visible = true
	add_event_btn.visible = false

func _show_empty_blocks_state() -> void:
	"""Show state when scene is loaded but has no blocks."""
	empty_label.visible = false
	add_event_btn.visible = true

func _show_content_state() -> void:
	"""Show content state UI."""
	empty_label.visible = false
	add_event_btn.visible = true

# === File Operations ===

func _get_sheet_path() -> String:
	"""Get the file path for current scene's event sheet."""
	if current_scene_name == "":
		return ""
	return "res://addons/flowkit/saved/event_sheet/%s.tres" % current_scene_name

func _load_scene_sheet() -> void:
	"""Load event sheet for current scene."""
	_clear_all_blocks()
	
	var sheet_path = _get_sheet_path()
	if sheet_path == "" or not FileAccess.file_exists(sheet_path):
		_show_empty_blocks_state()
		return
	
	var sheet = ResourceLoader.load(sheet_path)
	if not (sheet is FKEventSheet):
		_show_empty_blocks_state()
		return
	
	_populate_from_sheet(sheet)
	_show_content_state()

func _populate_from_sheet(sheet: FKEventSheet) -> void:
	"""Create event rows from event sheet data (GDevelop-style)."""
	# Note: standalone_conditions are deprecated in GDevelop-style layout
	# but we still load them for backwards compatibility as event rows without events
	
	# Add events as event rows
	for event_data in sheet.events:
		var event_row = _create_event_row(event_data)
		blocks_container.add_child(event_row)

func _save_sheet() -> void:
	"""Generate and save event sheet from current blocks."""
	if current_scene_name == "":
		push_warning("No scene open to save event sheet.")
		return
	
	var sheet = _generate_sheet_from_blocks()
	
	var dir_path = "res://addons/flowkit/saved/event_sheet"
	DirAccess.make_dir_recursive_absolute(dir_path)
	
	var sheet_path = _get_sheet_path()
	var error = ResourceSaver.save(sheet, sheet_path)
	
	if error == OK:
		print("✓ Event sheet saved: ", sheet_path)
	else:
		push_error("Failed to save event sheet: ", error)

func _generate_sheet_from_blocks() -> FKEventSheet:
	"""Build event sheet from event rows (GDevelop-style)."""
	var sheet = FKEventSheet.new()
	var events: Array[FKEventBlock] = []
	var standalone_conditions: Array[FKEventCondition] = []
	
	for row in _get_blocks():
		if row.has_method("get_event_data"):
			var data = row.get_event_data()
			if data:
				# Create a clean copy of the event with its conditions and actions
				var event_copy = FKEventBlock.new()
				event_copy.event_id = data.event_id
				event_copy.target_node = data.target_node
				event_copy.inputs = data.inputs.duplicate()
				event_copy.conditions = [] as Array[FKEventCondition]
				event_copy.actions = [] as Array[FKEventAction]
				
				# Copy conditions
				for cond in data.conditions:
					var cond_copy = FKEventCondition.new()
					cond_copy.condition_id = cond.condition_id
					cond_copy.target_node = cond.target_node
					cond_copy.inputs = cond.inputs.duplicate()
					cond_copy.negated = cond.negated
					cond_copy.actions = [] as Array[FKEventAction]
					event_copy.conditions.append(cond_copy)
				
				# Copy actions
				for act in data.actions:
					var act_copy = FKEventAction.new()
					act_copy.action_id = act.action_id
					act_copy.target_node = act.target_node
					act_copy.inputs = act.inputs.duplicate()
					event_copy.actions.append(act_copy)
				
				events.append(event_copy)
	
	sheet.events = events
	sheet.standalone_conditions = standalone_conditions
	return sheet

func _new_sheet() -> void:
	"""Create new empty sheet."""
	if current_scene_name == "":
		push_warning("No scene open to create event sheet.")
		return
	
	_clear_all_blocks()
	_show_content_state()

# === Event Row Creation ===

func _create_event_row(data: FKEventBlock) -> Control:
	"""Create event row node from data (GDevelop-style)."""
	var row = EVENT_ROW_SCENE.instantiate()
	
	var copy = FKEventBlock.new()
	copy.event_id = data.event_id
	copy.target_node = data.target_node
	copy.inputs = data.inputs.duplicate()
	copy.conditions = [] as Array[FKEventCondition]
	copy.actions = [] as Array[FKEventAction]
	
	# Copy conditions
	for cond in data.conditions:
		var cond_copy = FKEventCondition.new()
		cond_copy.condition_id = cond.condition_id
		cond_copy.target_node = cond.target_node
		cond_copy.inputs = cond.inputs.duplicate()
		cond_copy.negated = cond.negated
		cond_copy.actions = [] as Array[FKEventAction]
		copy.conditions.append(cond_copy)
	
	# Copy actions
	for act in data.actions:
		var act_copy = FKEventAction.new()
		act_copy.action_id = act.action_id
		act_copy.target_node = act.target_node
		act_copy.inputs = act.inputs.duplicate()
		copy.actions.append(act_copy)
	
	row.set_event_data(copy)
	row.set_registry(registry)
	_connect_event_row_signals(row)
	return row

# === Signal Connections ===

func _connect_event_row_signals(row) -> void:
	row.insert_event_below_requested.connect(_on_row_insert_below.bind(row))
	row.replace_event_requested.connect(_on_row_replace.bind(row))
	row.delete_event_requested.connect(_on_row_delete.bind(row))
	row.edit_event_requested.connect(_on_row_edit.bind(row))
	row.add_condition_requested.connect(_on_row_add_condition.bind(row))
	row.add_action_requested.connect(_on_row_add_action.bind(row))
	row.selected.connect(_on_row_selected)

# === Menu Button Handlers ===

func _on_new_sheet() -> void:
	_new_sheet()

func _on_save_sheet() -> void:
	_save_sheet()

func _on_generate_providers() -> void:
	if not generator:
		print("[FlowKit] Generator not available")
		return
	
	print("[FlowKit] Starting provider generation...")
	
	var result = generator.generate_all()
	
	var message = "Generation complete!\n"
	message += "Actions: %d\n" % result.actions
	message += "Conditions: %d\n" % result.conditions
	message += "Events: %d\n" % result.events
	
	if result.errors.size() > 0:
		message += "\nErrors:\n"
		for error in result.errors:
			message += "- " + error + "\n"
	
	message += "\nRestart Godot editor to load new providers?"
	
	print(message)
	
	# Show confirmation dialog with restart option
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = message
	dialog.title = "FlowKit Generator"
	dialog.ok_button_text = "Restart Editor"
	dialog.cancel_button_text = "Not Now"
	add_child(dialog)
	dialog.popup_centered()
	
	dialog.confirmed.connect(func():
		# Restart the editor
		if editor_interface:
			editor_interface.restart_editor()
		dialog.queue_free()
	)
	
	dialog.canceled.connect(func():
		# Just reload registry without restart
		if registry:
			registry.load_all()
		dialog.queue_free()
	)

func _on_add_event_button_pressed() -> void:
	if not editor_interface:
		return
	_start_add_workflow("event")

func _on_row_selected(row) -> void:
	"""Handle row selection with visual feedback."""
	# Deselect previous row
	if selected_row and is_instance_valid(selected_row) and selected_row.has_method("set_selected"):
		selected_row.set_selected(false)
	
	# Select new row
	selected_row = row
	if selected_row and selected_row.has_method("set_selected"):
		selected_row.set_selected(true)

# === Workflow System ===

func _start_add_workflow(block_type: String, target_row = null) -> void:
	"""Start workflow to add a new block."""
	pending_block_type = block_type
	pending_target_row = target_row
	
	var scene_root = editor_interface.get_edited_scene_root()
	if not scene_root:
		return
	
	select_node_modal.set_editor_interface(editor_interface)
	select_node_modal.populate_from_scene(scene_root)
	select_node_modal.popup_centered()

func _on_node_selected(node_path: String, node_class: String) -> void:
	"""Node selected in workflow."""
	pending_node_path = node_path
	select_node_modal.hide()
	
	match pending_block_type:
		"event", "event_replace":
			select_event_modal.populate_events(node_path, node_class)
			select_event_modal.popup_centered()
		"condition", "condition_replace":
			select_condition_modal.populate_conditions(node_path, node_class)
			select_condition_modal.popup_centered()
		"action", "action_replace":
			select_action_modal.populate_actions(node_path, node_class)
			select_action_modal.popup_centered()

func _on_event_selected(node_path: String, event_id: String, inputs: Array) -> void:
	"""Event type selected."""
	pending_id = event_id
	select_event_modal.hide()
	
	if inputs.size() > 0:
		expression_modal.populate_inputs(node_path, event_id, inputs)
		expression_modal.popup_centered()
	else:
		if pending_block_type == "event_replace":
			_replace_event({})
		else:
			_finalize_event_creation({})

func _on_condition_selected(node_path: String, condition_id: String, inputs: Array) -> void:
	"""Condition type selected."""
	pending_id = condition_id
	select_condition_modal.hide()
	
	if inputs.size() > 0:
		expression_modal.populate_inputs(node_path, condition_id, inputs)
		expression_modal.popup_centered()
	else:
		if pending_block_type == "condition_replace":
			_replace_condition({})
		else:
			_finalize_condition_creation({})

func _on_action_selected(node_path: String, action_id: String, inputs: Array) -> void:
	"""Action type selected."""
	pending_id = action_id
	select_action_modal.hide()
	
	if inputs.size() > 0:
		expression_modal.populate_inputs(node_path, action_id, inputs)
		expression_modal.popup_centered()
	else:
		if pending_block_type == "action_replace":
			_replace_action({})
		else:
			_finalize_action_creation({})

func _on_expressions_confirmed(_node_path: String, _id: String, expressions: Dictionary) -> void:
	"""Expressions entered."""
	expression_modal.hide()
	
	match pending_block_type:
		"event":
			_finalize_event_creation(expressions)
		"condition":
			_finalize_condition_creation(expressions)
		"action":
			_finalize_action_creation(expressions)
		"event_edit":
			_update_event_inputs(expressions)
		"condition_edit":
			_update_condition_inputs(expressions)
		"action_edit":
			_update_action_inputs(expressions)
		"event_replace":
			_replace_event(expressions)
		"condition_replace":
			_replace_condition(expressions)
		"action_replace":
			_replace_action(expressions)

func _finalize_event_creation(inputs: Dictionary) -> void:
	"""Create and add event row (GDevelop-style)."""
	var data = FKEventBlock.new()
	data.event_id = pending_id
	data.target_node = pending_node_path
	data.inputs = inputs
	data.conditions = [] as Array[FKEventCondition]
	data.actions = [] as Array[FKEventAction]
	
	var row = _create_event_row(data)
	
	if pending_target_row:
		var insert_idx = pending_target_row.get_index() + 1
		blocks_container.add_child(row)
		blocks_container.move_child(row, insert_idx)
	else:
		blocks_container.add_child(row)
	
	_show_content_state()
	_reset_workflow()
	_save_sheet()

func _finalize_condition_creation(inputs: Dictionary) -> void:
	"""Add condition to the current event row."""
	var data = FKEventCondition.new()
	data.condition_id = pending_id
	data.target_node = pending_node_path
	data.inputs = inputs
	data.negated = false
	data.actions = [] as Array[FKEventAction]
	
	if pending_target_row and pending_target_row.has_method("add_condition"):
		pending_target_row.add_condition(data)
	
	_show_content_state()
	_reset_workflow()
	_save_sheet()

func _finalize_action_creation(inputs: Dictionary) -> void:
	"""Add action to the current event row."""
	var data = FKEventAction.new()
	data.action_id = pending_id
	data.target_node = pending_node_path
	data.inputs = inputs
	
	if pending_target_row and pending_target_row.has_method("add_action"):
		pending_target_row.add_action(data)
	
	_show_content_state()
	_reset_workflow()
	_save_sheet()

func _update_event_inputs(expressions: Dictionary) -> void:
	"""Update existing event row with new inputs."""
	if pending_target_row:
		var data = pending_target_row.get_event_data()
		if data:
			data.inputs = expressions
			pending_target_row.update_display()
	_reset_workflow()
	_save_sheet()

func _update_condition_inputs(expressions: Dictionary) -> void:
	"""Update existing condition item with new inputs."""
	if pending_target_item:
		var data = pending_target_item.get_condition_data()
		if data:
			data.inputs = expressions
			pending_target_item.update_display()
	_reset_workflow()
	_save_sheet()

func _update_action_inputs(expressions: Dictionary) -> void:
	"""Update existing action item with new inputs."""
	if pending_target_item:
		var data = pending_target_item.get_action_data()
		if data:
			data.inputs = expressions
			pending_target_item.update_display()
	_reset_workflow()
	_save_sheet()

func _replace_event(expressions: Dictionary) -> void:
	"""Replace existing event row with new type."""
	if not pending_target_row:
		_reset_workflow()
		return
	
	# Get old row's position and conditions/actions
	var old_data = pending_target_row.get_event_data()
	var old_index = pending_target_row.get_index()
	
	# Create new event data
	var new_data = FKEventBlock.new()
	new_data.event_id = pending_id
	new_data.target_node = pending_node_path
	new_data.inputs = expressions
	new_data.conditions = old_data.conditions if old_data else ([] as Array[FKEventCondition])
	new_data.actions = old_data.actions if old_data else ([] as Array[FKEventAction])
	
	# Create new row
	var new_row = _create_event_row(new_data)
	
	# Remove old row and insert new one at same position
	blocks_container.remove_child(pending_target_row)
	pending_target_row.queue_free()
	blocks_container.add_child(new_row)
	blocks_container.move_child(new_row, old_index)
	
	_reset_workflow()
	_save_sheet()

func _replace_condition(expressions: Dictionary) -> void:
	"""Replace condition is not used in GDevelop-style layout."""
	_reset_workflow()

func _replace_action(expressions: Dictionary) -> void:
	"""Replace action is not used in GDevelop-style layout."""
	_reset_workflow()

func _reset_workflow() -> void:
	"""Clear workflow state."""
	pending_block_type = ""
	pending_node_path = ""
	pending_id = ""
	pending_target_row = null
	pending_target_item = null

# === Event Row Handlers ===

func _on_row_insert_below(signal_row, bound_row) -> void:
	pending_target_row = bound_row
	_start_add_workflow("event", bound_row)

func _on_row_replace(signal_row, bound_row) -> void:
	pending_target_row = bound_row
	pending_block_type = "event_replace"
	
	# Get current node path from the row being replaced
	var data = bound_row.get_event_data()
	if data:
		pending_node_path = str(data.target_node)
	
	# Open node selector
	var scene_root = editor_interface.get_edited_scene_root()
	if not scene_root:
		return
	
	select_node_modal.set_editor_interface(editor_interface)
	select_node_modal.populate_from_scene(scene_root)
	select_node_modal.popup_centered()

func _on_row_delete(signal_row, bound_row) -> void:
	blocks_container.remove_child(bound_row)
	bound_row.queue_free()
	_save_sheet()

func _on_row_edit(signal_row, bound_row) -> void:
	var data = bound_row.get_event_data()
	if not data:
		return
	
	# Get event provider to check if it has inputs
	var provider_inputs = []
	if registry:
		for provider in registry.event_providers:
			if provider.has_method("get_id") and provider.get_id() == data.event_id:
				if provider.has_method("get_inputs"):
					provider_inputs = provider.get_inputs()
				break
	
	if provider_inputs.size() > 0:
		# Set up editing mode
		pending_target_row = bound_row
		pending_block_type = "event_edit"
		pending_id = data.event_id
		pending_node_path = str(data.target_node)
		
		# Open expression modal with current values
		expression_modal.populate_inputs(str(data.target_node), data.event_id, provider_inputs, data.inputs)
		expression_modal.popup_centered()
	else:
		print("Event has no inputs to edit")

func _on_row_add_condition(signal_row, bound_row) -> void:
	pending_target_row = bound_row
	_start_add_workflow("condition", bound_row)

func _on_row_add_action(signal_row, bound_row) -> void:
	pending_target_row = bound_row
	_start_add_workflow("action", bound_row)
