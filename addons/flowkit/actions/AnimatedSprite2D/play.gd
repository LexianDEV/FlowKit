extends FKAction

func get_id() -> String:
	return "animatedsprite2d_play"

func get_name() -> String:
	return "Play"

func get_description() -> String:
	return "Plays the current animation on an AnimatedSprite2D."

func get_inputs() -> Array[Dictionary]:
	return [{"name": "Name", "type": "Variant"}, {"name": "Custom Speed", "type": "Float"}, {"name": "From End", "type": "Bool"}]

func get_supported_types() -> Array[String]:
	return ["AnimatedSprite2D"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	if not node is AnimatedSprite2D:
		return
	
	node.play(inputs.get("Name", null), inputs.get("Custom Speed", 0.0), inputs.get("From End", false))
