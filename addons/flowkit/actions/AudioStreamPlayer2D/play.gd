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
	return ["AudioStreamPlayer2D"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	if node and (node is AudioStreamPlayer2D):
		node.play()
