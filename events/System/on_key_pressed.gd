extends FKEvent

func get_id() -> String:
	return "on_key_pressed"

func get_name() -> String:
	return "On Key Pressed"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array:
	return [
		{"name": "key", "type": "string"}
	]

func poll(node: Node, inputs: Dictionary = {}) -> bool:
	if not node or not node.is_inside_tree():
		return false
	
	# If a specific key/action is provided, check only that
	if inputs.has("key") and inputs["key"] != "":
		var key_name = inputs["key"]
		# Check if it's an InputMap action
		if InputMap.has_action(key_name):
			return Input.is_action_pressed(key_name)
		# Otherwise check raw key input by name
		var key_code = OS.find_keycode_from_string(key_name)
		if key_code != KEY_NONE:
			return Input.is_key_pressed(key_code)
		return false
	
	# Check if any action in the InputMap is currently pressed
	for action in InputMap.get_actions():
		if Input.is_action_pressed(action):
			return true
	
	return false
