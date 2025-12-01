extends FKAction

func get_description() -> String:
	return "Toggles the pause state of the game."

func get_id() -> String:
	return "toggle_pause"

func get_name() -> String:
	return "Toggle Pause"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return []

func execute(node: Node, inputs: Dictionary) -> void:
	if not node or not node.is_inside_tree():
		return
	node.get_tree().paused = not node.get_tree().paused