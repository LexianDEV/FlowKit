extends FKAction

func get_description() -> String:
	return "Mutes or unmutes a specific audio bus."

func get_id() -> String:
	return "set_audio_bus_mute"

func get_name() -> String:
	return "Set Audio Bus Mute"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[FKActionInput]:
	return [_bus_name_input, _muted_input]

static var _bus_name_input: FKStringActionInput:
	get:
		return FKStringActionInput.new("Bus Name",
		"The name of the audio bus (e.g., 'Master', 'Music', 'SFX').", "Master")
static var _muted_input: FKBoolActionInput:
	get:
		return FKBoolActionInput.new("Muted", "Whether the audio bus should be muted.", true)

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var bus_name: String = _bus_name_input.get_val(inputs)
	var muted: bool = _muted_input.get_val(inputs)
	
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx >= 0:
		AudioServer.set_bus_mute(bus_idx, muted)
	else:
		push_error("[FlowKit] set_audio_bus_mute: Audio bus '%s' not found" % bus_name)
