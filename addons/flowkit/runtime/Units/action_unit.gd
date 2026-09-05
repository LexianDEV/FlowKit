@tool
extends FKUnit
class_name FKActionUnit

@export var action_id: String = ""
@export var target_node: NodePath
@export var inputs: Dictionary = {}

# Branch support
@export var is_branch: bool = false
@export var branch_type: String = ""			  # "if", "elseif", "else", etc.
@export var branch_id: String = ""				# Branch provider ID
@export var branch_condition: FKConditionUnit = null
@export var branch_inputs: Dictionary = {}
@export var branch_actions: Array[FKActionUnit] = []
@export var action_provider: FKAction
@export var branch_provider: FKBranch

func may_have_children() -> bool:
	return true

func get_children() -> Array[FKUnit]:
	var defensive_copy: Array[FKUnit] = [] as Array[FKUnit]
	defensive_copy.append_array(branch_actions)
	return defensive_copy

func _init() -> void:
	block_type = "action"

func serialize() -> Dictionary:
	var result := super.serialize()
	var our_added_fields := {
		"action_id": action_id,
		"target_node": str(target_node),
		"inputs": inputs.duplicate(),
		"is_branch": is_branch,
		"branch_type": branch_type,
		"branch_id": branch_id,
		"branch_inputs": branch_inputs.duplicate()
	}
	result.merge(our_added_fields)

	_serialize_branch_conds_and_actions(result)

	return result

func _serialize_branch_conds_and_actions(result: Dictionary):
	if is_branch and branch_condition != null:
		result["branch_condition"] = branch_condition.serialize()

		var copied_actions: Array = []
		for act in branch_actions:
			var copy := act.serialize()
			copied_actions.append(copy)
			
		result["branch_actions"] = copied_actions
		
func deserialize(dict: Dictionary) -> void:
	super.deserialize(dict)
	action_id = dict.get("action_id", "")
	target_node = NodePath(dict.get("target_node", ""))
	inputs = dict.get("inputs", {}).duplicate()
	
	is_branch = dict.get("is_branch", false)
	branch_type = dict.get("branch_type", "")
	branch_id = dict.get("branch_id", "")
	branch_inputs = dict.get("branch_inputs", {}).duplicate()

	_deserialize_branch_conds_and_actions(dict)

func _deserialize_branch_conds_and_actions(dict: Dictionary):
	branch_condition = null
	
	if dict.has("branch_condition"):
		var cond := FKConditionUnit.new()
		cond.deserialize(dict["branch_condition"])
		branch_condition = cond

	branch_actions.clear()
	for act_dict in dict.get("branch_actions", []):
		var act := FKActionUnit.new()
		act.deserialize(act_dict)
		branch_actions.append(act)
	
func get_id() -> String:
	if is_branch:
		return branch_id

	else:
		return action_id
	
func duplicate_block() -> FKUnit:
	#print("[FKActionUnit]: Duplicating!")
	var copy := FKActionUnit.new()
	copy.block_type = block_type
	copy.uid = uid
	copy.action_id = action_id
	copy.target_node = target_node
	copy.inputs = inputs.duplicate(true)
	copy.is_branch = is_branch
	copy.branch_type = branch_type
	copy.branch_id = branch_id
	copy.branch_inputs = branch_inputs.duplicate(true)
	copy.branch_condition = branch_condition.duplicate_block() if branch_condition != null \
	else null

	copy.action_provider = action_provider
	copy.branch_provider = branch_provider
	
	var branch_actions_copy: Array[FKActionUnit] = []
	for elem in branch_actions:
		var act_copy: FKActionUnit = elem.duplicate()
		branch_actions_copy.append(act_copy)
	copy.branch_actions = branch_actions_copy
		
	return copy
	
static func _to_action_unit_arr(arr: Array) -> Array[FKActionUnit]:
	var result: Array[FKActionUnit] = []
	for child in arr:
		if child is FKActionUnit:
			result.append(child)
	return result
		
func get_class() -> String:
	return "FKActionUnit"

func get_real_class() -> String:
	return self.get_class()

func get_provider() -> FKProvider:
	if is_branch:
		return branch_provider
	else:
		return action_provider

func get_resolved_provider_id() -> String:
	var provider := get_provider()
	var resolved := ""
	if provider:
		resolved = provider.get_provider_id().strip_edges()

	if resolved.is_empty():
		resolved = branch_id.strip_edges() if is_branch else action_id.strip_edges()

	return resolved

	
