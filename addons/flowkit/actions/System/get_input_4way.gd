extends FKAction

func get_description() -> String:
	return "Gets 4-way input axes (horizontal and vertical) and stores them in system variables. Access them via system.get_var(\"variable_name\") in expressions."

func get_id() -> String:
	return "get_input_axis_4way"

func get_name() -> String:
	return "Get Input Axis (4-Way)"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Negative X Action", "type": "String", "description": "The input action for negative horizontal axis (e.g., 'move_left')."},
		{"name": "Positive X Action", "type": "String", "description": "The input action for positive horizontal axis (e.g., 'move_right')."},
		{"name": "Negative Y Action", "type": "String", "description": "The input action for negative vertical axis (e.g., 'move_up')."},
		{"name": "Positive Y Action", "type": "String", "description": "The input action for positive vertical axis (e.g., 'move_down')."},
		{"name": "Store X In", "type": "String", "description": "The system variable name to store the horizontal result in."},
		{"name": "Store Y In", "type": "String", "description": "The system variable name to store the vertical result in."},
	]

func get_supported_types() -> Array[String]:
	return ["System"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var negative_x_action: String = str(inputs.get("Negative X Action", ""))
	var positive_x_action: String = str(inputs.get("Positive X Action", ""))
	var negative_y_action: String = str(inputs.get("Negative Y Action", ""))
	var positive_y_action: String = str(inputs.get("Positive Y Action", ""))
	var store_x_in: String = str(inputs.get("Store X In", ""))
	var store_y_in: String = str(inputs.get("Store Y In", ""))

	if negative_x_action.is_empty() or positive_x_action.is_empty() or store_x_in.is_empty():
		return
	
	if negative_y_action.is_empty() or positive_y_action.is_empty() or store_y_in.is_empty():
		return

	var x_value: float = Input.get_axis(negative_x_action, positive_x_action)
	var y_value: float = Input.get_axis(negative_y_action, positive_y_action)

	var system: Node = node.get_tree().root.get_node_or_null("/root/FlowKitSystem")
	if system and system.has_method("set_var"):
		system.set_var(store_x_in, x_value)
		system.set_var(store_y_in, y_value)
