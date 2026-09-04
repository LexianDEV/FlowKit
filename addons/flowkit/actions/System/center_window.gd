extends FKAction

func get_description() -> String:
	return "Centers the window on the primary screen."

func get_id() -> String:
	return "center_window"

func get_display_name() -> String:
	return "Center Window"

func get_supported_types() -> Array[String]:
	return ["System"]

func execute(node: Node, inputs: Dictionary, block_id: int = -1) -> void:
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var window_size: Vector2i = DisplayServer.window_get_size()
	var centered_pos: Vector2i = (screen_size - window_size) / 2
	DisplayServer.window_set_position(centered_pos)
