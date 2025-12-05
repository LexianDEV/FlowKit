extends FKCondition

func get_description() -> String:
	return "Checks if the game window currently has focus."

func get_id() -> String:
	return "is_window_focused"

func get_name() -> String:
	return "Is Window Focused"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return []

func check(node: Node, inputs: Dictionary, block_id: String = "") -> bool:
	return DisplayServer.window_is_focused()
