extends FKAction

func get_description() -> String:
	return "Captures or releases the mouse cursor (captured mode locks the cursor to the window center)."

func get_id() -> String:
	return "set_mouse_captured"

func get_name() -> String:
	return "Set Mouse Captured"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Captured", "type": "bool", "description": "Whether the mouse cursor should be captured."},
	]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var captured: bool = bool(inputs.get("Captured", true))
	if captured:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
