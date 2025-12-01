extends FKCondition

func get_description() -> String:
	return "Checks if the game is currently paused."

func get_id() -> String:
	return "is_paused"

func get_name() -> String:
	return "Is Paused"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return []

func check(node: Node, inputs: Dictionary) -> bool:
	if not node or not node.is_inside_tree():
		return false
	return node.get_tree().paused