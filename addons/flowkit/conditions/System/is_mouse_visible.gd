extends FKCondition

func get_description() -> String:
	return "Checks if the mouse cursor is currently visible."

func get_id() -> String:
	return "is_mouse_visible"

func get_name() -> String:
	return "Is Mouse Visible"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return []

func check(node: Node, inputs: Dictionary, block_id: String = "") -> bool:
	var mode: Input.MouseMode = Input.get_mouse_mode()
	return mode == Input.MOUSE_MODE_VISIBLE or mode == Input.MOUSE_MODE_CONFINED
