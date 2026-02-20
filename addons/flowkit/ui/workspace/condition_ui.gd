@tool
extends MarginContainer
class_name ConditionUi

signal insert_condition_requested(condition_node)
signal replace_condition_requested(condition_node)
signal delete_condition_requested(condition_node)
signal negate_condition_requested(condition_node)
signal edit_condition_requested(condition_node)
signal selected(block_node)

var condition_data: FKEventCondition
var registry: Node
var is_selected: bool = false

var context_menu: PopupMenu
var label: Label
var panel: PanelContainer
var normal_stylebox: StyleBox
var selected_stylebox: StyleBox

func _ready() -> void:
	label = get_node_or_null("Panel/MarginContainer/HBoxContainer/Label")
	panel = get_node_or_null("Panel")
	
	# Store original stylebox and create selected version
	if panel:
		normal_stylebox = panel.get_theme_stylebox("panel")
		if normal_stylebox:
			selected_stylebox = normal_stylebox.duplicate()
			if selected_stylebox is StyleBoxFlat:
				selected_stylebox.border_color = Color(1.0, 1.0, 1.0, 1.0)
				selected_stylebox.border_width_left = 6
				selected_stylebox.shadow_color = Color(1.0, 0.65, 0.2, 0.5)
				selected_stylebox.shadow_size = 8
	
	# Connect gui_input for click detection
	gui_input.connect(_on_gui_input)
	
	# Try to get context menu and connect if available
	call_deferred("_setup_context_menu")

func _setup_context_menu() -> void:
	context_menu = get_node_or_null("ContextMenu")
	if context_menu:
		context_menu.id_pressed.connect(_on_context_menu_id_pressed)
		# Make the Negate item checkable
		context_menu.set_item_as_checkable(4, true)
		context_menu.set_item_checked(4, condition_data.negated if condition_data else false)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Left-click to select
			selected.emit(self)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Right-click for context menu
			selected.emit(self)
			
			# Try to get context menu if we don't have it yet
			if not context_menu:
				context_menu = get_node_or_null("ContextMenu")
				if context_menu and not context_menu.id_pressed.is_connected(_on_context_menu_id_pressed):
					context_menu.id_pressed.connect(_on_context_menu_id_pressed)
			
			if context_menu:
				context_menu.position = DisplayServer.mouse_get_position()
				context_menu.popup()

func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		0: # Insert Condition Below
			insert_condition_requested.emit(self)
		1: # Replace Condition
			replace_condition_requested.emit(self)
		2: # Edit Condition
			edit_condition_requested.emit(self)
		3: # Delete Condition
			delete_condition_requested.emit(self)
		4: # Negate
			negate_condition_requested.emit(self)
			print("Negate condition requested for: ", condition_data.condition_id if condition_data else "unknown")

func set_condition_data(data: FKEventCondition) -> void:
	condition_data = data
	_update_label()

func set_registry(reg: Node) -> void:
	registry = reg
	_update_label()

func get_condition_data() -> FKEventCondition:
	"""Return the internal condition data."""
	return condition_data

func _update_label() -> void:
	if not label:
		label = get_node_or_null("Panel/MarginContainer/HBoxContainer/Label")
	
	if label and condition_data:
		var display_name = condition_data.condition_id
		
		# Try to get the provider's display name
		if registry:
			for provider in registry.condition_providers:
				if provider.has_method("get_id") and provider.get_id() == condition_data.condition_id:
					if provider.has_method("get_name"):
						display_name = provider.get_name()
					break
		
		var params_text = ""
		if not condition_data.inputs.is_empty():
			var param_pairs = []
			for key in condition_data.inputs:
				param_pairs.append("%s: %s" % [key, condition_data.inputs[key]])
			params_text = " (" + ", ".join(param_pairs) + ")"
		
		var negation_prefix = "NOT " if condition_data.negated else ""
		label.text = "%s%s%s" % [negation_prefix, display_name, params_text]
	
	# Update context menu checkmark
	if context_menu:
		context_menu.set_item_checked(4, condition_data.negated if condition_data else false)

func update_display() -> void:
	"""Refresh the label display."""
	_update_label()

func set_selected(value: bool) -> void:
	"""Set the selection state with visual feedback."""
	is_selected = value
	if panel and normal_stylebox and selected_stylebox:
		if is_selected:
			panel.add_theme_stylebox_override("panel", selected_stylebox)
		else:
			panel.add_theme_stylebox_override("panel", normal_stylebox)

func _get_drag_data(at_position: Vector2):
	# Create a simple preview control
	var preview_label := Label.new()
	preview_label.text = label.text if label else "Condition"
	preview_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.85, 0.7))
	
	var preview_margin := MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 8)
	preview_margin.add_theme_constant_override("margin_top", 4)
	preview_margin.add_theme_constant_override("margin_right", 8)
	preview_margin.add_theme_constant_override("margin_bottom", 4)
	preview_margin.add_child(preview_label)
	
	set_drag_preview(preview_margin)
	
	# Return drag data with type information
	return {
		"type": "condition",
		"node": self
	}

func _can_drop_data(at_position: Vector2, data) -> bool:
	return false  # VBoxContainer handles drops

func _drop_data(at_position: Vector2, data) -> void:
	pass  # VBoxContainer handles drops
