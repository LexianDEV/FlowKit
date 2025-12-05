extends FKAction

func get_description() -> String:
	return "Sets the window mode (windowed, fullscreen, borderless, etc.)."

func get_id() -> String:
	return "set_window_mode"

func get_name() -> String:
	return "Set Window Mode"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Mode", "type": "String", "description": "Window mode: 'windowed', 'fullscreen', 'borderless', 'minimized', or 'maximized'."},
	]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var mode_str: String = str(inputs.get("Mode", "windowed")).to_lower()
	var mode: DisplayServer.WindowMode = DisplayServer.WINDOW_MODE_WINDOWED
	
	match mode_str:
		"windowed":
			mode = DisplayServer.WINDOW_MODE_WINDOWED
		"fullscreen":
			mode = DisplayServer.WINDOW_MODE_FULLSCREEN
		"borderless", "exclusive_fullscreen":
			mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
		"minimized":
			mode = DisplayServer.WINDOW_MODE_MINIMIZED
		"maximized":
			mode = DisplayServer.WINDOW_MODE_MAXIMIZED
	
	DisplayServer.window_set_mode(mode)
