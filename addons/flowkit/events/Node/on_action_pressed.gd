extends FKAction

func get_description() -> String:
	return "This event occurs when an action from the input map is pressed."

func get_id() -> String:
    return "on_action_pressed"

func get_name() -> String:
    return "On Action Pressed"

func get_supported_types() -> Array:
    return ["Node2D"]

func get_inputs() -> Array:
    return [
        {"name": "amount", "type": "float"},
        {"name": "message", "type": "String"}
    ]

func execute(node: Node, inputs: Dictionary) -> void:
    var amount = inputs.get("amount", 0.0)
    var message = inputs.get("message", "")
    print(message, " - ", amount)
