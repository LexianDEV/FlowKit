extends FKAction

func get_description() -> String:
	return "Sets the volume of the audio player."

func get_id() -> String:
	return "set_volume"

func get_name() -> String:
	return "Set Volume"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Volume (dB)", "type": "float"}
	]

func get_supported_types() -> Array[String]:
	return ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]

func execute(node: Node, inputs: Dictionary) -> void:
	if node and (node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D):
		var volume_db: float = inputs.get("Volume (dB)", 0.0)
		node.volume_db = volume_db