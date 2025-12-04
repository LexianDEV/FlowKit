extends FKAction

func get_description() -> String:
	return "Sets a scene variable that can be retrieved via system.get_var(\"variable_name\") in the expression editor."

func get_id() -> String:
	return "set_variable"

func get_name() -> String:
	return "Set Variable"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Name", "type": "String", "description": "The name of the variable to set."},
        {"name": "Value", "type": "Variant", "description": "The value to assign to the variable."},
	]

func get_supported_types() -> Array[String]:
	return ["System"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var name: String = str(inputs.get("Name", ""))
	var value: Variant = inputs.get("Value", null)
	
	# Store in FlowKitSystem singleton
	var system: Node = node.get_tree().root.get_node_or_null("/root/FlowKitSystem")
	if system and system.has_method("set_var"):
		system.set_var(name, value)