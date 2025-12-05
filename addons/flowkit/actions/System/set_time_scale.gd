extends FKAction

func get_description() -> String:
	return "Sets the time scale of the game (1.0 = normal, 0.5 = half speed, 2.0 = double speed)."

func get_id() -> String:
	return "set_time_scale"

func get_name() -> String:
	return "Set Time Scale"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Scale", "type": "float", "description": "The time scale multiplier (1.0 = normal speed)."},
	]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var scale: float = float(inputs.get("Scale", 1.0))
	Engine.time_scale = scale
