@tool
extends MarginContainer

signal insert_event_below_requested(event_row)
signal replace_event_requested(event_row)
signal delete_event_requested(event_row)
signal edit_event_requested(event_row)
signal add_condition_requested(event_row)
signal add_action_requested(event_row)
signal condition_selected(condition_node)
signal action_selected(action_node)
signal selected(block_node)
signal data_changed()
signal before_data_changed()  # Emitted before any data modification for undo state capture

# Data
var event_data: FKEventBlock
var registry: Node
var is_selected: bool = false

# Preloads
const CONDITION_ITEM_SCENE = preload("res://addons/flowkit/ui/workspace/condition_item.tscn")
const ACTION_ITEM_SCENE = preload("res://addons/flowkit/ui/workspace/action_item.tscn")

# UI References
var panel: PanelContainer
var event_header_label: Label
var conditions_container: VBoxContainer
var actions_container: VBoxContainer
var add_condition_label: Label
var add_action_label: Label
var context_menu: PopupMenu
var normal_stylebox: StyleBox
var selected_stylebox: StyleBox

func _ready() -> void:
	_setup_references()
	_setup_styles()
	_setup_signals()

func _setup_references() -> void:
	panel = get_node_or_null("Panel")
	event_header_label = get_node_or_null("Panel/HBox/ConditionsColumn/EventHeader/MarginContainer/EventLabel")
	conditions_container = get_node_or_null("Panel/HBox/ConditionsColumn/ConditionsPanel/ConditionsMargin/ConditionsContainer")
	actions_container = get_node_or_null("Panel/HBox/ActionsColumn/ActionsPanel/ActionsMargin/ActionsContainer")
	add_condition_label = get_node_or_null("Panel/HBox/ConditionsColumn/AddConditionLabel")
	add_action_label = get_node_or_null("Panel/HBox/ActionsColumn/AddActionLabel")
	context_menu = get_node_or_null("ContextMenu")

func _setup_styles() -> void:
	if panel:
		normal_stylebox = panel.get_theme_stylebox("panel")
		if normal_stylebox:
			selected_stylebox = normal_stylebox.duplicate()
			if selected_stylebox is StyleBoxFlat:
				selected_stylebox.border_color = Color(1.0, 1.0, 1.0, 1.0)
				selected_stylebox.border_width_left = 3
				selected_stylebox.border_width_top = 2
				selected_stylebox.border_width_right = 2
				selected_stylebox.border_width_bottom = 2

func _setup_signals() -> void:
	gui_input.connect(_on_gui_input)
	call_deferred("_setup_context_menu")
	call_deferred("_setup_add_labels")

func _setup_context_menu() -> void:
	if context_menu:
		context_menu.id_pressed.connect(_on_context_menu_id_pressed)

func _setup_add_labels() -> void:
	if add_condition_label:
		add_condition_label.gui_input.connect(_on_add_condition_input)
	if add_action_label:
		add_action_label.gui_input.connect(_on_add_action_input)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			selected.emit(self)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			selected.emit(self)
			if context_menu:
				context_menu.position = DisplayServer.mouse_get_position()
				context_menu.popup()

func _on_add_condition_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		add_condition_requested.emit(self)

func _on_add_action_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		add_action_requested.emit(self)

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
	if not event_header_label:
		event_header_label = get_node_or_null("Panel/HBox/ConditionsColumn/EventHeader/MarginContainer/EventLabel")
	
	if event_header_label and event_data:
		var display_name = event_data.event_id
		
		if registry:
			for provider in registry.event_providers:
				if provider.has_method("get_id") and provider.get_id() == event_data.event_id:
					if provider.has_method("get_name"):
						display_name = provider.get_name()
					break
		
		var params_text = ""
		if not event_data.inputs.is_empty():
			var param_pairs = []
			for key in event_data.inputs:
				param_pairs.append("%s" % [event_data.inputs[key]])
			params_text = " (" + ", ".join(param_pairs) + ")"
		
		event_header_label.text = "⚡ %s%s" % [display_name, params_text]

func _update_conditions() -> void:
	if not conditions_container:
		conditions_container = get_node_or_null("Panel/HBox/ConditionsColumn/ConditionsPanel/ConditionsMargin/ConditionsContainer")
	
	if not conditions_container or not event_data:
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
	if not actions_container:
		actions_container = get_node_or_null("Panel/HBox/ActionsColumn/ActionsPanel/ActionsMargin/ActionsContainer")
	
	if not actions_container or not event_data:
		return
	
	# Clear existing action items
	for child in actions_container.get_children():
		actions_container.remove_child(child)
		child.queue_free()
	
	# Add action items
	for action_data in event_data.actions:
		var item = ACTION_ITEM_SCENE.instantiate()
		item.set_action_data(action_data)
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

func _connect_action_item_signals(item) -> void:
	if item.has_signal("selected"):
		item.selected.connect(func(node): action_selected.emit(node))
	if item.has_signal("edit_requested"):
		item.edit_requested.connect(_on_action_item_edit)
	if item.has_signal("delete_requested"):
		item.delete_requested.connect(_on_action_item_delete)

func _on_condition_item_edit(item) -> void:
	# Will be handled by editor.gd through signal forwarding
	pass

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
	# Will be handled by editor.gd through signal forwarding
	pass

func _on_action_item_delete(item) -> void:
	before_data_changed.emit()  # Signal for undo state capture
	var act_data = item.get_action_data()
	if act_data and event_data:
		var idx = event_data.actions.find(act_data)
		if idx >= 0:
			event_data.actions.remove_at(idx)
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
	if panel and normal_stylebox and selected_stylebox:
		if is_selected:
			panel.add_theme_stylebox_override("panel", selected_stylebox)
		else:
			panel.add_theme_stylebox_override("panel", normal_stylebox)

func _get_drag_data(at_position: Vector2):
	var preview_label := Label.new()
	preview_label.text = event_header_label.text if event_header_label else "Event"
	preview_label.add_theme_color_override("font_color", Color(0.9, 0.95, 0.9, 0.7))
	
	var preview_margin := MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 8)
	preview_margin.add_theme_constant_override("margin_top", 4)
	preview_margin.add_theme_constant_override("margin_right", 8)
	preview_margin.add_theme_constant_override("margin_bottom", 4)
	preview_margin.add_child(preview_label)
	
	set_drag_preview(preview_margin)
	
	return {
		"type": "event_row",
		"node": self
	}

func _can_drop_data(at_position: Vector2, data) -> bool:
	return false

func _drop_data(at_position: Vector2, data) -> void:
	pass
