extends Resource
class_name FKAction

signal exec_completed

func get_description() -> String:
	return "No description provided."

func get_id() -> String:
	return ""

func get_name() -> String:
	return ""

func get_inputs() -> Array[Dictionary]:
	return []

func get_supported_types() -> Array[String]:
	return []

func requires_multi_frames() -> bool:
	return false

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	pass
