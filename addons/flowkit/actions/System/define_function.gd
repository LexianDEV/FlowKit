extends FKAction

func get_description() -> String:
	return "Defines a new function that can be called anywhere else in the scene the function is defined in."

func get_id() -> String:
	return "define_function"

func get_name() -> String:
	return "Define Function"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Name", "type": "String", "description": "The name of the function to define."},
	]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var function_name: String = str(inputs.get("Name", ""))

	if function_name.is_empty():
		return