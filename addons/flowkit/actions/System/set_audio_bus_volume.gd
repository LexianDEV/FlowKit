extends FKAction

func get_description() -> String:
	return "Sets the volume for a specific audio bus (e.g., 'Master', 'Music', 'SFX')."

func get_id() -> String:
	return "set_audio_bus_volume"

func get_name() -> String:
	return "Set Audio Bus Volume"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "BusName", "type": "String", "description": "The name of the audio bus (e.g., 'Master', 'Music', 'SFX')."},
		{"name": "VolumeDb", "type": "float", "description": "The volume in decibels (0 = normal, -80 = silent, positive values = louder)."},
	]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var bus_name: String = str(inputs.get("BusName", "Master"))
	var volume_db: float = float(inputs.get("VolumeDb", 0.0))
	
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, volume_db)
	else:
		push_error("[FlowKit] set_audio_bus_volume: Audio bus '%s' not found" % bus_name)
