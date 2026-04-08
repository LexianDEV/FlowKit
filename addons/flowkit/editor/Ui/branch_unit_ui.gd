@tool
extends FKActionUnitUi
class_name FKBranchUnitUi

signal edit_condition_requested(item)
signal add_elseif_requested(item)
signal add_else_requested(item)
signal add_branch_action_requested(item)
signal branch_action_edit_requested(action_item, branch_item)
signal branch_action_delete_requested(action_item, branch_item)
signal branch_action_selected(action_item)
signal branch_action_reorder_requested(source_item, target_item, drop_above: bool)
signal action_cross_reorder_requested(source_data, target_data, is_drop_above: bool, target_branch)
signal action_dropped_into_branch(source_item, target_branch_item)
signal data_changed()
signal before_data_changed()
signal add_nested_branch_requested(branch_item, branch_id)

var parent_branch: Control = null

@export_category("Controls")
@export var header: Control
@export var actions_container: VBoxContainer
@export var body_node: PanelContainer

@export_category("Labels")
@export var type_label: Label
@export var condition_label: Label
@export var add_action_label: Label

@export_category("Menus")
@export var add_action_context_menu: PopupMenu

@export_category("Styling")
@export var body_base_stylebox: StyleBoxFlat
@export var body_highlight_stylebox: StyleBoxFlat

var is_body_drop := false

# ---------------------------------------------------------
# FKActionUnitUi Integration
# ---------------------------------------------------------

func _validate_block(to_set: FKUnit) -> bool:
	return to_set is FKActionUnit and to_set.is_branch

func _on_block_changed() -> void:
	update_display()

func _on_registry_set() -> void:
	update_display()

func update_display() -> void:
	_update_header()
	_update_branch_actions()

# ---------------------------------------------------------
# Subscription Handling
# ---------------------------------------------------------

func _toggle_subs(on: bool) -> void:
	if on and not _is_subbed:
		add_action_label.gui_input.connect(_on_add_action_input)
		add_action_label.mouse_entered.connect(_on_add_action_hover.bind(true))
		add_action_label.mouse_exited.connect(_on_add_action_hover.bind(false))
		add_action_context_menu.id_pressed.connect(_on_add_action_context_menu_id_pressed)
	elif not on and _is_subbed:
		add_action_label.gui_input.disconnect(_on_add_action_input)
		add_action_label.mouse_entered.disconnect(_on_add_action_hover)
		add_action_label.mouse_exited.disconnect(_on_add_action_hover)
		add_action_context_menu.id_pressed.disconnect(_on_add_action_context_menu_id_pressed)

	super._toggle_subs(on)

# ---------------------------------------------------------
# Input Handling
# ---------------------------------------------------------

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var left_click: bool = event.button_index == MOUSE_BUTTON_LEFT
		var right_click: bool = event.button_index == MOUSE_BUTTON_RIGHT
		if left_click:
			if event.double_click and _action.branch_type != "else":
				edit_condition_requested.emit(self)
		elif right_click:
			_show_context_menu()
		
		if left_click or right_click:
			set_selected(true)
			get_viewport().set_input_as_handled()

func _show_context_menu() -> void:
	context_menu.clear()

	var provider = _get_branch_provider()
	var input_type = provider.get_input_type() if provider and provider.has_method("get_input_type") \
	else "condition"

	if _action.branch_type != "else":
		if input_type == "condition":
			context_menu.add_item("Edit Condition", 0)
			var negated := _action.branch_condition and _action.branch_condition.negated
			var negate_text := "Set to True (remove negation)" if negated \
			else "Set to False (negate)"
			context_menu.add_item(negate_text, 4)
		else:
			context_menu.add_item("Edit Inputs", 0)

	context_menu.add_separator()

	var is_chain: bool = provider.get_type() == "chain" if provider and provider.has_method("get_type") \
	else false
	if is_chain:
		context_menu.add_item("Add Else If Below", 1)
		context_menu.add_item("Add Else Below", 2)
		context_menu.add_separator()

	context_menu.add_item("Delete Branch", 3)

	context_menu.position = DisplayServer.mouse_get_position()
	context_menu.popup()

func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		0: edit_condition_requested.emit(self)
		1: add_elseif_requested.emit(self)
		2: add_else_requested.emit(self)
		3: delete_requested.emit(self)
		4: _toggle_negate()

func _toggle_negate() -> void:
	if not _action.branch_condition:
		return

	before_data_changed.emit()
	_action.branch_condition.negated = not _action.branch_condition.negated
	update_display()
	data_changed.emit()

# ---------------------------------------------------------
# Add Action Button
# ---------------------------------------------------------

func _on_add_action_input(event: InputEvent) -> void:
	var we_want_to_respond: bool = event is InputEventMouseButton and event.pressed and \
	(event.button_index == MOUSE_BUTTON_RIGHT or event.button_index == MOUSE_BUTTON_LEFT)
	if we_want_to_respond:
		_flash_label(add_action_label)
		_show_add_action_context_menu()
		accept_event()

func _flash_label(lbl: Label) -> void:
	lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.65, 1))
	var tween := create_tween()
	tween.tween_interval(0.15)
	tween.tween_callback(func():
		if is_instance_valid(lbl):
			lbl.add_theme_color_override("font_color", Color(0.4, 0.45, 0.42, 1))
	)

func _show_add_action_context_menu() -> void:
	add_action_context_menu.clear()
	add_action_context_menu.add_item("Add Action", 0)
	add_action_context_menu.add_separator()

	var branches: Array = registry.branch_providers if registry else []
	for i in range(branches.size()):
		var provider = branches[i]
		if provider.has_method("get_name"):
			add_action_context_menu.add_item("Add %s" % provider.get_name(), 100 + i)

	add_action_context_menu.position = DisplayServer.mouse_get_position()
	add_action_context_menu.popup()

func _on_add_action_context_menu_id_pressed(id: int) -> void:
	if id == 0:
		add_branch_action_requested.emit(self)
	elif id >= 100:
		var branches: Array = registry.branch_providers if registry else []
		var idx := id - 100
		if idx < branches.size():
			add_nested_branch_requested.emit(self, branches[idx].get_id())

func _on_add_action_hover(is_hovering: bool) -> void:
	var color_to_use = Color(0.6, 0.65, 0.62, 1) if is_hovering \
	else Color(0.4, 0.45, 0.42, 1)
	add_action_label.add_theme_color_override(
		"font_color",
		color_to_use
	)

# ---------------------------------------------------------
# Header Rendering
# ---------------------------------------------------------

func _update_header() -> void:
	if not _action:
		return

	_update_type_label()
	_update_colors()
	_update_condition_desc()

func _update_type_label() -> void:
	var provider = _get_branch_provider()
	var name: String = provider.get_name().to_upper() if provider and provider.has_method("get_name") else "IF"

	match _action.branch_type:
		"if": type_label.text = name
		"elseif": type_label.text = "ELSE %s" % name
		"else": type_label.text = "ELSE"
		_: type_label.text = name

func _update_colors() -> void:
	var provider = _get_branch_provider()
	var base_color: Color = provider.get_color() if provider and provider.has_method("get_color") else \
	Color(0.3, 0.8, 0.5, 1)

	var color := base_color
	if _action.branch_type == "else":
		color = base_color.lerp(Color(0.85, 0.65, 0.3, 1), 0.7)

	type_label.add_theme_color_override("font_color", color)
	icon_label.add_theme_color_override("font_color", color)

func _update_condition_desc() -> void:
	if _action.branch_type == "else":
		condition_label.text = ""
		return

	var provider = _get_branch_provider()
	var input_type: String = provider.get_input_type() if provider and \
	provider.has_method("get_input_type") else \
	"condition"

	if input_type == "condition" and _action.branch_condition:
		var cond := _action.branch_condition
		var display_name := cond.condition_id

		if registry:
			for p in registry.condition_providers:
				if p.has_method("get_id") and p.get_id() == cond.condition_id:
					if p.has_method("get_name"):
						display_name = p.get_name()
					break

		var neg := "NOT " if cond.negated else ""
		var node_name := String(cond.target_node).get_file()

		var params := []
		for key in cond.inputs:
			params.append(str(cond.inputs[key]))

		var params_text := "" if params.is_empty() \
		else ": " + ", ".join(params)

		condition_label.text = "%s%s (%s)%s" % [neg, display_name, node_name, params_text]

	elif input_type == "evaluation":
		var pairs := []
		for key in _action.branch_inputs:
			pairs.append("%s: %s" % [key, str(_action.branch_inputs[key])])
		condition_label.text = ", ".join(pairs)
	else:
		condition_label.text = "(no inputs set)"

func _get_branch_provider():
	if not _action or not registry:
		return null

	var bid := _action.branch_id
	if bid.is_empty() and _action.branch_type in ["if", "elseif", "else"]:
		bid = "if_branch"

	return registry.get_branch_provider(bid)

# ---------------------------------------------------------
# Branch Actions Rendering
# ---------------------------------------------------------

func _update_branch_actions() -> void:
	if not _action:
		return

	for child in actions_container.get_children():
		child.queue_free()

	for sub in _action.branch_actions:
		if sub.is_branch:
			var scene := load(FKEditorGlobals.BRANCH_ITEM_SCENE_PATH)
			var nested: FKBranchUnitUi = scene.instantiate()
			nested.legitimize(sub, registry)
			nested.parent_branch = self
			_connect_nested_branch_signals(nested)
			actions_container.add_child(nested)
		else:
			var item: FKActionUnitUi = FKEditorGlobals.ACTION_ITEM_SCENE.instantiate()
			item.legitimize(sub, registry)
			_connect_sub_action_signals(item)
			actions_container.add_child(item)

# ---------------------------------------------------------
# Sub‑Action Signal Wiring
# ---------------------------------------------------------

func _connect_sub_action_signals(item) -> void:
	if item.has_signal("selected"):
		item.selected.connect(func(n): branch_action_selected.emit(n))
	if item.has_signal("edit_requested"):
		item.edit_requested.connect(func(n): branch_action_edit_requested.emit(n, self))
	if item.has_signal("delete_requested"):
		item.delete_requested.connect(func(n): _on_sub_action_delete(n))
	if item.has_signal("reorder_requested"):
		item.reorder_requested.connect(_on_sub_action_reorder)

func _connect_nested_branch_signals(nested) -> void:
	nested.selected.connect(func(n): selected.emit(n))
	nested.edit_condition_requested.connect(func(i): edit_condition_requested.emit(i))
	nested.delete_requested.connect(func(i): _on_sub_action_delete(i))
	nested.add_elseif_requested.connect(func(i): add_elseif_requested.emit(i))
	nested.add_else_requested.connect(func(i): add_else_requested.emit(i))
	nested.add_branch_action_requested.connect(func(i): add_branch_action_requested.emit(i))
	nested.branch_action_edit_requested.connect(func(ai, bi): branch_action_edit_requested.emit(ai, bi))
	nested.branch_action_selected.connect(func(n): branch_action_selected.emit(n))
	nested.add_nested_branch_requested.connect(func(i, bid): add_nested_branch_requested.emit(i, bid))
	nested.reorder_requested.connect(_on_sub_action_reorder)
	nested.action_cross_reorder_requested.connect(func(sd, td, above, tb): action_cross_reorder_requested.emit(sd, td, above, tb))
	nested.action_dropped_into_branch.connect(func(si, bi): action_dropped_into_branch.emit(si, bi))
	nested.data_changed.connect(func(): data_changed.emit())
	nested.before_data_changed.connect(func(): before_data_changed.emit())

# ---------------------------------------------------------
# Sub‑Action Delete / Reorder
# ---------------------------------------------------------

func _on_sub_action_delete(item) -> void:
	before_data_changed.emit()
	var data: FKUnit = item.get_block()
	if data and _action:
		var idx := _action.branch_actions.find(data)
		if idx >= 0:
			_action.branch_actions.remove_at(idx)
	_update_branch_actions()
	data_changed.emit()

func _on_sub_action_reorder(source_item, target_item, drop_above: bool) -> void:
	if not _action:
		return

	var source_data: FKUnit = source_item.get_block()
	var target_data: FKUnit = target_item.get_block()

	var source_idx := _action.branch_actions.find(source_data)
	var target_idx := _action.branch_actions.find(target_data)

	if target_idx < 0:
		return

	if source_idx < 0:
		action_cross_reorder_requested.emit(source_data, target_data, drop_above, self)
		return

	if source_idx == target_idx:
		return

	before_data_changed.emit()

	_action.branch_actions.remove_at(source_idx)
	if source_idx < target_idx:
		target_idx -= 1

	var insert_idx := target_idx if drop_above \
	else  target_idx + 1
	_action.branch_actions.insert(insert_idx, source_data)

	_update_branch_actions()
	data_changed.emit()

# ---------------------------------------------------------
# Drag & Drop
# ---------------------------------------------------------

func _get_drag_data(at_position: Vector2) -> FKDragData:
	if not _action:
		return null

	var preview := _create_drag_preview()
	set_drag_preview(preview)

	return FKDragData.new(DragTarget.Type.ACTION_ITEM, self, _action)

func _create_drag_preview() -> Control:
	var lbl := Label.new()
	var provider = _get_branch_provider()
	var name: String = provider.get_name() if provider and provider.has_method("get_name") else \
	"Branch"
	lbl.text = "%s Branch" % name

	var color: Color = provider.get_color() if provider and provider.has_method("get_color") else \
	Color(0.3, 0.8, 0.5, 1)
	color.a = 0.9
	lbl.add_theme_color_override("font_color", color)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.add_child(lbl)

	return margin

func _is_drop_in_body_area(at_position: Vector2) -> bool:
	var global_pos := global_position + at_position
	return body_node.get_global_rect().has_point(global_pos)

func _show_body_highlight() -> void:
	_hide_drop_indicator()
	is_body_drop = true
	body_node.add_theme_stylebox_override("panel", body_highlight_stylebox)

func _hide_body_highlight() -> void:
	is_body_drop = false
	body_node.add_theme_stylebox_override("panel", body_base_stylebox)

func _can_drop_data(at_position: Vector2, data) -> bool:
	var drag_data := data as FKDragData
	if not drag_data or drag_data.type != DragTarget.Type.ACTION_ITEM:
		_hide_drop_indicator()
		_hide_body_highlight()
		return false

	var source_node := drag_data.node
	if source_node == self:
		_hide_drop_indicator()
		_hide_body_highlight()
		return false

	if _is_descendant_of(source_node):
		_hide_drop_indicator()
		_hide_body_highlight()
		return false

	var source_data := drag_data.data
	var is_direct_child: bool = source_data and _action.branch_actions.has(source_data)

	if not is_direct_child and _is_drop_in_body_area(at_position):
		_show_body_highlight()
		return true

	_hide_body_highlight()

	var above := at_position.y < size.y / 2.0
	_show_drop_indicator(above)
	return true

func _drop_data(at_position: Vector2, data) -> void:
	_hide_drop_indicator()
	_hide_body_highlight()

	var drag_data := data as FKDragData
	if not drag_data or drag_data.type != DragTarget.Type.ACTION_ITEM:
		return

	var source_node := drag_data.node
	if not source_node or source_node == self:
		return

	if _is_drop_in_body_area(at_position):
		action_dropped_into_branch.emit(source_node, self)
		return

	var above := at_position.y < size.y / 2.0
	reorder_requested.emit(source_node, self, above)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_hide_drop_indicator()
		_hide_body_highlight()

func _on_mouse_exited() -> void:
	_hide_drop_indicator()
	_hide_body_highlight()
	
func _to_string() -> String:
	var result := "FKBranchUnitUi"
	
	if _block != null:
		result += "\nhas block: true"
	return result
	
func get_class() -> String:
	var result := "FKBranchUnitUi"
	return result
	
func add_branch_action(sub_action_unit: FKActionUnit):
	if _action:
		_action.branch_actions.append(sub_action_unit)
		_update_branch_actions()
