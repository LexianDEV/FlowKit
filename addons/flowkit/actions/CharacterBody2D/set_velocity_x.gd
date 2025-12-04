extends FKAction

func get_description() -> String:
	return "Sets the X component of the character's velocity."

func get_id() -> String:
	return "set_velocity_x"

func get_name() -> String:
	return "Set X Velocity"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "X", "type": "Float", "description": "The X component of the velocity to set."}
	]

func get_supported_types() -> Array[String]:
	return ["CharacterBody2D"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	if not node is CharacterBody2D:
		return
	
	var body: CharacterBody2D = node as CharacterBody2D
	var x: float = float(inputs.get("X", 0))
	
	body.velocity.x = x
