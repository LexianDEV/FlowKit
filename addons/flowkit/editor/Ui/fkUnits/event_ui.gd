# At the time of this writing, this class seems unused.
@tool
extends FKUnitUi
class_name FKEventUnitUi

signal insert_condition_requested(event_node)
signal replace_event_requested(event_node)
signal delete_event_requested(event_node)
signal edit_event_requested(event_node)

@export_category("Controls")
@export var context_menu: PopupMenu
@export var label: Label
@export var panel: PanelContainer

@export_category("Styles")
@export var normal_stylebox: StyleBox
@export var selected_stylebox: StyleBox

# ---------------------------------------------------------
# Block Handling
# ---------------------------------------------------------
	
func _validate_unit(to_set: FKUnit) -> bool:
	return to_set == null or to_set is FKEventUnit

func get_event() -> FKEventUnit:
	return _unit as FKEventUnit

func _on_contents_changed(node: FKUnitUi) -> void:
	update_display()

# ---------------------------------------------------------
# Registry Handling
# ---------------------------------------------------------

func _on_registry_set() -> void:
	_update_label()

# ---------------------------------------------------------
# Display / Styling
# ---------------------------------------------------------

func update_display() -> void:
	_update_label()
	_update_styling()

func _update_styling() -> void:
	var style := selected_stylebox if is_selected \
	else normal_stylebox
	panel.add_theme_stylebox_override("panel", style)

func _update_label() -> void:
	var e := get_event()
	if not e:
		return

	var display_name := _resolve_display_name(e)
	var params_text := _format_params(e)
	var node_name := String(e.target_node).get_file()

	label.text = "%s (%s)%s" % [display_name, node_name, params_text]

func _resolve_display_name(e: FKEventUnit) -> String:
	var name := e.event_id

	if registry:
		for provider in registry.event_providers:
			if provider.get_provider_id() == e.event_id:
				name = provider.get_display_name()
				break

	return name

func _format_params(e: FKEventUnit) -> String:
	if e.inputs.is_empty():
		return ""

	var pairs := []
	for key in e.inputs:
		pairs.append("%s: %s" % [key, e.inputs[key]])

	return " (" + ", ".join(pairs) + ")"

# ---------------------------------------------------------
# Context Menu
# ---------------------------------------------------------

func show_context_menu(global_pos: Vector2) -> void:
	print("Showing " + get_class() + " context menu")
	context_menu.position = global_pos
	context_menu.popup()

func _on_context_menu_id_pressed(id: int) -> void:
	match id:
		_insert_condition_choice: insert_condition_requested.emit(self)
		_replace_event_choice: replace_event_requested.emit(self)
		_edit_event_choice: edit_event_requested.emit(self)
		_delete_event_choice: delete_event_requested.emit(self)

const _insert_condition_choice := 0
const _replace_event_choice := 1
const _edit_event_choice := 2
const _delete_event_choice := 3

# ---------------------------------------------------------
# Input Handling
# ---------------------------------------------------------

func _toggle_subs(on: bool) -> void:
	if is_editor_preview:
		return
		
	if on && !_is_subbed:
		gui_input.connect(_on_gui_input)
		context_menu.id_pressed.connect(_on_context_menu_id_pressed)
	elif !on && _is_subbed:
		gui_input.disconnect(_on_gui_input)
		context_menu.id_pressed.disconnect(_on_context_menu_id_pressed)
	
	super._toggle_subs(on)

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			print("Clicked Event Block Ui")
			set_selected(true)
			get_viewport().set_input_as_handled()

		elif event.button_index == MOUSE_BUTTON_RIGHT:
			set_selected(true)
			show_context_menu(DisplayServer.mouse_get_position())
			get_viewport().set_input_as_handled()

# ---------------------------------------------------------
# Drag & Drop
# ---------------------------------------------------------

func _get_drag_data(at_position: Vector2) -> FKDragData:
	var preview := _create_drag_preview()
	set_drag_preview(preview)

	return FKDragData.new(DragTarget.Type.EVENT, self)

func _create_drag_preview() -> Control:
	var preview_label := Label.new()
	preview_label.text = label.text if label else "Event"
	preview_label.add_theme_color_override("font_color", _preview_color)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 4)
	margin.add_child(preview_label)

	return margin

const _preview_color := Color(0.9, 0.95, 0.9, 0.7)

func _can_drop_data(at_position: Vector2, data) -> bool:
	return false  # Parent VBoxContainer handles drops

func _drop_data(at_position: Vector2, data) -> void:
	pass  # Parent handles drops

func _to_string() -> String:
	var result := "\nFKEventUnitUi"
	
	if _unit != null:
		result += "\nhas block: true"
	return result
	
func get_class() -> String:
	return "FKEventUnitUi"
