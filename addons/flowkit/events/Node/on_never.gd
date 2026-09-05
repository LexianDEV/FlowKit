extends FKEvent

func get_description() -> String:
	return "This event will never be executed."

func get_id() -> String:
	return "on_never"

func get_name() -> String:
	return "On Never"

func get_supported_types() -> Array[String]:
	return ["Node", "System"]

func get_inputs() -> Array:
	return []

func poll(node: Node, inputs: Dictionary = {}, block_id: int = -1) -> bool:
	return false
