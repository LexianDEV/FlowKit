extends FKProvider
class_name FKCondition

func check(node: Node, inputs: Dictionary, unit_id: int = -1) -> bool:
	return false

func get_class() -> String:
	return "FKCondition"
