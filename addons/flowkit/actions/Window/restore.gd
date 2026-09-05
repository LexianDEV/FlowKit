extends FKAction

func get_description() -> String:
	return "Restores the window to normal mode."

func get_id() -> String:
	return "restore"

func get_display_name() -> String:
	return "Restore"

func get_supported_types() -> Array[String]:
	return ["Window"]

func execute(node: Node, inputs: Dictionary, block_id: int = -1) -> void:
	if node and node is Window:
		node.mode = Window.MODE_WINDOWED
