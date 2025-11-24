extends FKEvent

func get_id() -> String:
	return "on_ready"

func get_name() -> String:
	return "On Ready"

func get_supported_types() -> Array[String]:
	return ["Node", "System"]

func get_inputs() -> Array:
	return []

# Track which nodes have fired on_ready
# Key: node_instance_id, Value: frame number when first seen
var _first_seen: Dictionary = {}  # node_instance_id -> frame_number
var _last_scene_path: String = ""


func poll(node: Node, inputs: Dictionary = {}) -> bool:
	if not node:
		return false
	
	# Detect scene changes and reset tracking
	var current_scene = node.get_tree().current_scene
	if current_scene:
		var scene_path = current_scene.scene_file_path
		if scene_path != _last_scene_path:
			_last_scene_path = scene_path
			_first_seen.clear()
	
	# Clean up freed nodes occasionally
	_cleanup_fired()

	var node_id = node.get_instance_id()
	var current_frame = Engine.get_process_frames()
	
	# Check if this is the first frame we're seeing this node
	if not _first_seen.has(node_id):
		# First time ever seeing this node - record frame and fire
		_first_seen[node_id] = current_frame
		return true
	else:
		# We've seen this node before - check if it's still the same frame
		var first_frame = _first_seen[node_id]
		if current_frame == first_frame:
			# Same frame as first sighting - allow it to fire again
			# This allows multiple event blocks with on_ready for the same node
			return true
		else:
			# Different frame - already fired, don't fire again
			return false


func _cleanup_fired() -> void:
	# Remove nodes that have been freed
	var to_remove: Array = []
	for node_id in _first_seen.keys():
		var node_obj = instance_from_id(node_id)
		if not is_instance_valid(node_obj):
			to_remove.append(node_id)
	
	for node_id in to_remove:
		_first_seen.erase(node_id)
