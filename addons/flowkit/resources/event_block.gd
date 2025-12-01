extends Resource
class_name FKEventBlock

@export var block_id: String  # Unique identifier for this specific block instance
@export var event_id: String  # Type of event (e.g., "on_ready", "on_process")
@export var target_node: NodePath
@export var inputs: Dictionary = {}
@export var conditions: Array[FKEventCondition] = []
@export var actions: Array[FKEventAction] = []

func _init(p_block_id: String = "", p_event_id: String = "", p_target_node: NodePath = NodePath()) -> void:
	if p_block_id == "":
		block_id = _generate_unique_id()
	else:
		block_id = p_block_id
	event_id = p_event_id
	target_node = p_target_node

func _generate_unique_id() -> String:
	"""Generate a unique ID for this block using timestamp and random component."""
	return "%s_%d" % [event_id if event_id else "event", randi()]

func ensure_block_id() -> void:
	"""Ensure this block has a unique ID (called when loading from old saved sheets)."""
	if block_id == "" or block_id.is_empty():
		block_id = _generate_unique_id()
