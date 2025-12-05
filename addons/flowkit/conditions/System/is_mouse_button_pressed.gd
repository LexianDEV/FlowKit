extends FKCondition

func get_description() -> String:
	return "Checks if a mouse button is currently pressed."

func get_id() -> String:
	return "is_mouse_button_pressed"

func get_name() -> String:
	return "Is Mouse Button Pressed"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Button", "type": "String", "description": "The mouse button to check: 'left', 'right', 'middle', 'wheel_up', 'wheel_down'."}
	]

func check(node: Node, inputs: Dictionary, block_id: String = "") -> bool:
	var button_str: String = str(inputs.get("Button", "left")).to_lower()
	var button: MouseButton = _string_to_button(button_str)
	
	if button == MOUSE_BUTTON_NONE:
		return false
	
	return Input.is_mouse_button_pressed(button)

func _string_to_button(button_str: String) -> MouseButton:
	match button_str:
		"left", "lmb", "1": return MOUSE_BUTTON_LEFT
		"right", "rmb", "2": return MOUSE_BUTTON_RIGHT
		"middle", "mmb", "3": return MOUSE_BUTTON_MIDDLE
		"wheel_up", "wheelup", "4": return MOUSE_BUTTON_WHEEL_UP
		"wheel_down", "wheeldown", "5": return MOUSE_BUTTON_WHEEL_DOWN
		_: return MOUSE_BUTTON_NONE
