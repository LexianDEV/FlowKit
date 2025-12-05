extends FKAction

func get_description() -> String:
	return "Reloads the current scene."

func get_id() -> String:
	return "reload_scene"

func get_name() -> String:
	return "Reload Scene"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return []

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	if not node or not node.is_inside_tree():
		return
	node.get_tree().reload_current_scene()
