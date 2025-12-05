extends FKCondition

func get_description() -> String:
	return "Checks if the specified input action was just released this frame."

func get_id() -> String:
	return "is_action_released"

func get_name() -> String:
	return "Is Action Released"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Action", "type": "String", "description": "The name of the input action (defined in InputMap)."}
	]

func check(node: Node, inputs: Dictionary, block_id: String = "") -> bool:
	var action_name: String = str(inputs.get("Action", ""))
	if action_name.is_empty():
		return false
	return Input.is_action_just_released(action_name)
