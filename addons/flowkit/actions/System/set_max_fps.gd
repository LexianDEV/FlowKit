extends FKAction

func get_description() -> String:
	return "Sets the maximum frames per second (FPS) limit. Set to 0 for unlimited."

func get_id() -> String:
	return "set_max_fps"

func get_name() -> String:
	return "Set Max FPS"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "MaxFPS", "type": "int", "description": "The maximum FPS limit (0 = unlimited)."},
	]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var max_fps: int = int(inputs.get("MaxFPS", 0))
	Engine.max_fps = max_fps
