@tool
extends MarginContainer
class_name FKEventRowUi

signal insert_event_below_requested(event_row)
signal insert_comment_below_requested(event_row)
signal replace_event_requested(event_row)
signal delete_event_requested(event_row)
signal edit_event_requested(event_row)
signal add_condition_requested(event_row)
signal add_action_requested(event_row)
signal condition_selected(condition_node)
signal action_selected(action_node)
signal condition_edit_requested(condition_item)
signal action_edit_requested(action_item)
signal selected(block_node)
signal data_changed()
signal condition_dropped(source_row, condition_data, target_row)
signal action_dropped(source_row, action_data, target_row)
signal before_data_changed()  # Emitted before any data modification for undo state capture
# Branch signals
signal add_branch_requested(event_row)  # User wants to add an IF branch
signal add_elseif_requested(branch_item, event_row)  # Add elseif after a branch
signal add_else_requested(branch_item, event_row)  # Add else after a branch
signal branch_condition_edit_requested(branch_item, event_row)  # Edit branch condition
signal branch_action_add_requested(branch_item, event_row)  # Add action inside a branch
signal branch_action_edit_requested(action_item, branch_item, event_row)  # Edit action inside branch
signal nested_branch_add_requested(branch_item, event_row)  # Add nested IF branch inside a branch

# Data
var event_data: FKEventBlock
var registry: Node
var is_selected: bool = false

# Preloads
const CONDITION_ITEM_SCENE = preload("res://addons/flowkit/ui/workspace/condition_item_ui.tscn")
const ACTION_ITEM_SCENE = preload("res://addons/flowkit/ui/workspace/action_item_ui.tscn")
const BRANCH_ITEM_SCENE = preload("res://addons/flowkit/ui/workspace/branch_item_ui.tscn")

@export_category("Controls")
@export var panel: PanelContainer
@export var context_menu: PopupMenu

@export_category("Containers")
@export var conditions_container: VBoxContainer
@export var actions_container: VBoxContainer

@export_category("Labels")
@export var event_header_label: Label
@export var add_condition_label: Label
@export var add_action_label: Label

@export_category("Drop Zones")
@export var condition_drop_zone: Control
@export var action_drop_zone: Control

@export_category("Styles")
@export var normal_stylebox: StyleBox
@export var selected_stylebox: StyleBox

func _enter_tree() -> void:
	_toggle_subs(true)

# Not the only sub-toggler in this class, given the way we need things wired
func _toggle_subs(on: bool):
	if on:
		gui_input.connect(_on_gui_input)
		context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	else:
		gui_input.disconnect(_on_gui_input)
		context_menu.id_pressed.disconnect(_on_context_menu_id_pressed)
			
	_toggle_label_subs(on)
	_toggle_drop_zone_signals(on)

func _on_gui_input(event: InputEvent) -> void:
	var mouse_click: bool = event is InputEventMouseButton and event.pressed
	if not mouse_click:
		return
	
	if event.button_index == MOUSE_BUTTON_LEFT:
		selected.emit(self)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		selected.emit(self)
		_prep_then_show_context_menu()
		
func _prep_then_show_context_menu():
	context_menu.clear()
	context_menu.add_item("Add Event Below", 0)
	context_menu.add_item("Add Comment Below", 4)
	context_menu.add_separator()
	context_menu.add_item("Replace Event", 1)
	context_menu.add_item("Edit Event", 2)
	context_menu.add_separator()
	context_menu.add_item("Delete Event", 3)
	context_menu.position = DisplayServer.mouse_get_position()
	context_menu.popup()

func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		0: # Add Event Below
			insert_event_below_requested.emit(self)
		1: # Replace Event
			replace_event_requested.emit(self)
		2: # Edit Event
			edit_event_requested.emit(self)
		3: # Delete Event
			delete_event_requested.emit(self)
		4: # Add Comment Below
			insert_comment_below_requested.emit(self)

func _toggle_label_subs(on: bool) -> void:
	if on:
		add_condition_label.gui_input.connect(_on_add_condition_input)
		add_condition_label.mouse_entered.connect(_on_add_condition_hover.bind(true))
		add_condition_label.mouse_exited.connect(_on_add_condition_hover.bind(false))
		
		add_action_label.gui_input.connect(_on_add_action_input)
		add_action_label.mouse_entered.connect(_on_add_action_hover.bind(true))
		add_action_label.mouse_exited.connect(_on_add_action_hover.bind(false))
	else:
		add_condition_label.gui_input.disconnect(_on_add_condition_input)
		add_condition_label.mouse_entered.disconnect(_on_add_condition_hover.bind(true))
		add_condition_label.mouse_exited.disconnect(_on_add_condition_hover.bind(false))
		
		add_action_label.gui_input.disconnect(_on_add_action_input)
		add_action_label.mouse_entered.disconnect(_on_add_action_hover.bind(true))
		add_action_label.mouse_exited.disconnect(_on_add_action_hover.bind(false))
				
func _toggle_drop_zone_signals(on: bool):
	if on:
		if condition_drop_zone.has_signal("item_dropped"):
			condition_drop_zone.item_dropped.connect(_on_condition_drop_zone_dropped)
		if action_drop_zone.has_signal("item_dropped"):
			action_drop_zone.item_dropped.connect(_on_action_drop_zone_dropped)
	else:
		if condition_drop_zone.has_signal("item_dropped"):
			condition_drop_zone.item_dropped.disconnect(_on_condition_drop_zone_dropped)
		if action_drop_zone.has_signal("item_dropped"):
			action_drop_zone.item_dropped.disconnect(_on_action_drop_zone_dropped)
		
func _on_add_condition_input(event: InputEvent) -> void:
	var left_click: bool = event is InputEventMouseButton and \
	event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if not left_click:
		return
		
	_flash_label(add_condition_label)
	add_condition_requested.emit(self)

func _flash_label(label: Label) -> void:
	# Change color to light blue on click
	label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0, 1))
	# Restore color after a short delay
	var tween = create_tween()
	tween.tween_interval(0.15)
	tween.tween_callback(func():
		if is_instance_valid(label):
			label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6, 1))
	)

func _on_add_condition_hover(is_hovering: bool) -> void:
	if is_hovering:
		add_condition_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8, 1))
	else:
		add_condition_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6, 1))
		
func _on_add_action_input(event: InputEvent) -> void:
	var mouse_input_pressed = event is InputEventMouseButton and event.pressed
	if not mouse_input_pressed:
		return
		
	if event.button_index == MOUSE_BUTTON_LEFT:
		_flash_label(add_action_label)
		
	_show_add_action_context_menu()

func _show_add_action_context_menu() -> void:
	var popup := PopupMenu.new()
	popup.add_item("Add Action", 0)
	popup.add_separator()
	popup.add_item("Add If Branch", 1)
	popup.id_pressed.connect(func(id):
		match id:
			0: add_action_requested.emit(self)
			1: add_branch_requested.emit(self)
		popup.queue_free()
	)
	add_child(popup)
	popup.position = DisplayServer.mouse_get_position()
	popup.popup()

func _on_add_action_hover(is_hovering: bool) -> void:
	if is_hovering:
		add_action_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8, 1))
	else:
		add_action_label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6, 1))

func set_event_data(data: FKEventBlock) -> void:
	event_data = data
	call_deferred("_update_display")

func set_registry(reg: Node) -> void:
	registry = reg
	call_deferred("_update_display")

func get_event_data() -> FKEventBlock:
	return event_data

func _update_display() -> void:
	_update_event_header()
	_update_conditions()
	_update_actions()

func _update_event_header() -> void:
	if not event_data:
		return
		
	var display_name = _get_event_header_display_name()
	var params_text = _get_params_text()
	
	var node_name = String(event_data.target_node).get_file()
	event_header_label.text = _header_label_format % [display_name, node_name, params_text]

func _get_event_header_display_name() -> String:
	var result: String = event_data.event_id
	var from_registry := _provider_name_from_registry()
	if from_registry.length() > 0:
		result = from_registry
		
	return result

func _provider_name_from_registry() -> String:
	var result: String = ""
	if registry:
		for provider in registry.event_providers:
			if provider.has_method("get_id") and provider.get_id() == event_data.event_id:
				if provider.has_method("get_name"):
					result = provider.get_name()
				break
	return result
	
func _get_params_text() -> String:
	var params_text = ""
	
	if not event_data.inputs.is_empty():
		var param_pairs = []
		for key in event_data.inputs:
			param_pairs.append("%s" % [event_data.inputs[key]])
		params_text = " (" + ", ".join(param_pairs) + ")"
		
	return params_text

var _header_label_format: String = "⚡ %s (%s)%s"

func _update_conditions() -> void:
	if not event_data:
		return
	
	# Clear existing condition items
	for child in conditions_container.get_children():
		conditions_container.remove_child(child)
		child.queue_free()
	
	# Add condition items
	for condition_data in event_data.conditions:
		var item = CONDITION_ITEM_SCENE.instantiate()
		item.set_condition_data(condition_data)
		item.set_registry(registry)
		_connect_condition_item_signals(item)
		conditions_container.add_child(item)

func _update_actions() -> void:
	if not event_data:
		return
	
	# Clear existing action items
	for child in actions_container.get_children():
		actions_container.remove_child(child)
		child.queue_free()
	
	# Add action items (handles both regular actions and branches)
	for act_data in event_data.actions:
		if act_data.is_branch:
			var branch = BRANCH_ITEM_SCENE.instantiate()
			branch.set_action_data(act_data)
			branch.set_registry(registry)
			_connect_branch_item_signals(branch)
			actions_container.add_child(branch)
		else:
			var item = ACTION_ITEM_SCENE.instantiate()
			item.set_action_data(act_data)
			item.set_registry(registry)
			_connect_action_item_signals(item)
			actions_container.add_child(item)

func _connect_condition_item_signals(item) -> void:
	if item.has_signal("selected"):
		item.selected.connect(func(node): condition_selected.emit(node))
	if item.has_signal("edit_requested"):
		item.edit_requested.connect(_on_condition_item_edit)
	if item.has_signal("delete_requested"):
		item.delete_requested.connect(_on_condition_item_delete)
	if item.has_signal("negate_requested"):
		item.negate_requested.connect(_on_condition_item_negate)
	if item.has_signal("reorder_requested"):
		item.reorder_requested.connect(_on_condition_reorder)

func _connect_action_item_signals(item) -> void:
	if item.has_signal("selected"):
		item.selected.connect(func(node): action_selected.emit(node))
	if item.has_signal("edit_requested"):
		item.edit_requested.connect(_on_action_item_edit)
	if item.has_signal("delete_requested"):
		item.delete_requested.connect(_on_action_item_delete)
	if item.has_signal("reorder_requested"):
		item.reorder_requested.connect(_on_action_reorder)

func _connect_branch_item_signals(branch) -> void:
	if branch.has_signal("selected"):
		branch.selected.connect(func(node): action_selected.emit(node))
	if branch.has_signal("edit_condition_requested"):
		branch.edit_condition_requested.connect(func(item): branch_condition_edit_requested.emit(item, self))
	if branch.has_signal("delete_requested"):
		branch.delete_requested.connect(_on_branch_item_delete)
	if branch.has_signal("add_elseif_requested"):
		branch.add_elseif_requested.connect(func(item): add_elseif_requested.emit(item, self))
	if branch.has_signal("add_else_requested"):
		branch.add_else_requested.connect(func(item): add_else_requested.emit(item, self))
	if branch.has_signal("add_branch_action_requested"):
		branch.add_branch_action_requested.connect(func(item): branch_action_add_requested.emit(item, self))
	if branch.has_signal("branch_action_edit_requested"):
		branch.branch_action_edit_requested.connect(func(act_item, br_item): branch_action_edit_requested.emit(act_item, br_item, self))
	if branch.has_signal("branch_action_selected"):
		branch.branch_action_selected.connect(func(node): action_selected.emit(node))
	if branch.has_signal("reorder_requested"):
		branch.reorder_requested.connect(_on_action_reorder)
	if branch.has_signal("action_cross_reorder_requested"):
		branch.action_cross_reorder_requested.connect(_on_action_cross_reorder)
	if branch.has_signal("action_dropped_into_branch"):
		branch.action_dropped_into_branch.connect(_on_action_dropped_into_branch)
	if branch.has_signal("data_changed"):
		branch.data_changed.connect(func(): data_changed.emit())
	if branch.has_signal("before_data_changed"):
		branch.before_data_changed.connect(func(): before_data_changed.emit())
	if branch.has_signal("add_nested_branch_requested"):
		branch.add_nested_branch_requested.connect(func(item): nested_branch_add_requested.emit(item, self))

func _on_branch_item_delete(item) -> void:
	before_data_changed.emit()
	var act_data = item.get_action_data()
	if act_data and event_data:
		var idx = event_data.actions.find(act_data)
		if idx >= 0:
			event_data.actions.remove_at(idx)
			_update_actions()
			data_changed.emit()

func _on_condition_item_edit(item) -> void:
	condition_edit_requested.emit(item)

func _on_condition_item_delete(item) -> void:
	before_data_changed.emit()  # Signal for undo state capture
	var cond_data = item.get_condition_data()
	if cond_data and event_data:
		var idx = event_data.conditions.find(cond_data)
		if idx >= 0:
			event_data.conditions.remove_at(idx)
			_update_conditions()
			data_changed.emit()

func _on_condition_item_negate(item) -> void:
	before_data_changed.emit()  # Signal for undo state capture
	var cond_data = item.get_condition_data()
	if cond_data:
		cond_data.negated = not cond_data.negated
		item.update_display()
		data_changed.emit()

func _on_action_item_edit(item) -> void:
	action_edit_requested.emit(item)

func _on_action_item_delete(item) -> void:
	before_data_changed.emit()  # Signal for undo state capture
	var act_data = item.get_action_data()
	if act_data and event_data:
		var idx = event_data.actions.find(act_data)
		if idx >= 0:
			event_data.actions.remove_at(idx)
			_update_actions()
			data_changed.emit()

func _on_condition_reorder(source_item, target_item, drop_above: bool) -> void:
	"""Handle reordering conditions within the same event block."""
	if not event_data:
		return
	
	var source_data = source_item.get_condition_data()
	var target_data = target_item.get_condition_data()
	
	if not source_data or not target_data:
		return
	
	var source_idx = event_data.conditions.find(source_data)
	var target_idx = event_data.conditions.find(target_data)
	
	# Source not in this event block - it's a cross-block drag, let the existing system handle it
	if source_idx < 0:
		return
	
	if target_idx < 0:
		return
	
	# Same position, no change needed
	if source_idx == target_idx:
		return
	
	# Calculate final position
	var final_idx: int
	if drop_above:
		final_idx = target_idx if source_idx > target_idx else target_idx - 1
	else:
		final_idx = target_idx + 1 if source_idx > target_idx else target_idx
	
	# No actual movement needed
	if source_idx == final_idx:
		return
	
	before_data_changed.emit()
	
	# Remove from source position
	event_data.conditions.remove_at(source_idx)
	
	# Recalculate target index after removal
	if source_idx < target_idx:
		target_idx -= 1
	
	# Insert at new position
	var insert_idx = target_idx if drop_above else target_idx + 1
	event_data.conditions.insert(insert_idx, source_data)
	
	_update_conditions()
	data_changed.emit()

func _recursive_remove_action(actions_array: Array, target_action) -> bool:
	"""Recursively search and remove an action from actions array and branch sub-actions."""
	var idx = actions_array.find(target_action)
	if idx >= 0:
		actions_array.remove_at(idx)
		return true
	for act in actions_array:
		if act.is_branch and _recursive_remove_action(act.branch_actions, target_action):
			return true
	return false

func _on_action_cross_reorder(source_data, target_data, is_drop_above: bool, target_branch) -> void:
	"""Handle cross-context action reorder (action moved into a different branch)."""
	if not event_data:
		return
	
	before_data_changed.emit()
	
	# Remove source from wherever it is (top-level or any branch)
	_recursive_remove_action(event_data.actions, source_data)
	
	# Insert into target branch at the correct position
	var target_actions = target_branch.action_data.branch_actions
	var target_idx = target_actions.find(target_data)
	if target_idx >= 0:
		var insert_idx = target_idx if is_drop_above else target_idx + 1
		target_actions.insert(insert_idx, source_data)
	else:
		target_actions.append(source_data)
	
	_update_actions()
	data_changed.emit()

func _on_action_dropped_into_branch(source_item, target_branch) -> void:
	"""Handle action/branch dropped into a branch's body area."""
	if not event_data:
		return
	
	var source_data = source_item.get_action_data()
	if not source_data:
		return
	
	before_data_changed.emit()
	
	# Remove source from wherever it is (top-level or any branch)
	_recursive_remove_action(event_data.actions, source_data)
	
	# Add to target branch's sub-actions
	target_branch.action_data.branch_actions.append(source_data)
	
	_update_actions()
	data_changed.emit()

func _on_action_reorder(source_item, target_item, drop_above: bool) -> void:
	"""Handle reordering actions within the same event block."""
	if not event_data:
		return
	
	var source_data = source_item.get_action_data()
	var target_data = target_item.get_action_data()
	
	if not source_data or not target_data:
		return
	
	var source_idx = event_data.actions.find(source_data)
	var target_idx = event_data.actions.find(target_data)
	
	if target_idx < 0:
		return
	
	# Source not at top level - it's being moved from a branch to top level
	if source_idx < 0:
		before_data_changed.emit()
		
		# Recursively remove source from wherever it is (inside a branch)
		if not _recursive_remove_action(event_data.actions, source_data):
			return
		
		# Recalculate target index after removal (branch removal doesn't shift top-level indices
		# unless the branch itself was removed, but we're removing an item FROM a branch)
		target_idx = event_data.actions.find(target_data)
		if target_idx < 0:
			return
		
		var insert_idx = target_idx if drop_above else target_idx + 1
		event_data.actions.insert(insert_idx, source_data)
		
		_update_actions()
		data_changed.emit()
		return
	
	# Same position, no change needed
	if source_idx == target_idx:
		return
	
	# Calculate final position
	var final_idx: int
	if drop_above:
		final_idx = target_idx if source_idx > target_idx else target_idx - 1
	else:
		final_idx = target_idx + 1 if source_idx > target_idx else target_idx
	
	# No actual movement needed
	if source_idx == final_idx:
		return
	
	before_data_changed.emit()
	
	# Remove from source position
	event_data.actions.remove_at(source_idx)
	
	# Recalculate target index after removal
	if source_idx < target_idx:
		target_idx -= 1
	
	# Insert at new position
	var insert_idx = target_idx if drop_above else target_idx + 1
	event_data.actions.insert(insert_idx, source_data)
	
	_update_actions()
	data_changed.emit()

func add_condition(condition_data: FKEventCondition) -> void:
	if event_data:
		event_data.conditions.append(condition_data)
		_update_conditions()

func add_action(action_data: FKEventAction) -> void:
	if event_data:
		event_data.actions.append(action_data)
		_update_actions()

func update_display() -> void:
	_update_display()

func set_selected(value: bool) -> void:
	is_selected = value
	var style = normal_stylebox
	if is_selected:
		style = selected_stylebox
		
	panel.add_theme_stylebox_override("panel", style)

func _get_drag_data(at_position: Vector2):
	var drag_preview := _create_drag_preview()
	set_drag_preview(drag_preview)
	
	return \
	{
		"type": "event_row",
		"node": self
	}

func _create_drag_preview() -> Control:
	var preview_label := Label.new()
	preview_label.text = event_header_label.text if event_header_label else "Event"
	preview_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9, 0.7))
	
	var preview_margin := MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 8)
	preview_margin.add_theme_constant_override("margin_top", 4)
	preview_margin.add_theme_constant_override("margin_right", 8)
	preview_margin.add_theme_constant_override("margin_bottom", 4)
	preview_margin.add_child(preview_label)
	return preview_margin
	
func _can_drop_data(at_position: Vector2, data) -> bool:
	if not data is Dictionary:
		return false
	
	var drag_type = data.get("type", "")
	
	# For event_row, comment, or group drags, let the parent (blocks_container or group) handle it
	if drag_type in ["event_row", "comment", "group"]:
		# Forward to parent
		var parent = get_parent()
		if parent and parent.has_method("_can_drop_data"):
			var parent_pos = at_position + position
			return parent._can_drop_data(parent_pos, data)
		return false
	
	if drag_type != "condition_item" and drag_type != "action_item":
		return false
	
	# Use simple half-width check: left half = conditions, right half = actions
	var half_width = size.x / 2.0
	var is_left_side = at_position.x < half_width
	
	if drag_type == "condition_item" and is_left_side:
		return true
	elif drag_type == "action_item" and not is_left_side:
		return true
	
	return false

func _drop_data(at_position: Vector2, data) -> void:
	if not data is Dictionary:
		return
	
	var drag_type = data.get("type", "")
	
	# For event_row, comment, or group drags, let the parent handle it
	if drag_type in ["event_row", "comment", "group"]:
		var parent = get_parent()
		if parent and parent.has_method("_drop_data"):
			var parent_pos = at_position + position
			parent._drop_data(parent_pos, data)
		return
	
	var source_node = data.get("node")
	
	if not source_node or not is_instance_valid(source_node):
		return
	
	# Find the source event_row
	var source_row = _find_parent_event_row(source_node)
	if not source_row:
		return
	
	# Use simple half-width check
	var half_width = size.x / 2.0
	var is_left_side = at_position.x < half_width
	
	match drag_type:
		"condition_item":
			if is_left_side:
				var cond_data = data.get("data")
				if cond_data:
					# Allow same-row drops for reordering (handled by condition_item_ui.gd)
					# Only handle cross-row drops here
					if source_row != self:
						condition_dropped.emit(source_row, cond_data, self)
		"action_item":
			if not is_left_side:
				var act_data = data.get("data")
				if act_data:
					# Allow same-row drops for reordering (handled by action_item_ui.gd)
					# Only handle cross-row drops here
					if source_row != self:
						action_dropped.emit(source_row, act_data, self)

func _find_parent_event_row(node: Node):
	"""Find the event_row that contains this node."""
	var current = node.get_parent()
	while current:
		if current.has_method("get_event_data"):
			return current
		current = current.get_parent()
	return null

func _on_condition_drop_zone_dropped(drag_data: Dictionary) -> void:
	"""Handle condition dropped on the condition drop zone."""
	var source_node = drag_data.get("node")
	if not source_node or not is_instance_valid(source_node):
		return
	
	var source_row = _find_parent_event_row(source_node)
	if not source_row or source_row == self:
		return
	
	var cond_data = drag_data.get("data")
	if cond_data:
		condition_dropped.emit(source_row, cond_data, self)

func _on_action_drop_zone_dropped(drag_data: Dictionary) -> void:
	"""Handle action dropped on the action drop zone."""
	var source_node = drag_data.get("node")
	if not source_node or not is_instance_valid(source_node):
		return
	
	var source_row = _find_parent_event_row(source_node)
	if not source_row or source_row == self:
		return
	
	var act_data = drag_data.get("data")
	if act_data:
		action_dropped.emit(source_row, act_data, self)

func _exit_tree():
	_toggle_subs(false)
