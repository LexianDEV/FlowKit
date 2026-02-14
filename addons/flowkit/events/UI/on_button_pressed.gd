extends FKEvent

func get_description() -> String:
	return "Executes a block of Actions in response to a button-press."

func get_id() -> String:
	return "On Button Pressed"

func get_name() -> String:
	return "On Button Pressed"
	
func get_supported_types() -> Array:
	return ["Button"]

func is_signal_event() -> bool:
	return true

var _callback: Callable

func setup(target_node: Node, trigger_callback: Callable, instance_id: String = "") -> void:
	_callback = func(): trigger_callback.call()
	target_node.pressed.connect(_callback)

func teardown(target_node: Node, instance_id: String = "") -> void:
	if is_instance_valid(target_node) and target_node.pressed.is_connected(_callback):
		target_node.pressed.disconnect(_callback)
