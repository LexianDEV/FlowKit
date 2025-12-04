extends FKAction

func get_description() -> String:
	return "Prints a message to the console."

func get_id() -> String:
	return "print"

func get_name() -> String:
	return "Print"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Message", "type": "String", "description": "The message to print to the console."},
	]

func get_supported_types() -> Array[String]:
	return ["System"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var message: Variant = inputs.get("Message", "")
	print(message)
