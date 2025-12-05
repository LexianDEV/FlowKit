extends FKCondition

func get_description() -> String:
	return "Checks if the current time scale is greater than 1.0 (fast forward)."

func get_id() -> String:
	return "is_fast_forward"

func get_name() -> String:
	return "Is Fast Forward"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return []

func check(node: Node, inputs: Dictionary, block_id: String = "") -> bool:
	return Engine.time_scale > 1.0
