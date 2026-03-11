extends FKAction

func get_description() -> String:
	return "Simulates releasing an input action programmatically."

func get_id() -> String:
	return "action_release"

func get_name() -> String:
	return "Action Release"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[FKActionInput]:
	return [_action_input]
	
static var _action_input: FKStringActionInput:
	get:
		return FKStringActionInput.new("Action",
		"The name of the input action to simulate releasing.")

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var action_name: String = _action_input.get_val(inputs)
	
	if not action_name.is_empty():
		Input.action_release(action_name)
