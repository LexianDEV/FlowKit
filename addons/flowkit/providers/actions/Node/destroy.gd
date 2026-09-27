extends FKAction

func get_description() -> String:
	return "Destroys a node and removes it from the scene tree."

func get_id() -> String:
	return "destroy"

func get_display_name() -> String:
	return "Destroy Node"

func get_supported_types() -> Array[String]:
	return ["Node"]

func get_inputs() -> Array[FKActionInput]:
	return []

func execute(node: Node, inputs: Dictionary, unit_id: int = -1) -> void:
	node.queue_free()