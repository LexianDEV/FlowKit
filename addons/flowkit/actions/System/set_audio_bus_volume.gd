extends FKAction

func get_description() -> String:
	return "Sets the volume for a specific audio bus (e.g., 'Master', 'Music', 'SFX')."

func get_id() -> String:
	return "set_audio_bus_volume"

func get_name() -> String:
	return "Set Audio Bus Volume"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[FKActionInput]:
	return [_name_input, _volume_input]

static var _name_input: FKStringActionInput:
	get:
		return FKStringActionInput.new("Bus Name", 
		"The name of the audio bus (e.g., 'Master', 'Music', 'SFX').", 
		"Master")
static var _volume_input: FKFloatActionInput:
	get:
		return FKFloatActionInput.new("Volume (dB)", 
		"The volume in decibels (0 = normal, -80 = silent, positive values = louder).")

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var bus_name: String = _name_input.get_val(inputs)
	var volume_db: float = _volume_input.get_val(inputs)
	
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, volume_db)
	else:
		push_error("[FlowKit] set_audio_bus_volume: Audio bus '%s' not found" % bus_name)
