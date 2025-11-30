extends FKAction

func get_description() -> String:
	return "Starts playing the audio."

func get_id() -> String:
	return "play"

func get_name() -> String:
	return "Play"

func get_inputs() -> Array[Dictionary]:
	return []

func get_supported_types() -> Array[String]:
	return ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]

func execute(node: Node, inputs: Dictionary) -> void:
	if node and (node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D):
		node.play()
