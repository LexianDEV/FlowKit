extends FKAction

func get_description() -> String:
	return "Enables or disables vertical synchronization (VSync)."

func get_id() -> String:
	return "set_vsync"

func get_name() -> String:
	return "Set VSync"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Enabled", "type": "bool", "description": "Whether VSync should be enabled."},
	]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var enabled: bool = bool(inputs.get("Enabled", true))
	if enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
