@tool
extends MarginContainer
class_name BranchItemUi

signal selected(item)
signal edit_condition_requested(item)
signal delete_requested(item)
signal add_elseif_requested(item)
signal add_else_requested(item)
signal add_branch_action_requested(item)
signal branch_action_edit_requested(action_item, branch_item)
signal branch_action_delete_requested(action_item, branch_item)
signal branch_action_selected(action_item)
signal branch_action_reorder_requested(source_item, target_item, drop_above: bool)
signal reorder_requested(source_item, target_item, drop_above: bool)
signal action_cross_reorder_requested(source_data, target_data, is_drop_above: bool, target_branch)
signal action_dropped_into_branch(source_item, target_branch_item)
signal data_changed()
signal before_data_changed()
signal add_nested_branch_requested(branch_item)  # User wants to add a nested IF

var action_data: FKEventAction  # The FKEventAction with is_branch = true
var registry: Node
var is_selected: bool = false
var parent_branch = null  # Reference to parent branch_item for nested branches

const ACTION_ITEM_SCENE = preload("res://addons/flowkit/ui/workspace/action_item_ui.tscn")

# UI References
var panel: PanelContainer
var type_label: Label
var condition_label: Label
var icon_label: Label
var actions_container: VBoxContainer
var add_action_label: Label
var context_menu: PopupMenu
var add_action_context_menu: PopupMenu
var normal_stylebox: StyleBox
var selected_stylebox: StyleBox

# Drop indicator
var drop_indicator: ColorRect
var is_drop_target: bool = false
var drop_above: bool = true
var is_body_drop: bool = false  # True when drop target is the body (insert into branch)
var body_node: PanelContainer = null  # Reference to Body panel for highlight
var body_original_stylebox: StyleBox = null
var body_highlight_stylebox: StyleBox = null

func _ready() -> void:
	_setup_references()
	_setup_styles()
	_setup_drop_indicator()
	gui_input.connect(_on_gui_input)
	call_deferred("_setup_context_menu")
	call_deferred("_setup_add_action_label")

func _setup_references() -> void:
	panel = get_node_or_null("Panel")
	type_label = get_node_or_null("Panel/VBox/Header/HeaderMargin/HBox/TypeLabel")
	condition_label = get_node_or_null("Panel/VBox/Header/HeaderMargin/HBox/ConditionLabel")
	icon_label = get_node_or_null("Panel/VBox/Header/HeaderMargin/HBox/Icon")
	actions_container = get_node_or_null("Panel/VBox/Body/BodyMargin/BodyVBox/ActionsContainer")
	add_action_label = get_node_or_null("Panel/VBox/Body/BodyMargin/BodyVBox/AddActionLabel")
	context_menu = get_node_or_null("ContextMenu")
	add_action_context_menu = get_node_or_null("AddActionContextMenu")

func _setup_styles() -> void:
	if panel:
		normal_stylebox = panel.get_theme_stylebox("panel")
		if normal_stylebox:
			selected_stylebox = normal_stylebox.duplicate()
			if selected_stylebox is StyleBoxFlat:
				selected_stylebox.border_color = Color(0.4, 0.9, 0.6, 1.0)
				selected_stylebox.border_width_left = 2
				selected_stylebox.border_width_top = 1
				selected_stylebox.border_width_right = 1
				selected_stylebox.border_width_bottom = 1

func _setup_context_menu() -> void:
	if context_menu:
		context_menu.id_pressed.connect(_on_context_menu_id_pressed)

func _setup_add_action_label() -> void:
	if add_action_label:
		add_action_label.gui_input.connect(_on_add_action_input)
		add_action_label.mouse_entered.connect(_on_add_action_hover.bind(true))
		add_action_label.mouse_exited.connect(_on_add_action_hover.bind(false))
	if add_action_context_menu:
		add_action_context_menu.id_pressed.connect(_on_add_action_context_menu_id_pressed)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click:
				if action_data and action_data.branch_type != "else":
					edit_condition_requested.emit(self)
			else:
				selected.emit(self)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			selected.emit(self)
			_show_context_menu()
			get_viewport().set_input_as_handled()

func _show_context_menu() -> void:
	if not context_menu:
		return
	context_menu.clear()
	if action_data and action_data.branch_type != "else":
		context_menu.add_item("Edit Condition", 0)
		var is_negated = action_data.branch_condition and action_data.branch_condition.negated
		var negate_text = "Set to True (remove negation)" if is_negated else "Set to False (negate)"
		context_menu.add_item(negate_text, 4)
		context_menu.add_separator()
	context_menu.add_item("Add Else If Below", 1)
	context_menu.add_item("Add Else Below", 2)
	context_menu.add_separator()
	context_menu.add_item("Delete Branch", 3)
	context_menu.position = DisplayServer.mouse_get_position()
	context_menu.popup()

func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		0:  # Edit Condition
			edit_condition_requested.emit(self)
		1:  # Add Else If Below
			add_elseif_requested.emit(self)
		2:  # Add Else Below
			add_else_requested.emit(self)
		3:  # Delete Branch
			delete_requested.emit(self)
		4:  # Negate Condition
			_toggle_negate()

func _toggle_negate() -> void:
	if action_data and action_data.branch_condition:
		before_data_changed.emit()
		action_data.branch_condition.negated = not action_data.branch_condition.negated
		_update_display()
		data_changed.emit()

func _on_add_action_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_flash_label(add_action_label)
			_show_add_action_context_menu()
			accept_event()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_show_add_action_context_menu()
			accept_event()

func _show_add_action_context_menu() -> void:
	if not add_action_context_menu:
		return
	add_action_context_menu.position = DisplayServer.mouse_get_position()
	add_action_context_menu.popup()

func _on_add_action_context_menu_id_pressed(id: int) -> void:
	match id:
		0: add_branch_action_requested.emit(self)
		1: add_nested_branch_requested.emit(self)

func _on_add_action_hover(is_hovering: bool) -> void:
	if add_action_label:
		if is_hovering:
			add_action_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.62, 1))
		else:
			add_action_label.add_theme_color_override("font_color", Color(0.4, 0.45, 0.42, 1))

func _flash_label(lbl: Label) -> void:
	if not lbl:
		return
	lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.65, 1))
	var tween = create_tween()
	tween.tween_interval(0.15)
	tween.tween_callback(func():
		if is_instance_valid(lbl):
			lbl.add_theme_color_override("font_color", Color(0.4, 0.45, 0.42, 1))
	)

func set_action_data(data: FKEventAction) -> void:
	action_data = data
	call_deferred("_update_display")

func set_registry(reg: Node) -> void:
	registry = reg
	call_deferred("_update_display")

func get_action_data() -> FKEventAction:
	return action_data

func _update_display() -> void:
	_update_header()
	_update_branch_actions()

func _update_header() -> void:
	if not action_data:
		return

	# Update type label
	if type_label:
		match action_data.branch_type:
			"if":
				type_label.text = "IF"
			"elseif":
				type_label.text = "ELSE IF"
			"else":
				type_label.text = "ELSE"
			_:
				type_label.text = "IF"

	# Update colors based on branch type
	var branch_color: Color
	match action_data.branch_type:
		"else":
			branch_color = Color(0.85, 0.65, 0.3, 1)  # Orange for else
		_:
			branch_color = Color(0.3, 0.8, 0.5, 1)  # Green for if/elseif

	if type_label:
		type_label.add_theme_color_override("font_color", branch_color)
	if icon_label:
		icon_label.add_theme_color_override("font_color", branch_color)

	# Update condition description
	if condition_label:
		if action_data.branch_type == "else":
			condition_label.text = ""
		elif action_data.branch_condition:
			var cond = action_data.branch_condition
			var display_name = cond.condition_id
			if registry:
				for provider in registry.condition_providers:
					if provider.has_method("get_id") and provider.get_id() == cond.condition_id:
						if provider.has_method("get_name"):
							display_name = provider.get_name()
						break

			var negated_prefix = "NOT " if cond.negated else ""
			var node_name = String(cond.target_node).get_file()
			var params_text = ""
			if not cond.inputs.is_empty():
				var param_pairs = []
				for key in cond.inputs:
					param_pairs.append(str(cond.inputs[key]))
				params_text = ": " + ", ".join(param_pairs)

			condition_label.text = "%s%s (%s)%s" % [negated_prefix, display_name, node_name, params_text]
		else:
			condition_label.text = "(no condition set)"

func _update_branch_actions() -> void:
	if not actions_container:
		actions_container = get_node_or_null("Panel/VBox/Body/BodyMargin/BodyVBox/ActionsContainer")

	if not actions_container or not action_data:
		return

	# Clear existing action items
	for child in actions_container.get_children():
		actions_container.remove_child(child)
		child.queue_free()

	# Add action items for branch_actions (handles both regular and nested branches)
	for sub_action in action_data.branch_actions:
		if sub_action.is_branch:
			var branch_scene = load("res://addons/flowkit/ui/workspace/branch_item_ui.tscn")
			var nested = branch_scene.instantiate()
			nested.set_action_data(sub_action)
			nested.set_registry(registry)
			nested.parent_branch = self
			_connect_nested_branch_signals(nested)
			actions_container.add_child(nested)
		else:
			var item = ACTION_ITEM_SCENE.instantiate()
			item.set_action_data(sub_action)
			item.set_registry(registry)
			_connect_sub_action_signals(item)
			actions_container.add_child(item)

func _connect_sub_action_signals(item) -> void:
	if item.has_signal("selected"):
		item.selected.connect(func(node): branch_action_selected.emit(node))
	if item.has_signal("edit_requested"):
		item.edit_requested.connect(func(node): branch_action_edit_requested.emit(node, self))
	if item.has_signal("delete_requested"):
		item.delete_requested.connect(func(node): _on_sub_action_delete(node))
	if item.has_signal("reorder_requested"):
		item.reorder_requested.connect(_on_sub_action_reorder)

func _connect_nested_branch_signals(nested) -> void:
	"""Forward all signals from a nested branch_item."""
	if nested.has_signal("selected"):
		nested.selected.connect(func(node): selected.emit(node))
	if nested.has_signal("edit_condition_requested"):
		nested.edit_condition_requested.connect(func(item): edit_condition_requested.emit(item))
	if nested.has_signal("delete_requested"):
		nested.delete_requested.connect(func(item): _on_sub_action_delete(item))
	if nested.has_signal("add_elseif_requested"):
		nested.add_elseif_requested.connect(func(item): add_elseif_requested.emit(item))
	if nested.has_signal("add_else_requested"):
		nested.add_else_requested.connect(func(item): add_else_requested.emit(item))
	if nested.has_signal("add_branch_action_requested"):
		nested.add_branch_action_requested.connect(func(item): add_branch_action_requested.emit(item))
	if nested.has_signal("branch_action_edit_requested"):
		nested.branch_action_edit_requested.connect(func(ai, bi): branch_action_edit_requested.emit(ai, bi))
	if nested.has_signal("branch_action_selected"):
		nested.branch_action_selected.connect(func(node): branch_action_selected.emit(node))
	if nested.has_signal("add_nested_branch_requested"):
		nested.add_nested_branch_requested.connect(func(item): add_nested_branch_requested.emit(item))
	if nested.has_signal("reorder_requested"):
		nested.reorder_requested.connect(_on_sub_action_reorder)
	if nested.has_signal("action_cross_reorder_requested"):
		nested.action_cross_reorder_requested.connect(func(sd, td, above, tb): action_cross_reorder_requested.emit(sd, td, above, tb))
	if nested.has_signal("action_dropped_into_branch"):
		nested.action_dropped_into_branch.connect(func(si, bi): action_dropped_into_branch.emit(si, bi))
	if nested.has_signal("data_changed"):
		nested.data_changed.connect(func(): data_changed.emit())
	if nested.has_signal("before_data_changed"):
		nested.before_data_changed.connect(func(): before_data_changed.emit())

func _on_sub_action_delete(item) -> void:
	before_data_changed.emit()
	var act_data = item.get_action_data()
	if act_data and action_data:
		var idx = action_data.branch_actions.find(act_data)
		if idx >= 0:
			action_data.branch_actions.remove_at(idx)
			_update_branch_actions()
			data_changed.emit()

func _on_sub_action_reorder(source_item, target_item, is_drop_above: bool) -> void:
	"""Handle reordering sub-actions within the branch."""
	if not action_data:
		return

	var source_data = source_item.get_action_data()
	var target_data = target_item.get_action_data()

	if not source_data or not target_data:
		return

	var source_idx = action_data.branch_actions.find(source_data)
	var target_idx = action_data.branch_actions.find(target_data)

	# Target not in this branch - shouldn't happen
	if target_idx < 0:
		return

	# Source not in this branch - it's a cross-context drag
	if source_idx < 0:
		action_cross_reorder_requested.emit(source_data, target_data, is_drop_above, self)
		return

	if source_idx == target_idx:
		return

	before_data_changed.emit()

	action_data.branch_actions.remove_at(source_idx)

	if source_idx < target_idx:
		target_idx -= 1

	var insert_idx = target_idx if is_drop_above else target_idx + 1
	action_data.branch_actions.insert(insert_idx, source_data)

	_update_branch_actions()
	data_changed.emit()

func add_branch_action(sub_action_data: FKEventAction) -> void:
	"""Add a sub-action to this branch."""
	if action_data:
		action_data.branch_actions.append(sub_action_data)
		_update_branch_actions()

func update_display() -> void:
	_update_display()

func set_selected(value: bool) -> void:
	is_selected = value
	if panel and normal_stylebox and selected_stylebox:
		if is_selected:
			panel.add_theme_stylebox_override("panel", selected_stylebox)
		else:
			panel.add_theme_stylebox_override("panel", normal_stylebox)

func _setup_drop_indicator() -> void:
	drop_indicator = ColorRect.new()
	drop_indicator.color = Color(0.3, 0.8, 0.5, 0.8)
	drop_indicator.custom_minimum_size = Vector2(0, 2)
	drop_indicator.visible = false
	drop_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(drop_indicator)
	# Setup body highlight for "drop into" visual feedback
	body_node = get_node_or_null("Panel/VBox/Body")
	if body_node:
		body_original_stylebox = body_node.get_theme_stylebox("panel")
		if body_original_stylebox:
			body_highlight_stylebox = body_original_stylebox.duplicate()
			if body_highlight_stylebox is StyleBoxFlat:
				body_highlight_stylebox.border_width_left = 2
				body_highlight_stylebox.border_width_top = 1
				body_highlight_stylebox.border_width_right = 1
				body_highlight_stylebox.border_width_bottom = 1
				body_highlight_stylebox.border_color = Color(0.3, 0.8, 0.5, 0.8)

func _show_drop_indicator(above: bool) -> void:
	if not drop_indicator:
		return
	drop_above = above
	is_drop_target = true
	drop_indicator.visible = true
	drop_indicator.size = Vector2(size.x, 2)
	if above:
		drop_indicator.position = Vector2(0, 0)
	else:
		drop_indicator.position = Vector2(0, size.y - 2)

func _hide_drop_indicator() -> void:
	if drop_indicator:
		drop_indicator.visible = false
	is_drop_target = false

func _get_drag_data(at_position: Vector2):
	if not action_data:
		return null

	var preview_label := Label.new()
	var type_text = action_data.branch_type.to_upper() if action_data else "IF"
	preview_label.text = "%s Branch" % type_text
	preview_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.5, 0.9))

	var preview_margin := MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 8)
	preview_margin.add_theme_constant_override("margin_top", 4)
	preview_margin.add_theme_constant_override("margin_right", 8)
	preview_margin.add_theme_constant_override("margin_bottom", 4)
	preview_margin.add_child(preview_label)

	set_drag_preview(preview_margin)

	return {
		"type": "action_item",
		"node": self,
		"data": action_data
	}

func _is_drop_in_body_area(at_position: Vector2) -> bool:
	"""Check if the drop position is within the body area of the branch."""
	var header = get_node_or_null("Panel/VBox/Header")
	if not header or not panel:
		return false
	# Convert at_position (local to this MarginContainer) to check against body area
	var global_pos = global_position + at_position
	var body = get_node_or_null("Panel/VBox/Body")
	if body:
		return body.get_global_rect().has_point(global_pos)
	return false

func _show_body_highlight() -> void:
	"""Show visual feedback that item will be dropped INTO the branch."""
	_hide_drop_indicator()  # Hide the above/below indicator
	is_body_drop = true
	if body_node and body_highlight_stylebox:
		body_node.add_theme_stylebox_override("panel", body_highlight_stylebox)

func _hide_body_highlight() -> void:
	"""Remove the body drop highlight."""
	is_body_drop = false
	if body_node and body_original_stylebox:
		body_node.add_theme_stylebox_override("panel", body_original_stylebox)

func _can_drop_data(at_position: Vector2, data) -> bool:
	if not data is Dictionary:
		_hide_drop_indicator()
		_hide_body_highlight()
		return false

	var drag_type = data.get("type", "")
	if drag_type != "action_item":
		_hide_drop_indicator()
		_hide_body_highlight()
		return false

	var source_node = data.get("node")
	if source_node == self:
		_hide_drop_indicator()
		_hide_body_highlight()
		return false

	# Prevent dropping a parent onto its own descendant
	if _is_descendant_of(source_node):
		_hide_drop_indicator()
		_hide_body_highlight()
		return false

	# Check if dropping on body area (insert into branch) vs header area (reorder)
	if _is_drop_in_body_area(at_position):
		_show_body_highlight()
		return true

	_hide_body_highlight()
	var above = at_position.y < size.y / 2.0
	_show_drop_indicator(above)
	return true

func _is_descendant_of(node: Node) -> bool:
	"""Check if this item is a descendant of the given node."""
	var current = get_parent()
	while current:
		if current == node:
			return true
		current = current.get_parent()
	return false

func _drop_data(at_position: Vector2, data) -> void:
	_hide_drop_indicator()
	_hide_body_highlight()

	if not data is Dictionary:
		return

	var drag_type = data.get("type", "")
	if drag_type != "action_item":
		return

	var source_node = data.get("node")
	if not source_node or source_node == self:
		return

	# If dropping on body area, insert into this branch as a sub-action
	if _is_drop_in_body_area(at_position):
		action_dropped_into_branch.emit(source_node, self)
		return

	var above = at_position.y < size.y / 2.0
	reorder_requested.emit(source_node, self, above)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_hide_drop_indicator()
		_hide_body_highlight()
