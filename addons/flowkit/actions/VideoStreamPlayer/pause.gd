extends FKAction

func get_description() -> String:
	return "Pauses the video playback."

func get_id() -> String:
	return "pause"

func get_display_name() -> String:
	return "Pause"

func get_supported_types() -> Array[String]:
	return ["VideoStreamPlayer"]

func execute(node: Node, inputs: Dictionary, block_id: int = -1) -> void:
	if node and node is VideoStreamPlayer:
		node.paused = true
