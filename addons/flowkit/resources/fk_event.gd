extends FKProvider
class_name FKEvent

func poll(node: Node, inputs: Dictionary = {}, unit_id: int = -1) -> bool:
	return false

## Override to return true when this event fires via signals instead of polling.
## Signal events skip the per-frame poll() loop and instead call trigger_callback
## directly from setup() when the connected signal fires.
func is_signal_event() -> bool:
	return false

## Called once when the engine loads an event sheet containing this event.
## Use this to connect to Godot signals on the target node. Call
## trigger_callback.call() to fire this event's actions immediately, without
## waiting for the next poll() frame.
##
## Existing signal events can continue overriding this method when they do not
## need access to configured event inputs. Input-aware signal events should
## override setup_with_inputs() instead.
## Parameters:
##   node: The target node this event block points at.
##   trigger_callback: A Callable — call it to execute the block's conditions & actions.
##   unit_id: The unique identifier for this FKEventUnit instance.
func setup(node: Node, trigger_callback: Callable, unit_id: int = -1) -> void:
	pass

## Input-aware setup hook for signal-based events.
##
## The engine evaluates the FKEventUnit's configured inputs before calling this
## method. Override this when establishing the signal connection depends on
## event inputs, such as a named custom event or a configurable timer.
##
## The default implementation forwards to setup() so existing providers remain
## compatible without any changes.
func setup_with_inputs(
	node: Node,
	_inputs: Dictionary,
	trigger_callback: Callable,
	unit_id: int = -1
) -> void:
	setup(node, trigger_callback, unit_id)

## Called when the engine unloads an event sheet (e.g. on scene change).
## Use this to disconnect signals or clean up any state created in setup().
## The default implementation does nothing.
func teardown(node: Node, unit_id: int = -1) -> void:
	pass
	
func get_class() -> String:
	return "FKEvent"
