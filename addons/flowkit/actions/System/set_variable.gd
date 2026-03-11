extends FKAction

func get_description() -> String:
	return "Sets a scene variable that can be retrieved via system.get_var(\"variable_name\") in the expression editor."

func get_id() -> String:
	return "set_variable"

func get_name() -> String:
	return "Set Variable"

func get_inputs() -> Array[FKActionInput]:
	return [_name_input, _val_input]

static var _name_input: FKStringActionInput:
	get:
		return FKStringActionInput.new("Name", "The name of the variable to set.")
static var _val_input: FKActionInput:
	get:
		return FKActionInput.new("Value", "Variant", "The value to assign to the variable.", null)

func get_supported_types() -> Array[String]:
	return ["System"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var name: String = _name_input.get_val(inputs)
	var value: Variant = _val_input.get_val(inputs)
	
	# Store in FlowKitSystem singleton
	var system: Node = node.get_tree().root.get_node_or_null("/root/FlowKitSystem")
	if system and system.has_method("set_var"):
		system.set_var(name, value)
