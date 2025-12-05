extends FKAction

func get_description() -> String:
	return "Shows or hides the mouse cursor."

func get_id() -> String:
	return "set_mouse_visible"

func get_name() -> String:
	return "Set Mouse Visible"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Visible", "type": "bool", "description": "Whether the mouse cursor should be visible."},
	]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var visible: bool = bool(inputs.get("Visible", true))
	if visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
