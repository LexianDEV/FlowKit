extends FKCondition

func get_description() -> String:
	return "Checks if a specific keyboard key is currently pressed."

func get_id() -> String:
	return "is_key_pressed"

func get_name() -> String:
	return "Is Key Pressed"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Key", "type": "String", "description": "The key to check (e.g., 'W', 'A', 'Space', 'Escape', 'Enter')."}
	]

func check(node: Node, inputs: Dictionary, block_id: String = "") -> bool:
	var key_str: String = str(inputs.get("Key", "")).to_upper()
	if key_str.is_empty():
		return false
	
	var keycode: Key = _string_to_keycode(key_str)
	if keycode == KEY_NONE:
		return false
	
	return Input.is_key_pressed(keycode)

func _string_to_keycode(key_str: String) -> Key:
	# Handle common key names
	match key_str:
		"SPACE", " ": return KEY_SPACE
		"ESCAPE", "ESC": return KEY_ESCAPE
		"ENTER", "RETURN": return KEY_ENTER
		"TAB": return KEY_TAB
		"BACKSPACE": return KEY_BACKSPACE
		"DELETE", "DEL": return KEY_DELETE
		"INSERT", "INS": return KEY_INSERT
		"HOME": return KEY_HOME
		"END": return KEY_END
		"PAGEUP", "PGUP": return KEY_PAGEUP
		"PAGEDOWN", "PGDN": return KEY_PAGEDOWN
		"LEFT": return KEY_LEFT
		"RIGHT": return KEY_RIGHT
		"UP": return KEY_UP
		"DOWN": return KEY_DOWN
		"SHIFT": return KEY_SHIFT
		"CTRL", "CONTROL": return KEY_CTRL
		"ALT": return KEY_ALT
		"CAPSLOCK": return KEY_CAPSLOCK
		"F1": return KEY_F1
		"F2": return KEY_F2
		"F3": return KEY_F3
		"F4": return KEY_F4
		"F5": return KEY_F5
		"F6": return KEY_F6
		"F7": return KEY_F7
		"F8": return KEY_F8
		"F9": return KEY_F9
		"F10": return KEY_F10
		"F11": return KEY_F11
		"F12": return KEY_F12
		"0": return KEY_0
		"1": return KEY_1
		"2": return KEY_2
		"3": return KEY_3
		"4": return KEY_4
		"5": return KEY_5
		"6": return KEY_6
		"7": return KEY_7
		"8": return KEY_8
		"9": return KEY_9
	
	# Handle single letter keys
	if key_str.length() == 1:
		var char_code: int = key_str.unicode_at(0)
		if char_code >= 65 and char_code <= 90:  # A-Z
			return char_code as Key
	
	return KEY_NONE
