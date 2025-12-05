extends FKEvent

# Track time scale changes
static var previous_time_scale: float = 1.0

func get_description() -> String:
	return "Triggers when the game time scale changes."

func get_id() -> String:
	return "on_time_scale_changed"

func get_name() -> String:
	return "On Time Scale Changed"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array:
	return []

func poll(node: Node, inputs: Dictionary = {}, block_id: String = "") -> bool:
	var current_scale: float = Engine.time_scale
	
	if current_scale != previous_time_scale:
		previous_time_scale = current_scale
		return true
	
	return false
