extends FKAction

func get_description() -> String:
	return "Sets the size of the game window."

func get_id() -> String:
	return "set_window_size"

func get_name() -> String:
	return "Set Window Size"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[FKActionInput]:
	return [_width_input, _height_input]

static var _width_input: FKActionInput:
	get:
		return FKActionInput.new("Width", "int", "The width of the window in pixels.")
static var _height_input: FKActionInput:
	get:
		return FKActionInput.new("Height", "int", "The height of the window in pixels.")

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var width: int = int(inputs.get("Width", 1280))
	var height: int = int(inputs.get("Height", 720))
	DisplayServer.window_set_size(Vector2i(width, height))
