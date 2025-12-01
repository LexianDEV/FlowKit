extends FKCondition

func get_description() -> String:
	return "Checks if the window is minimized."

func get_id() -> String:
	return "is_minimized"

func get_name() -> String:
	return "Is Minimized"

func get_inputs() -> Array[Dictionary]:
	return []

func get_supported_types() -> Array[String]:
	return ["Window"]

func check(node: Node, inputs: Dictionary) -> bool:
	if node and node is Window:
		return node.mode == Window.MODE_MINIMIZED
	return false