extends FKAction

func get_description() -> String:
	return "Gets a project setting and stores it in a system variable. Access it via system.get_var(\"variable_name\") in expressions."

func get_id() -> String:
	return "get_project_setting"

func get_name() -> String:
	return "Get Project Setting"

func get_inputs() -> Array[FKActionInput]:
	return [_path_input, _store_input]

static var _path_input: FKStringActionInput:
	get:
		return FKStringActionInput.new("Path", 
		"The setting path (e.g., 'application/config/name', 'display/window/size/viewport_width').")
static var _store_input: FKStringActionInput:
	get:
		return FKStringActionInput.new("Store In", 
		"The system variable name to store the result in.")

func get_supported_types() -> Array[String]:
	return ["System"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var path: String = _path_input.get_val(inputs)
	var store_in: String = _store_input.get_val(inputs)

	if path.is_empty() or store_in.is_empty():
		return

	var value: Variant = ProjectSettings.get_setting(path)

	var system: Node = node.get_tree().root.get_node_or_null("/root/FlowKitSystem")
	if system and system.has_method("set_var"):
		system.set_var(store_in, value)
