extends FKCondition

func get_description() -> String:
	return "Checks if the audio is currently playing."

func get_id() -> String:
	return "is_playing"

func get_name() -> String:
	return "Is Playing"

func get_inputs() -> Array[Dictionary]:
	return []

func get_supported_types() -> Array[String]:
	return ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]

func check(node: Node, inputs: Dictionary) -> bool:
	if node and (node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D):
		return node.playing
	return false