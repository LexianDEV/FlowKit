extends FKCondition

func get_description() -> String:
	return "Checks if the game window is in fullscreen mode."

func get_id() -> String:
	return "is_window_fullscreen"

func get_name() -> String:
	return "Is Window Fullscreen"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return []

func check(node: Node, inputs: Dictionary, block_id: String = "") -> bool:
	var mode: DisplayServer.WindowMode = DisplayServer.window_get_mode()
	return mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
