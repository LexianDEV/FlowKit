extends FKCondition

func get_description() -> String:
	return "Checks if the timer is stopped."

func get_id() -> String:
	return "is_stopped"

func get_display_name() -> String:
	return "Is Stopped"

func get_inputs() -> Array[Dictionary]:
	return []

func get_supported_types() -> Array[String]:
	return ["Timer"]

func check(node: Node, inputs: Dictionary, block_id: int = -1) -> bool:
	if node and node is Timer:
		return node.is_stopped()
	return false