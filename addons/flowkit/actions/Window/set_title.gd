extends FKAction

func get_description() -> String:
	return "Sets the title of the window."

func get_id() -> String:
	return "set_title"

func get_name() -> String:
	return "Set Title"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Title", "type": "String"}
	]

func get_supported_types() -> Array[String]:
	return ["Window"]

func execute(node: Node, inputs: Dictionary) -> void:
	if node and node is Window:
		var title: String = inputs.get("Title", "")
		node.title = title