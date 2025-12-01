extends FKEvent

func get_description() -> String:
	return "Triggered when the audio playback finishes."

func get_id() -> String:
	return "on_finished"

func get_name() -> String:
	return "On Finished"

func get_supported_types() -> Array[String]:
	return ["AudioStreamPlayer", "AudioStreamPlayer2D", "AudioStreamPlayer3D"]

func get_inputs() -> Array:
	return []

var _emitted: Dictionary = {}  # node -> bool

func poll(node: Node, inputs: Dictionary = {}) -> bool:
	if not node or not node.is_inside_tree() or not (node is AudioStreamPlayer or node is AudioStreamPlayer2D or node is AudioStreamPlayer3D):
		return false
	
	if not _emitted.has(node):
		_emitted[node] = false
		node.finished.connect(func(): _emitted[node] = true)
	
	if _emitted[node]:
		_emitted[node] = false
		return true
	
	return false
