@tool
extends MarginContainer

signal selected(item)
signal edit_requested(item)
signal delete_requested(item)
signal negate_requested(item)

var condition_data: FKEventCondition
var registry: Node
var is_selected: bool = false

var label: Label
var icon_label: Label
var panel: PanelContainer
var context_menu: PopupMenu
var normal_stylebox: StyleBox
var selected_stylebox: StyleBox

func _ready() -> void:
	_setup_references()
	_setup_styles()
	gui_input.connect(_on_gui_input)
	call_deferred("_setup_context_menu")

func _setup_references() -> void:
	panel = get_node_or_null("Panel")
	label = get_node_or_null("Panel/Margin/HBox/Label")
	icon_label = get_node_or_null("Panel/Margin/HBox/Icon")
	context_menu = get_node_or_null("ContextMenu")

func _setup_styles() -> void:
	if panel:
		normal_stylebox = panel.get_theme_stylebox("panel")
		if normal_stylebox:
			selected_stylebox = normal_stylebox.duplicate()
			if selected_stylebox is StyleBoxFlat:
				selected_stylebox.border_color = Color(1.0, 0.8, 0.4, 1.0)
				selected_stylebox.border_width_left = 2
				selected_stylebox.border_width_top = 1
				selected_stylebox.border_width_right = 1
				selected_stylebox.border_width_bottom = 1

func _setup_context_menu() -> void:
	if context_menu:
		context_menu.id_pressed.connect(_on_context_menu_id_pressed)
		context_menu.set_item_as_checkable(2, true)
		if condition_data:
			context_menu.set_item_checked(2, condition_data.negated)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click:
				edit_requested.emit(self)
			else:
				selected.emit(self)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			selected.emit(self)
			if context_menu:
				if condition_data:
					context_menu.set_item_checked(2, condition_data.negated)
				context_menu.position = DisplayServer.mouse_get_position()
				context_menu.popup()
			get_viewport().set_input_as_handled()

func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		0: # Edit
			edit_requested.emit(self)
		1: # Delete
			delete_requested.emit(self)
		2: # Negate
			negate_requested.emit(self)

func set_condition_data(data: FKEventCondition) -> void:
	condition_data = data
	call_deferred("_update_label")

func set_registry(reg: Node) -> void:
	registry = reg
	call_deferred("_update_label")

func get_condition_data() -> FKEventCondition:
	return condition_data

func _update_label() -> void:
	if not label:
		label = get_node_or_null("Panel/Margin/HBox/Label")
	if not icon_label:
		icon_label = get_node_or_null("Panel/Margin/HBox/Icon")
	
	if label and condition_data:
		var display_name = condition_data.condition_id
		
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
				param_pairs.append(str(condition_data.inputs[key]))
			params_text = ": " + ", ".join(param_pairs)
		
		var negation_prefix = "NOT " if condition_data.negated else ""
		label.text = "%s%s%s" % [negation_prefix, display_name, params_text]
		
		# Update icon color based on negation
		if icon_label:
			if condition_data.negated:
				icon_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4, 1))
			else:
				icon_label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3, 1))

func update_display() -> void:
	_update_label()

func set_selected(value: bool) -> void:
	is_selected = value
	if panel and normal_stylebox and selected_stylebox:
		if is_selected:
			panel.add_theme_stylebox_override("panel", selected_stylebox)
		else:
			panel.add_theme_stylebox_override("panel", normal_stylebox)

func _get_drag_data(at_position: Vector2):
	if not condition_data:
		return null
	
	var preview_label := Label.new()
	preview_label.text = label.text if label else "Condition"
	preview_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4, 0.9))
	
	var preview_margin := MarginContainer.new()
	preview_margin.add_theme_constant_override("margin_left", 8)
	preview_margin.add_theme_constant_override("margin_top", 4)
	preview_margin.add_theme_constant_override("margin_right", 8)
	preview_margin.add_theme_constant_override("margin_bottom", 4)
	preview_margin.add_child(preview_label)
	
	set_drag_preview(preview_margin)
	
	return {
		"type": "condition_item",
		"node": self,
		"data": condition_data
	}
