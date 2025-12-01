extends FKAction

func get_description() -> String:
	return "Maximizes the window."

func get_id() -> String:
	return "maximize"

func get_name() -> String:
	return "Maximize"

func get_inputs() -> Array[Dictionary]:
	return []

func get_supported_types() -> Array[String]:
	return ["Window"]

func execute(node: Node, inputs: Dictionary) -> void:
	if node and node is Window:
		node.mode = Window.MODE_MAXIMIZED