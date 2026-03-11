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

static var _width_input: FKIntActionInput:
	get:
		return FKIntActionInput.new("Width", "The width of the window in pixels.", 1280)
static var _height_input: FKIntActionInput:
	get:
		return FKIntActionInput.new("Height", "The height of the window in pixels.", 720)

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var width: int = _width_input.get_val(inputs)
	var height: int = _height_input.get_val(inputs)
	var size: Vector2i = Vector2i(width, height)
	DisplayServer.window_set_size(size)
