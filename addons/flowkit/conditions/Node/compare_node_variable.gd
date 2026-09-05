extends FKCondition

func get_description() -> String:
	return "Compares a property of the node against a specified value using the given comparison operator."

func get_id() -> String:
	return "compare_node_variable"

func get_display_name() -> String:
	return "Compare Node Variable"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Property", "type": "String", "description": "The property expression to compare (e.g., 'velocity.x', 'position', 'node.global_position.y')."},
		{"name": "Comparison", "type": "String", "description": "The comparison operator (==, !=, <, >, <=, >=)."},
		{"name": "Value", "type": "Variant", "description": "The value to compare against. Can be a literal (1, 1.0, true, \"text\") or expression (node.speed, node.position.length())."}
	]

func get_supported_types() -> Array[String]:
	return ["Node"]

func check(node: Node, inputs: Dictionary, block_id: int = -1) -> bool:
	# Note: inputs are pre-evaluated by the registry, so Property is already the value
	var current_value: Variant = inputs.get("Property", null)
	var comparison: String = str(inputs.get("Comparison", "=="))
	var compare_value: Variant = inputs.get("Value", null)
	
	if current_value == null:
		return false
	
	# Perform the comparison
	match comparison:
		"==": return current_value == compare_value
		"!=": return current_value != compare_value
		"<": return current_value < compare_value
		">": return current_value > compare_value
		"<=": return current_value <= compare_value
		">=": return current_value >= compare_value
		_: return current_value == compare_value
