extends Resource
class_name FKEvent

func get_description() -> String:
	return "No description provided."

func get_id() -> String:
	return ""

func get_name() -> String:
	return ""

func get_supported_types() -> Array[String]:
	return []

func get_inputs() -> Array:
	return []

func poll(node: Node, inputs: Dictionary = {}, block_id: String = "") -> bool:
	return false
