extends FKEvent

func get_description() -> String:
	return "Triggers when the specified input action is released."

func get_id() -> String:
	return "on_action_released"

func get_name() -> String:
	return "On Action Released"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array:
	return [
		{"name": "action", "type": "string", "description": "The name of the input action (defined in InputMap)."}
	]

func poll(node: Node, inputs: Dictionary = {}, block_id: String = "") -> bool:
	var action_name: String = inputs.get("action", "")
	if action_name == "":
		return false
	
	return Input.is_action_just_released(action_name)
