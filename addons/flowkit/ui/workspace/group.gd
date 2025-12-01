@tool
extends MarginContainer
## Collapsible group block for organizing events, comments, and nested groups.
##
## Groups can contain any block type and support:
## - Drag-and-drop reordering of children
## - Collapse/expand functionality
## - Custom colors and titles
## - Nested groups

# === Signals ===
signal selected(group_node)  ## Emitted when group is selected
signal delete_requested  ## Emitted when deletion is requested
signal data_changed  ## Emitted when group data changes
signal child_added(child_data)  ## Emitted when a child is added
signal before_data_changed  ## Emitted before data changes (for undo)

# === Constants ===
const EVENT_ROW_SCENE = preload("res://addons/flowkit/ui/workspace/event_row.tscn")
const COMMENT_SCENE = preload("res://addons/flowkit/ui/workspace/comment.tscn")

# === State ===
var group_data: FKGroupBlock  ## The group's data resource
var is_selected: bool = false  ## Selection state
var registry: Node  ## Reference to the provider registry
var current_drop_index: int = -1  ## Current calculated drop position

# === Drag State ===
var _drag_start_pos: Vector2 = Vector2.ZERO  ## Mouse position when drag started
var _is_potential_drag: bool = false  ## Whether we're tracking a potential drag
var _is_processing_drop: bool = false  ## Prevent recursive drop processing
const DRAG_THRESHOLD: float = 8.0  ## Minimum pixels to move before starting drag

# === Styles ===
var normal_stylebox: StyleBox
var selected_stylebox: StyleBox

# === Node References ===
@onready var panel: PanelContainer = $Panel
@onready var header: HBoxContainer = $Panel/VBox/Header
@onready var collapse_btn: Label = $Panel/VBox/Header/CollapseButton
@onready var title_label: Label = $Panel/VBox/Header/TitleLabel
@onready var title_edit: LineEdit = $Panel/VBox/Header/TitleEdit
@onready var children_container: VBoxContainer = $Panel/VBox/ChildrenMargin/ChildrenContainer
@onready var drop_hint: Label = $Panel/VBox/ChildrenMargin/ChildrenContainer/DropHint
@onready var context_menu: PopupMenu = $ContextMenu

# === Lifecycle ===

func _ready() -> void:
	_setup_styles()
	_setup_signals()


func _input(event: InputEvent) -> void:
	"""Handle global input to cancel title edit when clicking outside."""
	if title_edit and title_edit.visible:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Check if click is outside the title_edit
			var global_rect = title_edit.get_global_rect()
			if not global_rect.has_point(event.global_position):
				_finish_title_edit(title_edit.text)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_hide_drop_indicator()

# === Setup ===

func _setup_styles() -> void:
	"""Initialize normal and selected styleboxes."""
	if panel:
		normal_stylebox = panel.get_theme_stylebox("panel")
		if normal_stylebox:
			selected_stylebox = normal_stylebox.duplicate()
			if selected_stylebox is StyleBoxFlat:
				selected_stylebox.border_color = Color(1.0, 1.0, 1.0, 1.0)
				selected_stylebox.border_width_left = 2
				selected_stylebox.border_width_top = 1
				selected_stylebox.border_width_right = 1
				selected_stylebox.border_width_bottom = 1


func _setup_signals() -> void:
	"""Connect UI signals."""
	# Connect collapse button (Label) click
	if collapse_btn:
		collapse_btn.gui_input.connect(_on_collapse_btn_input)
	if title_label:
		title_label.gui_input.connect(_on_title_input)
	if title_edit:
		title_edit.text_submitted.connect(_on_title_submitted)
		title_edit.focus_exited.connect(_on_title_focus_lost)
	if context_menu:
		context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	if header:
		header.gui_input.connect(_on_header_gui_input)
	gui_input.connect(_on_gui_input)


func _on_collapse_btn_input(event: InputEvent) -> void:
	"""Handle collapse button (triangle) input - collapse on release, drag on press+move."""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			# Select the group and start tracking for potential drag
			selected.emit(self)
			_drag_start_pos = event.position
			_is_potential_drag = true
		else:
			# Release - toggle collapse if we didn't drag
			if _is_potential_drag:
				_on_collapse_pressed()
			_is_potential_drag = false
	elif event is InputEventMouseMotion and _is_potential_drag:
		# Check if moved enough to start drag
		var distance = event.position.distance_to(_drag_start_pos)
		if distance >= DRAG_THRESHOLD and not get_viewport().gui_is_dragging():
			_is_potential_drag = false
			var preview := Label.new()
			preview.text = "📁 " + (group_data.title if group_data else "Group")
			preview.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 0.9))
			force_drag({"node": self, "type": "group"}, preview)

# === Data Management ===

func set_group_data(data: FKGroupBlock) -> void:
	"""Set the group's data and update display."""
	group_data = data
	call_deferred("_update_display")


func get_group_data() -> FKGroupBlock:
	"""Get the group's data resource."""
	return group_data


func set_registry(reg: Node) -> void:
	"""Set the provider registry reference."""
	registry = reg
	call_deferred("_update_display")

# === Display Updates ===

func _update_display() -> void:
	"""Update all visual elements from data."""
	if not group_data:
		return
	
	if title_label:
		title_label.text = group_data.title
	
	_update_collapse_state()
	_update_panel_color()
	_rebuild_children()


func update_display() -> void:
	"""Public method to refresh display."""
	_update_display()


func _update_collapse_state() -> void:
	"""Update collapse button and children visibility."""
	if not group_data:
		return
	
	if collapse_btn:
		collapse_btn.text = "▶" if group_data.collapsed else "▼"
	
	var children_margin = get_node_or_null("Panel/VBox/ChildrenMargin")
	if children_margin:
		children_margin.visible = not group_data.collapsed
	
	# Adjust height based on collapse state
	custom_minimum_size.y = 32 if group_data.collapsed else 60


func _update_panel_color() -> void:
	"""Update panel background and border colors."""
	if not panel or not group_data:
		return
	
	var style = panel.get_theme_stylebox("panel")
	if style:
		style = style.duplicate()
		if style is StyleBoxFlat:
			style.bg_color = group_data.color
			style.border_color = group_data.color.lightened(0.3)
			style.border_width_left = 3
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
		panel.add_theme_stylebox_override("panel", style)
		normal_stylebox = style
		
		# Update selected style
		selected_stylebox = style.duplicate()
		if selected_stylebox is StyleBoxFlat:
			selected_stylebox.border_color = Color(1.0, 1.0, 1.0, 1.0)
			selected_stylebox.border_width_left = 3
			selected_stylebox.border_width_top = 2
			selected_stylebox.border_width_right = 2
			selected_stylebox.border_width_bottom = 2

# === Children Management ===

func _rebuild_children() -> void:
	"""Rebuild child nodes from data."""
	if not children_container or not group_data:
		return
	
	# Clear existing children (except drop hint)
	for child in children_container.get_children():
		if child != drop_hint and not DropIndicatorManager.is_indicator(child):
			children_container.remove_child(child)
			child.queue_free()
	
	# Create children from data
	for child_dict in group_data.children:
		var child_type = child_dict.get("type", "")
		var child_data = child_dict.get("data")
		
		if child_type == "event" and child_data is FKEventBlock:
			var row = _create_event_row(child_data)
			children_container.add_child(row)
		elif child_type == "comment" and child_data is FKCommentBlock:
			var comment = _create_comment_block(child_data)
			children_container.add_child(comment)
		elif child_type == "group" and child_data is FKGroupBlock:
			var nested_group = _create_nested_group(child_data)
			children_container.add_child(nested_group)
	
	# Show hint if empty
	if drop_hint:
		drop_hint.visible = group_data.children.is_empty()


func _create_event_row(data: FKEventBlock) -> Control:
	"""Create an event row from data."""
	var row = EVENT_ROW_SCENE.instantiate()
	
	# Deep copy the data, preserving block_id
	var copy = FKEventBlock.new(data.block_id, data.event_id, data.target_node)
	copy.inputs = data.inputs.duplicate()
	copy.conditions = [] as Array[FKEventCondition]
	copy.actions = [] as Array[FKEventAction]
	
	for cond in data.conditions:
		var cond_copy = FKEventCondition.new()
		cond_copy.condition_id = cond.condition_id
		cond_copy.target_node = cond.target_node
		cond_copy.inputs = cond.inputs.duplicate()
		cond_copy.negated = cond.negated
		cond_copy.actions = [] as Array[FKEventAction]
		copy.conditions.append(cond_copy)
	
	for act in data.actions:
		var act_copy = FKEventAction.new()
		act_copy.action_id = act.action_id
		act_copy.target_node = act.target_node
		act_copy.inputs = act.inputs.duplicate()
		copy.actions.append(act_copy)
	
	row.set_event_data(copy)
	row.set_registry(registry)
	_connect_child_event_row_signals(row)
	return row


func _create_comment_block(data: FKCommentBlock) -> Control:
	"""Create a comment block from data."""
	var comment = COMMENT_SCENE.instantiate()
	var copy = FKCommentBlock.new()
	copy.text = data.text
	comment.set_comment_data(copy)
	_connect_child_comment_signals(comment)
	return comment


func _create_nested_group(data: FKGroupBlock) -> Control:
	"""Create a nested group from data."""
	var group_scene = load("res://addons/flowkit/ui/workspace/group.tscn")
	var nested = group_scene.instantiate()
	nested.set_group_data(data)
	nested.set_registry(registry)
	_connect_nested_group_signals(nested)
	return nested

# === Child Signal Connections ===

func _connect_child_event_row_signals(row) -> void:
	"""Connect signals for child event rows."""
	row.data_changed.connect(_on_child_data_changed)
	row.before_data_changed.connect(func(): before_data_changed.emit())
	row.selected.connect(func(node): selected.emit(node))


func _connect_child_comment_signals(comment) -> void:
	"""Connect signals for child comments."""
	comment.data_changed.connect(_on_child_data_changed)
	comment.selected.connect(func(node): selected.emit(node))
	comment.delete_requested.connect(_on_child_delete_requested.bind(comment))


func _connect_nested_group_signals(nested) -> void:
	"""Connect signals for nested groups."""
	nested.data_changed.connect(_on_child_data_changed)
	nested.before_data_changed.connect(func(): before_data_changed.emit())
	nested.selected.connect(func(node): selected.emit(node))
	nested.delete_requested.connect(_on_child_delete_requested.bind(nested))

# === Child Event Handlers ===

func _on_child_data_changed() -> void:
	"""Handle child data changes."""
	_sync_children_to_data()
	data_changed.emit()


func _on_child_delete_requested(child_node) -> void:
	"""Handle child deletion request."""
	before_data_changed.emit()
	_remove_child_node(child_node)
	data_changed.emit()


func _remove_child_node(child_node) -> void:
	"""Remove a child node and update data."""
	if not children_container or not group_data:
		return
	
	var child_idx = child_node.get_index()
	var data_idx = _get_data_index_for_child(child_idx)
	
	if data_idx >= 0:
		group_data.children.remove_at(data_idx)
	
	children_container.remove_child(child_node)
	child_node.queue_free()
	
	if drop_hint:
		drop_hint.visible = group_data.children.is_empty()


func _get_data_index_for_child(child_idx: int) -> int:
	"""Convert child node index to data array index."""
	var actual_idx = 0
	for i in range(children_container.get_child_count()):
		var child = children_container.get_child(i)
		if child == drop_hint or DropIndicatorManager.is_indicator(child):
			continue
		if i == child_idx:
			return actual_idx
		actual_idx += 1
	return -1


func _sync_children_to_data() -> void:
	"""Sync children_container state to group_data.children array."""
	if not children_container or not group_data:
		return
	
	group_data.children.clear()
	
	for child in children_container.get_children():
		if child == drop_hint or DropIndicatorManager.is_indicator(child):
			continue
		
		if child.has_method("get_event_data"):
			var data = child.get_event_data()
			if data:
				group_data.children.append({"type": "event", "data": data})
		elif child.has_method("get_comment_data"):
			var data = child.get_comment_data()
			if data:
				group_data.children.append({"type": "comment", "data": data})
		elif child.has_method("get_group_data"):
			var data = child.get_group_data()
			if data:
				group_data.children.append({"type": "group", "data": data})


# === Collapse/Expand ===

func _on_collapse_pressed() -> void:
	"""Toggle collapse state."""
	if group_data:
		before_data_changed.emit()
		group_data.collapsed = not group_data.collapsed
		_update_collapse_state()
		data_changed.emit()

# === Title Editing ===

func _on_title_input(event: InputEvent) -> void:
	"""Handle title label input - collapse on release, drag on press+move, edit on double-click."""
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos = event.position
		var text_width = title_label.get_theme_font("font").get_string_size(
			title_label.text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			title_label.get_theme_font_size("font_size")
		).x
		
		if event.pressed:
			# Select the group
			selected.emit(self)
			if event.double_click and click_pos.x <= text_width + 10:
				_start_title_edit()
				_is_potential_drag = false
			else:
				# Start tracking for potential drag
				_drag_start_pos = event.position
				_is_potential_drag = true
		else:
			# Release - toggle collapse if we didn't drag
			if _is_potential_drag:
				_on_collapse_pressed()
			_is_potential_drag = false
	elif event is InputEventMouseMotion and _is_potential_drag:
		# Check if moved enough to start drag
		var distance = event.position.distance_to(_drag_start_pos)
		if distance >= DRAG_THRESHOLD and not get_viewport().gui_is_dragging():
			_is_potential_drag = false
			var preview := Label.new()
			preview.text = "📁 " + (group_data.title if group_data else "Group")
			preview.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 0.9))
			force_drag({"node": self, "type": "group"}, preview)


func _start_title_edit() -> void:
	"""Enter title edit mode."""
	# Cancel any potential drag
	_is_potential_drag = false
	
	if title_label and title_edit:
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
	if title_edit and title_edit.visible:
		_finish_title_edit(title_edit.text)


func _finish_title_edit(new_text: String) -> void:
	"""Exit title edit mode and save changes."""
	if title_label and title_edit:
		before_data_changed.emit()
		title_edit.visible = false
		title_label.visible = true
		if group_data:
			group_data.title = new_text if new_text != "" else "Group"
			title_label.text = group_data.title
		data_changed.emit()

# === Input Handling ===

func _on_gui_input(event: InputEvent) -> void:
	"""Handle general input events."""
	# Don't handle if click is on children area
	if event is InputEventMouseButton and event.pressed:
		var children_margin = get_node_or_null("Panel/VBox/ChildrenMargin")
		if children_margin and children_margin.visible:
			var local_pos = children_margin.get_local_mouse_position()
			if children_margin.get_rect().has_point(local_pos + children_margin.position):
				# Click is in children area, let children handle it
				return
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			selected.emit(self)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			selected.emit(self)
			_show_context_menu(event.global_position)


func _on_header_gui_input(event: InputEvent) -> void:
	"""Handle header input (selection and drag initiation)."""
	# Don't process drag when in edit mode
	if title_edit and title_edit.visible:
		_is_potential_drag = false
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start tracking potential drag
				_drag_start_pos = event.position
				_is_potential_drag = true
				selected.emit(self)
			else:
				# Mouse released - reset drag tracking
				_is_potential_drag = false
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			selected.emit(self)
			_show_context_menu(event.global_position)
	elif event is InputEventMouseMotion and _is_potential_drag:
		# Check if we've moved enough to start a drag
		var distance = event.position.distance_to(_drag_start_pos)
		if distance >= DRAG_THRESHOLD and not get_viewport().gui_is_dragging():
			_is_potential_drag = false
			var preview := Label.new()
			preview.text = "📁 " + (group_data.title if group_data else "Group")
			preview.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 0.9))
			force_drag({"node": self, "type": "group"}, preview)

# === Context Menu ===

func _show_context_menu(pos: Vector2) -> void:
	"""Show the context menu."""
	if context_menu:
		context_menu.clear()
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


func _show_color_picker() -> void:
	"""Show color picker dialog."""
	var picker = ColorPickerButton.new()
	picker.color = group_data.color if group_data else Color(0.25, 0.22, 0.35, 1.0)
	
	var dialog = AcceptDialog.new()
	dialog.title = "Choose Group Color"
	dialog.add_child(picker)
	add_child(dialog)
	
	picker.color_changed.connect(func(color):
		if group_data:
			before_data_changed.emit()
			group_data.color = color
			_update_panel_color()
			data_changed.emit()
	)
	
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered()

# === Selection ===

func set_selected(value: bool) -> void:
	"""Set selection state and update visual."""
	is_selected = value
	if panel and normal_stylebox and selected_stylebox:
		if is_selected:
			panel.add_theme_stylebox_override("panel", selected_stylebox)
		else:
			panel.add_theme_stylebox_override("panel", normal_stylebox)

# === Drag and Drop ===

func _get_drag_data(_at_position: Vector2):
	"""Provide drag data when dragging this group."""
	var preview := Label.new()
	preview.text = "📁 " + (group_data.title if group_data else "Group")
	preview.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 0.9))
	set_drag_preview(preview)
	return {"node": self, "type": "group"}


func _can_drop_data(at_position: Vector2, data) -> bool:
	"""Check if drop is allowed and show indicator."""
	# Prevent recursive calls
	if _is_processing_drop:
		return false
	
	if not data is Dictionary:
		return false
	
	var drag_type = data.get("type", "")
	var drag_node = data.get("node")
	
	# Prevent dropping on self or ancestors
	if drag_node == self or _is_ancestor_of_node(drag_node):
		_hide_drop_indicator()
		return false
	
	# Accept blocks in children area
	if drag_type in ["event_row", "comment", "group"]:
		var children_margin = get_node_or_null("Panel/VBox/ChildrenMargin")
		if children_margin and children_margin.visible:
			var local_pos = children_margin.get_local_mouse_position()
			if children_margin.get_rect().has_point(local_pos + children_margin.position):
				_show_drop_indicator(at_position, drag_node)
				return true
	
	_hide_drop_indicator()
	return false


func _drop_data(at_position: Vector2, data) -> void:
	"""Handle the drop operation."""
	_hide_drop_indicator()
	
	if not data is Dictionary:
		return
	
	var drag_type = data.get("type", "")
	var drag_node = data.get("node")
	
	if not drag_node or not is_instance_valid(drag_node):
		return
	
	# Prevent dropping on self
	if drag_node == self:
		return
	
	# Check if drop is in children area
	var children_margin = get_node_or_null("Panel/VBox/ChildrenMargin")
	if children_margin and children_margin.visible:
		var local_pos = children_margin.get_local_mouse_position()
		if children_margin.get_rect().has_point(local_pos + children_margin.position):
			_handle_child_drop(drag_node, drag_type)


func _handle_child_drop(drag_node: Node, drag_type: String) -> void:
	"""Handle dropping a block into this group's children."""
	before_data_changed.emit()
	
	var original_parent = drag_node.get_parent()
	var is_internal = (original_parent == children_container)
	var drop_idx = _calculate_drop_index()
	
	if is_internal:
		# Internal reorder
		var current_idx = drag_node.get_index()
		var actual_idx = _adjust_drop_index(drop_idx, current_idx)
		
		if current_idx != actual_idx and current_idx != actual_idx - 1:
			if actual_idx > current_idx:
				actual_idx -= 1
			children_container.move_child(drag_node, actual_idx)
	else:
		# External drop
		if original_parent:
			original_parent.remove_child(drag_node)
			if original_parent.has_method("_sync_children_to_data"):
				original_parent._sync_children_to_data()
				if original_parent.has_signal("data_changed"):
					original_parent.data_changed.emit()
		
		children_container.add_child(drag_node)
		if drop_idx >= 0 and drop_idx < children_container.get_child_count():
			children_container.move_child(drag_node, drop_idx)
	
	# Reconnect signals
	match drag_type:
		"event_row": _connect_child_event_row_signals(drag_node)
		"comment": _connect_child_comment_signals(drag_node)
		"group": _connect_nested_group_signals(drag_node)
	
	_sync_children_to_data()
	if drop_hint:
		drop_hint.visible = false
	data_changed.emit()


func _adjust_drop_index(drop_idx: int, current_idx: int) -> int:
	"""Adjust drop index accounting for special nodes."""
	var actual_idx = drop_idx
	for i in range(mini(drop_idx, children_container.get_child_count())):
		var child = children_container.get_child(i)
		if child == drop_hint or DropIndicatorManager.is_indicator(child):
			actual_idx += 1
	return actual_idx


func _calculate_drop_index() -> int:
	"""Calculate drop index from mouse position."""
	var local_y = children_container.get_local_mouse_position().y
	var result = DropIndicatorManager.calculate_drop_position(children_container, local_y, [drop_hint])
	return result["index"]


func _is_ancestor_of_node(node: Node) -> bool:
	"""Check if this group is an ancestor of the given node."""
	if not node:
		return false
	var current = node.get_parent()
	while current:
		if current == self:
			return true
		current = current.get_parent()
	return false

# === Drop Indicator ===

func _show_drop_indicator(at_position: Vector2, dragged_node: Node) -> void:
	"""Show drop indicator in children container."""
	var local_y = children_container.get_local_mouse_position().y
	var result = DropIndicatorManager.calculate_drop_position(
		children_container, local_y, [drop_hint, dragged_node]
	)
	current_drop_index = result["index"]
	DropIndicatorManager.show_indicator(
		children_container, result["y_position"], children_container.size.x - 20
	)


func _hide_drop_indicator() -> void:
	"""Hide the drop indicator."""
	DropIndicatorManager.hide_indicator()
	current_drop_index = -1

# === Serialization ===

func get_all_children_data() -> Array:
	"""Get all children data recursively for serialization."""
	var result = []
	for child_dict in group_data.children:
		result.append(child_dict.duplicate(true))
	return result
