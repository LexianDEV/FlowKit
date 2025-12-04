extends FKAction

func get_description() -> String:
	return "Sets the rotation of the character in radians."

func get_id() -> String:
	return "set_rotation"

func get_name() -> String:
	return "Set Rotation"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Rotation", "type": "Float", "description": "The rotation in radians to set the character to."},
	]

func get_supported_types() -> Array[String]:
	return ["CharacterBody2D"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	if not node is CharacterBody2D:
		return
	
	var body: CharacterBody2D = node as CharacterBody2D
	var rotation_value: float = float(inputs.get("Rotation", 0))
	
	body.rotation = rotation_value
