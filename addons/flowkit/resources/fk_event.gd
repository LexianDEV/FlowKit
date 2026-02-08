extends Resource
class_name FKEvent

func get_description() -> String:
	return "No description provided."

func get_id() -> String:
	return ""

func get_name() -> String:
	return ""

func get_supported_types() -> Array[String]:
	return []

func get_inputs() -> Array:
	return []

func poll(node: Node, inputs: Dictionary = {}, block_id: String = "") -> bool:
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
## Override this in signal-based events. The default implementation does nothing.
## Parameters:
##   node: The target node this event block points at.
##   trigger_callback: A Callable — call it to execute the block's conditions & actions.
##   block_id: The unique identifier for this event block instance.
func setup(node: Node, trigger_callback: Callable, block_id: String = "") -> void:
	pass

## Called when the engine unloads an event sheet (e.g. on scene change).
## Use this to disconnect signals or clean up any state created in setup().
## The default implementation does nothing.
func teardown(node: Node, block_id: String = "") -> void:
	pass
