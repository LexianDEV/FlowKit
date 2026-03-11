extends FKAction

func get_description() -> String:
	return "Sets the Y component of the character's velocity."

func get_id() -> String:
	return "set_velocity_y"

func get_name() -> String:
	return "Set Y Velocity"

func get_inputs() -> Array[FKActionInput]:
	return [_value_input]

static var _value_input: FKFloatActionInput:
	get:
		return FKFloatActionInput.new("Y",
		"What to set the Y component of the velocity to.")

func get_supported_types() -> Array[String]:
	return ["CharacterBody2D"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	if not node is CharacterBody2D:
		return
	
	var body: CharacterBody2D = node as CharacterBody2D
	var y: float = _value_input.get_val(inputs)
	
	body.velocity.y = y

func get_class() -> String:
	return "Set Velocity Y"
