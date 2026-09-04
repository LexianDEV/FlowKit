extends FKAction

func get_description() -> String:
	return "Starts playing the video."

func get_id() -> String:
	return "play"

func get_name() -> String:
	return "Play"

func get_supported_types() -> Array[String]:
	return ["VideoStreamPlayer"]

func execute(node: Node, inputs: Dictionary, block_id: int = -1) -> void:
	if node and node is VideoStreamPlayer:
		node.play()
