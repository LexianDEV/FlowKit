extends FKAction

func get_description() -> String:
	return "Changes to a different scene."

func get_id() -> String:
	return "change_scene"

func get_name() -> String:
	return "Change Scene"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "ScenePath", "type": "String", "description": "The path to the scene file (e.g., 'res://scenes/level2.tscn')."},
	]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	if not node or not node.is_inside_tree():
		return
	var scene_path: String = str(inputs.get("ScenePath", ""))
	if scene_path.is_empty():
		push_error("[FlowKit] change_scene: ScenePath is empty")
		return
	var err: Error = node.get_tree().change_scene_to_file(scene_path)
	if err != OK:
		push_error("[FlowKit] change_scene: Failed to change scene to '%s', error: %d" % [scene_path, err])
