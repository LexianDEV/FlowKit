extends FKAction

func get_description() -> String:
	return "Closes the window."

func get_id() -> String:
	return "close"

func get_display_name() -> String:
	return "Close"

func get_supported_types() -> Array[String]:
	return ["Window"]

func execute(node: Node, inputs: Dictionary, block_id: int = -1) -> void:
	if node and node is Window:
		node.queue_free()
