extends FKAction

func get_description() -> String:
	return "Gets a project setting and stores it in a system variable. Access it via system.get_var(\"variable_name\") in expressions."

func get_id() -> String:
	return "get_project_setting"

func get_name() -> String:
	return "Get Project Setting"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Path", "type": "String", "description": "The setting path (e.g., 'application/config/name', 'display/window/size/viewport_width')."},
		{"name": "Store In", "type": "String", "description": "The system variable name to store the result in."},
	]

func get_supported_types() -> Array[String]:
	return ["System"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var path: String = str(inputs.get("Path", ""))
	var store_in: String = str(inputs.get("Store In", ""))

	if path.is_empty() or store_in.is_empty():
		return

	var value: Variant = ProjectSettings.get_setting(path)

	var system: Node = node.get_tree().root.get_node_or_null("/root/FlowKitSystem")
	if system and system.has_method("set_var"):
		system.set_var(store_in, value)
