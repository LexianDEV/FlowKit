extends FKProviderBase
class_name FKCondition

func get_provider_kind() -> String:
	return KIND_CONDITION

func check(node: Node, inputs: Dictionary, unit_id: int = -1) -> bool:
	return false

func get_class() -> String:
	return "FKCondition"
