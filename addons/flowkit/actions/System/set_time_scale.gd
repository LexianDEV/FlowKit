extends FKAction

func get_description() -> String:
	return "Sets the time scale of the game (1.0 = normal, 0.5 = half speed, 2.0 = double speed)."

func get_id() -> String:
	return "set_time_scale"

func get_name() -> String:
	return "Set Time Scale"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[FKActionInput]:
	return [_scale_input]
	
static var _scale_input: FKFloatActionInput:
	get:
		return FKFloatActionInput.new("Scale", 
		"The time scale multiplier (1.0 = normal speed).",
		1.0)

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var scale: float = _scale_input.get_val(inputs)
	Engine.time_scale = scale
