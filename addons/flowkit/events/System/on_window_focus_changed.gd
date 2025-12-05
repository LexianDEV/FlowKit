extends FKEvent

static var previous_focused: bool = true

func get_description() -> String:
	return "Triggers when the game window gains or loses focus."

func get_id() -> String:
	return "on_window_focus_changed"

func get_name() -> String:
	return "On Window Focus Changed"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array:
	return []

func poll(node: Node, inputs: Dictionary = {}, block_id: String = "") -> bool:
	var current_focused: bool = DisplayServer.window_is_focused()
	
	if current_focused != previous_focused:
		previous_focused = current_focused
		return true
	
	return false
