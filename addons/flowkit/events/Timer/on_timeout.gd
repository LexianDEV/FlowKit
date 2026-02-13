extends FKEvent 

func get_description() -> String:
	return "Runs the actions when the designated Timer is done counting down."

func get_id() -> String:
	return "Timer on Timeout"

func get_name() -> String:
	return "On Timeout"

func get_supported_types() -> Array[String]:
	return ["Timer"]

func is_signal_event() -> bool:
	return true

func setup(node: Node, trigger_callback: Callable, _block_id: String = "") -> void:
	exec_actions = trigger_callback
	var timer: Timer = node
	timer.timeout.connect(exec_actions)
	pass
	
var exec_actions: Callable

func on_timeout() -> void:
	exec_actions.call()
	pass

## Called when the engine unloads an event sheet (e.g. on scene change).
## Use this to disconnect signals or clean up any state created in setup().
## The default implementation does nothing.
func teardown(_node: Node, _block_id: String = "") -> void:
	exec_actions = Callable()
	pass
