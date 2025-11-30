extends FKEvent

static var previous_paused: bool = false

func get_description() -> String:
	return "Triggers when the pause state of the game changes (paused or unpaused)."

func get_id() -> String:
	return "on_pause_state_changed"

func get_name() -> String:
	return "On Pause State Changed"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array:
	return []

func poll(node: Node, inputs: Dictionary = {}) -> bool:
	if not node or not node.is_inside_tree():
		return false
	
	var current_paused = node.get_tree().paused
	if current_paused != previous_paused:
		previous_paused = current_paused
		return true
	return false