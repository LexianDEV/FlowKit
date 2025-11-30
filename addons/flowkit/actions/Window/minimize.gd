extends FKAction

func get_description() -> String:
	return "Minimizes the window."

func get_id() -> String:
	return "minimize"

func get_name() -> String:
	return "Minimize"

func get_inputs() -> Array[Dictionary]:
	return []

func get_supported_types() -> Array[String]:
	return ["Window"]

func execute(node: Node, inputs: Dictionary) -> void:
	if node and node is Window:
		node.mode = Window.MODE_MINIMIZED