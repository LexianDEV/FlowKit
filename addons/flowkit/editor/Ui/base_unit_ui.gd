@tool
extends MarginContainer
class_name FKUnitUi

signal before_block_changed(node: FKUnitUi)
signal block_changed(node: FKUnitUi)
signal block_contents_changed()
signal selected(node: FKUnitUi)

## Call this when you want to have an FKUnitUi work properly as
## a non-preview instance. This func assumes this instance
## already has a Block and registry registered.

func legitimize(block: FKUnit, registry: FKRegistry):
	if not is_editor_preview:
		return
	is_editor_preview = false
	set_block(block)
	set_registry(registry)
	_enter_tree()
	_ready()
	
func _enter_tree() -> void:
	if is_editor_preview:
		return
	#print("Legit " + get_class() + " instantiated")
	_toggle_subs(true)


## When overriding, make sure to call the super class version last.
## 
func _toggle_subs(on: bool):
	_is_subbed = on
	
## Whether or not this instance is just being shown in the editor preview or not. 
## Helps keep the instance from doing things it shouldn't in that case
var is_editor_preview := true
var _is_subbed := false

func _ready() -> void:
	if is_editor_preview:
		return
	# Ensure we receive mouse events
	mouse_filter = Control.MOUSE_FILTER_STOP
	update_display.call_deferred()
	
## Returns the FKUnit this is representing.
func get_block() -> FKUnit:
	return _block

## The Block that this Node represents.
var _block: FKUnit

func has_block() -> bool:
	return _block != null

func set_block(to_set: FKUnit) -> void:
	if is_editor_preview:
		return
	var valid := _validate_block(to_set)
	if not valid:
		return
		
	before_block_changed.emit(self)
	_block = to_set
	_on_block_changed()
	block_changed.emit(self)
	
## Meant to be overridden by subclasses.
func _validate_block(to_set: FKUnit) -> bool:
	if is_editor_preview:
		return false
	_alert_need_for_override("_validate_block")
	return false
	
func _on_block_changed() -> void:
	update_display()
	
func _alert_need_for_override(func_name: String):
	var error_message := "FKUnitUi " + name + " must override %s" % [func_name]
	printerr(error_message)
	
func set_registry(reg: Node) -> void:
	if is_editor_preview:
		return
	registry = reg
	_on_registry_set()
	
var registry: Node

func _on_registry_set() -> void:
	_alert_need_for_override("_on_registry_set")
	
func set_selected(value: bool) -> void:
	if _is_selected == value or is_editor_preview:
		return
		
	_is_selected = value
	_update_styling()
	if _is_selected:
		selected.emit(self)
	
var is_selected: bool:
	get:
		return _is_selected

var _is_selected := false

func _update_styling() -> void:
	_alert_need_for_override("_update_styling")

func update_display() -> void:
	_update_styling()

func show_context_menu(global_pos: Vector2) -> void:
	_alert_need_for_override("show_context_menu")

func _get_drag_data(_pos: Vector2) -> FKDragData: return null
func _can_drop_data(_pos: Vector2, _data) -> bool: return false
func _drop_data(_pos: Vector2, _data): pass

func _exit_tree() -> void:
	if is_editor_preview:
		return
	_toggle_subs(false)

func _to_string() -> String:
	var result := "FKUnitUi"
	
	if _block != null:
		result += "\nhas block: true"
	return result
	
func get_class() -> String:
	return "FKUnitUi"
