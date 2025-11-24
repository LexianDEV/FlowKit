extends FKEvent

func get_id() -> String:
	return "on_process"

func get_name() -> String:
	return "On Process"

func get_supported_types() -> Array[String]:
	return ["Node", "System"]

func get_inputs() -> Array:
	return []

func poll(node: Node, inputs: Dictionary = {}) -> bool:
	if node and node.is_inside_tree():
		return true

	return false
