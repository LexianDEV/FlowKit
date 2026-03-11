extends FKAction

func get_description() -> String:
	return "Simulates pressing an input action programmatically."

func get_id() -> String:
	return "action_press"

func get_name() -> String:
	return "Action Press"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[FKActionInput]:
	return [_action_input, _strength_input]

static var _action_input: FKStringActionInput:
	get:
		return FKStringActionInput.new("Action", 
		"The name of the input action to simulate pressing.")
static var _strength_input: FKFloatActionInput:
	get:
		return FKFloatActionInput.new("Strength", 
		"The strength of the action press (0.0 to 1.0).",
		1.0)

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var action_name: String = _action_input.get_val(inputs)
	var strength: float = _strength_input.get_val(inputs)
	strength = clampf(strength, 0.0, 1.0)
	
	if not action_name.is_empty():
		Input.action_press(action_name, strength)
