extends FKAction

func get_description() -> String:
	return "Sets a project setting at runtime. Note: Runtime changes are not saved to disk unless ProjectSettings.save() is called."

func get_id() -> String:
	return "set_project_setting"

func get_name() -> String:
	return "Set Project Setting"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Path", "type": "String", "description": "The setting path (e.g., 'application/config/name')."},
		{"name": "Value", "type": "Variant", "description": "The value to set."},
	]

func get_supported_types() -> Array[String]:
	return ["System"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var path: String = str(inputs.get("Path", ""))
	var value: Variant = inputs.get("Value", null)

	if path.is_empty():
		return

	ProjectSettings.set_setting(path, value)
