extends FKAction

func get_description() -> String:
	return "Sets the X coordinate of the node's position."

func get_id() -> String:
	return "set_position_x"

func get_name() -> String:
	return "Set X Position"

func get_inputs() -> Array[FKActionInput]:
	return [_val_input]

static var _val_input: FKFloatActionInput:
	get:
		return FKFloatActionInput.new("X", 
		"The X coordinate to set the node's position to.")

func get_supported_types() -> Array[String]:
	return ["Node2D"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	if not node is Node2D:
		return
	
	var node2d: Node2D = node as Node2D
	node2d.position.x = _val_input.get_val(inputs)
