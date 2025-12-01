extends FKAction

func get_description() -> String:
	return "Starts the timer."

func get_id() -> String:
	return "start"

func get_name() -> String:
	return "Start"

func get_inputs() -> Array[Dictionary]:
	return []

func get_supported_types() -> Array[String]:
	return ["Timer"]

func execute(node: Node, inputs: Dictionary) -> void:
	if node and node is Timer:
		node.start()