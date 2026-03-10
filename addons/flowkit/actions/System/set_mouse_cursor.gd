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

static var _path_input: FKActionInput:
	get:
		return FKActionInput.new("Cursor Path", "String",
		"Path to the cursor texture (e.g., 'res://assets/cursor.png'). Leave empty to reset to default.")
static var _x_input: FKActionInput:
	get:
		return FKActionInput.new("Hotspot X", "int",
		"The X coordinate of the cursor hotspot.")
static var _y_input: FKActionInput:
	get:
		return FKActionInput.new("Hotspot Y", "int",
		"The Y coordinate of the cursor hotspot.")

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var cursor_path: String = str(inputs.get("CursorPath", ""))
	var hotspot_x: int = int(inputs.get("HotspotX", 0))
	var hotspot_y: int = int(inputs.get("HotspotY", 0))
	
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
