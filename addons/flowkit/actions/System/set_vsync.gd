extends FKAction

func get_description() -> String:
	return "Enables or disables vertical synchronization (VSync)."

func get_id() -> String:
	return "set_vsync"

func get_name() -> String:
	return "Set VSync"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[FKActionInput]:
	return [_enabled_input]

static var _enabled_input: FKBoolActionInput:
	get:
		return FKBoolActionInput.new("Enabled", "Whether VSync should be enabled.", true)

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var enabled: bool = _enabled_input.get_val(inputs)
	if enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
