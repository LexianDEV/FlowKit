extends FKBaseBlock
class_name FKEventBlock

@export var block_id: String  # Unique identifier for this specific block instance
@export var event_id: String  # Type of event (e.g., "on_ready", "on_process")
@export var target_node: NodePath
@export var inputs: Dictionary = {}
@export var conditions: Array[FKEventCondition] = []
@export var actions: Array[FKEventAction] = []

func _init(p_block_id: String = "", p_event_id: String = "", 
p_target_node: NodePath = NodePath()) -> void:
	block_type = "event"
	
	if p_block_id.is_empty():
		block_id = _generate_unique_id()
	else:
		block_id = p_block_id
	event_id = p_event_id
	target_node = p_target_node

func _generate_unique_id() -> String:
	"""Generate a unique ID for this block using timestamp and random component."""
	var timestamp = Time.get_unix_time_from_system()
	return "%s_%d_%d" % [event_id if event_id else "event", int(timestamp), randi()]

func ensure_block_id() -> void:
	"""Ensure this block has a unique ID (called when loading from old saved sheets)."""
	if block_id.is_empty():
		block_id = _generate_unique_id()
		
func serialize() -> Dictionary:
	var result := {
		"type": block_type,
		"block_id": block_id,
		"event_id": event_id,
		"target_node": str(target_node),
		"inputs": inputs.duplicate(),
		"conditions": [],
		"actions": []
	}

	for cond in conditions:
		result["conditions"].append(cond.serialize())

	for act in actions:
		result["actions"].append(act.serialize())

	return result

func deserialize(dict: Dictionary) -> void:
	block_id = dict.get("block_id", "")
	event_id = dict.get("event_id", "")
	target_node = NodePath(dict.get("target_node", ""))
	inputs = dict.get("inputs", {}).duplicate()

	conditions = []
	for cond_dict in dict.get("conditions", []):
		var cond := FKEventCondition.new()
		cond.deserialize(cond_dict)
		conditions.append(cond)

	actions = []
	for act_dict in dict.get("actions", []):
		var act := FKEventAction.new()
		act.deserialize(act_dict)
		actions.append(act)
