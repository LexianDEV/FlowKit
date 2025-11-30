extends FKAction

func get_id() -> String:
	return "add_child"

func get_name() -> String:
	return "Add Child"

func get_inputs() -> Array[Dictionary]:
	return [{"name": "Node", "type": "Object"}, {"name": "Force Readable Name", "type": "Bool"}, {"name": "Internal", "type": "Int"}]

func get_supported_types() -> Array[String]:
	return ["AnimatedSprite2D"]

func execute(node: Node, inputs: Dictionary) -> void:
	if not node is AnimatedSprite2D:
		return
	
	node.add_child(inputs.get("Node", null), inputs.get("Force Readable Name", false), inputs.get("Internal", 0))
