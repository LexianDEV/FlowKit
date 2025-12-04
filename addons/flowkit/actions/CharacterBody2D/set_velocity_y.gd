extends FKAction

func get_description() -> String:
	return "Sets the Y component of the character's velocity."

func get_id() -> String:
	return "set_velocity_y"

func get_name() -> String:
	return "Set Y Velocity"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Y", "type": "Float", "description": "The Y component of the velocity to set."}
	]

func get_supported_types() -> Array[String]:
	return ["CharacterBody2D"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	if not node is CharacterBody2D:
		return
	
	var body: CharacterBody2D = node as CharacterBody2D
	var y: float = float(inputs.get("Y", 0))
	
	body.velocity.y = y
