extends FKAction

func get_description() -> String:
	return "Starts playing the video."

func get_id() -> String:
	return "play"

func get_name() -> String:
	return "Play"

func get_inputs() -> Array[Dictionary]:
	return []

func get_supported_types() -> Array[String]:
	return ["VideoStreamPlayer"]

func execute(node: Node, inputs: Dictionary) -> void:
	if node and node is VideoStreamPlayer:
		node.play()