@tool
extends MarginContainer

signal selected(item)
signal edit_requested(item)
signal delete_requested(item)

var action_data: FKEventAction
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
				selected_stylebox.border_color = Color(0.5, 0.7, 1.0, 1.0)
				selected_stylebox.border_width_left = 2
				selected_stylebox.border_width_top = 1
				selected_stylebox.border_width_right = 1
				selected_stylebox.border_width_bottom = 1

func _setup_context_menu() -> void:
	if context_menu:
		context_menu.id_pressed.connect(_on_context_menu_id_pressed)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			selected.emit(self)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			selected.emit(self)
			if context_menu:
				context_menu.position = DisplayServer.mouse_get_position()
				context_menu.popup()

func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		0: # Edit
			edit_requested.emit(self)
		1: # Delete
			delete_requested.emit(self)

func set_action_data(data: FKEventAction) -> void:
	action_data = data
	call_deferred("_update_label")

func set_registry(reg: Node) -> void:
	registry = reg
	call_deferred("_update_label")

func get_action_data() -> FKEventAction:
	return action_data

func _update_label() -> void:
	if not label:
		label = get_node_or_null("Panel/Margin/HBox/Label")
	
	if label and action_data:
		var display_name = action_data.action_id
		
		if registry:
			for provider in registry.action_providers:
				if provider.has_method("get_id") and provider.get_id() == action_data.action_id:
					if provider.has_method("get_name"):
						display_name = provider.get_name()
					break
		
		var node_name = String(action_data.target_node).get_file()
		var params_text = ""
		if not action_data.inputs.is_empty():
			var param_pairs = []
			for key in action_data.inputs:
				param_pairs.append(str(action_data.inputs[key]))
			params_text = ": " + ", ".join(param_pairs)
		
		# Format: "Action on NodeName: params"
		label.text = "%s %s%s" % [display_name, node_name, params_text]

func update_display() -> void:
	_update_label()

func set_selected(value: bool) -> void:
	is_selected = value
	if panel and normal_stylebox and selected_stylebox:
		if is_selected:
			panel.add_theme_stylebox_override("panel", selected_stylebox)
		else:
			panel.add_theme_stylebox_override("panel", normal_stylebox)
