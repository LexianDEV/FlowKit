extends FKAction

func get_description() -> String:
	return "Sets a custom mouse cursor from an image resource."

func get_id() -> String:
	return "set_mouse_cursor"

func get_name() -> String:
	return "Set Mouse Cursor"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[FKActionInput]:
	return [_path_input, _x_input, _y_input]

static var _path_input: FKStringActionInput:
	get:
		return FKStringActionInput.new("Cursor Path", 
		"Path to the cursor texture (e.g., 'res://assets/cursor.png'). Leave empty to reset to default.")
static var _x_input: FKIntActionInput:
	get:
		return FKIntActionInput.new("Hotspot X",
		"The X coordinate of the cursor hotspot.")
static var _y_input: FKIntActionInput:
	get:
		return FKIntActionInput.new("Hotspot Y",
		"The Y coordinate of the cursor hotspot.")

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var cursor_path: String = _path_input.get_val(inputs)
	var hotspot_x: int = _x_input.get_val(inputs)
	var hotspot_y: int = _y_input.get_val(inputs)
	
	if cursor_path.is_empty():
		Input.set_custom_mouse_cursor(null)
	else:
		if not ResourceLoader.exists(cursor_path):
			push_error("[FlowKit] set_mouse_cursor: Cursor texture not found at '%s'" % cursor_path)
			return
		var texture: Texture2D = ResourceLoader.load(cursor_path, "Texture2D", ResourceLoader.CACHE_MODE_REUSE) as Texture2D
		if texture:
			Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, Vector2(hotspot_x, hotspot_y))
		else:
			push_error("[FlowKit] set_mouse_cursor: Failed to load cursor texture from '%s'" % cursor_path)
