extends FKEvent

func get_description() -> String:
	return "This event will run at the start of the scene."

func get_id() -> String:
	return "on_ready"

func get_name() -> String:
	return "On Ready"

func get_supported_types() -> Array[String]:
	return ["Node", "System"]

func get_inputs() -> Array:
	return []

# Track the frame when on_ready fired for the current scene
var _ready_frame: int = -1
var _last_scene_path: String = ""
var _has_fired: bool = false


func poll(node: Node, inputs: Dictionary = {}) -> bool:
	if not node:
		return false
	
	# Detect scene changes and reset tracking
	var current_scene = node.get_tree().current_scene
	if current_scene:
		var scene_path = current_scene.scene_file_path
		if scene_path != _last_scene_path:
			_last_scene_path = scene_path
			_ready_frame = -1
			_has_fired = false
	
	if _has_fired:
		return false
	
	var current_frame = Engine.get_process_frames()
	
	# If this is the first poll for this scene, record the frame and fire
	if _ready_frame == -1:
		_ready_frame = current_frame
		_has_fired = true
		return true
	
	# If still on the same frame, allow firing
	if current_frame == _ready_frame:
		_has_fired = true
		return true
	
	# Otherwise, already fired
	return false
