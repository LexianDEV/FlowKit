extends FKAction

func get_id() -> String:
	return "set_flip_v"

func get_name() -> String:
	return "Set Flip V"

func get_description() -> String:
	return "Flips the sprite vertically when set to true."

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Value", "type": "Bool"}
	]

func get_supported_types() -> Array[String]:
	return ["AnimatedSprite2D"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	if not node is AnimatedSprite2D:
		return
	
	var value = inputs.get("Value", false)
	node.flip_v = value
