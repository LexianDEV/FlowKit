extends FKAction

func get_id() -> String:
	return "animatedsprite2d_play"

func get_name() -> String:
	return "Play"

func get_description() -> String:
	return "Plays the current animation on an AnimatedSprite2D."

func get_inputs() -> Array[FKActionInput]:
	return [_name_input, _speed_input, _from_end_input]

static var _name_input: FKActionInput:
	get: return FKActionInput.new("Name", "Variant")
static var _speed_input: FKActionInput:
	get: return FKActionInput.new("Custom Speed", "Float")
	
static var _from_end_input: FKActionInput:
	get: return FKActionInput.new("From End", "Bool")

func get_supported_types() -> Array[String]:
	return ["AnimatedSprite2D"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	if not node is AnimatedSprite2D:
		return
	
	node.play(inputs.get("Name", null), inputs.get("Custom Speed", 0.0), inputs.get("From End", false))
