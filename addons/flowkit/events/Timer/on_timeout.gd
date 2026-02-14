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

var _callback: Callable

func setup(node: Node, trigger_callback: Callable, _block_id: String = "") -> void:
	_callback = func(): trigger_callback.call()
	node.timeout.connect(_callback)

func teardown(node: Node, _block_id: String = "") -> void:
	if is_instance_valid(node) and node.timeout.is_connected(_callback):
		node.timeout.disconnect(_callback)
