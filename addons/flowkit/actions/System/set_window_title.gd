extends FKAction

func get_description() -> String:
	return "Sets the title of the main game window."

func get_id() -> String:
	return "set_window_title"

func get_name() -> String:
	return "Set Window Title"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Title", "type": "String", "description": "The title to set for the window."},
	]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var title: String = str(inputs.get("Title", ""))
	DisplayServer.window_set_title(title)
