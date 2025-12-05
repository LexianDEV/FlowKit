extends FKCondition

func get_description() -> String:
	return "Checks if the current time scale is less than 1.0 (slow motion)."

func get_id() -> String:
	return "is_slow_motion"

func get_name() -> String:
	return "Is Slow Motion"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return []

func check(node: Node, inputs: Dictionary, block_id: String = "") -> bool:
	return Engine.time_scale < 1.0 and Engine.time_scale > 0.0
