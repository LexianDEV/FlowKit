extends FKEvent

# Track mouse button states per button
var previous_button_states: Dictionary = {}

func get_description() -> String:
	return "Triggers when a mouse button is released."

func get_id() -> String:
	return "on_mouse_button_released"

func get_name() -> String:
	return "On Mouse Button Released"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array:
	return [
		{"name": "button", "type": "string", "description": "The mouse button to detect: 'left', 'right', 'middle'."}
	]

func poll(node: Node, inputs: Dictionary = {}, block_id: String = "") -> bool:
	var button_str: String = str(inputs.get("button", "left")).to_lower()
	var button: MouseButton = _string_to_button(button_str)
	
	if button == MOUSE_BUTTON_NONE:
		return false
	
	var current_pressed: bool = Input.is_mouse_button_pressed(button)
	var previous_pressed: bool = previous_button_states.get(button_str, false)
	previous_button_states[button_str] = current_pressed
	
	# Trigger only on the frame the button is released
	return not current_pressed and previous_pressed

func _string_to_button(button_str: String) -> MouseButton:
	match button_str:
		"left", "lmb", "1": return MOUSE_BUTTON_LEFT
		"right", "rmb", "2": return MOUSE_BUTTON_RIGHT
		"middle", "mmb", "3": return MOUSE_BUTTON_MIDDLE
		_: return MOUSE_BUTTON_NONE
