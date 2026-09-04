extends FKAction

func get_description() -> String:
	return "Stops the video playback."

func get_id() -> String:
	return "stop"

func get_name() -> String:
	return "Stop"

func get_supported_types() -> Array[String]:
	return ["VideoStreamPlayer"]

func execute(node: Node, inputs: Dictionary, block_id: int = -1) -> void:
	if node and node is VideoStreamPlayer:
		node.stop()
