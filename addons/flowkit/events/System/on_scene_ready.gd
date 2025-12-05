extends FKEvent

# Track scene readiness using frame counting
static var scene_ready_frames: Dictionary = {}

func get_description() -> String:
	return "Triggers once when the current scene has finished loading."

func get_id() -> String:
	return "on_scene_ready"

func get_name() -> String:
	return "On Scene Ready"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array:
	return []

func poll(node: Node, inputs: Dictionary = {}, block_id: String = "") -> bool:
	if not node or not node.is_inside_tree():
		return false
	
	var scene: Node = node.get_tree().current_scene
	if not scene:
		return false
	
	var scene_path: String = scene.scene_file_path
	var current_frame: int = Engine.get_process_frames()
	
	# If this scene hasn't been tracked yet, mark it as ready
	if not scene_ready_frames.has(scene_path):
		scene_ready_frames[scene_path] = current_frame
		return true
	
	# Only trigger on the first frame the scene was ready
	return scene_ready_frames[scene_path] == current_frame
