extends FKAction

func get_description() -> String:
	return "Generates a vibration on mobile devices."

func get_id() -> String:
	return "vibrate"

func get_name() -> String:
	return "Vibrate"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[FKActionInput]:
	return [_duration_input]

static var _duration_input: FKIntActionInput:
	get:
		return FKIntActionInput.new("Duration (Ms)", 
		"Duration of vibration in milliseconds.",
		200)

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var duration_ms: int = _duration_input.get_val(inputs)
	Input.vibrate_handheld(duration_ms)
