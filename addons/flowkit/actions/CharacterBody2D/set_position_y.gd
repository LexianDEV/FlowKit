extends FKAction

func get_description() -> String:
	return "Sets the Y coordinate of the character's position."

func get_id() -> String:
	return "set_position_y"

func get_name() -> String:
	return "Set Y Position"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Y", "type": "Float", "description": "The Y coordinate to set the character's position to."},
	]

func get_supported_types() -> Array[String]:
	return ["CharacterBody2D"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	if not node is CharacterBody2D:
		return
	
	var body: CharacterBody2D = node as CharacterBody2D
	var y: float = float(inputs.get("Y", 0))
	
	body.position.y = y
