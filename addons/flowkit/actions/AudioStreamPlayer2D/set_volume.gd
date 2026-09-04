extends FKAction

func get_description() -> String:
	return "Sets the volume of the audio player."

func get_id() -> String:
	return "set_volume"

func get_display_name() -> String:
	return "Set Volume"

func get_inputs() -> Array[FKActionInput]:
	return [_volume_input]

static var _volume_input: FKFloatActionInput:
	get: 
		return FKFloatActionInput.new("Volume (dB)",  
		"The volume in decibels to set the audio player to.")

func get_supported_types() -> Array[String]:
	return ["AudioStreamPlayer2D"]

func execute(node: Node, inputs: Dictionary, block_id: int = -1) -> void:
	if node and (node is AudioStreamPlayer2D):
		var volume_db: float = _volume_input.get_val(inputs)
		node.volume_db = volume_db
