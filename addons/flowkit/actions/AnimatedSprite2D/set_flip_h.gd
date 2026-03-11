extends FKAction

func get_id() -> String:
	return "set_flip_h"

func get_name() -> String:
	return "Set Flip H"

func get_description() -> String:
	return "Flips the sprite horizontally when set to true."

func get_inputs() -> Array[FKActionInput]:
	return [_value_input]

static var _value_input: FKBoolActionInput:
	get: return FKBoolActionInput.new("Value")

func get_supported_types() -> Array[String]:
	return ["AnimatedSprite2D"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	if not node is AnimatedSprite2D:
		return
	
	var value = _value_input.get_val(inputs)
	node.flip_h = value
