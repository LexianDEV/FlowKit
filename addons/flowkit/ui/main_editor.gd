@tool
extends Control
class_name FKMainEditor

var editor_interface: EditorInterface
var registry: Node
var generator
var current_scene_uid: int = 0

# Scene preloads - GDevelop-style event rows
const EVENT_ROW_SCENE = preload("res://addons/flowkit/ui/workspace/event_row_ui.tscn")
const COMMENT_SCENE = preload("res://addons/flowkit/ui/workspace/comment_ui.tscn")
const GROUP_SCENE = preload("res://addons/flowkit/ui/workspace/group_ui.tscn")

# UI References
@onready var scroll_container: ScrollContainer = $OuterVBox/ScrollContainer
@onready var blocks_container: BlockContainerUi = $OuterVBox/ScrollContainer/MarginContainer/BlocksContainer
@onready var empty_label: Label = $OuterVBox/ScrollContainer/MarginContainer/BlocksContainer/EmptyLabel
@onready var add_event_btn: Button = $OuterVBox/BottomMargin/ButtonContainer/AddEventButton
@onready var menu_bar: FKMenuBar = $"OuterVBox/TopMargin/TopBar/MenuBar"

# Drag spacer state
var drag_spacer_top: Control = null  # Temporary spacer at top during drag
var drag_spacer_bottom: Control = null  # Temporary spacer at bottom during drag
const DRAG_SPACER_HEIGHT := 50  # Height of temporary drop zone

# Modals
@onready var select_node_modal: FKSelectNodeModal = $SelectNodeModal
@onready var select_event_modal: FKSelectEventModal = $SelectEventModal
@onready var select_condition_modal: FKSelectConditionModal = $SelectConditionModal
@onready var select_action_modal: FKSelectActionModal = $SelectActionModal
@onready var expression_modal: FKExpressionEditorModal = $ExpressionModal

# Workflow state
var pending_block_type: String = ""  # "event", "condition", "action", "event_replace", "event_in_group", etc.
var pending_node_path: String = ""
var pending_id: String = ""
var pending_target_row = null  # The event row being modified
var pending_target_item = null  # The specific condition/action item being edited
var pending_target_group = null  # The group to add content to (for event_in_group workflow)
var pending_target_branch = null  # The branch item for branch sub-action workflows
var selected_row = null  # Currently selected event row
var selected_item = null  # Currently selected condition/action item

var undo_manager: FKUndoManager = FKUndoManager.new()
var clipboard := FKClipboardManager.new()

func _ready() -> void:
	_setup_ui()
	# Connect block_moved signals for autosave and undo state on drag-and-drop reorder
	blocks_container.before_block_moved.connect(_push_undo_state)
	blocks_container.block_moved.connect(_save_and_reload_sheet)

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

func _popup_centered_on_editor(popup: Window) -> void:
	"""Center popup on the same window as the editor, supporting multi-monitor setups."""
	# Use editor_interface to get the actual main editor window
	var editor_window: Window = null
	if editor_interface:
		editor_window = editor_interface.get_base_control().get_window()
	
	if not editor_window:
		# Fallback to default behavior if window not available
		popup.popup_centered()
		return
	
	# Get the editor window's position and size
	var window_pos: Vector2i = editor_window.position
	var window_size: Vector2i = editor_window.size
	
	# Get the popup's size
	var popup_size: Vector2i = popup.size
	
	# Calculate centered position within the editor window
	var centered_pos: Vector2i = window_pos + (window_size - popup_size) / 2
	
	# Ensure popup stays within editor window bounds (handle case where popup is larger than window)
	centered_pos.x = maxi(centered_pos.x, window_pos.x)
	centered_pos.y = maxi(centered_pos.y, window_pos.y)
	
	# Set the popup position and show it
	popup.position = centered_pos
	popup.popup()

func _input(event: InputEvent) -> void:
	# Handle mouse click to deselect when clicking outside selected elements
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		
		# Check if we have any selection (row or item)
		if selected_row or selected_item:
			# Deselect if click is outside all event rows
			if not _is_click_on_event_row(mouse_pos):
				_deselect_all()
	
	# Only handle key press (not echo/repeat)
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	
	# Handle Ctrl+Z (undo) and Ctrl+Shift+Z / Ctrl+Y (redo) when FlowKit panel is visible
	# This allows undo/redo to work even when keyboard navigating or mouse is outside
	if visible and (_is_mouse_in_editor_area() or _has_focus_in_subtree()):
		if event.keycode == KEY_Z and event.ctrl_pressed:
			if event.shift_pressed:
				_redo()
			else:
				_undo()
			get_viewport().set_input_as_handled()
			return
		elif event.keycode == KEY_Y and event.ctrl_pressed:
			_redo()
			get_viewport().set_input_as_handled()
			return
	
	# Safety: Only act if mouse is within our blocks area for other shortcuts
	if not _is_mouse_in_blocks_area():
		return
	
	# Check if a text editing control has focus - if so, don't intercept copy/paste
	var focused = get_viewport().gui_get_focus_owner()
	var is_editing_text = focused is TextEdit or focused is LineEdit
	
	# Handle Delete key
	if event.keycode == KEY_DELETE:
		if selected_item and is_instance_valid(selected_item):
			_delete_selected_item()
			get_viewport().set_input_as_handled()
		elif selected_row and is_instance_valid(selected_row):
			_delete_selected_row()
			get_viewport().set_input_as_handled()
	# Handle Ctrl+C (copy) - only if not editing text
	elif event.keycode == KEY_C and event.ctrl_pressed and not is_editing_text:
		if selected_item and is_instance_valid(selected_item):
			if selected_item and selected_item.has_method("get_action_data"):
				clipboard.copy_action(selected_item.get_action_data())
			elif selected_item and selected_item.has_method("get_condition_data"):
				clipboard.copy_condition(selected_item.get_condition_data())
	
			get_viewport().set_input_as_handled()
		elif selected_row and is_instance_valid(selected_row):
			if selected_row and selected_row.has_method("get_event_data"):
				clipboard.copy_event(selected_row.get_event_data())
			elif selected_row and selected_row.has_method("get_group_data"):
				clipboard.copy_group(selected_row.get_group_data())
			get_viewport().set_input_as_handled()
	# Handle Ctrl+V (paste) - only if not editing text
	elif event.keycode == KEY_V and event.ctrl_pressed and not is_editing_text:
		
		match clipboard.get_clipboard_type():
			"event":
				_paste_events()
			"action":
				_paste_actions()
			"condition":
				_paste_conditions()
			"group":
				_paste_group()
				
		get_viewport().set_input_as_handled()

func _paste_events() -> void:
	var new_events = clipboard.paste_event()
	if new_events.is_empty():
		return

	_push_undo_state()

	var insert_idx = blocks_container.get_child_count()
	if selected_row:
		insert_idx = selected_row.get_index() + 1

	var first_row = null
	for ev in new_events:
		var row = _create_event_row(ev)
		blocks_container.add_child(row)
		blocks_container.move_child(row, insert_idx)
		insert_idx += 1
		if first_row == null:
			first_row = row

	_save_sheet()

	if first_row:
		_on_row_selected(first_row)
		
func _find_parent_branch(node: Node) -> BranchItemUi:
	"""Find the branch_item that contains this node, or null if at top level."""
	var current = node.get_parent()
	while current:
		if current.has_method("add_branch_action"):
			return current
		if current.has_method("get_event_data"):
			return null  # Reached event_row, no branch parent
		current = current.get_parent()
	return null
	
func _paste_actions() -> void:
	var target_row = selected_row

	# If only an item is selected, find its parent row
	if not target_row and selected_item:
		target_row = _find_parent_event_row(selected_item)

	if not target_row:
		return

	var new_actions = clipboard.paste_action()
	if new_actions.is_empty():
		return

	_push_undo_state()

	# Check if pasting into a branch
	var target_branch = null
	if selected_item:
		target_branch = _find_parent_branch(selected_item)

	if target_branch:
		var branch_data = target_branch.get_action_data()
		for act in new_actions:
			branch_data.branch_actions.append(act)
		target_row.update_display()
		_save_sheet()
		_on_row_selected(target_row)
		return

	# Normal paste into event row
	var data = target_row.get_event_data()
	for act in new_actions:
		data.actions.append(act)

	target_row.update_display()
	_save_sheet()
	_on_row_selected(target_row)

func _paste_conditions() -> void:
	var target_row = selected_row

	# If only an item is selected, find its parent row
	if not target_row and selected_item:
		target_row = _find_parent_event_row(selected_item)

	if not target_row:
		return

	var new_conditions = clipboard.paste_condition()
	if new_conditions.is_empty():
		return

	_push_undo_state()

	var data = target_row.get_event_data()
	for cond in new_conditions:
		data.conditions.append(cond)

	target_row.update_display()
	_save_sheet()
	_on_row_selected(target_row)

func _paste_group() -> void:
	var new_group = clipboard.paste_group()
	if not new_group:
		return

	_push_undo_state()

	var target_group = null

	# Case 1: selected row *is* a group
	if selected_row and selected_row.has_method("get_group_data"):
		target_group = selected_row

	# Case 2: selected row is inside a group
	elif selected_row:
		var parent = selected_row.get_parent()
		while parent:
			if parent.has_method("get_group_data"):
				target_group = parent
				break
			parent = parent.get_parent()

	# Paste inside a group if we found one
	if target_group:
		if target_group.has_method("add_group_to_group"):
			target_group.add_group_to_group(new_group)
		else:
			# Fallback: append to children manually
			target_group.get_group_data().children.append({
				"type": "group",
				"data": new_group
			})
		target_group.update_display()
		_save_sheet()
		_on_row_selected(target_group)
		return

	# Otherwise paste at root level
	var group_node = _create_group_block(new_group)
	blocks_container.add_child(group_node)

	_save_sheet()
	_on_row_selected(group_node)
	
func _is_click_on_event_row(mouse_pos: Vector2) -> bool:
	"""Check if the mouse position is over any event row."""
	for block in _get_blocks():
		if block.get_global_rect().has_point(mouse_pos):
			return true
	return false

func _is_mouse_in_blocks_area() -> bool:
	"""Check if mouse is hovering over the blocks container."""
	var mouse_pos = get_global_mouse_position()
	return blocks_container.get_global_rect().has_point(mouse_pos)

func _is_mouse_in_editor_area() -> bool:
	"""Check if mouse is hovering over the FlowKit editor panel."""
	var mouse_pos = get_global_mouse_position()
	return get_global_rect().has_point(mouse_pos)

func _has_focus_in_subtree() -> bool:
	"""Check if any child control has focus."""
	var focused = get_viewport().gui_get_focus_owner()
	if focused == null:
		return false
	return focused == self or is_ancestor_of(focused)

# === Undo/Redo System ===

func _capture_sheet_state() -> Array:
	"""Capture current sheet state as serialized data."""
	var state: Array = []
	for block in _get_blocks():
		# Double-check the block is still valid and not queued for deletion
		if not is_instance_valid(block) or block.is_queued_for_deletion():
			continue
		
		if block.has_method("get_event_data"):
			var data = block.get_event_data()
			if data:
				state.append(_serialize_event_block(data))
		elif block.has_method("get_comment_data"):
			var data = block.get_comment_data()
			if data:
				state.append(_serialize_comment_block(data))
		elif block.has_method("get_group_data"):
			var data = block.get_group_data()
			if data:
				state.append(_serialize_group_block(data))
	return state

func _serialize_comment_block(data: FKCommentBlock) -> Dictionary:
	"""Serialize a comment block to a dictionary."""
	return {
		"type": "comment",
		"text": data.text
	}

func _serialize_event_block(data: FKEventBlock) -> Dictionary:
	"""Serialize an event block to a dictionary."""
	var result = {
		"type": "event",
		"block_id": data.block_id,
		"event_id": data.event_id,
		"target_node": str(data.target_node),
		"inputs": data.inputs.duplicate(),
		"conditions": [],
		"actions": []
	}
	
	for cond in data.conditions:
		result["conditions"].append({
			"condition_id": cond.condition_id,
			"target_node": str(cond.target_node),
			"inputs": cond.inputs.duplicate(),
			"negated": cond.negated
		})
	
	for act in data.actions:
		result["actions"].append(_serialize_action(act))
	
	return result

func _serialize_action(act: FKEventAction) -> Dictionary:
	"""Serialize an action (including branch data) to a dictionary."""
	var act_dict = {
		"action_id": act.action_id,
		"target_node": str(act.target_node),
		"inputs": act.inputs.duplicate(),
		"is_branch": act.is_branch,
		"branch_type": act.branch_type
	}
	if act.is_branch:
		if act.branch_condition:
			act_dict["branch_condition"] = {
				"condition_id": act.branch_condition.condition_id,
				"target_node": str(act.branch_condition.target_node),
				"inputs": act.branch_condition.inputs.duplicate(),
				"negated": act.branch_condition.negated
			}
		act_dict["branch_actions"] = []
		for sub_act in act.branch_actions:
			act_dict["branch_actions"].append(_serialize_action(sub_act))
	return act_dict

func _serialize_group_block(data: FKGroupBlock) -> Dictionary:
	"""Serialize a group block to a dictionary."""
	var result = {
		"type": "group",
		"title": data.title,
		"collapsed": data.collapsed,
		"color": data.color,
		"children": []
	}
	
	for child_dict in data.children:
		var child_type = child_dict.get("type", "")
		var child_data = child_dict.get("data")
		var children = result["children"]
		if child_type == "event" and child_data is FKEventBlock:
			children.append(_serialize_event_block(child_data))
		elif child_type == "comment" and child_data is FKCommentBlock:
			children.append(_serialize_comment_block(child_data))
		elif child_type == "group" and child_data is FKGroupBlock:
			children.append(_serialize_group_block(child_data))
	
	return result

func _push_undo_state() -> void:
	"""Push current state to undo manager before making changes."""
	var state := _capture_sheet_state()
	undo_manager.push_state(state)

func _clear_undo_history() -> void:
	"""Clear undo/redo history (called when switching scenes)."""
	undo_manager.clear()

func _undo() -> void:
	"""Undo the last action."""
	if not undo_manager.can_undo():
		return

	var current_state := _capture_sheet_state()
	var previous_state := undo_manager.undo(current_state)

	_restore_sheet_state(previous_state)
	_save_sheet()
	print("[FlowKit] Undo performed")
	
func _redo() -> void:
	"""Redo the last undone action."""
	if not undo_manager.can_redo():
		return

	var current_state := _capture_sheet_state()
	var next_state := undo_manager.redo(current_state)

	_restore_sheet_state(next_state)
	_save_sheet()
	print("[FlowKit] Redo performed")

func _restore_sheet_state(state: Array) -> void:
	"""Restore sheet to a previous state."""
	# Clear current blocks
	_clear_all_blocks()
	
	# Recreate blocks from state
	for item_dict in state:
		var item_type = item_dict.get("type", "event")
		if item_type == "comment":
			var data = _deserialize_comment_block(item_dict)
			var comment = _create_comment_block(data)
			blocks_container.add_child(comment)
		elif item_type == "group":
			var data = _deserialize_group_block(item_dict)
			var group = _create_group_block(data)
			blocks_container.add_child(group)
		else:
			var data = _deserialize_event_block(item_dict)
			var row = _create_event_row(data)
			blocks_container.add_child(row)
	
	# Update UI state
	if _get_blocks().size() > 0:
		_show_content_state()
	else:
		_show_empty_blocks_state()

func _deserialize_comment_block(dict: Dictionary) -> FKCommentBlock:
	"""Deserialize a dictionary to a comment block."""
	var data = FKCommentBlock.new()
	data.text = dict.get("text", "")
	return data

func _deserialize_event_block(dict: Dictionary) -> FKEventBlock:
	"""Deserialize a dictionary to an event block."""
	var block_id = dict.get("block_id", "")
	var event_id = dict.get("event_id", "")
	var target_node = NodePath(dict.get("target_node", ""))
	var data = FKEventBlock.new(block_id, event_id, target_node)
	data.inputs = dict.get("inputs", {}).duplicate()
	data.conditions = [] as Array[FKEventCondition]
	data.actions = [] as Array[FKEventAction]
	
	for cond_dict in dict.get("conditions", []):
		var cond = FKEventCondition.new()
		cond.condition_id = cond_dict.get("condition_id", "")
		cond.target_node = NodePath(cond_dict.get("target_node", ""))
		cond.inputs = cond_dict.get("inputs", {}).duplicate()
		cond.negated = cond_dict.get("negated", false)
		cond.actions = [] as Array[FKEventAction]
		data.conditions.append(cond)
	
	for act_dict in dict.get("actions", []):
		var act = _deserialize_action(act_dict)
		data.actions.append(act)
	
	return data

func _deserialize_action(act_dict: Dictionary) -> FKEventAction:
	"""Deserialize a dictionary to an action (including branch data)."""
	var act = FKEventAction.new()
	act.action_id = act_dict.get("action_id", "")
	act.target_node = NodePath(act_dict.get("target_node", ""))
	act.inputs = act_dict.get("inputs", {}).duplicate()
	act.is_branch = act_dict.get("is_branch", false)
	act.branch_type = act_dict.get("branch_type", "")
	if act.is_branch:
		var cond_dict = act_dict.get("branch_condition", null)
		if cond_dict:
			var cond = FKEventCondition.new()
			cond.condition_id = cond_dict.get("condition_id", "")
			cond.target_node = NodePath(cond_dict.get("target_node", ""))
			cond.inputs = cond_dict.get("inputs", {}).duplicate()
			cond.negated = cond_dict.get("negated", false)
			cond.actions = [] as Array[FKEventAction]
			act.branch_condition = cond
		act.branch_actions = [] as Array[FKEventAction]
		for sub_dict in act_dict.get("branch_actions", []):
			act.branch_actions.append(_deserialize_action(sub_dict))
	return act

func _deserialize_group_block(dict: Dictionary) -> FKGroupBlock:
	"""Deserialize a dictionary to a group block."""
	var data = FKGroupBlock.new()
	data.title = dict.get("title", "Group")
	data.collapsed = dict.get("collapsed", false)
	data.color = dict.get("color", Color(0.25, 0.22, 0.35, 1.0))
	data.children = []
	
	for child_dict in dict.get("children", []):
		var child_type = child_dict.get("type", "event")
		if child_type == "event":
			var child_data = _deserialize_event_block(child_dict)
			data.children.append({"type": "event", "data": child_data})
		elif child_type == "comment":
			var child_data = _deserialize_comment_block(child_dict)
			data.children.append({"type": "comment", "data": child_data})
		elif child_type == "group":
			var child_data = _deserialize_group_block(child_dict)
			data.children.append({"type": "group", "data": child_data})
	
	return data

func _delete_selected_row() -> void:
	"""Delete the currently selected event row."""
	if not selected_row or not is_instance_valid(selected_row):
		return
	
	# Push undo state before deleting
	_push_undo_state()
	
	var row_to_delete = selected_row
	
	# Clear selection first
	if row_to_delete.has_method("set_selected"):
		row_to_delete.set_selected(false)
	selected_row = null
	
	# Check if row is a direct child of blocks_container or inside a group
	if row_to_delete.get_parent() == blocks_container:
		# Direct child of blocks_container - delete it
		blocks_container.remove_child(row_to_delete)
		row_to_delete.queue_free()
		_save_sheet()
	else:
		# Row is inside a group - emit the appropriate delete signal
		if row_to_delete.has_method("get_group_data"):
			# It's a nested group
			row_to_delete.delete_requested.emit()
		elif row_to_delete.has_method("get_comment_data"):
			# It's a comment
			row_to_delete.delete_requested.emit()
		else:
			# It's an event row
			row_to_delete.delete_event_requested.emit(row_to_delete)

func _delete_selected_item() -> void:
	"""Delete the currently selected condition or action item."""
	if not selected_item or not is_instance_valid(selected_item):
		return
	
	var item_to_delete = selected_item
	
	# Find the parent event_row
	var parent_row = _find_parent_event_row(item_to_delete)
	if not parent_row:
		return
	
	# Push undo state before deleting
	_push_undo_state()
	
	# Check if it's a condition or action
	if item_to_delete.has_method("get_condition_data"):
		var cond_data = item_to_delete.get_condition_data()
		var event_data = parent_row.get_event_data()
		if cond_data and event_data:
			var idx = event_data.conditions.find(cond_data)
			if idx >= 0:
				event_data.conditions.remove_at(idx)
	elif item_to_delete.has_method("get_action_data"):
		var act_data = item_to_delete.get_action_data()
		var event_data = parent_row.get_event_data()
		if act_data and event_data:
			var idx = event_data.actions.find(act_data)
			if idx >= 0:
				event_data.actions.remove_at(idx)
			else:
				# Action might be inside a branch - search recursively
				_recursive_remove_action_from_list(event_data.actions, act_data)
	
	# Clear selection
	_deselect_item()
	
	# Update display and save
	parent_row.update_display()
	_save_sheet()

func _recursive_remove_action_from_list(actions: Array, target_action) -> bool:
	"""Recursively search and remove an action from actions array and branch sub-actions."""
	var idx = actions.find(target_action)
	if idx >= 0:
		actions.remove_at(idx)
		return true
	for act in actions:
		if act.is_branch and _recursive_remove_action_from_list(act.branch_actions, target_action):
			return true
	return false

func _find_parent_event_row(node: Node) -> FKEventRowUi:
	"""Find the event_row that contains this node."""
	var current = node.get_parent()
	while current:
		if current.has_method("get_event_data"):
			return current
		current = current.get_parent()
	return null

func _set_expression_interface(interface: EditorInterface) -> void:
	if expression_modal:
		expression_modal.set_editor_interface(interface)

func _process(delta: float) -> void:
	# Handle drag spacers - add temporary space only when needed
	if get_viewport().gui_is_dragging():
		if scroll_container and blocks_container:
			var mouse_pos = scroll_container.get_local_mouse_position()
			var scroll_rect = scroll_container.get_rect()
			var blocks_size = blocks_container.size
			var scroll_pos = scroll_container.scroll_vertical
			
			# Check if we need top spacer (dragging near top)
			# Always show if near top, regardless of scroll position
			var need_top_spacer = mouse_pos.y < DRAG_SPACER_HEIGHT
			
			# Check if we need bottom spacer (dragging near bottom AND not enough space below)
			var visible_bottom = scroll_pos + scroll_rect.size.y
			var content_bottom = blocks_size.y
			var need_bottom_spacer = mouse_pos.y > scroll_rect.size.y - DRAG_SPACER_HEIGHT and visible_bottom >= content_bottom - DRAG_SPACER_HEIGHT
			
			# Create/remove top spacer
			if need_top_spacer and not drag_spacer_top:
				drag_spacer_top = Control.new()
				drag_spacer_top.custom_minimum_size = Vector2(0, DRAG_SPACER_HEIGHT)
				drag_spacer_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
				blocks_container.add_child(drag_spacer_top)
				blocks_container.move_child(drag_spacer_top, 0)
			elif not need_top_spacer and drag_spacer_top and is_instance_valid(drag_spacer_top):
				drag_spacer_top.queue_free()
				drag_spacer_top = null
			
			# Create/remove bottom spacer
			if need_bottom_spacer and not drag_spacer_bottom:
				drag_spacer_bottom = Control.new()
				drag_spacer_bottom.custom_minimum_size = Vector2(0, DRAG_SPACER_HEIGHT)
				drag_spacer_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
				blocks_container.add_child(drag_spacer_bottom)
				blocks_container.move_child(drag_spacer_bottom, blocks_container.get_child_count() - 1)
			elif not need_bottom_spacer and drag_spacer_bottom and is_instance_valid(drag_spacer_bottom):
				drag_spacer_bottom.queue_free()
				drag_spacer_bottom = null
	else:
		if drag_spacer_top and is_instance_valid(drag_spacer_top):
			drag_spacer_top.queue_free()
			drag_spacer_top = null
		if drag_spacer_bottom and is_instance_valid(drag_spacer_bottom):
			drag_spacer_bottom.queue_free()
			drag_spacer_bottom = null
	
	# Handle scene detection
	if not editor_interface:
		return

	var scene_root = editor_interface.get_edited_scene_root()
	if not scene_root:
		if current_scene_uid != 0:
			current_scene_uid = 0
			_clear_all_blocks()
			_clear_undo_history()
			_show_empty_state()
		return

	var scene_path = scene_root.scene_file_path
	if scene_path == "":
		if current_scene_uid != 0:
			current_scene_uid = 0
			_clear_all_blocks()
			_clear_undo_history()
			_show_empty_state()
		return

	var scene_uid = ResourceLoader.get_resource_uid(scene_path)
	if scene_uid != current_scene_uid:
		current_scene_uid = scene_uid
		_clear_undo_history()
		_load_scene_sheet()

# === Block Management ===

func _get_blocks() -> Array:
	"""Get all block nodes (excluding empty label and nodes queued for deletion)."""
	var blocks = []
	for child in blocks_container.get_children():
		if child != empty_label and is_instance_valid(child) and not child.is_queued_for_deletion():
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
	if current_scene_uid == 0:
		return ""
	return "res://addons/flowkit/saved/event_sheet/%d.tres" % current_scene_uid

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
	"""Create event rows and comments from event sheet data (GDevelop-style)."""
	# If we have item_order, use it to restore the correct order
	if sheet.item_order.size() > 0:
		for item in sheet.item_order:
			var item_type = item.get("type", "")
			var item_index = item.get("index", 0)
			
			if item_type == "event" and item_index < sheet.events.size():
				var event_row = _create_event_row(sheet.events[item_index])
				blocks_container.add_child(event_row)
			elif item_type == "comment" and item_index < sheet.comments.size():
				var comment = _create_comment_block(sheet.comments[item_index])
				blocks_container.add_child(comment)
			elif item_type == "group" and item_index < sheet.groups.size():
				var group = _create_group_block(sheet.groups[item_index])
				blocks_container.add_child(group)
	else:
		# Fallback: load events only (backwards compatibility)
		for event_data in sheet.events:
			var event_row = _create_event_row(event_data)
			blocks_container.add_child(event_row)

func _save_sheet() -> void:
	"""Generate and save event sheet from current blocks."""
	if current_scene_uid == 0:
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

func _save_and_reload_sheet() -> void:
	"""Save sheet and reload UI to ensure visual/data sync (for drag-drop operations)."""
	_save_sheet()
	_load_scene_sheet()

func _generate_sheet_from_blocks() -> FKEventSheet:
	"""Build event sheet from event rows, comments, and groups (GDevelop-style)."""
	var sheet = FKEventSheet.new()
	var events: Array[FKEventBlock] = []
	var comments: Array[FKCommentBlock] = []
	var groups: Array[FKGroupBlock] = []
	var item_order: Array[Dictionary] = []
	var standalone_conditions: Array[FKEventCondition] = []
	
	for block in _get_blocks():
		# Skip invalid or deleted blocks
		if not is_instance_valid(block) or block.is_queued_for_deletion():
			continue
		
		if block.has_method("get_event_data"):
			var data = block.get_event_data()
			if data:
				var event_copy = _copy_event_block(data)
				item_order.append({"type": "event", "index": events.size()})
				events.append(event_copy)
		
		elif block.has_method("get_comment_data"):
			var data = block.get_comment_data()
			if data:
				var comment_copy = FKCommentBlock.new()
				comment_copy.text = data.text
				item_order.append({"type": "comment", "index": comments.size()})
				comments.append(comment_copy)
		
		elif block.has_method("get_group_data"):
			var data = block.get_group_data()
			if data:
				var group_copy = _copy_group_block(data)
				item_order.append({"type": "group", "index": groups.size()})
				groups.append(group_copy)
	
	sheet.events = events
	sheet.comments = comments
	sheet.groups = groups
	sheet.item_order = item_order
	sheet.standalone_conditions = standalone_conditions
	return sheet

func _copy_event_block(data: FKEventBlock) -> FKEventBlock:
	"""Create a clean copy of an event block."""
	var event_copy = FKEventBlock.new(data.block_id, data.event_id, data.target_node)
	event_copy.inputs = data.inputs.duplicate()
	event_copy.conditions = [] as Array[FKEventCondition]
	event_copy.actions = [] as Array[FKEventAction]
	
	for cond in data.conditions:
		var cond_copy = FKEventCondition.new()
		cond_copy.condition_id = cond.condition_id
		cond_copy.target_node = cond.target_node
		cond_copy.inputs = cond.inputs.duplicate()
		cond_copy.negated = cond.negated
		cond_copy.actions = [] as Array[FKEventAction]
		event_copy.conditions.append(cond_copy)
	
	for act in data.actions:
		var act_copy = _copy_action(act)
		event_copy.actions.append(act_copy)
	
	return event_copy

func _copy_action(act: FKEventAction) -> FKEventAction:
	"""Create a clean copy of an action, including branch data."""
	var act_copy = FKEventAction.new()
	act_copy.action_id = act.action_id
	act_copy.target_node = act.target_node
	act_copy.inputs = act.inputs.duplicate()
	act_copy.is_branch = act.is_branch
	act_copy.branch_type = act.branch_type
	
	if act.branch_condition:
		var cond_copy = FKEventCondition.new()
		cond_copy.condition_id = act.branch_condition.condition_id
		cond_copy.target_node = act.branch_condition.target_node
		cond_copy.inputs = act.branch_condition.inputs.duplicate()
		cond_copy.negated = act.branch_condition.negated
		cond_copy.actions = [] as Array[FKEventAction]
		act_copy.branch_condition = cond_copy
	
	act_copy.branch_actions = [] as Array[FKEventAction]
	for sub_act in act.branch_actions:
		act_copy.branch_actions.append(_copy_action(sub_act))
	
	return act_copy

func _copy_group_block(data: FKGroupBlock) -> FKGroupBlock:
	"""Create a clean copy of a group block with all children."""
	var group_copy = FKGroupBlock.new()
	group_copy.title = data.title
	group_copy.collapsed = data.collapsed
	group_copy.color = data.color
	group_copy.children = []
	
	for child_dict in data.children:
		var child_type = child_dict.get("type", "")
		var child_data = child_dict.get("data")
		
		if child_type == "event" and child_data is FKEventBlock:
			group_copy.children.append({"type": "event", "data": _copy_event_block(child_data)})
		elif child_type == "comment" and child_data is FKCommentBlock:
			var comment_copy = FKCommentBlock.new()
			comment_copy.text = child_data.text
			group_copy.children.append({"type": "comment", "data": comment_copy})
		elif child_type == "group" and child_data is FKGroupBlock:
			group_copy.children.append({"type": "group", "data": _copy_group_block(child_data)})
	
	return group_copy

func _new_sheet() -> void:
	"""Create new empty sheet."""
	if current_scene_uid == 0:
		push_warning("No scene open to create event sheet.")
		return
	
	_clear_all_blocks()
	_show_content_state()

# === Event Row Creation ===

func _create_event_row(data: FKEventBlock) -> Control:
	"""Create event row node from data (GDevelop-style)."""
	var row = EVENT_ROW_SCENE.instantiate()
	
	var copy = _copy_event_block(data)
	
	row.set_event_data(copy)
	row.set_registry(registry)
	_connect_event_row_signals(row)
	return row

func _create_comment_block(data: FKCommentBlock) -> Control:
	"""Create comment block node from data."""
	var comment = COMMENT_SCENE.instantiate()
	
	var copy = FKCommentBlock.new()
	copy.text = data.text
	
	comment.set_comment_data(copy)
	_connect_comment_signals(comment)
	return comment

func _connect_comment_signals(comment) -> void:
	comment.selected.connect(_on_comment_selected)
	comment.delete_requested.connect(_on_comment_delete.bind(comment))
	comment.data_changed.connect(_save_sheet)
	comment.insert_comment_above_requested.connect(_on_comment_insert_above.bind(comment))
	comment.insert_comment_below_requested.connect(_on_comment_insert_below.bind(comment))
	comment.insert_event_above_requested.connect(_on_comment_insert_event_above.bind(comment))
	comment.insert_event_below_requested.connect(_on_comment_insert_event_below.bind(comment))

func _create_group_block(data: FKGroupBlock) -> Control:
	"""Create group block node from data."""
	var group = GROUP_SCENE.instantiate()
	
	var copy = FKGroupBlock.new()
	copy.title = data.title
	copy.collapsed = data.collapsed
	copy.color = data.color
	copy.children = []
	
	# Deep copy children
	for child_dict in data.children:
		var child_type = child_dict.get("type", "")
		var child_data = child_dict.get("data")
		
		if child_type == "event" and child_data is FKEventBlock:
			copy.children.append({"type": "event", "data": _copy_event_block(child_data)})
		elif child_type == "comment" and child_data is FKCommentBlock:
			var comment_copy = FKCommentBlock.new()
			comment_copy.text = child_data.text
			copy.children.append({"type": "comment", "data": comment_copy})
		elif child_type == "group" and child_data is FKGroupBlock:
			copy.children.append({"type": "group", "data": _copy_group_block(child_data)})
	
	group.set_group_data(copy)
	group.set_registry(registry)
	_connect_group_signals(group)
	return group

func _connect_group_signals(group) -> void:
	group.selected.connect(_on_group_selected)
	group.delete_requested.connect(_on_group_delete.bind(group))
	group.data_changed.connect(_save_sheet)
	group.before_data_changed.connect(_push_undo_state)
	group.add_event_requested.connect(_on_group_add_event_requested)
	group.add_comment_requested.connect(_on_group_add_comment_requested)
	# Connect edit signals from children inside groups
	group.condition_edit_requested.connect(_on_condition_edit_requested)
	group.action_edit_requested.connect(_on_action_edit_requested)
	group.insert_event_below_requested.connect(func(row): _on_row_insert_below(row, row))
	group.insert_event_above_requested.connect(func(target): _on_comment_insert_event_above(target, target))
	group.insert_comment_below_requested.connect(func(row): _on_row_insert_comment_below(row, row))
	group.insert_comment_above_requested.connect(func(target): _on_comment_insert_above(target, target))
	group.replace_event_requested.connect(func(row): _on_row_replace(row, row))
	group.edit_event_requested.connect(func(row): _on_row_edit(row, row))
	group.add_condition_requested.connect(func(row): _on_row_add_condition(row, row))
	group.add_action_requested.connect(func(row): _on_row_add_action(row, row))
	group.condition_dropped.connect(_on_condition_dropped)
	group.action_dropped.connect(_on_action_dropped)
	# Branch signals from groups
	if group.has_signal("add_branch_requested"):
		group.add_branch_requested.connect(func(row): _on_row_add_branch(row, row))
	if group.has_signal("add_elseif_requested"):
		group.add_elseif_requested.connect(_on_branch_add_elseif)
	if group.has_signal("add_else_requested"):
		group.add_else_requested.connect(_on_branch_add_else)
	if group.has_signal("branch_condition_edit_requested"):
		group.branch_condition_edit_requested.connect(_on_branch_condition_edit)
	if group.has_signal("branch_action_add_requested"):
		group.branch_action_add_requested.connect(_on_branch_action_add)
	if group.has_signal("branch_action_edit_requested"):
		group.branch_action_edit_requested.connect(_on_branch_action_edit)
	if group.has_signal("nested_branch_add_requested"):
		group.nested_branch_add_requested.connect(_on_nested_branch_add)

func _on_group_add_event_requested(group_node) -> void:
	"""Handle request to add an event inside a group."""
	pending_target_group = group_node
	_start_add_workflow("event_in_group")

func _on_group_add_comment_requested(group_node) -> void:
	"""Handle request to add a comment inside a group (already handled in group_ui.gd)."""
	pass

func _on_group_selected(node) -> void:
	"""Handle selection from group (could be the group itself or a child)."""
	# Check if it's a condition or action item
	if node.has_method("get_condition_data"):
		_on_condition_selected_in_row(node)
		return
	
	if node.has_method("get_action_data"):
		_on_action_selected_in_row(node)
		return
	
	# Check if it's an event_row inside the group
	if node.has_method("get_event_data"):
		_on_row_selected(node)
		return
	
	# Check if it's a comment inside the group
	if node.has_method("get_comment_data") and not node.has_method("get_group_data"):
		_on_comment_selected(node)
		return
	
	# It's a group (or nested group)
	_deselect_item()
	
	if selected_row and is_instance_valid(selected_row) and selected_row.has_method("set_selected"):
		selected_row.set_selected(false)
	
	selected_row = node
	if selected_row and selected_row.has_method("set_selected"):
		selected_row.set_selected(true)

func _on_group_delete(group) -> void:
	"""Delete a group block."""
	_push_undo_state()
	
	if selected_row == group:
		selected_row = null
	
	blocks_container.remove_child(group)
	group.queue_free()
	_save_sheet()



func _on_add_group_button_pressed() -> void:
	"""Add a new group block."""
	_push_undo_state()
	
	var data = FKGroupBlock.new()
	data.title = "New Group"
	data.collapsed = false
	data.color = Color(0.25, 0.22, 0.35, 1.0)
	data.children = []
	
	var group = _create_group_block(data)
	blocks_container.add_child(group)
	
	_show_content_state()
	_save_sheet()

# === Signal Connections ===

func _connect_event_row_signals(row) -> void:
	row.insert_event_below_requested.connect(_on_row_insert_below.bind(row))
	row.insert_comment_below_requested.connect(_on_row_insert_comment_below.bind(row))
	row.replace_event_requested.connect(_on_row_replace.bind(row))
	row.delete_event_requested.connect(_on_row_delete.bind(row))
	row.edit_event_requested.connect(_on_row_edit.bind(row))
	row.add_condition_requested.connect(_on_row_add_condition.bind(row))
	row.add_action_requested.connect(_on_row_add_action.bind(row))
	row.selected.connect(_on_row_selected)
	row.condition_selected.connect(_on_condition_selected_in_row)
	row.action_selected.connect(_on_action_selected_in_row)
	row.condition_edit_requested.connect(_on_condition_edit_requested.bind(row))
	row.action_edit_requested.connect(_on_action_edit_requested.bind(row))
	row.condition_dropped.connect(_on_condition_dropped)
	row.action_dropped.connect(_on_action_dropped)
	row.data_changed.connect(_save_sheet)
	row.before_data_changed.connect(_push_undo_state)
	# Branch signals
	row.add_branch_requested.connect(_on_row_add_branch.bind(row))
	row.add_elseif_requested.connect(_on_branch_add_elseif)
	row.add_else_requested.connect(_on_branch_add_else)
	row.branch_condition_edit_requested.connect(_on_branch_condition_edit)
	row.branch_action_add_requested.connect(_on_branch_action_add)
	row.branch_action_edit_requested.connect(_on_branch_action_edit)
	row.nested_branch_add_requested.connect(_on_nested_branch_add)

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
	_popup_centered_on_editor(dialog)
	
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

func _on_generate_manifest() -> void:
	if not generator:
		print("[FlowKit] Generator not available")
		return
	
	print("[FlowKit] Generating provider manifest for export...")
	
	var result = generator.generate_manifest()
	
	var message = "Manifest generated!\n"
	message += "Actions: %d\n" % result.actions
	message += "Conditions: %d\n" % result.conditions
	message += "Events: %d\n" % result.events
	message += "Behaviors: %d\n" % result.behaviors
	
	if result.errors.size() > 0:
		message += "\nErrors:\n"
		for error in result.errors:
			message += "- " + error + "\n"
	else:
		message += "\nThe manifest has been saved and will be used\n"
		message += "in exported builds to load providers."
	
	print(message)
	
	# Show info dialog
	var dialog = AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = "FlowKit Manifest Generator"
	dialog.ok_button_text = "OK"
	add_child(dialog)
	_popup_centered_on_editor(dialog)
	
	dialog.confirmed.connect(func():
		dialog.queue_free()
	)

func _on_add_event_button_pressed() -> void:
	if not editor_interface:
		return
	_start_add_workflow("event")

func _on_add_comment_button_pressed() -> void:
	"""Add a new comment block."""
	_push_undo_state()
	
	var data = FKCommentBlock.new()
	data.text = ""
	
	var comment = _create_comment_block(data)
	blocks_container.add_child(comment)
	
	_show_content_state()
	_save_sheet()

func _on_row_selected(row) -> void:
	"""Handle row selection with visual feedback."""
	# Deselect previous item (condition/action)
	_deselect_item()
	
	# Deselect previous row
	if selected_row and is_instance_valid(selected_row) and selected_row.has_method("set_selected"):
		selected_row.set_selected(false)
	
	# Select new row
	selected_row = row
	if selected_row and selected_row.has_method("set_selected"):
		selected_row.set_selected(true)

func _on_comment_selected(comment_node) -> void:
	"""Handle comment block selection."""
	_deselect_item()
	
	if selected_row and is_instance_valid(selected_row) and selected_row.has_method("set_selected"):
		selected_row.set_selected(false)
	
	selected_row = comment_node
	if selected_row and selected_row.has_method("set_selected"):
		selected_row.set_selected(true)

func _on_comment_delete(comment) -> void:
	"""Delete a comment block."""
	_push_undo_state()
	
	if selected_row == comment:
		selected_row = null
	
	blocks_container.remove_child(comment)
	comment.queue_free()
	_save_sheet()

func _on_comment_insert_above(signal_node, bound_comment) -> void:
	"""Insert a new comment above the specified comment."""
	_insert_comment_relative_to(bound_comment, 0)

func _on_comment_insert_below(signal_node, bound_comment) -> void:
	"""Insert a new comment below the specified comment."""
	_insert_comment_relative_to(bound_comment, 1)

func _on_comment_insert_event_above(signal_node, bound_comment) -> void:
	"""Insert a new event above the specified comment."""
	pending_target_row = bound_comment
	_start_add_workflow("event_above_target", bound_comment)

func _on_comment_insert_event_below(signal_node, bound_comment) -> void:
	"""Insert a new event below the specified comment."""
	pending_target_row = bound_comment
	_start_add_workflow("event", bound_comment)

func _on_row_insert_comment_below(signal_row, bound_row) -> void:
	"""Insert a new comment below the specified event row."""
	_insert_comment_relative_to(bound_row, 1)

func _insert_comment_relative_to(target_block, offset: int) -> void:
	"""Insert a new comment relative to a target block (0 = above, 1 = below)."""
	_push_undo_state()
	
	var data = FKCommentBlock.new()
	data.text = ""
	
	var comment = _create_comment_block(data)
	blocks_container.add_child(comment)
	
	# Calculate insert position
	var insert_idx = target_block.get_index() + offset
	blocks_container.move_child(comment, insert_idx)
	
	_show_content_state()
	_save_sheet()

func _on_condition_selected_in_row(condition_node) -> void:
	"""Handle condition item selection."""
	# Deselect previous row
	if selected_row and is_instance_valid(selected_row) and selected_row.has_method("set_selected"):
		selected_row.set_selected(false)
	selected_row = null
	
	# Deselect previous item
	_deselect_item()
	
	# Select new item
	selected_item = condition_node
	if selected_item and selected_item.has_method("set_selected"):
		selected_item.set_selected(true)

func _on_action_selected_in_row(action_node) -> void:
	"""Handle action item selection."""
	# Deselect previous row
	if selected_row and is_instance_valid(selected_row) and selected_row.has_method("set_selected"):
		selected_row.set_selected(false)
	selected_row = null
	
	# Deselect previous item
	_deselect_item()
	
	# Select new item
	selected_item = action_node
	if selected_item and selected_item.has_method("set_selected"):
		selected_item.set_selected(true)

func _deselect_item() -> void:
	"""Deselect current condition/action item."""
	if selected_item and is_instance_valid(selected_item) and selected_item.has_method("set_selected"):
		selected_item.set_selected(false)
	selected_item = null

func _deselect_all() -> void:
	"""Deselect all rows and items."""
	if selected_row and is_instance_valid(selected_row) and selected_row.has_method("set_selected"):
		selected_row.set_selected(false)
	selected_row = null
	_deselect_item()

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
	_popup_centered_on_editor(select_node_modal)

func _on_node_selected(node_path: String, node_class: String) -> void:
	"""Node selected in workflow."""
	pending_node_path = node_path
	select_node_modal.hide()
	
	match pending_block_type:
		"event", "event_replace", "event_in_group":
			select_event_modal.populate_events(node_path, node_class)
			_popup_centered_on_editor(select_event_modal)
		"condition", "condition_replace":
			select_condition_modal.populate_conditions(node_path, node_class)
			_popup_centered_on_editor(select_condition_modal)
		"action", "action_replace":
			select_action_modal.populate_actions(node_path, node_class)
			_popup_centered_on_editor(select_action_modal)
		"branch_condition", "branch_condition_edit", "elseif_condition":
			select_condition_modal.populate_conditions(node_path, node_class)
			_popup_centered_on_editor(select_condition_modal)
		"branch_action":
			select_action_modal.populate_actions(node_path, node_class)
			_popup_centered_on_editor(select_action_modal)

func _on_event_selected(node_path: String, event_id: String, inputs: Array) -> void:
	"""Event type selected."""
	pending_id = event_id
	select_event_modal.hide()
	
	if inputs.size() > 0:
		expression_modal.populate_inputs(node_path, event_id, inputs)
		_popup_centered_on_editor(expression_modal)
	else:
		if pending_block_type == "event_replace":
			_replace_event({})
		elif pending_block_type == "event_in_group":
			_finalize_event_in_group({})
		elif pending_block_type == "event_above_target":
			_finalize_event_above_target({})
		else:
			_finalize_event_creation({})

func _on_condition_selected(node_path: String, condition_id: String, inputs: Array) -> void:
	"""Condition type selected."""
	pending_id = condition_id
	select_condition_modal.hide()
	
	if inputs.size() > 0:
		expression_modal.populate_inputs(node_path, condition_id, inputs)
		_popup_centered_on_editor(expression_modal)
	else:
		if pending_block_type == "condition_replace":
			_replace_condition({})
		elif pending_block_type == "branch_condition":
			_finalize_branch_creation({})
		elif pending_block_type == "branch_condition_edit":
			_update_branch_condition({})
		elif pending_block_type == "elseif_condition":
			_finalize_elseif_creation({})
		else:
			_finalize_condition_creation({})

func _on_action_selected(node_path: String, action_id: String, inputs: Array) -> void:
	"""Action type selected."""
	pending_id = action_id
	select_action_modal.hide()
	
	if inputs.size() > 0:
		expression_modal.populate_inputs(node_path, action_id, inputs)
		_popup_centered_on_editor(expression_modal)
	else:
		if pending_block_type == "action_replace":
			_replace_action({})
		elif pending_block_type == "branch_action":
			_finalize_branch_action_creation({})
		else:
			_finalize_action_creation({})

func _on_expressions_confirmed(_node_path: String, _id: String, expressions: Dictionary) -> void:
	"""Expressions entered."""
	expression_modal.hide()
	
	match pending_block_type:
		"event":
			_finalize_event_creation(expressions)
		"event_in_group":
			_finalize_event_in_group(expressions)
		"event_above_target":
			_finalize_event_above_target(expressions)
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
		"branch_condition":
			_finalize_branch_creation(expressions)
		"branch_condition_edit":
			_update_branch_condition(expressions)
		"elseif_condition":
			_finalize_elseif_creation(expressions)
		"branch_action":
			_finalize_branch_action_creation(expressions)

func _finalize_event_creation(inputs: Dictionary) -> void:
	"""Create and add event row (GDevelop-style)."""
	# Push undo state before adding event
	_push_undo_state()
	
	# Generate new block_id for new events (pass empty string to auto-generate)
	var data = FKEventBlock.new("", pending_id, pending_node_path)
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


func _finalize_event_above_target(inputs: Dictionary) -> void:
	"""Create and add event row above the target (GDevelop-style)."""
	# Push undo state before adding event
	_push_undo_state()
	
	# Generate new block_id for new events (pass empty string to auto-generate)
	var data = FKEventBlock.new("", pending_id, pending_node_path)
	data.inputs = inputs
	data.conditions = [] as Array[FKEventCondition]
	data.actions = [] as Array[FKEventAction]
	
	var row = _create_event_row(data)
	
	if pending_target_row:
		var insert_idx = pending_target_row.get_index()  # Insert at same position (above)
		blocks_container.add_child(row)
		blocks_container.move_child(row, insert_idx)
	else:
		blocks_container.add_child(row)
	
	_show_content_state()
	_reset_workflow()
	_save_sheet()


func _finalize_event_in_group(inputs: Dictionary) -> void:
	"""Create and add event inside a group."""
	if not pending_target_group:
		_reset_workflow()
		return
	
	# Push undo state before adding event
	_push_undo_state()
	
	# Generate new block_id for new events (pass empty string to auto-generate)
	var data = FKEventBlock.new("", pending_id, pending_node_path)
	data.inputs = inputs
	data.conditions = [] as Array[FKEventCondition]
	data.actions = [] as Array[FKEventAction]
	
	# Add the event data to the group
	if pending_target_group.has_method("add_event_to_group"):
		pending_target_group.add_event_to_group(data)
	
	_show_content_state()
	_reset_workflow()
	_save_sheet()

func _finalize_condition_creation(inputs: Dictionary) -> void:
	"""Add condition to the current event row."""
	# Push undo state before adding condition
	_push_undo_state()
	
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
	# Push undo state before adding action
	_push_undo_state()
	
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
	# Push undo state before editing event
	_push_undo_state()
	
	if pending_target_row:
		var data = pending_target_row.get_event_data()
		if data:
			data.inputs = expressions
			pending_target_row.update_display()
	_reset_workflow()
	_save_sheet()

func _update_condition_inputs(expressions: Dictionary) -> void:
	"""Update existing condition item with new inputs."""
	# Push undo state before editing condition
	_push_undo_state()
	
	if pending_target_item:
		var data = pending_target_item.get_condition_data()
		if data:
			data.inputs = expressions
			pending_target_item.update_display()
	_reset_workflow()
	_save_sheet()

func _update_action_inputs(expressions: Dictionary) -> void:
	"""Update existing action item with new inputs."""
	# Push undo state before editing action
	_push_undo_state()
	
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
	
	# Push undo state before replacing event
	_push_undo_state()
	
	# Get old row's position and conditions/actions
	var old_data = pending_target_row.get_event_data()
	var old_index = pending_target_row.get_index()
	var old_parent = pending_target_row.get_parent()
	
	# Create new event data, preserving block_id if available
	var old_block_id = old_data.block_id if old_data else ""
	var new_data = FKEventBlock.new(old_block_id, pending_id, pending_node_path)
	new_data.inputs = expressions
	new_data.conditions = old_data.conditions if old_data else ([] as Array[FKEventCondition])
	new_data.actions = old_data.actions if old_data else ([] as Array[FKEventAction])
	
	# Create new row
	var new_row = _create_event_row(new_data)
	
	# Remove old row and insert new one at same position
	if old_parent:
		old_parent.remove_child(pending_target_row)
	pending_target_row.queue_free()
	
	# Add to the same parent (blocks_container or children_container within group)
	if old_parent:
		old_parent.add_child(new_row)
		old_parent.move_child(new_row, old_index)
	else:
		# Fallback if no parent found
		blocks_container.add_child(new_row)
		blocks_container.move_child(new_row, old_index)
	
	# If parent is a container inside a group, find the group and sync its data
	if old_parent:
		var parent_to_sync = old_parent
		# If parent is children_container (inside a group), get the group from metadata
		if old_parent.has_meta("_parent_group"):
			parent_to_sync = old_parent.get_meta("_parent_group")
		
		if parent_to_sync and parent_to_sync.has_method("_sync_children_to_data"):
			parent_to_sync._sync_children_to_data()
	
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
	pending_target_group = null
	pending_target_branch = null

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
	_popup_centered_on_editor(select_node_modal)

func _on_row_delete(signal_row, bound_row) -> void:
	# Push undo state before deleting row
	_push_undo_state()
	
	# Only delete if this row is a direct child of blocks_container
	# (event rows inside groups are handled by the group itself)
	if bound_row.get_parent() == blocks_container:
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
		_popup_centered_on_editor(expression_modal)
	else:
		print("Event has no inputs to edit")

func _on_row_add_condition(signal_row, bound_row) -> void:
	pending_target_row = bound_row
	pending_target_branch = null
	_start_add_workflow("condition", bound_row)

func _on_row_add_action(signal_row, bound_row) -> void:
	pending_target_row = bound_row
	pending_target_branch = null
	_start_add_workflow("action", bound_row)

# === Branch Handlers ===

func _on_row_add_branch(signal_row, bound_row) -> void:
	"""Start adding an IF branch to the event row."""
	pending_target_row = bound_row
	pending_target_branch = null  # Ensure no stale branch target from previous workflow
	_start_add_workflow("branch_condition", bound_row)

func _on_branch_add_elseif(branch_item, event_row) -> void:
	"""Add an Else If branch below an existing branch."""
	pending_target_row = event_row
	pending_target_branch = branch_item
	_start_add_workflow("elseif_condition", event_row)

func _on_nested_branch_add(branch_item, event_row) -> void:
	"""Start adding a nested IF branch inside a branch."""
	pending_target_row = event_row
	pending_target_branch = branch_item
	_start_add_workflow("branch_condition", event_row)

func _on_branch_add_else(branch_item, event_row) -> void:
	"""Add an Else branch below an existing branch."""
	_push_undo_state()

	var branch_data = branch_item.get_action_data()
	if not branch_data or not event_row:
		return

	# Create an else branch action
	var else_data = FKEventAction.new()
	else_data.is_branch = true
	else_data.branch_type = "else"
	else_data.branch_condition = null
	else_data.branch_actions = [] as Array[FKEventAction]

	# Find the array containing this branch (could be nested)
	var actions_array: Array
	if branch_item.parent_branch:
		actions_array = branch_item.parent_branch.get_action_data().branch_actions
	else:
		var event_data = event_row.get_event_data()
		if not event_data:
			return
		actions_array = event_data.actions

	# Insert after the current branch
	var idx = actions_array.find(branch_data)
	if idx >= 0:
		actions_array.insert(idx + 1, else_data)
	else:
		actions_array.append(else_data)

	event_row.update_display()
	_save_sheet()

func _on_branch_condition_edit(branch_item, event_row) -> void:
	"""Edit the condition of a branch."""
	var act_data = branch_item.get_action_data()
	if not act_data or not act_data.branch_condition:
		return

	var cond = act_data.branch_condition
	var provider_inputs = []
	if registry:
		for provider in registry.condition_providers:
			if provider.has_method("get_id") and provider.get_id() == cond.condition_id:
				if provider.has_method("get_inputs"):
					provider_inputs = provider.get_inputs()
				break

	pending_target_row = event_row
	pending_target_branch = branch_item
	pending_block_type = "branch_condition_edit"
	pending_id = cond.condition_id
	pending_node_path = str(cond.target_node)

	if provider_inputs.size() > 0:
		expression_modal.populate_inputs(str(cond.target_node), cond.condition_id, provider_inputs, cond.inputs)
		_popup_centered_on_editor(expression_modal)
	else:
		# No inputs but user wants to change condition type - open node selector
		_start_add_workflow("branch_condition_edit", event_row)

func _on_branch_action_add(branch_item, event_row) -> void:
	"""Add an action inside a branch."""
	pending_target_row = event_row
	pending_target_branch = branch_item
	_start_add_workflow("branch_action", event_row)

func _on_branch_action_edit(action_item, branch_item, event_row) -> void:
	"""Edit an action inside a branch."""
	var act_data = action_item.get_action_data()
	if not act_data:
		return

	var provider_inputs = []
	if registry:
		for provider in registry.action_providers:
			if provider.has_method("get_id") and provider.get_id() == act_data.action_id:
				if provider.has_method("get_inputs"):
					provider_inputs = provider.get_inputs()
				break

	if provider_inputs.size() > 0:
		pending_target_row = event_row
		pending_target_item = action_item
		pending_target_branch = branch_item
		pending_block_type = "action_edit"
		pending_id = act_data.action_id
		pending_node_path = str(act_data.target_node)

		expression_modal.populate_inputs(str(act_data.target_node), act_data.action_id, provider_inputs, act_data.inputs)
		_popup_centered_on_editor(expression_modal)
	else:
		print("Action has no inputs to edit")

func _finalize_branch_creation(inputs: Dictionary) -> void:
	"""Create an IF branch and add it to the target's actions."""
	_push_undo_state()

	var cond = FKEventCondition.new()
	cond.condition_id = pending_id
	cond.target_node = pending_node_path
	cond.inputs = inputs
	cond.negated = false

	var branch_data = FKEventAction.new()
	branch_data.is_branch = true
	branch_data.branch_type = "if"
	branch_data.branch_condition = cond
	branch_data.branch_actions = [] as Array[FKEventAction]

	# If pending_target_branch is set, add as nested branch
	if pending_target_branch and pending_target_branch.has_method("add_branch_action"):
		pending_target_branch.add_branch_action(branch_data)
	elif pending_target_row and pending_target_row.has_method("add_action"):
		pending_target_row.add_action(branch_data)

	_show_content_state()
	_reset_workflow()
	_save_sheet()

func _finalize_elseif_creation(inputs: Dictionary) -> void:
	"""Create an ELSE IF branch and insert it after the current branch."""
	_push_undo_state()

	var cond = FKEventCondition.new()
	cond.condition_id = pending_id
	cond.target_node = pending_node_path
	cond.inputs = inputs
	cond.negated = false

	var elseif_data = FKEventAction.new()
	elseif_data.is_branch = true
	elseif_data.branch_type = "elseif"
	elseif_data.branch_condition = cond
	elseif_data.branch_actions = [] as Array[FKEventAction]

	if pending_target_branch and pending_target_row:
		var branch_act_data = pending_target_branch.get_action_data()
		# Find the array containing this branch (could be nested)
		var actions_array: Array
		if pending_target_branch.parent_branch:
			actions_array = pending_target_branch.parent_branch.get_action_data().branch_actions
		else:
			var event_data = pending_target_row.get_event_data()
			if not event_data:
				_reset_workflow()
				return
			actions_array = event_data.actions
		if branch_act_data:
			var idx = actions_array.find(branch_act_data)
			if idx >= 0:
				actions_array.insert(idx + 1, elseif_data)
			else:
				actions_array.append(elseif_data)
			pending_target_row.update_display()

	_show_content_state()
	_reset_workflow()
	_save_sheet()

func _update_branch_condition(expressions: Dictionary) -> void:
	"""Update an existing branch's condition inputs."""
	_push_undo_state()

	if pending_target_branch:
		var act_data = pending_target_branch.get_action_data()
		if act_data and act_data.branch_condition:
			act_data.branch_condition.inputs = expressions
			pending_target_branch.update_display()

	_reset_workflow()
	_save_sheet()

func _finalize_branch_action_creation(inputs: Dictionary) -> void:
	"""Add an action inside a branch."""
	_push_undo_state()

	var data = FKEventAction.new()
	data.action_id = pending_id
	data.target_node = pending_node_path
	data.inputs = inputs

	if pending_target_branch and pending_target_branch.has_method("add_branch_action"):
		pending_target_branch.add_branch_action(data)

	_show_content_state()
	_reset_workflow()
	_save_sheet()

# === Condition/Action Edit Handlers ===

func _on_condition_edit_requested(condition_item, bound_row) -> void:
	"""Handle double-click on condition to edit its inputs."""
	var cond_data = condition_item.get_condition_data()
	if not cond_data:
		return
	
	# Get condition provider to check if it has inputs
	var provider_inputs = []
	if registry:
		for provider in registry.condition_providers:
			if provider.has_method("get_id") and provider.get_id() == cond_data.condition_id:
				if provider.has_method("get_inputs"):
					provider_inputs = provider.get_inputs()
				break
	
	if provider_inputs.size() > 0:
		pending_target_row = bound_row
		pending_target_item = condition_item
		pending_block_type = "condition_edit"
		pending_id = cond_data.condition_id
		pending_node_path = str(cond_data.target_node)
		
		expression_modal.populate_inputs(str(cond_data.target_node), cond_data.condition_id, provider_inputs, cond_data.inputs)
		_popup_centered_on_editor(expression_modal)
	else:
		print("Condition has no inputs to edit")

func _on_action_edit_requested(action_item, bound_row) -> void:
	"""Handle double-click on action to edit its inputs."""
	var act_data = action_item.get_action_data()
	if not act_data:
		return
	
	# Get action provider to check if it has inputs
	var provider_inputs = []
	if registry:
		for provider in registry.action_providers:
			if provider.has_method("get_id") and provider.get_id() == act_data.action_id:
				if provider.has_method("get_inputs"):
					provider_inputs = provider.get_inputs()
				break
	
	if provider_inputs.size() > 0:
		pending_target_row = bound_row
		pending_target_item = action_item
		pending_block_type = "action_edit"
		pending_id = act_data.action_id
		pending_node_path = str(act_data.target_node)
		
		expression_modal.populate_inputs(str(act_data.target_node), act_data.action_id, provider_inputs, act_data.inputs)
		_popup_centered_on_editor(expression_modal)
	else:
		print("Action has no inputs to edit")

# === Drag and Drop Handlers ===

func _on_condition_dropped(source_row, condition_data: FKEventCondition, target_row) -> void:
	"""Handle condition dropped from one event row to another."""
	if not source_row or not target_row or not condition_data:
		return
	
	# Remove from source
	var source_data = source_row.get_event_data()
	if source_data:
		var idx = source_data.conditions.find(condition_data)
		if idx >= 0:
			source_data.conditions.remove_at(idx)
			source_row.update_display()
	
	# Add to target
	var target_data = target_row.get_event_data()
	if target_data:
		# Create a copy of the condition data
		var cond_copy = FKEventCondition.new()
		cond_copy.condition_id = condition_data.condition_id
		cond_copy.target_node = condition_data.target_node
		cond_copy.inputs = condition_data.inputs.duplicate()
		cond_copy.negated = condition_data.negated
		cond_copy.actions = [] as Array[FKEventAction]
		
		target_data.conditions.append(cond_copy)
		target_row.update_display()
	
	_save_sheet()

func _on_action_dropped(source_row, action_data: FKEventAction, target_row) -> void:
	"""Handle action dropped from one event row to another."""
	if not source_row or not target_row or not action_data:
		return
	
	# Remove from source (search recursively in case it's inside a branch)
	var source_data = source_row.get_event_data()
	if source_data:
		var idx = source_data.actions.find(action_data)
		if idx >= 0:
			source_data.actions.remove_at(idx)
		else:
			_recursive_remove_action_from_list(source_data.actions, action_data)
		source_row.update_display()
	
	# Add to target
	var target_data = target_row.get_event_data()
	if target_data:
		# Create a copy of the action data
		var act_copy = FKEventAction.new()
		act_copy.action_id = action_data.action_id
		act_copy.target_node = action_data.target_node
		act_copy.inputs = action_data.inputs.duplicate()
		
		target_data.actions.append(act_copy)
		target_row.update_display()
	
	_save_sheet()

func _generate_unique_block_id(event_id: String) -> String:
	"""Generate a unique ID for an event block."""
	return "%s_%d_%d" % [event_id, Time.get_ticks_msec(), randi()]
