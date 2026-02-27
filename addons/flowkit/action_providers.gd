extends Resource
class_name FKActionProvider

func get_supported_types() -> Array[String]:
	return []

func get_actions_for(node: Node) -> Array[Dictionary]:
	return []

func execute(action_id: String, node: Node, inputs: Dictionary) -> void:
	pass
