extends FKAction

func get_description() -> String:
	return "Sets the rotation of the node in radians."

func get_id() -> String:
	return "set_rotation"

func get_name() -> String:
	return "Set Rotation"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Rotation", "type": "Float", "description": "The rotation in radians to set the node to."},
	]

func get_supported_types() -> Array[String]:
	return ["Node2D"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	if not node is Node2D:
		return
	
	var node2d: Node2D = node as Node2D
	var rotation_value: float = float(inputs.get("Rotation", 0))
	
	node2d.rotation = rotation_value
