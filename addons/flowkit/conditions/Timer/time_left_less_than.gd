extends FKCondition

func get_description() -> String:
	return "Checks if the time left is less than the specified value."

func get_id() -> String:
	return "time_left_less_than"

func get_name() -> String:
	return "Time Left < Value"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Value", "type": "float"}
	]

func get_supported_types() -> Array[String]:
	return ["Timer"]

func check(node: Node, inputs: Dictionary) -> bool:
	if node and node is Timer:
		var value: float = inputs.get("Value", 0.0)
		return node.time_left < value
	return false