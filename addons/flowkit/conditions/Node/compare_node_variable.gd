extends FKCondition

func get_description() -> String:
	return "Compares a property of the node against a specified value using the given comparison operator."

func get_id() -> String:
	return "compare_node_variable"

func get_name() -> String:
	return "Compare Node Variable"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Property", "type": "String", "description": "The property expression to compare (e.g., 'velocity.x', 'position', 'node.global_position.y')."},
		{"name": "Comparison", "type": "String", "description": "The comparison operator (==, !=, <, >, <=, >=)."},
		{"name": "Value", "type": "Variant", "description": "The value to compare against. Can be a literal (1, 1.0, true, \"text\") or expression (node.speed, node.position.length())."}
	]

func get_supported_types() -> Array[String]:
	return ["Node"]

func check(node: Node, inputs: Dictionary, block_id: String = "") -> bool:
	var property_expr: String = str(inputs.get("Property", ""))
	var comparison: String = str(inputs.get("Comparison", "=="))
	var compare_value: Variant = inputs.get("Value", null)
	
	if property_expr.is_empty():
		return false
	
	# Get FKExpressionEvaluator and evaluate both sides
	var evaluator = load("res://addons/flowkit/runtime/expression_evaluator.gd")
	var current_value: Variant = evaluator.evaluate(property_expr, node)
	
	# Also evaluate the comparison value if it's a string (could be a literal or expression)
	if compare_value is String:
		compare_value = evaluator.evaluate(compare_value, node)
	
	# Perform the comparison
	match comparison:
		"==": return current_value == compare_value
		"!=": return current_value != compare_value
		"<": return current_value < compare_value
		">": return current_value > compare_value
		"<=": return current_value <= compare_value
		">=": return current_value >= compare_value
		_: return current_value == compare_value
