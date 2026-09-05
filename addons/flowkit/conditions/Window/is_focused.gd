extends FKCondition

func get_description() -> String:
	return "Checks if the window has focus."

func get_id() -> String:
	return "is_focused"

func get_display_name() -> String:
	return "Is Focused"

func get_inputs() -> Array[Dictionary]:
	return []

func get_supported_types() -> Array[String]:
	return ["Window"]

func check(node: Node, inputs: Dictionary, block_id: int = -1) -> bool:
	if node and node is Window:
		return node.has_focus()
	return false