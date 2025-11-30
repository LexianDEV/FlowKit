extends FKAction

func get_description() -> String:
	return "Pauses the game."

func get_id() -> String:
	return "pause_game"

func get_name() -> String:
	return "Pause Game"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return []

func execute(node: Node, inputs: Dictionary) -> void:
	if not node or not node.is_inside_tree():
		return
	node.get_tree().paused = true