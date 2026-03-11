extends FKAction

func get_description() -> String:
	return "Sets the position of the game window on the screen."

func get_id() -> String:
	return "set_window_position"

func get_name() -> String:
	return "Set Window Position"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[FKActionInput]:
	return [_x_input, _y_input]
	
static var _x_input: FKIntActionInput:
	get:
		return FKIntActionInput.new("X", "The X position of the window in pixels.")
static var _y_input: FKIntActionInput:
	get:
		return FKIntActionInput.new("Y", "The Y position of the window in pixels.")

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var x: int = _x_input.get_val(inputs)
	var y: int = _y_input.get_val(inputs)
	DisplayServer.window_set_position(Vector2i(x, y))
