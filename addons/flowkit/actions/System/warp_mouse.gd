extends FKAction

func get_description() -> String:
	return "Warps (moves) the mouse cursor to a specific screen position."

func get_id() -> String:
	return "warp_mouse"

func get_name() -> String:
	return "Warp Mouse"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[FKActionInput]:
	return [_x_input, _y_input]

static var _x_input: FKFloatActionInput:
	get:
		return FKFloatActionInput.new("X", "The X position to move the mouse to.")
static var _y_input: FKFloatActionInput:
	get:
		return FKFloatActionInput.new("Y", "The Y position to move the mouse to.")

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var x: float = _x_input.get_val(inputs)
	var y: float = _y_input.get_val(inputs)
	var pos: Vector2 = Vector2(x, y)
	Input.warp_mouse(pos)
