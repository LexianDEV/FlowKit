extends FKCondition

func get_description() -> String:
	return "Checks if the video is currently playing."

func get_id() -> String:
	return "is_playing"

func get_name() -> String:
	return "Is Playing"

func get_inputs() -> Array[Dictionary]:
	return []

func get_supported_types() -> Array[String]:
	return ["VideoStreamPlayer"]

func check(node: Node, inputs: Dictionary) -> bool:
	if node and node is VideoStreamPlayer:
		return node.is_playing()
	return false