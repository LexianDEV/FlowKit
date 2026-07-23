extends FKProviderBase
class_name FKAction

func get_provider_kind() -> String:
	return KIND_ACTION

signal exec_completed

func get_description() -> String:
	return "No description provided."

func get_inputs() -> Array[FKActionInput]:
	return []

func requires_multi_frames() -> bool:
	return false

func execute(node: Node, inputs: Dictionary, unit_id: int = -1) -> void:
	pass

func get_class() -> String:
	return "FKAction"
