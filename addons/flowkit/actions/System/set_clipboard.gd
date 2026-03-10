extends FKAction

func get_description() -> String:
	return "Sets the text content of the system clipboard."

func get_id() -> String:
	return "set_clipboard"

func get_name() -> String:
	return "Set Clipboard"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[FKActionInput]:
	return [_text_input]
	
static var _text_input: FKActionInput:
	get:
		return FKActionInput.new("Text", "String", "The text to copy to the clipboard.")

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var text: String = str(inputs.get("Text", ""))
	DisplayServer.clipboard_set(text)
