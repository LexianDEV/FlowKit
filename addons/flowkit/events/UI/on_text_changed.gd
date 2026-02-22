extends FKEvent

func get_description() -> String:
	return "Executes a block of Actions in response to the text of a Node changing."

func get_id() -> String:
	return "On Text Changed"

func get_name() -> String:
	return "On Text Changed"
	
func get_supported_types() -> Array:
	return ["Label", "RichTextLabel", "Button", "TextEdit", "LineEdit"]

func is_signal_event() -> bool:
	return true

func setup(target_node: Node, trigger_callback: Callable, instance_id: String = "") -> void:
	# Note that this will _not_ execute before the OnReady in the same Event Sheet this is
	# in, unless enough waiting happens there for this func to start. That's why in the 
	# quiz game demo scene, we added a 1-frame wait Action so that we can listen _before_
	# the target answer button's text changes.
	_our_target = target_node
	_exec_actions = trigger_callback
	_toggle_subs_for(target_node, true)

var _our_target: Node
# ^We need this so that when responding to the global signal, we only respond to 
# the target we were assigned.

var _exec_actions: Callable

## Handles connecting and disconnecting the signals. ##
func _toggle_subs_for(target_node: Node, on: bool):
	var type := target_node.get_class()
	var system = target_node.get_tree().root.get_node_or_null("/root/FlowKitSystem")
	if not system:
		return
	var globals = system.global_signals
	var use_our_own_signal := !auto_signals_own_text_changes.has(type)
	
	if on:
		if use_our_own_signal:
			_callback = _global_text_change_response
			globals.text_changed.connect(_callback)
		else:
			_callback = func(new_text): _exec_actions.call()
			target_node.text_changed.connect(_callback)
	else:
		if globals.text_changed.is_connected(_callback):
			globals.text_changed.disconnect(_callback)
			
		if target_node.has_signal("text_changed") && target_node.text_changed.is_connected(_callback):
			target_node.text_changed.disconnect(_callback)
	
static var auto_signals_own_text_changes: Array = ["LineEdit"]
var _callback: Callable

func _global_text_change_response(new_text: String, prev_text: String, target: Variant):
	if target != _our_target:
		return
	_exec_actions.call()
	
func teardown(target_node: Node, instance_id: String = "") -> void:
	if !is_instance_valid(target_node):
		return
		
	_toggle_subs_for(target_node, false)
	
