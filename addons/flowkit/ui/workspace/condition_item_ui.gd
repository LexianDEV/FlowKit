@tool
extends MarginContainer
class_name ConditionItemUi

signal selected(item)
signal edit_requested(item)
signal delete_requested(item)
signal negate_requested(item)
signal reorder_requested(source_item, target_item, drop_above: bool)

var condition_data: FKEventCondition
var registry: Node
var is_selected: bool = false

@export_category("Controls")
@export var panel: PanelContainer
@export var label: Label
@export var icon_label: Label
@export var context_menu: PopupMenu
@export var drop_indicator: ColorRect

@export_category("Styles")
@export var normal_stylebox: StyleBox
@export var selected_stylebox: StyleBox

var is_drop_target: bool = false
var drop_above: bool = true

func _ready() -> void:
	_toggle_subs(true)
	call_deferred("_setup_context_menu")

func _toggle_subs(on: bool):
	if on:
		gui_input.connect(_on_gui_input)
		mouse_exited.connect(_on_mouse_exited)
	else:
		gui_input.disconnect(_on_gui_input)
		mouse_exited.disconnect(_on_mouse_exited)
		
func _on_mouse_exited():
	_hide_drop_indicator()
	
func _setup_context_menu() -> void:
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

func _can_drop_data(at_position: Vector2, data) -> bool:
	if not data is Dictionary:
		_hide_drop_indicator()
		return false
	
	var drag_type = data.get("type", "")
	if drag_type != "condition_item":
		_hide_drop_indicator()
		return false
	
	var source_node = data.get("node")
	if source_node == self:
		_hide_drop_indicator()
		return false
	
	# Check if source is adjacent and prevent indicator on the shared edge
	var above = at_position.y < size.y / 2.0
	if _is_adjacent_to_source(source_node, above):
		_hide_drop_indicator()
		return false
	
	_show_drop_indicator(above)
	return true

func _is_adjacent_to_source(source_node: Node, drop_above: bool) -> bool:
	"""Check if dropping would result in no actual movement (adjacent items)."""
	var parent = get_parent()
	if not parent:
		return false
	
	var my_index = get_index()
	var source_index = -1
	
	for i in parent.get_child_count():
		if parent.get_child(i) == source_node:
			source_index = i
			break
	
	if source_index < 0:
		return false
	
	# If dropping above and source is directly above us, no movement needed
	if drop_above and source_index == my_index - 1:
		return true
	
	# If dropping below and source is directly below us, no movement needed
	if not drop_above and source_index == my_index + 1:
		return true
	
	return false

func _drop_data(at_position: Vector2, data) -> void:
	_hide_drop_indicator()
	
	if not data is Dictionary:
		return
	
	var drag_type = data.get("type", "")
	if drag_type != "condition_item":
		return
	
	var source_node = data.get("node")
	if not source_node or source_node == self:
		return
	
	var above = at_position.y < size.y / 2.0
	reorder_requested.emit(source_node, self, above)

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_hide_drop_indicator()

func _exit_tree() -> void:
	_toggle_subs(false)
