extends MarginContainer
class_name FKBaseBlockNode

signal before_block_changed(node)
signal block_changed(node)
signal block_contents_changed()
signal selected(node)

func get_block() -> FKBaseBlock:
	return block

## The Block that this Node represents.
var block: FKBaseBlock:
	get:
		return _block

var _block: FKBaseBlock

func set_block(to_set: FKBaseBlock) -> void:
	var valid := _validate_block(to_set)
	if not valid:
		return
		
	before_block_changed.emit(self)
	_block = to_set
	_on_block_changed()
	block_changed.emit(self)
	
## Meant to be overridden by subclasses.
func _validate_block(to_set: FKBaseBlock) -> bool:
	_alert_need_for_override("_validate_block")
	return false
	
func _on_block_changed() -> void:
	update_display()

func _on_block_contents_changed():
	update_display()
	
func _alert_need_for_override(func_name: String):
	var error_message := "FKBlockNode subclasses must override %s" % [func_name]
	printerr(error_message)
	
func set_registry(reg: Node) -> void:
	registry = reg
	_on_registry_set()
	
var registry: Node

func _on_registry_set() -> void:
	_alert_need_for_override("_on_registry_set")
	
func set_selected(value: bool) -> void:
	if _is_selected == value:
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

func _get_drag_data(_pos): return null
func _can_drop_data(_pos, _data): return false
func _drop_data(_pos, _data): pass
