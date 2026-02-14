extends FKEvent

func get_description() -> String:
	return "This event will run at the start of the scene."

func get_id() -> String:
	return "on_ready"

func get_name() -> String:
	return "On Ready"

func get_supported_types() -> Array[String]:
	return ["Node"]

func get_inputs() -> Array:
	return []

func is_signal_event() -> bool:
	return true

func setup(node: Node, trigger_callback: Callable, block_id: String = "") -> void:
	trigger_callback.call()
