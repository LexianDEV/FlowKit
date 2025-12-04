extends FKAction

func get_description() -> String:
	return "Sets the volume of the audio player."

func get_id() -> String:
	return "set_volume"

func get_name() -> String:
	return "Set Volume"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Volume (dB)", "type": "float", "description": "The volume in decibels to set the audio player to."}
	]

func get_supported_types() -> Array[String]:
	return ["AudioStreamPlayer2D"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	if node and (node is AudioStreamPlayer2D):
		var volume_db: float = inputs.get("Volume (dB)", 0.0)
		node.volume_db = volume_db