extends FKAction

func get_description() -> String:
	return "Gets a 2-way input axis (e.g., left/right or up/down) and stores it in a system variable. Access it via system.get_var(\"variable_name\") in expressions."

func get_id() -> String:
	return "get_input_axis_2way"

func get_name() -> String:
	return "Get Input Axis (2-Way)"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Negative Action", "type": "String", "description": "The input action for negative axis (e.g., 'move_left')."},
		{"name": "Positive Action", "type": "String", "description": "The input action for positive axis (e.g., 'move_right')."},
		{"name": "Store In", "type": "String", "description": "The system variable name to store the result in."},
	]

func get_supported_types() -> Array[String]:
	return ["System"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var negative_action: String = str(inputs.get("Negative Action", ""))
	var positive_action: String = str(inputs.get("Positive Action", ""))
	var store_in: String = str(inputs.get("Store In", ""))

	if negative_action.is_empty() or positive_action.is_empty() or store_in.is_empty():
		return

	var value: float = Input.get_axis(negative_action, positive_action)

	var system: Node = node.get_tree().root.get_node_or_null("/root/FlowKitSystem")
	if system and system.has_method("set_var"):
		system.set_var(store_in, value)
