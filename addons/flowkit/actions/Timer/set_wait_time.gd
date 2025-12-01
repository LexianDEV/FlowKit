extends FKAction

func get_description() -> String:
	return "Sets the wait time of the timer."

func get_id() -> String:
	return "set_wait_time"

func get_name() -> String:
	return "Set Wait Time"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Wait Time", "type": "float"}
	]

func get_supported_types() -> Array[String]:
	return ["Timer"]

func execute(node: Node, inputs: Dictionary) -> void:
	if node and node is Timer:
		var wait_time: float = inputs.get("Wait Time", 1.0)
		node.wait_time = wait_time