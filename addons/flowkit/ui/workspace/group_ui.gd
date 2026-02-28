@tool
extends MarginContainer
class_name GroupBlockUi

## Collapsible group block for organizing events, comments, and nested groups.
##
## Groups can contain events, comments, and other groups.
## They can be collapsed/expanded, renamed, and recolored.
## Items can be dragged in and out of groups.

# === Signals ===
signal selected(group_node)  ## Emitted when group or child is selected
signal delete_requested  ## Emitted when group deletion is requested
signal data_changed  ## Emitted after any data within group changes
signal before_data_changed  ## Emitted before data changes (for undo)
signal add_event_requested(group_node)  ## Emitted when user wants to add event to group
signal add_comment_requested(group_node)  ## Emitted when user wants to add comment to group
signal condition_edit_requested(condition_item, row)  ## Emitted when condition needs editing
signal action_edit_requested(action_item, row)  ## Emitted when action needs editing
signal insert_event_below_requested(row)  ## Emitted when inserting event below
signal insert_event_above_requested(target)  ## Emitted when inserting event above
signal insert_comment_below_requested(row)  ## Emitted when inserting comment below event
signal insert_comment_above_requested(target)  ## Emitted when inserting comment above
signal replace_event_requested(row)  ## Emitted when replacing event
signal edit_event_requested(row)  ## Emitted when editing event
signal add_condition_requested(row)  ## Emitted when adding condition to event
signal add_action_requested(row)  ## Emitted when adding action to event
signal condition_dropped(source_row, condition_data, target_row)  ## Emitted when condition is dropped on an event
signal action_dropped(source_row, action_data, target_row)  ## Emitted when action is dropped on an event
# Branch signals
signal add_branch_requested(row)  ## Emitted when adding IF branch to event
signal add_elseif_requested(branch_item, row)  ## Emitted when adding Else If below a branch
signal add_else_requested(branch_item, row)  ## Emitted when adding Else below a branch
signal branch_condition_edit_requested(branch_item, row)  ## Emitted when editing branch condition
signal branch_action_add_requested(branch_item, row)  ## Emitted when adding action inside branch
signal branch_action_edit_requested(action_item, branch_item, row)  ## Emitted when editing action inside branch
signal nested_branch_add_requested(branch_item, row)  ## Emitted when adding nested IF branch

# === Constants ===
const EVENT_ROW_SCENE = preload("res://addons/flowkit/ui/workspace/event_row_ui.tscn")
const COMMENT_SCENE = preload("res://addons/flowkit/ui/workspace/comment_ui.tscn")

# === State ===
var group_data: FKGroupBlock
var is_selected: bool = false
var registry: Node
var _last_selected_child_data: Variant = null  # Track which child was last selected for insertion positioning

# === Drag State ===
var _drag_start_pos: Vector2 = Vector2.ZERO
var _is_potential_drag: bool = false
const DRAG_THRESHOLD: float = 8.0

@export_category("Controls")
@export var panel: PanelContainer
@export var title_edit: LineEdit
@export var children_container: VBoxContainer
@export var context_menu: PopupMenu
@export var header: BoxContainer
@export var children_margin: MarginContainer

@export_category("Labels")
@export var collapse_btn: Label
@export var title_label: Label
@export var drop_hint: Label

@export_category("Styles")
@export var normal_stylebox: StyleBox
@export var selected_stylebox: StyleBox

# === Lifecycle ===

func _enter_tree() -> void:
	_toggle_subs(true)
	children_container.set_meta("_parent_group", self)

func _toggle_subs(on: bool):
	if on:
		gui_input.connect(_on_gui_input)
	
		collapse_btn.gui_input.connect(_on_collapse_btn_input)
		
		collapse_btn.mouse_entered.connect(_on_collapse_btn_mouse_entered)
		collapse_btn.mouse_exited.connect(_on_collapse_btn_mouse_exited)
		
		title_label.gui_input.connect(_on_title_input)
		
		title_edit.text_submitted.connect(_on_title_submitted)
		title_edit.focus_exited.connect(_on_title_focus_lost)
		
		context_menu.id_pressed.connect(_on_context_menu_id_pressed)
		
		header.gui_input.connect(_on_header_gui_input)
	else:
		gui_input.disconnect(_on_gui_input)
	
		collapse_btn.gui_input.disconnect(_on_collapse_btn_input)
		
		collapse_btn.mouse_entered.disconnect(_on_collapse_btn_mouse_entered)
		collapse_btn.mouse_exited.disconnect(_on_collapse_btn_mouse_exited)
		
		title_label.gui_input.disconnect(_on_title_input)
		
		title_edit.text_submitted.disconnect(_on_title_submitted)
		title_edit.focus_exited.disconnect(_on_title_focus_lost)
		
		context_menu.id_pressed.disconnect(_on_context_menu_id_pressed)
		
		header.gui_input.disconnect(_on_header_gui_input)
	
func _input(event: InputEvent) -> void:
	"""Cancel title edit when clicking outside."""
	var left_click: bool = event is InputEventMouseButton and event.pressed and \
	event.button_index == MOUSE_BUTTON_LEFT
	if not left_click or not title_edit.visible:
		return
		
	var clicked_title_edit: bool = title_edit.get_global_rect().has_point(event.global_position)
	if not clicked_title_edit:
		_finish_title_edit(title_edit.text)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		DropIndicatorManager.hide_indicator()

# === Data Management ===

func set_group_data(data: FKGroupBlock) -> void:
	"""Set the group's data resource."""
	group_data = data
	call_deferred("_refresh_display")


func get_group_data() -> FKGroupBlock:
	"""Get the group's data resource."""
	return group_data


func set_registry(reg: Node) -> void:
	"""Set the provider registry reference."""
	registry = reg
	call_deferred("_refresh_display")

# === Display Management ===

func _refresh_display() -> void:
	"""Refresh all visual elements from data."""
	if not group_data:
		return
	
	_update_title_display()
	_update_collapse_display()
	_update_color_display()
	_rebuild_child_nodes()


func _update_title_display() -> void:
	"""Update title label from data."""
	title_label.text = group_data.title


func _update_collapse_display() -> void:
	"""Update collapse button and visibility."""
	collapse_btn.text = "▶" if group_data.collapsed else "▼"
	children_margin.visible = not group_data.collapsed
	custom_minimum_size.y = 32 if group_data.collapsed else 60


func _update_color_display() -> void:
	"""Update panel color from data."""
	if not group_data:
		return
	
	# We'll need to dynamically alter the normal and selected styles based on
	# the group data we're working with. As we don't want to change the assets
	# on disk through code, we'll assign both style boxes to copies.
	normal_stylebox = normal_stylebox.duplicate()
	if normal_stylebox is StyleBoxFlat:
		normal_stylebox.bg_color = group_data.color
		normal_stylebox.border_color = group_data.color.lightened(0.3)
		
	panel.add_theme_stylebox_override("panel", normal_stylebox)
	
	selected_stylebox = selected_stylebox.duplicate()
	if selected_stylebox is StyleBoxFlat:
		selected_stylebox.bg_color = group_data.color

func _rebuild_child_nodes() -> void:
	"""Rebuild child UI nodes from group_data.children."""
	if not group_data:
		return
	
	# Remove old children (except drop_hint)
	for child in children_container.get_children():
		if child != drop_hint and not DropIndicatorManager.is_indicator(child):
			children_container.remove_child(child)
			child.queue_free()
	
	# Create new children from data
	for child_dict in group_data.children:
		var child_type: String = child_dict.get("type", "")
		var child_data = child_dict.get("data")
		
		match child_type:
			"event":
				if child_data is FKEventBlock:
					var row = _instantiate_event_row(child_data)
					children_container.add_child(row)
			"comment":
				if child_data is FKCommentBlock:
					var comment = _instantiate_comment(child_data)
					children_container.add_child(comment)
			"group":
				if child_data is FKGroupBlock:
					var nested = _instantiate_group(child_data)
					children_container.add_child(nested)
	
	# Update drop hint visibility
	if drop_hint:
		drop_hint.visible = group_data.children.is_empty()

# === Child Node Instantiation ===

func _instantiate_event_row(data: FKEventBlock) -> Control:
	"""Create an event row UI node for the given data."""
	var row = EVENT_ROW_SCENE.instantiate()
	
	# Defer initialization to ensure node is ready
	row.call_deferred("set_event_data", data)
	row.call_deferred("set_registry", registry)
	
	# Connect row signals to group handlers - propagate all signals to parent
	row.delete_event_requested.connect(_on_child_row_delete_requested.bind(data))
	row.selected.connect(func(n): _on_child_selected(data); selected.emit(n))
	row.condition_selected.connect(func(n): selected.emit(n))
	row.action_selected.connect(func(n): selected.emit(n))
	row.condition_edit_requested.connect(func(item): condition_edit_requested.emit(item, row))
	row.action_edit_requested.connect(func(item): action_edit_requested.emit(item, row))
	row.insert_event_below_requested.connect(func(r): insert_event_below_requested.emit(r))
	row.insert_comment_below_requested.connect(func(r): insert_comment_below_requested.emit(r))
	row.replace_event_requested.connect(func(r): replace_event_requested.emit(r))
	row.edit_event_requested.connect(func(r): edit_event_requested.emit(r))
	row.add_condition_requested.connect(func(r): add_condition_requested.emit(r))
	row.add_action_requested.connect(func(r): add_action_requested.emit(r))
	row.condition_dropped.connect(func(src, cond, tgt): condition_dropped.emit(src, cond, tgt))
	row.action_dropped.connect(func(src, act, tgt): action_dropped.emit(src, act, tgt))
	# Branch signal forwarding
	row.add_branch_requested.connect(func(r): add_branch_requested.emit(r))
	row.add_elseif_requested.connect(func(bi, r): add_elseif_requested.emit(bi, r))
	row.add_else_requested.connect(func(bi, r): add_else_requested.emit(bi, r))
	row.branch_condition_edit_requested.connect(func(bi, r): branch_condition_edit_requested.emit(bi, r))
	row.branch_action_add_requested.connect(func(bi, r): branch_action_add_requested.emit(bi, r))
	row.branch_action_edit_requested.connect(func(ai, bi, r): branch_action_edit_requested.emit(ai, bi, r))
	row.nested_branch_add_requested.connect(func(bi, r): nested_branch_add_requested.emit(bi, r))
	row.data_changed.connect(_on_child_modified)
	row.before_data_changed.connect(func(): before_data_changed.emit())
	
	return row


func _instantiate_comment(data: FKCommentBlock) -> Control:
	"""Create a comment UI node for the given data."""
	var comment = COMMENT_SCENE.instantiate()
	comment.set_comment_data(data)
	
	# Connect comment signals to group handlers
	comment.delete_requested.connect(_on_child_comment_delete_requested.bind(data))
	comment.selected.connect(func(n): _on_child_selected(data); selected.emit(n))
	comment.data_changed.connect(_on_child_modified)
	comment.insert_comment_above_requested.connect(func(c): insert_comment_above_requested.emit(c))
	comment.insert_comment_below_requested.connect(func(c): insert_comment_below_requested.emit(c))
	comment.insert_event_above_requested.connect(func(c): insert_event_above_requested.emit(c))
	comment.insert_event_below_requested.connect(func(c): insert_event_below_requested.emit(c))
	
	return comment


func _instantiate_group(data: FKGroupBlock) -> Control:
	"""Create a nested group UI node for the given data."""
	var group_scene = load("res://addons/flowkit/ui/workspace/group_ui.tscn")
	var nested = group_scene.instantiate()
	nested.set_group_data(data)
	nested.set_registry(registry)
	
	# Connect nested group signals to parent handlers - propagate everything
	nested.delete_requested.connect(_on_child_group_delete_requested.bind(data))
	nested.selected.connect(func(n): selected.emit(n))
	nested.data_changed.connect(_on_child_modified)
	nested.before_data_changed.connect(func(): before_data_changed.emit())
	nested.add_event_requested.connect(func(g): add_event_requested.emit(g))
	nested.add_comment_requested.connect(func(g): add_comment_requested.emit(g))
	nested.condition_edit_requested.connect(func(item, row): condition_edit_requested.emit(item, row))
	nested.action_edit_requested.connect(func(item, row): action_edit_requested.emit(item, row))
	nested.insert_event_below_requested.connect(func(r): insert_event_below_requested.emit(r))
	nested.insert_event_above_requested.connect(func(r): insert_event_above_requested.emit(r))
	nested.insert_comment_below_requested.connect(func(r): insert_comment_below_requested.emit(r))
	nested.insert_comment_above_requested.connect(func(r): insert_comment_above_requested.emit(r))
	nested.replace_event_requested.connect(func(r): replace_event_requested.emit(r))
	nested.edit_event_requested.connect(func(r): edit_event_requested.emit(r))
	nested.add_condition_requested.connect(func(r): add_condition_requested.emit(r))
	nested.add_action_requested.connect(func(r): add_action_requested.emit(r))
	nested.condition_dropped.connect(func(src, cond, tgt): condition_dropped.emit(src, cond, tgt))
	nested.action_dropped.connect(func(src, act, tgt): action_dropped.emit(src, act, tgt))
	# Branch signal forwarding for nested groups
	if nested.has_signal("add_branch_requested"):
		nested.add_branch_requested.connect(func(r): add_branch_requested.emit(r))
	if nested.has_signal("add_elseif_requested"):
		nested.add_elseif_requested.connect(func(bi, r): add_elseif_requested.emit(bi, r))
	if nested.has_signal("add_else_requested"):
		nested.add_else_requested.connect(func(bi, r): add_else_requested.emit(bi, r))
	if nested.has_signal("branch_condition_edit_requested"):
		nested.branch_condition_edit_requested.connect(func(bi, r): branch_condition_edit_requested.emit(bi, r))
	if nested.has_signal("branch_action_add_requested"):
		nested.branch_action_add_requested.connect(func(bi, r): branch_action_add_requested.emit(bi, r))
	if nested.has_signal("branch_action_edit_requested"):
		nested.branch_action_edit_requested.connect(func(ai, bi, r): branch_action_edit_requested.emit(ai, bi, r))
	if nested.has_signal("nested_branch_add_requested"):
		nested.nested_branch_add_requested.connect(func(bi, r): nested_branch_add_requested.emit(bi, r))
	
	return nested

# === Child Event Handlers ===

func _on_child_modified() -> void:
	"""Child data changed - propagate to parent."""
	data_changed.emit()


func _on_child_row_delete_requested(row: Node, data: FKEventBlock) -> void:
	"""Handle deletion of an event row child."""
	_remove_child_data(data)


func _on_child_comment_delete_requested(data: FKCommentBlock) -> void:
	"""Handle deletion of a comment child."""
	_remove_child_data(data)


func _on_child_group_delete_requested(data: FKGroupBlock) -> void:
	"""Handle deletion of a nested group child."""
	_remove_child_data(data)


func _remove_child_data(child_data) -> void:
	"""Remove child data and rebuild UI."""
	if not group_data:
		return
	
	# Find and remove from data
	var idx = -1
	for i in range(group_data.children.size()):
		if group_data.children[i].get("data") == child_data:
			idx = i
			break
	
	if idx >= 0:
		before_data_changed.emit()
		group_data.children.remove_at(idx)
		_rebuild_child_nodes()
		data_changed.emit()


func _sync_children_to_data() -> void:
	"""Sync the data array to match the current UI child order."""
	if not group_data or not children_container:
		return
	
	var new_children = []
	
	for child in children_container.get_children():
		if child == drop_hint or DropIndicatorManager.is_indicator(child):
			continue
		
		# Skip invalid or deleted children
		if not is_instance_valid(child) or child.is_queued_for_deletion():
			continue
		
		if child.has_method("get_event_data"):
			var data = child.get_event_data()
			if data:
				new_children.append({"type": "event", "data": data})
		elif child.has_method("get_group_data"):
			var data = child.get_group_data()
			if data:
				new_children.append({"type": "group", "data": data})
		elif child.has_method("get_comment_data"):
			var data = child.get_comment_data()
			if data:
				new_children.append({"type": "comment", "data": data})
	
	group_data.children = new_children


func add_event_to_group(event_data: FKEventBlock) -> void:
	"""Add an event to this group (called by editor when workflow completes)."""
	if not group_data:
		return
	
	group_data.children.append({"type": "event", "data": event_data})
	_rebuild_child_nodes()
	data_changed.emit()

# === Collapse/Expand ===

func _on_collapse_btn_input(event: InputEvent) -> void:
	"""Handle collapse button input - only toggle on direct click."""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			selected.emit(self)
			_toggle_collapse()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			selected.emit(self)
			_show_context_menu(event.global_position)


func _on_collapse_btn_mouse_entered() -> void:
	"""Highlight the collapse button on hover."""
	collapse_btn.add_theme_color_override("font_color", Color.WHITE)


func _on_collapse_btn_mouse_exited() -> void:
	"""Restore the collapse button on hover exit."""
	collapse_btn.remove_theme_color_override("font_color")


func _toggle_collapse() -> void:
	"""Toggle collapsed state."""
	if group_data:
		before_data_changed.emit()
		group_data.collapsed = not group_data.collapsed
		_update_collapse_display()
		data_changed.emit()


func _start_group_drag() -> void:
	"""Initiate group drag."""
	var preview = Label.new()
	preview.text = "📁 " + (group_data.title if group_data else "Group")
	preview.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 0.9))
	force_drag({"node": self, "type": "group"}, preview)

# === Title Editing ===

func _on_title_input(event: InputEvent) -> void:
	"""Handle title label input."""
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				selected.emit(self)
				if event.double_click:
					_start_title_edit()
					_is_potential_drag = false
				else:
					_drag_start_pos = event.position
					_is_potential_drag = true
			else:
				if _is_potential_drag:
					# Only drag, don't collapse from title click
					pass
				_is_potential_drag = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			selected.emit(self)
			_show_context_menu(event.global_position)
	elif event is InputEventMouseMotion and _is_potential_drag:
		var distance = event.position.distance_to(_drag_start_pos)
		if distance >= DRAG_THRESHOLD and not get_viewport().gui_is_dragging():
			_is_potential_drag = false
			_start_group_drag()


func _start_title_edit() -> void:
	"""Enter title edit mode."""
	_is_potential_drag = false
	
	title_label.visible = false
	title_edit.visible = true
	title_edit.text = group_data.title if group_data else "Group"
	title_edit.grab_focus()
	title_edit.select_all()


func _on_title_submitted(new_text: String) -> void:
	"""Handle title edit submission."""
	_finish_title_edit(new_text)


func _on_title_focus_lost() -> void:
	"""Handle title edit focus loss."""
	if title_edit.visible:
		_finish_title_edit(title_edit.text)


func _finish_title_edit(new_text: String) -> void:
	"""Exit title edit mode."""
	before_data_changed.emit()
	title_edit.visible = false
	title_label.visible = true
	if group_data:
		group_data.title = new_text if new_text != "" else "Group"
		title_label.text = group_data.title
		data_changed.emit()

# === Context Menu ===

func _show_context_menu(pos: Vector2) -> void:
	"""Show context menu."""
	context_menu.clear()
	context_menu.add_item("Add Event", 10)
	context_menu.add_item("Add Comment", 11)
	context_menu.add_separator()
	context_menu.add_item("Rename Group", 0)
	context_menu.add_item("Change Color", 1)
	context_menu.add_separator()
	context_menu.add_item("Delete Group", 2)
	context_menu.position = Vector2i(pos)
	context_menu.popup()


func _on_context_menu_id_pressed(id: int) -> void:
	"""Handle context menu selection."""
	match id:
		0: _start_title_edit()
		1: _show_color_picker()
		2: delete_requested.emit()
		10: add_event_requested.emit(self)
		11: _add_comment_to_group()


func _on_child_selected(child_data: Variant) -> void:
	"""Track which child was last selected for insertion positioning."""
	_last_selected_child_data = child_data

func _add_comment_to_group() -> void:
	"""Add a new comment inside this group, positioned after the currently selected item if any."""
	if not group_data:
		return
	
	before_data_changed.emit()
	
	var comment = FKCommentBlock.new()
	comment.text = ""
	
	# Find the index where to insert the comment
	var insert_index = group_data.children.size()  # Default to end
	
	# If there's a selected child, insert after it
	if _last_selected_child_data != null:
		for j in range(group_data.children.size()):
			if group_data.children[j].get("data") == _last_selected_child_data:
				insert_index = j + 1
				break
	
	group_data.children.insert(insert_index, {"type": "comment", "data": comment})
	
	_rebuild_child_nodes()
	data_changed.emit()


func _show_color_picker() -> void:
	"""Show color picker dialog."""
	var picker = ColorPickerButton.new()
	picker.color = group_data.color if group_data else Color(0.25, 0.22, 0.35, 1.0)
	
	var dialog = AcceptDialog.new()
	dialog.title = "Choose Group Color"
	dialog.add_child(picker)
	add_child(dialog)
	
	var original_color = picker.color
	
	# Preview color changes without saving
	picker.color_changed.connect(func(color):
		if group_data:
			group_data.color = color
			_update_color_display()
	)
	
	dialog.confirmed.connect(func():
		# Only save when confirmed
		if group_data:
			before_data_changed.emit()
			group_data.color = picker.color
			_update_color_display()
			data_changed.emit()
		dialog.queue_free()
	)
	
	dialog.canceled.connect(func():
		# Restore original color on cancel
		if group_data:
			group_data.color = original_color
			_update_color_display()
		dialog.queue_free()
	)
	
	dialog.popup_centered()

# === Input Handling ===

func _on_gui_input(event: InputEvent) -> void:
	"""Handle general input."""
	if event is InputEventMouseButton and event.pressed:
		if children_margin.visible:
			var local_pos = children_margin.get_local_mouse_position()
			if children_margin.get_rect().has_point(local_pos + children_margin.position):
				return
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			selected.emit(self)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			selected.emit(self)
			_show_context_menu(event.global_position)


func _on_header_gui_input(event: InputEvent) -> void:
	"""Handle header input."""
	if title_edit.visible:
		_is_potential_drag = false
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_start_pos = event.position
				_is_potential_drag = true
				selected.emit(self)
			else:
				_is_potential_drag = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			selected.emit(self)
			_show_context_menu(event.global_position)
	elif event is InputEventMouseMotion and _is_potential_drag:
		var distance = event.position.distance_to(_drag_start_pos)
		if distance >= DRAG_THRESHOLD and not get_viewport().gui_is_dragging():
			_is_potential_drag = false
			_start_group_drag()

# === Selection ===

func set_selected(value: bool) -> void:
	"""Set selection state."""
	is_selected = value
	_update_panel_style_based_on_selection()

func _update_panel_style_based_on_selection():
	var style := normal_stylebox
	if is_selected:
		style = selected_stylebox
	panel.add_theme_stylebox_override("panel", style)
		
# === Drag and Drop ===

func _get_drag_data(_at_position: Vector2):
	"""Provide drag data."""
	var preview = Label.new()
	preview.text = "📁 " + (group_data.title if group_data else "Group")
	preview.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 0.9))
	set_drag_preview(preview)
	return {"node": self, "type": "group"}


func _can_drop_data(at_position: Vector2, data) -> bool:
	"""Check if drop is allowed."""
	if not data is Dictionary:
		return false
	
	var drag_type = data.get("type", "")
	var drag_node = data.get("node")
	
	# Prevent self or ancestor drops
	if drag_node == self:
		DropIndicatorManager.hide_indicator()
		return false
	
	var current = drag_node
	while current:
		if current == self:
			DropIndicatorManager.hide_indicator()
			return false
		current = current.get_parent() if current.get_parent() else null
	
	# Accept block types
	if drag_type not in ["event_row", "comment", "group"]:
		DropIndicatorManager.hide_indicator()
		return false
	
	# Check if drop is in children area
	var children_margin = get_node_or_null("Panel/VBox/ChildrenMargin")
	if children_margin and children_margin.visible:
		var local_pos = children_margin.get_local_mouse_position()
		if children_margin.get_rect().has_point(local_pos + children_margin.position):
			_show_drop_indicator(at_position, drag_node)
			return true
	
	DropIndicatorManager.hide_indicator()
	return false


func _drop_data(at_position: Vector2, data) -> void:
	"""Handle drop."""
	DropIndicatorManager.hide_indicator()
	
	if not data is Dictionary:
		return
	
	var drag_node = data.get("node")
	if not drag_node or not is_instance_valid(drag_node):
		return
	
	if not children_margin.visible:
		return
	
	var local_pos = children_margin.get_local_mouse_position()
	if not children_margin.get_rect().has_point(local_pos + children_margin.position):
		return
	
	_handle_drop(drag_node, data.get("type", ""))


func _handle_drop(drag_node: Node, drag_type: String) -> void:
	"""Handle the actual drop operation."""
	var original_parent = drag_node.get_parent()
	
	# Check if this is an internal reorder (same parent = children_container)
	if original_parent == children_container:
		_handle_internal_reorder(drag_node)
		return
	
	# External drop - moving from another container
	_handle_external_drop(drag_node, drag_type, original_parent)


func _handle_internal_reorder(drag_node: Node) -> void:
	"""Handle reordering within this group."""
	# Get visible children (excluding drop_hint, indicator)
	var visible_children = []
	for child in children_container.get_children():
		if child == drop_hint or DropIndicatorManager.is_indicator(child):
			continue
		# Skip invalid or deleted children
		if not is_instance_valid(child) or child.is_queued_for_deletion():
			continue
		if child.visible:
			visible_children.append(child)
	
	# Calculate visual drop index using same logic as blocks_container
	var local_y = children_container.get_local_mouse_position().y
	var target_visual_idx = visible_children.size()  # Default to end
	
	for i in range(visible_children.size()):
		var child = visible_children[i]
		var rect = child.get_rect()
		var mid_y = rect.position.y + rect.size.y * 0.5
		if local_y < mid_y:
			target_visual_idx = i
			break
	
	var current_visual_idx = visible_children.find(drag_node)
	
	# No-op if same position
	if target_visual_idx == current_visual_idx or target_visual_idx == current_visual_idx + 1:
		return
	
	# Calculate actual child index from visual index
	var target_child_idx: int
	if target_visual_idx >= visible_children.size():
		target_child_idx = children_container.get_child_count()
	else:
		target_child_idx = visible_children[target_visual_idx].get_index()
	
	var current_child_idx = drag_node.get_index()
	
	# Adjust for moving down (same as blocks_container)
	if target_child_idx > current_child_idx:
		target_child_idx -= 1
	
	before_data_changed.emit()
	children_container.move_child(drag_node, target_child_idx)
	
	# Sync data from new visual order
	_sync_children_to_data()
	data_changed.emit()


func _handle_external_drop(drag_node: Node, drag_type: String, original_parent: Node) -> void:
	"""Handle drop from external source (another group or blocks_container)."""
	# Extract data from the dragged node
	var drag_data = null
	match drag_type:
		"event_row":
			if drag_node.has_method("get_event_data"):
				drag_data = drag_node.get_event_data()
		"comment":
			if drag_node.has_method("get_comment_data"):
				drag_data = drag_node.get_comment_data()
		"group":
			if drag_node.has_method("get_group_data"):
				drag_data = drag_node.get_group_data()
	
	if not drag_data:
		return
	
	before_data_changed.emit()
	
	# Calculate drop position BEFORE removing the drag node from its parent
	# (so we can properly exclude it from visible children calculation)
	var drop_idx = _calculate_drop_index(drag_node)
	
	# Find and sync the source owner (another group or blocks_container)
	var source_owner = original_parent
	var max_depth = 5
	var depth = 0
	while source_owner and not (source_owner.has_method("_sync_children_to_data") or source_owner.has_signal("before_block_moved")) and depth < max_depth:
		source_owner = source_owner.get_parent()
		depth += 1
	
	# Remove from source and sync its data
	if original_parent and is_instance_valid(original_parent):
		original_parent.remove_child(drag_node)
		
		if source_owner:
			if source_owner.has_method("_sync_children_to_data"):
				# Source is a group
				source_owner._sync_children_to_data()
			# If source is blocks_container, it will sync on reload
	
	# Free the old visual node
	drag_node.queue_free()
	
	# Determine the type name for storage
	var type_name = drag_type
	if type_name == "event_row":
		type_name = "event"
	
	# Add to this group's data
	group_data.children.insert(drop_idx, {"type": type_name, "data": drag_data})
	
	# Rebuild UI
	_rebuild_child_nodes()
	data_changed.emit()


func _calculate_drop_index(dragged_node: Node) -> int:
	"""Calculate insert position for drop based on visual position."""
	var local_y = children_container.get_local_mouse_position().y
	
	# Get visible children (excluding drop_hint, indicator, and dragged node)
	var visible_children = []
	for child in children_container.get_children():
		if child == drop_hint or DropIndicatorManager.is_indicator(child):
			continue
		if child == dragged_node:
			continue
		# Skip invalid or deleted children
		if not is_instance_valid(child) or child.is_queued_for_deletion():
			continue
		if child.visible:
			visible_children.append(child)
	
	# Empty container or all excluded - insert at beginning
	if visible_children.is_empty():
		return 0
	
	# Find which visible child the mouse is above
	for i in range(visible_children.size()):
		var child = visible_children[i]
		var rect = child.get_rect()
		var mid_y = rect.position.y + rect.size.y * 0.5
		
		if local_y < mid_y:
			# Insert at this position (i is the visual index which maps to data index)
			return i
	
	# Insert at end (after all visible children)
	return visible_children.size()


func _get_child_node_at_data_index(data_idx: int) -> Node:
	"""Get the visual node corresponding to a data array index."""
	var skipped = 0
	for child in children_container.get_children():
		if child == drop_hint or DropIndicatorManager.is_indicator(child):
			continue
		# Skip invalid or deleted children
		if not is_instance_valid(child) or child.is_queued_for_deletion():
			continue
		if skipped == data_idx:
			return child
		skipped += 1
	return null


func _show_drop_indicator(at_position: Vector2, dragged_node: Node) -> void:
	"""Show drop indicator."""
	var local_y = children_container.get_local_mouse_position().y
	var result = DropIndicatorManager.calculate_drop_position(
		children_container, local_y, [drop_hint, dragged_node]
	)
	DropIndicatorManager.show_indicator(
		children_container, result["y_position"], children_container.size.x - 20
	)

func _exit_tree() -> void:
	_toggle_subs(false)
