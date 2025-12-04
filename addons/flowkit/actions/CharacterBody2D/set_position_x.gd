extends FKAction

func get_description() -> String:
	return "Sets the X coordinate of the character's position."

func get_id() -> String:
	return "set_position_x"

func get_name() -> String:
	return "Set X Position"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "X", "type": "Float", "description": "The X coordinate to set the character's position to."},
	]

func get_supported_types() -> Array[String]:
	return ["CharacterBody2D"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	if not node is CharacterBody2D:
		return
	
	var body: CharacterBody2D = node as CharacterBody2D
	var x: float = float(inputs.get("X", 0))
	
	body.position.x = x
