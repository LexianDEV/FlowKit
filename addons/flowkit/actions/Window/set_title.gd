extends FKAction

func get_description() -> String:
	return "Sets the title of the window."

func get_id() -> String:
	return "set_title"

func get_name() -> String:
	return "Set Title"

func get_inputs() -> Array[FKActionInput]:
	return [_title_input]

static var _title_input: FKActionInput:
	get:
		return FKActionInput.new("Title", "String", "The title to set for the window.")

func get_supported_types() -> Array[String]:
	return ["Window"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	if node and node is Window:
		var title: String = inputs.get("Title", "")
		node.title = title
