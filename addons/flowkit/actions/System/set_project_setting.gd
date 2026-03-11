extends FKAction

func get_description() -> String:
	return "Sets a project setting at runtime. Note: Runtime changes are not saved to disk unless ProjectSettings.save() is called."

func get_id() -> String:
	return "set_project_setting"

func get_name() -> String:
	return "Set Project Setting"

func get_inputs() -> Array[FKActionInput]:
	return [_path_input, _val_input]

static var _path_input: FKStringActionInput:
	get:
		return FKStringActionInput.new("Path", 
		"The setting path (e.g., 'application/config/name').")
static var _val_input: FKActionInput:
	get:
		return FKActionInput.new("Value", "Variant", "The value to set.", null)

func get_supported_types() -> Array[String]:
	return ["System"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var path: String = _path_input.get_val(inputs)
	var value: Variant = _val_input.get_val(inputs)

	if path.is_empty():
		return

	ProjectSettings.set_setting(path, value)
