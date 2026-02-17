extends FKAction

func get_description() -> String:
	return "What you'd expect."

func get_id() -> String:
	return "Set Text"

func get_name() -> String:
	return "Set Text"
	
func get_inputs() -> Array:
	return [
		{
			"name": "New Text",
			"type": "String",
			"description": "The text that the target will hold."
		},
	]
	
func get_supported_types() -> Array:
	return ["Label", "RichTextLabel", "Button", "TextEdit", "LineEdit"]

func execute(target_node: Node, inputs: Dictionary, _str := "") -> void:
	var new_text: String = inputs.get("New Text", "")
	var has_text: Variant = target_node
	has_text.text = new_text
