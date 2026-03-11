extends FKAction

func get_description() -> String:
	return "Shows or hides the mouse cursor."

func get_id() -> String:
	return "set_mouse_visible"

func get_name() -> String:
	return "Set Mouse Visible"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[FKActionInput]:
	return [_vis_input]

static var _vis_input: FKBoolActionInput:
	get:
		return FKBoolActionInput.new("Visible", 
		"Whether the mouse cursor should be visible.",
		true)

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var visible: bool = _vis_input.get_val(inputs)
	if visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
