extends FKAction

func get_description() -> String:
	return "Stops the timer."

func get_id() -> String:
	return "stop"

func get_name() -> String:
	return "Stop"

func get_inputs() -> Array[Dictionary]:
	return []

func get_supported_types() -> Array[String]:
	return ["Timer"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	if node and node is Timer:
		node.stop()