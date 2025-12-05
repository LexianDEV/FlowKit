extends FKAction

func get_description() -> String:
	return "Warps (moves) the mouse cursor to a specific screen position."

func get_id() -> String:
	return "warp_mouse"

func get_name() -> String:
	return "Warp Mouse"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "X", "type": "float", "description": "The X position to move the mouse to."},
		{"name": "Y", "type": "float", "description": "The Y position to move the mouse to."},
	]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var x: float = float(inputs.get("X", 0))
	var y: float = float(inputs.get("Y", 0))
	Input.warp_mouse(Vector2(x, y))
