@tool
extends FKUnitUi
class_name FKGroupUi

## Collapsible group block for organizing events, comments, and nested groups.

signal delete_requested
signal data_changed
signal before_data_changed

signal add_event_requested(group_node)
signal add_comment_requested(group_node)

signal condition_edit_requested(condition_item, row)
signal action_edit_requested(action_item, row)

signal insert_event_below_requested(row)
signal insert_event_above_requested(target)
signal insert_comment_below_requested(row)
signal insert_comment_above_requested(target)

signal replace_event_requested(row)
signal edit_event_requested(row)
signal add_condition_requested(row)
signal add_action_requested(row)

signal condition_dropped(source_row, condition_data, target_row)
signal action_dropped(source_row, action_data, target_row)

# Branch signals
signal add_branch_requested(row, branch_id)
signal add_elseif_requested(branch_item, row)
signal add_else_requested(branch_item, row)
signal branch_condition_edit_requested(branch_item, row)
signal branch_action_add_requested(branch_item, row)
signal branch_action_edit_requested(action_item, branch_item, row)
signal nested_branch_add_requested(branch_item, branch_id, row)

# --- State ---

var _last_selected_child_data: Variant = null

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

func legitimize(block: FKUnit, registry: FKRegistry):
	if not is_editor_preview:
		return
	var group := block as FKGroup
	group.normalize_children()
	super.legitimize(block, registry)
# ---------------------------------------------------------
# FKUnitUi integration
# ---------------------------------------------------------

func _validate_block(to_set: FKUnit) -> bool:
	return to_set == null or to_set is FKGroup

func _on_block_changed() -> void:
	_refresh_display()

func _on_registry_set() -> void:
	_refresh_display()

func update_display() -> void:
	_refresh_display()

func _update_styling() -> void:
	var style := selected_stylebox if is_selected \
	else normal_stylebox
	panel.add_theme_stylebox_override("panel", style)

var _group: FKGroup:
	get:
		return _block as FKGroup

# ---------------------------------------------------------
# Lifecycle / subscriptions
# ---------------------------------------------------------

func _enter_tree() -> void:
	if is_editor_preview:
		return
	#print("Group ui enter tree")
	super._enter_tree()
	children_container.set_meta("_parent_group", self)


func _toggle_subs(on: bool) -> void:
	if on and not _is_subbed:
		gui_input.connect(_on_gui_input)
		
		collapse_btn.gui_input.connect(_on_collapse_btn_input)
		collapse_btn.mouse_entered.connect(_on_collapse_btn_mouse_entered)
		collapse_btn.mouse_exited.connect(_on_collapse_btn_mouse_exited)

		title_label.gui_input.connect(_on_title_input)

		title_edit.text_submitted.connect(_on_title_submitted)
		title_edit.focus_exited.connect(_on_title_focus_lost)

		context_menu.id_pressed.connect(_on_context_menu_id_pressed)

		header.gui_input.connect(_on_header_gui_input)
	elif not on and _is_subbed:
			gui_input.disconnect(_on_gui_input)

			collapse_btn.gui_input.disconnect(_on_collapse_btn_input)
			collapse_btn.mouse_entered.disconnect(_on_collapse_btn_mouse_entered)
			collapse_btn.mouse_exited.disconnect(_on_collapse_btn_mouse_exited)

			title_label.gui_input.disconnect(_on_title_input)

			title_edit.text_submitted.disconnect(_on_title_submitted)
			title_edit.focus_exited.disconnect(_on_title_focus_lost)

			context_menu.id_pressed.disconnect(_on_context_menu_id_pressed)

			header.gui_input.disconnect(_on_header_gui_input)

	super._toggle_subs(on)

func _input(event: InputEvent) -> void:
	if is_editor_preview:
		return
	var left_click: bool = event is InputEventMouseButton and event.pressed and \
	event.button_index == MOUSE_BUTTON_LEFT
	if not left_click or not title_edit.visible:
		return
		
	var global_rect := title_edit.get_global_rect()
	var mouse_pos: Vector2 = event.global_position
	var clicked_title_edit := global_rect.has_point(mouse_pos)
	if not clicked_title_edit:
		_finish_title_edit(title_edit.text)

func _notification(what: int) -> void:
	if is_editor_preview:
		return
	if what == NOTIFICATION_DRAG_END:
		DropIndicatorManager.hide_indicator()

# ---------------------------------------------------------
# Data / display
# ---------------------------------------------------------

func _refresh_display() -> void:
	if not _group:
		printerr("Cannot refresh display of gruop block. No group to work with.")
		return
	_update_title_display()
	_update_collapse_display()
	_update_color_display()
	_rebuild_child_nodes()
	_update_styling()

func _update_title_display() -> void:
	if _group:
		title_label.text = _group.title

func _update_collapse_display() -> void:
	if not _group:
		return
	collapse_btn.text = "▶" if _group.collapsed else "▼"
	children_margin.visible = not _group.collapsed
	custom_minimum_size.y = 32 if _group.collapsed else 60

func _update_color_display() -> void:
	if not _group:
		return
	normal_stylebox = normal_stylebox.duplicate()
	if normal_stylebox is StyleBoxFlat:
		normal_stylebox.bg_color = _group.color
		normal_stylebox.border_color = _group.color.lightened(0.3)
	panel.add_theme_stylebox_override("panel", normal_stylebox)

	selected_stylebox = selected_stylebox.duplicate()
	if selected_stylebox is StyleBoxFlat:
		selected_stylebox.bg_color = _group.color

func _rebuild_child_nodes() -> void:
	if not _group:
		printerr("Can't rebuild child nodes. Got no group to work with")
		return

	for child in children_container.get_children():
		if child != drop_hint and not DropIndicatorManager.is_indicator(child):
			children_container.remove_child(child)
			child.queue_free()

	for raw_child in _group.children:
		var unit = raw_child

		# Legacy format: { "type": String, "data": FKUnit }
		if raw_child is Dictionary:
			unit = raw_child.get("data")

		if unit is FKEventBlock:
			var row := _instantiate_event_row(unit)
			if row:
				children_container.add_child(row)
		elif unit is FKComment:
			var comment := _instantiate_comment(unit)
			if comment:
				children_container.add_child(comment)
		elif unit is FKGroup:
			var nested := _instantiate_group(unit)
			if nested:
				children_container.add_child(nested)


	if drop_hint:
		drop_hint.visible = _group.children.is_empty()

# ---------------------------------------------------------
# Child instantiation
# ---------------------------------------------------------

var EVENT_ROW_SCENE: PackedScene:
	get:
		return FKEditorGlobals.EVENT_ROW_SCENE

static var COMMENT_SCENE: PackedScene:
	get:
		return FKEditorGlobals.COMMENT_SCENE

func _instantiate_event_row(data: FKEventBlock) -> Control:
	if is_editor_preview:
		printerr("[FKGroupUi]: Cannot instantiate event row in editor preview mode")
		return null
	var row: FKEventRowUi = EVENT_ROW_SCENE.instantiate()
	row.call_deferred("legitimize", data, registry)
	_connect_event_row_signals(row, data)
	return row

func _connect_event_row_signals(row: FKEventRowUi, data: FKEventBlock) -> void:
	row.delete_event_requested.connect(_on_child_row_delete_requested.bind(data))
	row.selected.connect(func(n): _on_child_selected(data); selected.emit(n))
	row.condition_selected.connect(func(n): selected.emit(n))
	row.action_selected.connect(func(n): selected.emit(n))

	row.condition_edit_requested.connect(func(item): condition_edit_requested.emit(item, row))
	row.action_edit_requested.connect(func(item): action_edit_requested.emit(item, row))

	row.insert_event_below_requested.connect(func(r): insert_event_below_requested.emit(r))
	row.insert_comment_below_requested.connect(func(r): insert_comment_below_requested.emit(r))
	#row.insert_event_above_requested.connect(func(r): insert_event_above_requested.emit(r))
	#row.insert_comment_above_requested.connect(func(r): insert_comment_above_requested.emit(r))

	row.replace_event_requested.connect(func(r): replace_event_requested.emit(r))
	row.edit_event_requested.connect(func(r): edit_event_requested.emit(r))
	row.add_condition_requested.connect(func(r): add_condition_requested.emit(r))
	row.add_action_requested.connect(func(r): add_action_requested.emit(r))

	row.condition_dropped.connect(func(src, cond, tgt): condition_dropped.emit(src, cond, tgt))
	row.action_dropped.connect(func(src, act, tgt): action_dropped.emit(src, act, tgt))

	row.add_branch_requested.connect(func(r, bid): add_branch_requested.emit(r, bid))
	row.add_elseif_requested.connect(func(bi, r): add_elseif_requested.emit(bi, r))
	row.add_else_requested.connect(func(bi, r): add_else_requested.emit(bi, r))
	row.branch_condition_edit_requested.connect(func(bi, r): branch_condition_edit_requested.emit(bi, r))
	row.branch_action_add_requested.connect(func(bi, r): branch_action_add_requested.emit(bi, r))
	row.branch_action_edit_requested.connect(func(ai, bi, r): branch_action_edit_requested.emit(ai, bi, r))
	row.nested_branch_add_requested.connect(func(bi, bid, r): nested_branch_add_requested.emit(bi, bid, r))

	row.data_changed.connect(_on_child_modified)
	row.before_data_changed.connect(func(): before_data_changed.emit())

func _instantiate_comment(data: FKComment) -> Control:
	if is_editor_preview:
		printerr("[FKGroupUi]: Cannot instantiate comment in editor preview mode")
		return null
	var comment: FKCommentUi = COMMENT_SCENE.instantiate()
	comment.legitimize(data, registry)
	_connect_comment_signals_to_group_handlers(comment, data)
	return comment

func _connect_comment_signals_to_group_handlers(comment: FKCommentUi, data: FKComment) -> void:
	comment.delete_requested.connect(_on_child_comment_delete_requested.bind(data))
	comment.selected.connect(func(n): _on_child_selected(data); selected.emit(n))
	comment.block_contents_changed.connect(_on_child_modified)
	comment.insert_comment_above_requested.connect(func(c): insert_comment_above_requested.emit(c))
	comment.insert_comment_below_requested.connect(func(c): insert_comment_below_requested.emit(c))
	comment.insert_event_above_requested.connect(func(c): insert_event_above_requested.emit(c))
	comment.insert_event_below_requested.connect(func(c): insert_event_below_requested.emit(c))

func _instantiate_group(data: FKGroup) -> Control:
	if is_editor_preview:
		printerr("[FKGroupUi]: Cannot instantiate group in editor preview mode")
		return null
	var group_scene := load("res://addons/flowkit/ui/workspace/group_ui.tscn")
	var nested: FKGroupUi = group_scene.instantiate()
	data.normalize_children()
	nested.legitimize(data, registry)
	
	_attach_nested_group_signals(nested, data)
	return nested

func _attach_nested_group_signals(nested: FKGroupUi, data: FKGroup):
	nested.delete_requested.connect(_on_child_group_delete_requested.bind(data))
	nested.selected.connect(func(n): selected.emit(n))

	nested.block_contents_changed.connect(_on_child_modified)

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

	nested.add_branch_requested.connect(func(r, bid): add_branch_requested.emit(r, bid))
	nested.add_elseif_requested.connect(func(bi, r): add_elseif_requested.emit(bi, r))
	nested.add_else_requested.connect(func(bi, r): add_else_requested.emit(bi, r))
	
	nested.branch_condition_edit_requested.connect(func(bi, r): branch_condition_edit_requested.emit(bi, r))
	nested.branch_action_add_requested.connect(func(bi, r): branch_action_add_requested.emit(bi, r))
	nested.branch_action_edit_requested.connect(func(ai, bi, r): branch_action_edit_requested.emit(ai, bi, r))
	nested.nested_branch_add_requested.connect(func(bi, bid, r): nested_branch_add_requested.emit(bi, bid, r))

# ---------------------------------------------------------
# Child events / data sync
# ---------------------------------------------------------

func _on_child_modified() -> void:
	data_changed.emit()

func _on_child_row_delete_requested(row: Node, data: FKEventBlock) -> void:
	_remove_child_data(data)

func _on_child_comment_delete_requested(data: FKComment) -> void:
	_remove_child_data(data)

func _on_child_group_delete_requested(data: FKGroup) -> void:
	_remove_child_data(data)

func _remove_child_data(child_data) -> void:
	if not _group:
		return
	var idx := -1
	for i in range(_group.children.size()):
		if _group.children[i] == child_data:
			idx = i
			break
	if idx >= 0:
		print("Emitting FKGroupUi before_data_changed")
		before_data_changed.emit()
		_group.children.remove_at(idx)
		_rebuild_child_nodes()
		data_changed.emit()

func _sync_children_to_data() -> void:
	if not _group or is_editor_preview:
		return
		
	var new_children: Array[Node] = []
	for child in children_container.get_children():
		if child == drop_hint or DropIndicatorManager.is_indicator(child):
			continue
		if not is_instance_valid(child) or child.is_queued_for_deletion():
			continue
		if child is FKUnitUi:
			var unit: FKUnit = child.get_block()
			if unit:
				new_children.append(unit)
	_group.children = new_children

func add_event_to_group(event_data: FKEventBlock) -> void:
	if not _group or is_editor_preview:
		return
	before_data_changed.emit()
	_group.children.append(event_data)
	_rebuild_child_nodes()
	data_changed.emit()

# ---------------------------------------------------------
# Collapse / expand
# ---------------------------------------------------------

func _on_collapse_btn_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton or not event.pressed:
		return
		
	var left_click: bool = event.button_index == MOUSE_BUTTON_LEFT
	var right_click = event.button_index == MOUSE_BUTTON_RIGHT
	
	if left_click:
		_toggle_collapse()
	elif right_click:
		_show_context_menu(event.global_position)
	
	if left_click or right_click:
		set_selected(true)

func _on_collapse_btn_mouse_entered() -> void:
	collapse_btn.add_theme_color_override("font_color", Color.WHITE)

func _on_collapse_btn_mouse_exited() -> void:
	collapse_btn.remove_theme_color_override("font_color")

func _toggle_collapse() -> void:
	if _group:
		before_data_changed.emit()
		_group.collapsed = not _group.collapsed
		_update_collapse_display()
		data_changed.emit()

# ---------------------------------------------------------
# Title editing
# ---------------------------------------------------------

func _on_title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton: 
		_on_title_input_mouse_button_event(event)
	elif event is InputEventMouseMotion and _is_potential_drag:
		var distance: float = event.position.distance_to(_drag_start_pos)
		if distance >= DRAG_THRESHOLD and not get_viewport().gui_is_dragging():
			_is_potential_drag = false
			_start_group_drag()

func _on_title_input_mouse_button_event(event: InputEventMouseButton):
	var left_mb: bool = event.button_index == MOUSE_BUTTON_LEFT
	var right_mb: bool = event.button_index == MOUSE_BUTTON_RIGHT
	var left_click: bool = left_mb and event.pressed 
	var right_click: bool = right_mb and event.pressed
	
	if left_click or right_click:
		set_selected(true)
		
	var left_drag: bool = left_mb and not event.pressed 
		
	if left_mb:
		if left_click:
			if event.double_click:
				_start_title_edit()
				_is_potential_drag = false
			else:
				_drag_start_pos = event.position
				_is_potential_drag = true
		else:
			if _is_potential_drag:
				_is_potential_drag = false
	elif right_click:
		_show_context_menu(event.global_position)
	pass
	
func _on_title_input_mouse_motion(event: InputEventMouseMotion):
	if not _is_potential_drag:
		return
		
	var distance: float = event.position.distance_to(_drag_start_pos)
	if distance >= DRAG_THRESHOLD and not get_viewport().gui_is_dragging():
		_is_potential_drag = false
		_start_group_drag()

	
func _start_title_edit() -> void:
	_is_potential_drag = false
	title_label.visible = false
	title_edit.visible = true
	title_edit.text = _group.title if _group else "Group"
	title_edit.grab_focus()
	title_edit.select_all()

func _on_title_submitted(new_text: String) -> void:
	_finish_title_edit(new_text)

func _on_title_focus_lost() -> void:
	if title_edit and title_edit.visible:
		_finish_title_edit(title_edit.text)

func _finish_title_edit(new_text: String) -> void:
	before_data_changed.emit()
	title_edit.visible = false
	title_label.visible = true
	if _group:
		_group.title = new_text if new_text != "" else "Group"
		title_label.text = _group.title
	data_changed.emit()

# ---------------------------------------------------------
# Context menu
# ---------------------------------------------------------

func _show_context_menu(pos: Vector2) -> void:
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
	match id:
		MenuChoices.START_TITLE_EDIT: _start_title_edit()
		MenuChoices.SHOW_COLOR_PICKER: _show_color_picker()
		MenuChoices.DELETE_REQUESTED: delete_requested.emit()
		MenuChoices.ADD_EVENT_REQUESTED: add_event_requested.emit(self)
		MenuChoices.ADD_COMMENT_TO_GROUP: _add_comment_to_group()

enum MenuChoices
{
	NULL,
	START_TITLE_EDIT = 0,
	SHOW_COLOR_PICKER = 1,
	DELETE_REQUESTED = 2,
	ADD_EVENT_REQUESTED = 10,
	ADD_COMMENT_TO_GROUP = 11
}

func _on_child_selected(child_data: Variant) -> void:
	_last_selected_child_data = child_data

func _add_comment_to_group() -> void:
	if not _group:
		return
	before_data_changed.emit()
	var comment := FKComment.new()
	comment.text = ""
	var insert_index := _group.children.size()
	if _last_selected_child_data != null:
		for j in range(_group.children.size()):
			if _group.children[j] == _last_selected_child_data:
				insert_index = j + 1
				break
	_group.children.insert(insert_index, comment)
	_rebuild_child_nodes()
	data_changed.emit()

func _show_color_picker() -> void:
	if not _group:
		return
	var picker := ColorPickerButton.new()
	picker.color = _group.color
	var dialog := AcceptDialog.new()
	dialog.title = "Choose Group Color"
	dialog.add_child(picker)
	add_child(dialog)

	var original_color := picker.color

	picker.color_changed.connect(func(color):
		_group.color = color
		_update_color_display()
	)

	dialog.confirmed.connect(func():
		before_data_changed.emit()
		_group.color = picker.color
		_update_color_display()
		data_changed.emit()
		dialog.queue_free()
	)

	dialog.canceled.connect(func():
		_group.color = original_color
		_update_color_display()
		dialog.queue_free()
	)

	dialog.popup_centered()

# ---------------------------------------------------------
# General input / header input
# ---------------------------------------------------------

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if children_margin and children_margin.visible:
			var local_pos := children_margin.get_local_mouse_position()
			if children_margin.get_rect().has_point(local_pos + children_margin.position):
				return
		if event.button_index == MOUSE_BUTTON_LEFT:
			set_selected(true)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			set_selected(true)
			_show_context_menu(event.global_position)

func _on_header_gui_input(event: InputEvent) -> void:
	if title_edit.visible:
		_is_potential_drag = false
		return
		
	if event is InputEventMouseButton:
		_on_header_gui_input_mouse_button(event)
	elif event is InputEventMouseMotion:
		_on_header_gui_input_mouse_motion(event)

func _on_header_gui_input_mouse_button(event: InputEventMouseButton):
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_start_pos = event.position
			_is_potential_drag = true
			set_selected(true)
		else:
			_is_potential_drag = false
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		set_selected(true)
		_show_context_menu(event.global_position)
		
func _on_header_gui_input_mouse_motion(event: InputEventMouseMotion):
	if not _is_potential_drag:
		return
	var distance: float = event.position.distance_to(_drag_start_pos)
	if distance >= DRAG_THRESHOLD and not get_viewport().gui_is_dragging():
		_is_potential_drag = false
		_start_group_drag()
# ---------------------------------------------------------
# Drag & drop
# ---------------------------------------------------------

func _start_group_drag() -> void:
	var preview := _prep_preview()
	var drag_data := FKDragData.new(DragTarget.Type.GROUP, self, _group)
	force_drag(drag_data, preview)

func _prep_preview() -> Control:
	var preview := Label.new()
	preview.text = "📁 " + (_group.title if _group else "Group")
	preview.add_theme_color_override("font_color", _preview_color)
	return preview
	
static var _preview_color := Color(0.6, 0.8, 1.0, 0.9)

func _get_drag_data(_at_position: Vector2) -> FKDragData:
	if not _group:
		return null
	var preview := _prep_preview()
	set_drag_preview(preview)
	var result := FKDragData.new(DragTarget.Type.GROUP, self, _group)
	return result

func _can_drop_data(at_position: Vector2, data) -> bool:
	if data is not FKDragData:
		return false
	var drag_data := data as FKDragData

	var drag_type := drag_data.type
	var drag_node := drag_data.node

	if drag_node == self:
		DropIndicatorManager.hide_indicator()
		return false

	var current := drag_node
	while current:
		if current == self:
			DropIndicatorManager.hide_indicator()
			return false
		current = current.get_parent() if current.get_parent() else null

	if drag_type not in [DragTarget.Type.EVENT_ROW, DragTarget.Type.COMMENT, DragTarget.Type.GROUP]:
		DropIndicatorManager.hide_indicator()
		return false

	if not children_margin.visible:
		DropIndicatorManager.hide_indicator()
		return false

	var local_pos := children_margin.get_local_mouse_position()
	var rect := children_margin.get_rect()
	var real_pos := local_pos + children_margin.position
	if rect.has_point(real_pos):
		_show_drop_indicator(at_position, drag_node)
		return true

	DropIndicatorManager.hide_indicator()
	return false

func _drop_data(at_position: Vector2, data) -> void:
	DropIndicatorManager.hide_indicator()
	
	if data is not FKDragData:
		return
	var drag_data := data as FKDragData
	
	var drag_node := drag_data.node
	if not drag_node or not is_instance_valid(drag_node):
		return

	if not children_margin.visible:
		return

	var local_pos := children_margin.get_local_mouse_position()
	var rect := children_margin.get_rect()
	var real_pos :=local_pos + children_margin.position
	var pos_in_rect := rect.has_point(real_pos)
	if not pos_in_rect:
		return

	_handle_drop(drag_node, drag_data)

func _handle_drop(drag_node: Node, drag_data: FKDragData) -> void:
	var original_parent := drag_node.get_parent()

	if original_parent == children_container:
		_handle_internal_reorder(drag_node)
		return

	_handle_external_drop(drag_node, drag_data, original_parent)

func _handle_internal_reorder(drag_node: Node) -> void:
	if not children_container:
		return

	var visible_children := _get_visible_unit_children()

	var local_y := children_container.get_local_mouse_position().y
	var target_visual_idx := visible_children.size()
	for i in range(visible_children.size()):
		var child := visible_children[i]
		var rect := child.get_rect()
		var mid_y := rect.position.y + rect.size.y * 0.5
		if local_y < mid_y:
			target_visual_idx = i
			break

	var current_visual_idx := visible_children.find(drag_node)
	if target_visual_idx == current_visual_idx or target_visual_idx == current_visual_idx + 1:
		return

	var target_child_idx: int
	if target_visual_idx >= visible_children.size():
		target_child_idx = children_container.get_child_count()
	else:
		target_child_idx = visible_children[target_visual_idx].get_index()

	var current_child_idx := drag_node.get_index()
	if target_child_idx > current_child_idx:
		target_child_idx -= 1

	before_data_changed.emit()
	children_container.move_child(drag_node, target_child_idx)
	_sync_children_to_data()
	data_changed.emit()

func _get_visible_unit_children() -> Array[Control]:
	var visible_children: Array[Control] = []
	
	for child in children_container.get_children():
		if child == drop_hint or DropIndicatorManager.is_indicator(child):
			continue
		if not is_instance_valid(child) or child.is_queued_for_deletion():
			continue
		if child.visible:
			visible_children.append(child)
			
	return visible_children

func _handle_external_drop(drag_node: Node, drag_data: FKDragData, original_parent: Node) -> void:
	var unit := drag_data.data as FKUnit
	if not unit or not _group:
		return

	before_data_changed.emit()

	var drop_idx := _calculate_drop_index(drag_node)

	var source_owner := original_parent
	var max_depth := 5
	var depth := 0
	while source_owner and not (source_owner.has_method("_sync_children_to_data") or \
	source_owner.has_signal("before_block_moved")) and depth < max_depth:
		source_owner = source_owner.get_parent()
		depth += 1

	if original_parent and is_instance_valid(original_parent):
		original_parent.remove_child(drag_node)

	if source_owner and source_owner.has_method("_sync_children_to_data"):
		source_owner._sync_children_to_data()

	drag_node.queue_free()

	_group.children.insert(drop_idx, unit)
	_rebuild_child_nodes()
	data_changed.emit()

func _calculate_drop_index(dragged_node: Node) -> int:
	if not children_container:
		return _group.children.size() if _group else 0

	var local_y := children_container.get_local_mouse_position().y
	var visible_children := []
	for child in children_container.get_children():
		if child == drop_hint or DropIndicatorManager.is_indicator(child):
			continue
		if child == dragged_node:
			continue
		if not is_instance_valid(child) or child.is_queued_for_deletion():
			continue
		if child.visible:
			visible_children.append(child)

	if visible_children.is_empty():
		return 0

	for i in range(visible_children.size()):
		var child: Control = visible_children[i]
		var rect := child.get_rect()
		var mid_y := rect.position.y + rect.size.y * 0.5
		if local_y < mid_y:
			return i

	return visible_children.size()

func _show_drop_indicator(at_position: Vector2, _drag_node: Node) -> void:
	DropIndicatorManager.show_indicator(children_container, at_position.y)

func _to_string() -> String:
	var result := "\nFKGroupUi"
	
	if _block != null:
		result += "\nhas block: true"
	return result
	
func get_class() -> String:
	return "FKGroupUi"

func get_block() -> FKGroup:
	if _block is FKGroup:
		return _block as FKGroup
	else:
		return null
		
