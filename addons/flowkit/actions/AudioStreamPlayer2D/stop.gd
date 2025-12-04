extends FKAction

func get_description() -> String:
	return "Stops the audio playback."

func get_id() -> String:
	return "stop"

func get_name() -> String:
	return "Stop"

func get_inputs() -> Array[Dictionary]:
	return []

func get_supported_types() -> Array[String]:
	return ["AudioStreamPlayer2D"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	if node and (node is AudioStreamPlayer2D):
		node.stop()