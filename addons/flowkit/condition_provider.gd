# condition_provider.gd
extends Resource
class_name FKConditionProvider

func get_supported_types() -> Array[String]:
	return []

func get_conditions_for(node: Node) -> Array[Dictionary]:
	return []

func check(condition_id: String, node: Node, inputs: Dictionary) -> bool:
	return false
