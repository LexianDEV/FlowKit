@tool
extends FKUnit
class_name FKEventUnit

@export var event_id: String  # Type of event (e.g., "on_ready", "on_process")
@export var target_node: NodePath
@export var inputs: Dictionary = {}
@export var conditions: Array[FKConditionUnit] = []
@export var actions: Array[FKActionUnit] = []

func may_have_children() -> bool:
	return true

func get_children() -> Array[FKUnit]:
	var defensive_copy: Array[FKUnit] = [] as Array[FKUnit]
	defensive_copy.append_array(conditions)
	defensive_copy.append_array(actions)
	return defensive_copy

func _init(p_event_id: String = "", p_target_node: NodePath = NodePath()) -> void:
	block_type = "event"
	
	event_id = p_event_id
	target_node = p_target_node

func _generate_unique_id() -> String:
	"""Generate a unique ID for this block using timestamp and random component."""
	var timestamp = Time.get_unix_time_from_system()
	# event_id can be stuff like "on_ready" and "on_process"
	return "%s_%d_%d" % [event_id if event_id else "event", int(timestamp), randi()]

		
func serialize() -> Dictionary:
	var result := super.serialize()
	var our_added_fields := {
		"event_id": event_id,
		"target_node": str(target_node),
		"inputs": inputs.duplicate(),
		"conditions": [],
		"actions": []
	}
	result.merge(our_added_fields)

	for cond in conditions:
		result["conditions"].append(cond.serialize())

	for act in actions:
		result["actions"].append(act.serialize())

	return result


func deserialize(dict: Dictionary) -> void:
	super.deserialize(dict)
	event_id = dict.get("event_id", "")
	target_node = NodePath(dict.get("target_node", ""))
	inputs = dict.get("inputs", {}).duplicate()

	conditions = []
	for cond_dict in dict.get("conditions", []):
		var cond := FKConditionUnit.new()
		cond.deserialize(cond_dict)
		conditions.append(cond)

	actions = []
	for act_dict in dict.get("actions", []):
		var act := FKActionUnit.new()
		act.deserialize(act_dict)
		actions.append(act)

func get_id() -> String:
	return "Null"
	
func duplicate_block() -> FKUnit:
	var copy := self.duplicate(true)
	return copy
	
func get_class() -> String:
	return "FKEventUnit"

func get_real_class() -> String:
	return self.get_class()