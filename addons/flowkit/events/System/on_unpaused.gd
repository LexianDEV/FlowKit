extends FKEvent

static var previous_paused: bool = false

func get_description() -> String:
	return "Triggers when the game is unpaused."

func get_id() -> String:
	return "on_unpaused"

func get_name() -> String:
	return "On Unpaused"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array:
	return []

func poll(node: Node, inputs: Dictionary = {}) -> bool:
	if not node or not node.is_inside_tree():
		return false
	
	var current_paused = node.get_tree().paused
	if not current_paused and previous_paused:
		previous_paused = current_paused
		return true
	previous_paused = current_paused
	return false