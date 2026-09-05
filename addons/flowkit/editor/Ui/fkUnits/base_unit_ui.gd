@tool
extends MarginContainer
class_name FKUnitUi

signal selected(node: FKUnitUi)
signal before_contents_changed(node: FKUnitUi)
signal contents_changed(node: FKUnitUi)
signal edit_requested(node: FKUnitUi)
signal delete_requested(node: FKUnitUi)
signal reorder_requested(source_item: Control, target_item: Control, drop_above: bool)

## Call this when you want to have an FKUnitUi work properly as
## a non-preview instance. This func assumes this instance
## already has an FKUnit and registry registered.

func legitimize(unit: FKUnit, editor_globals: FKEditorGlobals):
	if not is_editor_preview:
		return
	is_editor_preview = false
	self._globals = editor_globals
	set_unit(unit)
	_enter_tree()
	_ready()

var _globals: FKEditorGlobals

func _enter_tree() -> void:
	if is_editor_preview:
		return
	_toggle_subs(true)

## When overriding, make sure to call the super class version last.
func _toggle_subs(on: bool):
	var success := _toggle_subs_for_signal_bus(on)
	if success:
		_is_subbed = on

func _toggle_subs_for_signal_bus(on: bool) -> bool:
	# So that objects that want to listen for FKUnitUi signals
	# won't need to have any references to such beforehand.
	# This returns true if successful, false otherwise
	if on and not _is_subbed:
		before_contents_changed.connect(_on_before_contents_changed)
		contents_changed.connect(_on_contents_changed)
		selected.connect(_on_selected)
		edit_requested.connect(_on_edit_requested)
		delete_requested.connect(_on_delete_requested)
		reorder_requested.connect(_on_reorder_requested)
	elif _is_subbed and not on:
		before_contents_changed.disconnect(_on_before_contents_changed)
		contents_changed.disconnect(_on_contents_changed)
		selected.disconnect(_on_selected)
		edit_requested.disconnect(_on_edit_requested)
		delete_requested.disconnect(_on_delete_requested)
		reorder_requested.disconnect(_on_reorder_requested)
	else:
		return false
		
	return true

func _on_before_contents_changed(unit_ui: FKUnitUi):
	_unit_ui_signals.before_contents_changed.emit(unit_ui)
	
func _on_contents_changed(unit_ui: FKUnitUi):
	update_display()
	_unit_ui_signals.contents_changed.emit(self)

var _unit_ui_signals: FKUnitUiSignals:
	get:
		return _globals.unit_ui_signals
		
func _on_selected(node: FKUnitUi):
	_unit_ui_signals.selected.emit(self)
	
func _on_edit_requested(unit: FKUnitUi):
	_unit_ui_signals.edit_requested.emit(self)
	
func _on_delete_requested(unit: FKUnitUi):
	_unit_ui_signals.delete_requested.emit(self)
	
func _on_reorder_requested(unit: FKUnitUi, other: FKUnitUi, drop_above: bool):
	_unit_ui_signals.reorder_requested.emit(unit, other, drop_above)
	
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
func get_unit() -> FKUnit:
	return _unit

## The FKUnit that this Node represents.
var _unit: FKUnit

func has_unit() -> bool:
	return _unit != null

func set_unit(to_set: FKUnit) -> void:
	if is_editor_preview:
		return
	var valid := _validate_unit(to_set)
	if not valid:
		return
		
	before_contents_changed.emit(self)
	_unit = to_set
	contents_changed.emit(self)
	
## Meant to be overridden by subclasses.
func _validate_unit(to_set: FKUnit) -> bool:
	if is_editor_preview:
		return false
	_alert_need_for_override("_validate_unit")
	return false
	
	
func _alert_need_for_override(func_name: String):
	var error_message := "FKUnitUi " + name + " must override %s" % [func_name]
	printerr(error_message)
	
var registry: FKRegistry:
	get:
		return _globals.registry

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
	
	if _unit != null:
		result += "\nhas unit: true"
	return result
	
func get_class() -> String:
	return "FKUnitUi"
