extends FKAction

func get_description() -> String:
	var result: String = "Logs a message to the console."
	return result

func get_id() -> String:
	return "Print Message"

func get_name() -> String:
	return "Print Message"

func get_supported_types() -> Array:
	return ["Node"]

func get_inputs() -> Array[FKActionInput]:
	return [_color_input, _message_input]

static var _color_input: FKStringActionInput:
	get:
		return FKStringActionInput.new("Color",
		"Decides what BBCode color the message is wrapped in. Default: white.")

static var _message_input: FKStringActionInput:
	get:
		return FKStringActionInput.new("Message", 
		"The message to print. BBCode tags are supported.")

func execute(_node: Node, inputs: Dictionary, _str: String = "") -> void:
	var color = _color_input.get_val(inputs)
	var color_start_tag: String = "[color=" + color + "]"
	var color_end_tag: String = "[/color]"
	var node_name_tag = "[" + _node.name + "]: "
	var message := _message_input.get_val(inputs)
	message = color_start_tag + node_name_tag + str(message) + color_end_tag
	print_rich(message)
	
var default_color: String = "white"
