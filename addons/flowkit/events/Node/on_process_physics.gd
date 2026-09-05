extends FKEvent

func get_description() -> String:
	return "This runs every time physics are calculated."

func get_id() -> String:
	return "on_process_physics"

func get_name() -> String:
	return "On Physics Process"

func get_supported_types() -> Array[String]:
	return ["Node", "System"]

func get_inputs() -> Array:
	return []

func poll(node: Node, inputs: Dictionary = {}, block_id: int = -1) -> bool:
	if node and node.is_inside_tree():
		return true
	
	return false
