extends FKCondition

func get_description() -> String:
	return "Compares the elapsed time since the game started against a threshold."

func get_id() -> String:
	return "is_elapsed_time_greater"

func get_name() -> String:
	return "Is Elapsed Time Greater"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Seconds", "type": "float", "description": "The time in seconds to compare against."}
	]

func check(node: Node, inputs: Dictionary, block_id: String = "") -> bool:
	var seconds: float = float(inputs.get("Seconds", 0.0))
	var threshold_ms: float = seconds * 1000.0
	return Time.get_ticks_msec() > threshold_ms
