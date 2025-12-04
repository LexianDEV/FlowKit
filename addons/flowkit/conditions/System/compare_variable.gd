extends FKCondition

func get_description() -> String:
	return "Compares a global variable against a specified value using the given comparison operator."

func get_id() -> String:
	return "compare_variable"

func get_name() -> String:
	return "Compare Variable"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Name", "type": "String", "description": "The name of the variable to compare."},
		{"name": "Comparison", "type": "String", "description": "The comparison operator to use (e.g., '==', '!=', '<', '>', '<=', '>=')."},
		{"name": "Value", "type": "Variant", "description": "The value to compare the variable against."}
	]

func get_supported_types() -> Array[String]:
	return ["System"]

func check(node: Node, inputs: Dictionary, block_id: String = "") -> bool:
	var name: String = str(inputs.get("Name", ""))
	var comparison: String = str(inputs.get("Comparison", "=="))
	var compare_value: Variant = inputs.get("Value", null)
	
	var system: Node = node.get_tree().root.get_node_or_null("/root/FlowKitSystem")
	if not system or not system.has_method("get_var"):
		return false
	
	var var_value: Variant = system.get_var(name, null)
	
	match comparison:
		"==": return var_value == compare_value
		"!=": return var_value != compare_value
		"<": return var_value < compare_value
		">": return var_value > compare_value
		"<=": return var_value <= compare_value
		">=": return var_value >= compare_value
		_: return var_value == compare_value
