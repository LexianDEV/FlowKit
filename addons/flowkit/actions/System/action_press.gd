extends FKAction

func get_description() -> String:
	return "Simulates pressing an input action programmatically."

func get_id() -> String:
	return "action_press"

func get_name() -> String:
	return "Action Press"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Action", "type": "String", "description": "The name of the input action to simulate pressing."},
		{"name": "Strength", "type": "float", "description": "The strength of the action press (0.0 to 1.0)."},
	]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var action_name: String = str(inputs.get("Action", ""))
	var strength: float = clampf(float(inputs.get("Strength", 1.0)), 0.0, 1.0)
	
	if not action_name.is_empty():
		Input.action_press(action_name, strength)
