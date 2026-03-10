extends FKAction

func get_description() -> String:
	return "Prints a message to the console."

func get_id() -> String:
	return "print"

func get_name() -> String:
	return "Print"

func get_inputs() -> Array[FKActionInput]:
	return [_message_input]

static var _message_input: FKActionInput:
	get:
		return FKActionInput.new("Message", "String", "The message to print to the console.")

func get_supported_types() -> Array[String]:
	return ["System"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var message: Variant = inputs.get("Message", "")
	print(message)
