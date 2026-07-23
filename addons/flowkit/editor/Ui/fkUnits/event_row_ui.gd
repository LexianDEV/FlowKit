##
## Represents an Action entry (parented to an Event Block) in the FlowKit editor.
##
@tool
extends FKUnitUi
class_name FKEventRowUi

# Scene Dependencies
var CONDITION_ITEM_SCENE: PackedScene:
	get:
		return FKEditorGlobals.CONDITION_ITEM_SCENE

var BRANCH_ITEM_SCENE: PackedScene:
	get:
		return FKEditorGlobals.BRANCH_ITEM_SCENE

var ACTION_ITEM_SCENE: PackedScene:
	get:
		return FKEditorGlobals.ACTION_ITEM_SCENE

signal insert_event_below_requested(event_row: FKEventRowUi)
signal insert_comment_below_requested(event_row: FKEventRowUi)
signal replace_event_requested(event_row: FKEventRowUi)
signal delete_event_requested(event_row: FKEventRowUi)
signal edit_event_requested(event_row: FKEventRowUi)

signal add_condition_requested(event_row: FKEventRowUi)
signal add_action_requested(event_row: FKEventRowUi)

signal condition_selected(condition_node: FKConditionUnitUi)
signal action_selected(action_node: FKActionUnitUi)

signal condition_edit_requested(condition_item: FKConditionUnitUi)
signal action_edit_requested(action_item: FKActionUnitUi)

signal condition_dropped(source_row, condition_data, target_row)
signal action_dropped(source_row, action_data, target_row)

# Branch signals
signal add_branch_requested(event_row: FKEventRowUi, branch_id: String)
signal add_elseif_requested(branch_item: FKBranchUnitUi, event_row: FKEventRowUi)
signal add_else_requested(branch_item: FKBranchUnitUi, event_row: FKEventRowUi)
signal branch_condition_edit_requested(branch_item: FKBranchUnitUi, event_row: FKEventRowUi)
signal branch_action_add_requested(branch_item: FKBranchUnitUi, event_row: FKEventRowUi)
signal branch_action_edit_requested(action_item: FKActionUnitUi, branch_item: FKBranchUnitUi, \
event_row: FKEventRowUi)
signal nested_branch_add_requested(branch_item: FKBranchUnitUi, branch_id: String, \
event_row: FKEventRowUi)

# Ui and Styling
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

var _header_label_format: String = "⚡ %s (%s)%s"
const _preview_label_color := Color(0.9, 0.95, 0.9, 0.7)

# ---------------------------------------------------------
# FKUnitUi integration
# ---------------------------------------------------------

func _validate_unit(to_set: FKUnit) -> bool:
	return to_set == null or to_set is FKEventUnit

func _update_styling() -> void:
	var style := selected_stylebox if is_selected \
	else normal_stylebox
	panel.add_theme_stylebox_override("panel", style)

# Public version since we want to allow other modules to ask this to update
# its display.
func update_display() -> void:
	_update_display()

func _toggle_subs(on: bool) -> void:
	if on and not _is_subbed:
		gui_input.connect(_on_gui_input)
		context_menu.id_pressed.connect(_on_context_menu_id_pressed)
		_toggle_label_subs(true)
		_toggle_drop_zone_signals(true)
	elif not on and _is_subbed:
		gui_input.disconnect(_on_gui_input)
		context_menu.id_pressed.disconnect(_on_context_menu_id_pressed)
		_toggle_label_subs(false)
		_toggle_drop_zone_signals(false)

	super._toggle_subs(on)

# ---------------------------------------------------------
# Input & Context Menu
# ---------------------------------------------------------

func _on_gui_input(event: InputEvent) -> void:
	var mouse_click: bool = event is InputEventMouseButton and event.pressed
	if not mouse_click:
		return

	var right_click: bool = event.button_index == MOUSE_BUTTON_RIGHT
	if right_click:
		var mouse_pos := DisplayServer.mouse_get_position()
		show_context_menu(mouse_pos)
		
	var left_click: bool = event.button_index == MOUSE_BUTTON_LEFT
	if left_click or right_click:
		set_selected(true)
		get_viewport().set_input_as_handled()
		
func show_context_menu(global_pos: Vector2) -> void:
	context_menu.clear()
	context_menu.add_item("Add Event Below", MenuChoices.ADD_EVENT_BELOW)
	context_menu.add_item("Add Comment Below", MenuChoices.ADD_COMMENT_BELOW)
	context_menu.add_separator()
	context_menu.add_item("Replace Event", MenuChoices.REPLACE_EVENT)
	context_menu.add_item("Edit Event", MenuChoices.EDIT_EVENT)
	context_menu.add_separator()
	context_menu.add_item("Delete Event", MenuChoices.DELETE_EVENT)

	context_menu.position = global_pos
	context_menu.popup()

enum MenuChoices {
	NULL,
	ADD_EVENT_BELOW = 0,
	REPLACE_EVENT = 1,
	EDIT_EVENT = 2,
	DELETE_EVENT = 3,
	ADD_COMMENT_BELOW = 4
}

func _on_context_menu_id_pressed(choice: int) -> void:
	match choice:
		MenuChoices.ADD_EVENT_BELOW:
			insert_event_below_requested.emit(self)
		MenuChoices.REPLACE_EVENT:
			replace_event_requested.emit(self)
		MenuChoices.EDIT_EVENT:
			edit_event_requested.emit(self)
		MenuChoices.DELETE_EVENT:
			delete_event_requested.emit(self)
		MenuChoices.ADD_COMMENT_BELOW:
			insert_comment_below_requested.emit(self)

# ---------------------------------------------------------
# Add Condition / Action Labels
# ---------------------------------------------------------

func _toggle_label_subs(on: bool) -> void:
	if on and !_is_subbed:
		add_condition_label.gui_input.connect(_on_add_condition_input)
		add_condition_label.mouse_entered.connect(_on_add_condition_hover.bind(true))
		add_condition_label.mouse_exited.connect(_on_add_condition_hover.bind(false))

		add_action_label.gui_input.connect(_on_add_action_input)
		add_action_label.mouse_entered.connect(_on_add_action_hover.bind(true))
		add_action_label.mouse_exited.connect(_on_add_action_hover.bind(false))
		
	elif !on and _is_subbed:
		add_condition_label.gui_input.disconnect(_on_add_condition_input)
		add_condition_label.mouse_entered.disconnect(_on_add_condition_hover)
		add_condition_label.mouse_exited.disconnect(_on_add_condition_hover)

		add_action_label.gui_input.disconnect(_on_add_action_input)
		add_action_label.mouse_entered.disconnect(_on_add_action_hover)
		add_action_label.mouse_exited.disconnect(_on_add_action_hover)

func _on_add_condition_input(event: InputEvent) -> void:
	var left_click: bool = event is InputEventMouseButton and \
		event.button_index == MOUSE_BUTTON_LEFT and event.pressed
	if not left_click:
		return

	_flash_label(add_condition_label)
	add_condition_requested.emit(self)

func _flash_label(label: Label) -> void:
	label.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0, 1))
	var tween = create_tween()
	tween.tween_interval(0.15)
	tween.tween_callback(func():
		if is_instance_valid(label):
			label.add_theme_color_override("font_color", Color(0.5, 0.55, 0.6, 1))
	)

func _on_add_condition_hover(is_hovering: bool) -> void:
	var color_to_apply := _hover_color if is_hovering \
	else _normal_color
	add_condition_label.add_theme_color_override("font_color", color_to_apply)

static var _hover_color := Color(0.7, 0.75, 0.8, 1)
static var _normal_color := Color(0.5, 0.55, 0.6, 1)
# ^For the context menu

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

	var branches: Array = []
	if registry:
		branches = registry.branch_providers

	for i in range(branches.size()):
		var branch_provider = branches[i]
		if branch_provider.has_method("get_name"):
			popup.add_item("Add %s" % branch_provider.get_name(), 100 + i)

	popup.id_pressed.connect(func(id):
		if id == MenuChoices.ADD_EVENT_BELOW:
			add_action_requested.emit(self)
		elif id >= 100:
			var branch_idx = id - 100
			if branch_idx < branches.size():
				var bid = branches[branch_idx].get_id()
				add_branch_requested.emit(self, bid)
		popup.queue_free()
	)

	add_child(popup)
	popup.position = DisplayServer.mouse_get_position()
	popup.popup()

func _on_add_action_hover(is_hovering: bool) -> void:
	var color_to_apply: Color = _hover_color if is_hovering \
	else _normal_color
	add_action_label.add_theme_color_override("font_color", color_to_apply)


# ---------------------------------------------------------
# Drop Zones
# ---------------------------------------------------------

func _toggle_drop_zone_signals(on: bool) -> void:
	if on && !_is_subbed:
		if condition_drop_zone.has_signal("item_dropped"):
			condition_drop_zone.item_dropped.connect(_on_condition_drop_zone_dropped)
		if action_drop_zone.has_signal("item_dropped"):
			action_drop_zone.item_dropped.connect(_on_action_drop_zone_dropped)
	elif !on && _is_subbed:
		if condition_drop_zone.has_signal("item_dropped"):
			condition_drop_zone.item_dropped.disconnect(_on_condition_drop_zone_dropped)
		if action_drop_zone.has_signal("item_dropped"):
			action_drop_zone.item_dropped.disconnect(_on_action_drop_zone_dropped)

func _on_condition_drop_zone_dropped(drag_data: FKDragData) -> void:
	var source_node := drag_data.node
	if not source_node or not is_instance_valid(source_node):
		return

	var source_row = _find_parent_event_row(source_node)
	if not source_row or source_row == self:
		return

	var cond_data := drag_data.data
	if cond_data:
		condition_dropped.emit(source_row, cond_data, self)

func _find_parent_event_row(node: Node):
	var current = node.get_parent()
	while current:
		if current is FKEventRowUi:
			return current
		current = current.get_parent()
	return null
	
func _on_action_drop_zone_dropped(drag_data: FKDragData) -> void:
	var source_node := drag_data.node
	if not source_node or not is_instance_valid(source_node):
		return

	var source_row = _find_parent_event_row(source_node)
	if not source_row:
		return

	var act_data := drag_data.data
	if act_data:
		if source_row == self:
			_pull_action_to_top_level(act_data)
		else:
			action_dropped.emit(source_row, act_data, self)
			
# ---------------------------------------------------------
# Display / Rebuild
# ---------------------------------------------------------

func _update_display() -> void:
	#print("Updating display for " + _to_string())
	_update_event_header()
	_update_conditions()
	_update_actions()
	
func _update_event_header() -> void:
	var e := _get_event()
	if not e:
		printerr("[FKEventRowUi]: Cannot update event header. Got no event to work with.")
		return

	var display_name = _get_event_header_display_name(e)
	var params_text = _get_params_text(e)
	var node_name = String(e.target_node).get_file()

	event_header_label.text = _header_label_format % [display_name, node_name, params_text]

func _get_event() -> FKEventUnit:
	return get_unit() as FKEventUnit

func _update_conditions() -> void:
	var e := _get_event()
	if not e:
		return

	for child in conditions_container.get_children():
		conditions_container.remove_child(child)
		child.queue_free()

	for condition_data in e.conditions:
		var item: FKConditionUnitUi = CONDITION_ITEM_SCENE.instantiate()
		item.legitimize(condition_data, _globals)
		_connect_condition_item_signals(item)
		conditions_container.add_child(item)

func _get_event_header_display_name(e: FKEventUnit) -> String:
	var result: String = e.event_id
	var from_registry := _provider_name_from_registry(e)
	if from_registry.length() > 0:
		result = from_registry
	return result

func _provider_name_from_registry(e: FKEventUnit) -> String:
	var result: String = ""
	if registry:
		for provider in registry.event_providers:
			if provider.has_method("get_id") and provider.get_id() == e.event_id:
				if provider.has_method("get_name"):
					result = provider.get_name()
				break
	return result

func _get_params_text(e: FKEventUnit) -> String:
	var params_text = ""
	if not e.inputs.is_empty():
		var param_pairs = []
		for key in e.inputs:
			param_pairs.append("%s" % [e.inputs[key]])
		params_text = " (" + ", ".join(param_pairs) + ")"
	return params_text

func _update_actions() -> void:
	var e := _get_event()
	if not e:
		return
	
	_clear_action_container()	

	for act_data in e.actions:
		if act_data.is_branch:
			_add_branch_item_based_on(act_data)
		else:
			_add_regular_action_item_based_on(act_data)

func _clear_action_container():
	for child in actions_container.get_children():
		actions_container.remove_child(child)
		child.queue_free()

func _add_branch_item_based_on(act_data: FKActionUnit):
	#print("Adding branch action in Event row ui")
	var branch: FKBranchUnitUi = BRANCH_ITEM_SCENE.instantiate()
	branch.legitimize(act_data, _globals)
	_connect_branch_item_signals(branch)
	actions_container.add_child(branch)

func _add_regular_action_item_based_on(act_data: FKActionUnit):
	#print("Adding regular action in Event row ui")
	var item: FKActionUnitUi = ACTION_ITEM_SCENE.instantiate()
	item.legitimize(act_data, _globals)
	_connect_action_item_signals(item)
	actions_container.add_child(item)

# ---------------------------------------------------------
# Condition / Action / Branch signal wiring
# ---------------------------------------------------------

func _connect_condition_item_signals(item: FKConditionUnitUi) -> void:
	item.selected.connect(_on_condition_selected)
	item.edit_requested.connect(_on_condition_item_edit)
	item.delete_requested.connect(_on_condition_item_delete)
	item.negate_requested.connect(_on_condition_item_negate)
	item.reorder_requested.connect(_on_condition_reorder)

func _on_condition_selected(act: FKConditionUnitUi):
	print("[FKEventRowUi]: Condition selected")
	condition_selected.emit(act)
	
func _connect_action_item_signals(item: FKActionUnitUi) -> void:
	item.selected.connect(_on_action_selected)
	item.edit_requested.connect(_on_action_item_edit)
	item.delete_requested.connect(_on_action_item_delete)
	item.reorder_requested.connect(_on_action_reorder)

func _on_action_selected(act: FKActionUnitUi):
	print("[FKEventRowUi]: Action selected")
	action_selected.emit(act)
	
func _connect_branch_item_signals(branch: FKBranchUnitUi) -> void:
	branch.selected.connect(_on_branch_selected)
	branch.edit_condition_requested.connect(_on_branch_condition_edit_requested)
	branch.delete_requested.connect(_on_branch_item_delete)
	branch.add_elseif_requested.connect(_on_branch_add_elseif_requested)
	branch.add_else_requested.connect(_on_branch_add_else_requested)
	branch.add_branch_action_requested.connect(_on_branch_add_nested_branch_requested)
	branch.branch_action_edit_requested.connect(_on_branch_action_edit_requested)
	branch.branch_action_selected.connect(_on_branch_action_selected)
	branch.reorder_requested.connect(_on_action_reorder)
	branch.action_cross_reorder_requested.connect(_on_action_cross_reorder)
	branch.action_dropped_into_branch.connect(_on_action_dropped_into_branch)
	branch.before_contents_changed.connect(_on_branch_before_contents_changed)
	branch.add_nested_branch_requested.connect(_on_nested_branch_requested)

func _on_branch_selected(act: FKBranchUnitUi):
	print("[FKEventRowUi]: Branch Unit selected")
	action_selected.emit(act)
	
func _on_branch_condition_edit_requested(branch: FKBranchUnitUi):
	branch_condition_edit_requested.emit(branch, self)
	
func _on_branch_add_elseif_requested(branch: FKBranchUnitUi):
	add_elseif_requested.emit(branch, self)
	
func _on_branch_add_else_requested(branch: FKBranchUnitUi):
	add_else_requested.emit(branch, self)
	
func _on_branch_add_nested_branch_requested(branch: FKBranchUnitUi):
	branch_action_add_requested.emit(branch, self)

func _on_branch_action_edit_requested(action_item, branch: FKBranchUnitUi):
	branch_action_edit_requested.emit(action_item, branch, self)

func _on_branch_action_selected(action_item: FKActionUnitUi):
	action_selected.emit(action_item)
	
func _on_branch_before_contents_changed(branch: FKBranchUnitUi):
	before_contents_changed.emit(self)

func _on_nested_branch_requested(requester: FKBranchUnitUi, branch_id: String):
	nested_branch_add_requested.emit(requester, branch_id, self)
	
# ---------------------------------------------------------
# Condition handlers
# ---------------------------------------------------------

func _on_branch_item_delete(item: FKUnitUi) -> void:
	before_contents_changed.emit(self)
	var act_data := item.get_unit()
	var e := _get_event()
	if act_data and e:
		var idx = e.actions.find(act_data)
		if idx >= 0:
			e.actions.remove_at(idx)
		_update_actions()

func _on_condition_item_edit(item: FKConditionUnitUi) -> void:
	condition_edit_requested.emit(item)

func _on_condition_item_delete(item: FKConditionUnitUi) -> void:
	before_contents_changed.emit(self)
	var cond_data = item.get_unit()
	var e := _get_event()
	if cond_data and e:
		var idx = e.conditions.find(cond_data)
		if idx >= 0:
			e.conditions.remove_at(idx)
		_update_conditions()
		contents_changed.emit(self)

func _on_condition_item_negate(item: FKConditionUnitUi) -> void:
	before_contents_changed.emit(self)
	var cond_data = item.get_unit()
	if cond_data:
		cond_data.negated = not cond_data.negated
		item.update_display()
		contents_changed.emit(self)

# ---------------------------------------------------------
# Action handlers
# ---------------------------------------------------------

func _on_action_item_edit(item: FKActionUnitUi) -> void:
	action_edit_requested.emit(item)

func _on_action_item_delete(item: FKActionUnitUi) -> void:
	before_contents_changed.emit(self)
	var act_data = item.get_unit()
	var e := _get_event()
	if act_data and e:
		var idx = e.actions.find(act_data)
		if idx >= 0:
			e.actions.remove_at(idx)
		_update_actions()
		contents_changed.emit(self)

# ---------------------------------------------------------
# Reordering helpers
# ---------------------------------------------------------

func _on_condition_reorder(source_item: FKConditionUnitUi, target_item: FKConditionUnitUi, \
drop_above: bool) -> void:
	var e := _get_event()
	if not e:
		return

	var source_data := source_item.get_unit()
	var target_data := target_item.get_unit()
	if not source_data or not target_data:
		return

	var source_idx := e.conditions.find(source_data)
	var target_idx := e.conditions.find(target_data)

	if source_idx < 0 or target_idx < 0:
		return
	if source_idx == target_idx:
		return

	var final_idx: int
	if drop_above:
		final_idx = target_idx if source_idx > target_idx else target_idx - 1
	else:
		final_idx = target_idx + 1 if source_idx > target_idx else target_idx

	if source_idx == final_idx:
		return

	before_contents_changed.emit(self)

	e.conditions.remove_at(source_idx)
	if source_idx < target_idx:
		target_idx -= 1

	var insert_idx = target_idx if drop_above else target_idx + 1
	e.conditions.insert(insert_idx, source_data)

	_update_conditions()
	contents_changed.emit(self)

func _recursive_remove_action(actions_array: Array, target_action) -> bool:
	var idx = actions_array.find(target_action)
	if idx >= 0:
		actions_array.remove_at(idx)
		return true

	for act in actions_array:
		if act.is_branch and _recursive_remove_action(act.branch_actions, target_action):
			return true

	return false

func _on_action_cross_reorder(source_data, target_data, is_drop_above: bool, 
target_branch: FKActionUnitUi) -> void:
	var e := _get_event()
	if not e:
		return

	before_contents_changed.emit(self)

	_recursive_remove_action(e.actions, source_data)

	var action_data: FKActionUnit = target_branch.get_unit()
	var target_actions := action_data.branch_actions
	var target_idx := target_actions.find(target_data)

	if target_idx >= 0:
		var insert_idx = target_idx if is_drop_above else target_idx + 1
		target_actions.insert(insert_idx, source_data)
	else:
		target_actions.append(source_data)

	_update_actions()
	contents_changed.emit(self)

func _on_action_dropped_into_branch(source_item: FKActionUnitUi, target_branch: FKBranchUnitUi) -> void:
	var e := _get_event()
	if not e:
		return

	var source_data := source_item.get_unit()
	if not source_data:
		return

	before_contents_changed.emit(self)

	_recursive_remove_action(e.actions, source_data)
	var action_data: FKActionUnit = target_branch.get_unit()
	action_data.branch_actions.append(source_data)

	_update_actions()
	contents_changed.emit(self)

func _on_action_reorder(source_item: FKActionUnitUi, target_item: FKActionUnitUi, 
drop_above: bool) -> void:
	var e := _get_event()
	if not e:
		return

	var source_data := source_item.get_unit()
	var target_data := target_item.get_unit()
	if not source_data or not target_data:
		return

	var source_idx := e.actions.find(source_data)
	var target_idx := e.actions.find(target_data)

	if target_idx < 0:
		return

	if source_idx < 0:
		before_contents_changed.emit(self)

		if not _recursive_remove_action(e.actions, source_data):
			return
		
		target_idx = e.actions.find(target_data)
		if target_idx < 0:
			return

		var insert_idx := target_idx if drop_above else target_idx + 1
		e.actions.insert(insert_idx, source_data)

		_update_actions()
		contents_changed.emit(self)
		return

	if source_idx == target_idx:
		return

	var final_idx: int
	if drop_above:
		final_idx = target_idx if source_idx > target_idx else target_idx - 1
	else:
		final_idx = target_idx + 1 if source_idx > target_idx else target_idx

	if source_idx == final_idx:
		return

	before_contents_changed.emit(self)

	e.actions.remove_at(source_idx)
	if source_idx < target_idx:
		target_idx -= 1

	var insert_idx2 := target_idx if drop_above else target_idx + 1
	e.actions.insert(insert_idx2, source_data)

	_update_actions()
	contents_changed.emit(self)

func _pull_action_to_top_level(act_data: FKActionUnit) -> void:
	var e := _get_event()
	if not e:
		return

	if e.actions.has(act_data):
		return

	before_contents_changed.emit(self)

	if _recursive_remove_action(e.actions, act_data):
		e.actions.append(act_data)

	_update_actions()
	contents_changed.emit(self)

# ---------------------------------------------------------
# Add condition / action to data
# ---------------------------------------------------------

func add_condition(condition_data: FKConditionUnit) -> void:
	var e := _get_event()
	if e:
		e.conditions.append(condition_data)
		_update_conditions()

func add_action(action_data: FKActionUnit) -> void:
	var e := _get_event()
	if e:
		e.actions.append(action_data)
		_update_actions()

# ---------------------------------------------------------
# Drag & Drop
# ---------------------------------------------------------

func _get_drag_data(at_position: Vector2) -> FKDragData:
	var drag_preview := _create_drag_preview()
	set_drag_preview(drag_preview)
	return FKDragData.new(DragTarget.Type.EVENT_ROW, self)

func _create_drag_preview() -> Control:
	var preview_label := Label.new()
	preview_label.text = event_header_label.text if event_header_label else "Event"
	preview_label.add_theme_color_override("font_color", _preview_label_color)

	var preview_margin := MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 8)
	preview_margin.add_theme_constant_override("margin_top", 4)
	preview_margin.add_theme_constant_override("margin_right", 8)
	preview_margin.add_theme_constant_override("margin_bottom", 4)
	preview_margin.add_child(preview_label)

	return preview_margin

func _can_drop_data(at_position: Vector2, data) -> bool:
	if data is not FKDragData:
		printerr("FKEventRowUi _can_drop_data was not passed an FKDragData. " +\
		"It was given: " + str(data))
		return false

	var drag_data := data as FKDragData
	var drag_type := drag_data.type

	if drag_type in [DragTarget.Type.EVENT_ROW, DragTarget.Type.COMMENT, DragTarget.Type.GROUP]:
		var parent = get_parent()
		if parent and parent.has_method("_can_drop_data"):
			var parent_pos = at_position + position
			return parent._can_drop_data(parent_pos, data)
		return false

	if drag_type != DragTarget.Type.CONDITION_ITEM and drag_type != DragTarget.Type.ACTION_ITEM:
		return false

	var half_width = size.x / 2.0
	var is_left_side = at_position.x < half_width

	if drag_type == DragTarget.Type.CONDITION_ITEM and is_left_side:
		return true
	elif drag_type == DragTarget.Type.ACTION_ITEM and not is_left_side:
		return true

	return false

func _drop_data(at_position: Vector2, data) -> void:
	if data is not FKDragData:
		printerr("FKEventRowUi _drop_data not given an FKDragData. It was given: " + str(data))
		return

	var drag_data := data as FKDragData
	var drag_type = drag_data.type

	if drag_type in [DragTarget.Type.EVENT_ROW, DragTarget.Type.COMMENT, DragTarget.Type.GROUP]:
		var parent = get_parent()
		if parent and parent.has_method("_drop_data"):
			var parent_pos = at_position + position
			parent._drop_data(parent_pos, data)
		return

	var source_node = drag_data.node
	if not source_node or not is_instance_valid(source_node):
		return

	var source_row = _find_parent_event_row(source_node)
	if not source_row:
		return

	var half_width = size.x / 2.0
	var is_left_side = at_position.x < half_width

	match drag_type:
		DragTarget.Type.CONDITION_ITEM:
			if is_left_side:
				var cond_data = drag_data.data
				if cond_data and source_row != self:
					condition_dropped.emit(source_row, cond_data, self)

		DragTarget.Type.ACTION_ITEM:
			if not is_left_side:
				var act_data = drag_data.data
				if act_data:
					if source_row != self:
						action_dropped.emit(source_row, act_data, self)
					else:
						_pull_action_to_top_level(act_data)
						

func _to_string() -> String:
	var result := "FKEventRowUi"
	
	if _unit != null:
		result += "\nhas block: true"
	return result

func get_class() -> String:
	var result := "FKEventRowUi"
	return result
	
func get_unit() -> FKEventUnit:
	if _unit is FKEventUnit:
		return _unit as FKEventUnit
	else:
		return null
	
