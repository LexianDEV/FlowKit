extends FKCondition

func get_description() -> String:
	return "Checks if an audio bus is muted."

func get_id() -> String:
	return "is_audio_bus_muted"

func get_name() -> String:
	return "Is Audio Bus Muted"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "BusName", "type": "String", "description": "The name of the audio bus to check."}
	]

func check(node: Node, inputs: Dictionary, block_id: String = "") -> bool:
	var bus_name: String = str(inputs.get("BusName", "Master"))
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	
	if bus_idx >= 0:
		return AudioServer.is_bus_mute(bus_idx)
	
	return false
