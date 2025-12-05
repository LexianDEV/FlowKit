extends FKEvent

func get_description() -> String:
	return "Triggers on every process frame (every _process call)."

func get_id() -> String:
	return "on_process"

func get_name() -> String:
	return "On Process"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array:
	return []

func poll(node: Node, inputs: Dictionary = {}, block_id: String = "") -> bool:
	# Always triggers on every frame
	return true
