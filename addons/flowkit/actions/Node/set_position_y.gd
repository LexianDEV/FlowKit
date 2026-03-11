extends FKAction

func get_description() -> String:
	return "Sets the Y coordinate of the node's position."

func get_id() -> String:
	return "set_position_y"

func get_name() -> String:
	return "Set Y Position"

func get_inputs() -> Array[FKActionInput]:
	return [_val_input]

static var _val_input: FKActionInput:
	get:
		return FKActionInput.new("Y", "Float",
		"The Y coordinate to set the node's position to.")

func get_supported_types() -> Array[String]:
	return ["Node2D"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	if not node is Node2D:
		return
	
	var node2d: Node2D = node as Node2D
	node2d.position.y = _val_input.get_val(inputs)
