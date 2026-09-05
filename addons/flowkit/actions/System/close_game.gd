extends FKAction

func get_description() -> String:
	return "Closes the game."

func get_id() -> String:
	return "close_game"

func get_display_name() -> String:
	return "Close Game"

func get_supported_types() -> Array[String]:
	return ["System"]

func execute(node: Node, inputs: Dictionary, block_id: int = -1) -> void:
	if not node or not node.is_inside_tree():
		return
	node.get_tree().quit()
