extends FKCondition

func get_description() -> String:
	return "Checks if the current FPS is above a specified threshold."

func get_id() -> String:
	return "is_fps_above"

func get_name() -> String:
	return "Is FPS Above"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Threshold", "type": "float", "description": "The FPS threshold to compare against."}
	]

func check(node: Node, inputs: Dictionary, block_id: String = "") -> bool:
	var threshold: float = float(inputs.get("Threshold", 30.0))
	return Engine.get_frames_per_second() > threshold
