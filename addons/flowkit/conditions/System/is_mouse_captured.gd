extends FKCondition

func get_description() -> String:
	return "Checks if the mouse cursor is captured (locked to the window center)."

func get_id() -> String:
	return "is_mouse_captured"

func get_name() -> String:
	return "Is Mouse Captured"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return []

func check(node: Node, inputs: Dictionary, block_id: String = "") -> bool:
	return Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
