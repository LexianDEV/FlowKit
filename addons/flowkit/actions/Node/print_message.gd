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

func get_inputs() -> Array:
    return [
        {
            "name": "color",
            "type": "String", 
            "description": "Decides what BBCode color the message is wrapped in. Default: white."
        },
        {
            "name": "message",
            "type": "String",
            "description": "The message to print. BBCode tags are supported."
        }
    ]

func execute(_node: Node, inputs: Dictionary, _str: String = "") -> void:
    var color_input = inputs.get("color", default_color)
    var color_start_tag: String = "[color=" + color_input + "]"
    var color_end_tag: String = "[/color]"
    var node_name_tag = "[" + _node.name + "]: "
    var message = inputs.get("message", "")
    message = color_start_tag + node_name_tag + message + color_end_tag
    print_rich(message)
    
var default_color: String = "white"