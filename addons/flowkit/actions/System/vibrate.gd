extends FKAction

func get_description() -> String:
	return "Generates a vibration on mobile devices."

func get_id() -> String:
	return "vibrate"

func get_name() -> String:
	return "Vibrate"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "DurationMs", "type": "int", "description": "Duration of vibration in milliseconds."},
	]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var duration_ms: int = int(inputs.get("DurationMs", 200))
	Input.vibrate_handheld(duration_ms)
