extends FKAction

func get_description() -> String:
	return "Closes the window."

func get_id() -> String:
	return "close"

func get_name() -> String:
	return "Close"

func get_inputs() -> Array[Dictionary]:
	return []

func get_supported_types() -> Array[String]:
	return ["Window"]

func execute(node: Node, inputs: Dictionary) -> void:
	if node and node is Window:
		node.queue_free()