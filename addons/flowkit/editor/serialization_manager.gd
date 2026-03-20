@tool
class_name FKSerializationManager
# Note: we serialize to Dictionaries (instead of Resources) for the sake of the undo/redo
# system. Of course, we _de_serialize to Resources since that's what we most
# want to use in RAM.

# Serialization #
func capture_state(blocks: Array[Node]) -> Array[Dictionary]:
	"""Capture the state of the passed block Nodes as serialized data."""
	var state: Array[Dictionary] = []

	for block_el in blocks:
		# Double-check the block is still valid and not queued for deletion
		if not is_instance_valid(block_el) or block_el.is_queued_for_deletion():
			continue
		
		var to_append := serialize_block(block_el)
		state.append(to_append)
			
	return state
	
func serialize_block(block: Node) -> Dictionary:
	"""Serializes a block node's contents in Dictionary form."""
	var result: Dictionary = {}

	if block.has_method("get_event_data"):
		var data = block.get_event_data()
		if data:
			result = _serialize_event_block(data)
	elif block.has_method("get_comment_data"):
		var data = block.get_comment_data()
		if data:
			result = _serialize_event_block(data)
	elif block.has_method("get_group_data"):
		var data = block.get_group_data()
		if data:
			result = _serialize_group_block(data)
	else:
		var error_message := "Node passed to serialize_block does not have a method for " \
		+ "getting its Block data."
		printerr(error_message)

	return result
	
func _serialize_comment_block(data: FKCommentBlock) -> Dictionary:
	"""Serialize a comment block to a dictionary."""
	return {
		"type": "comment",
		"text": data.text
	}

func _serialize_event_block(data: FKEventBlock) -> Dictionary:
	"""Serialize an event block to a dictionary."""
	var result = {
		"type": "event",
		"block_id": data.block_id,
		"event_id": data.event_id,
		"target_node": str(data.target_node),
		"inputs": data.inputs.duplicate(),
		"conditions": [],
		"actions": []
	}
	
	for cond in data.conditions:
		result["conditions"].append({
			"condition_id": cond.condition_id,
			"target_node": str(cond.target_node),
			"inputs": cond.inputs.duplicate(),
			"negated": cond.negated
		})
	
	for act in data.actions:
		result["actions"].append(_serialize_action(act))
	
	return result

func _serialize_action(act: FKEventAction) -> Dictionary:
	"""Serialize an action (including branch data) to a dictionary."""
	var act_dict = {
		"action_id": act.action_id,
		"target_node": str(act.target_node),
		"inputs": act.inputs.duplicate(),
		"is_branch": act.is_branch,
		"branch_type": act.branch_type,
		"branch_id": act.branch_id,
		"branch_inputs": act.branch_inputs.duplicate()
	}
	if act.is_branch:
		if act.branch_condition:
			act_dict["branch_condition"] = {
				"condition_id": act.branch_condition.condition_id,
				"target_node": str(act.branch_condition.target_node),
				"inputs": act.branch_condition.inputs.duplicate(),
				"negated": act.branch_condition.negated
			}
		act_dict["branch_actions"] = []
		for sub_act in act.branch_actions:
			act_dict["branch_actions"].append(_serialize_action(sub_act))
	return act_dict

func _serialize_group_block(data: FKGroupBlock) -> Dictionary:
	"""Serialize a group block to a dictionary."""
	var result = {
		"type": "group",
		"title": data.title,
		"collapsed": data.collapsed,
		"color": data.color,
		"children": []
	}
	
	for child_dict in data.children:
		var child_type = child_dict.get("type", "")
		var child_data = child_dict.get("data")
		var children = result["children"]
		if child_type == "event" and child_data is FKEventBlock:
			children.append(_serialize_event_block(child_data))
		elif child_type == "comment" and child_data is FKCommentBlock:
			children.append(_serialize_comment_block(child_data))
		elif child_type == "group" and child_data is FKGroupBlock:
			children.append(_serialize_group_block(child_data))
	
	return result

# Deserialization #
func restore_state(state: Array) -> Array[Resource]:
	var result: Array[Resource] = []

	for dict in state:
		var to_append = deserialize_block(dict)
		result.append(to_append)

	return result
	
func deserialize_block(dict: Dictionary) -> Resource:
	var t := dict.get("type", "event")

	match t:
		"event":
			return _deserialize_event_block(dict)
		"comment":
			return _deserialize_comment_block(dict)
		"group":
			return _deserialize_group_block(dict)

	return null
	
func _deserialize_comment_block(dict: Dictionary) -> FKCommentBlock:
	"""Deserialize a dictionary to a comment block."""
	var data = FKCommentBlock.new()
	data.text = dict.get("text", "")
	return data

func _deserialize_event_block(dict: Dictionary) -> FKEventBlock:
	"""Deserialize a dictionary to an event block."""
	var block_id = dict.get("block_id", "")
	var event_id = dict.get("event_id", "")
	var target_node = NodePath(dict.get("target_node", ""))
	var data = FKEventBlock.new(block_id, event_id, target_node)
	data.inputs = dict.get("inputs", {}).duplicate()
	data.conditions = [] as Array[FKEventCondition]
	data.actions = [] as Array[FKEventAction]
	
	for cond_dict in dict.get("conditions", []):
		var cond = FKEventCondition.new()
		cond.condition_id = cond_dict.get("condition_id", "")
		cond.target_node = NodePath(cond_dict.get("target_node", ""))
		cond.inputs = cond_dict.get("inputs", {}).duplicate()
		cond.negated = cond_dict.get("negated", false)
		cond.actions = [] as Array[FKEventAction]
		data.conditions.append(cond)
	
	for act_dict in dict.get("actions", []):
		var act = _deserialize_action(act_dict)
		data.actions.append(act)
	
	return data

func _deserialize_action(act_dict: Dictionary) -> FKEventAction:
	"""Deserialize a dictionary to an action (including branch data)."""
	var act = FKEventAction.new()
	act.action_id = act_dict.get("action_id", "")
	act.target_node = NodePath(act_dict.get("target_node", ""))
	act.inputs = act_dict.get("inputs", {}).duplicate()
	act.is_branch = act_dict.get("is_branch", false)
	act.branch_type = act_dict.get("branch_type", "")
	act.branch_id = act_dict.get("branch_id", "")
	act.branch_inputs = act_dict.get("branch_inputs", {}).duplicate()
	if act.is_branch:
		var cond_dict = act_dict.get("branch_condition", null)
		if cond_dict:
			var cond = FKEventCondition.new()
			cond.condition_id = cond_dict.get("condition_id", "")
			cond.target_node = NodePath(cond_dict.get("target_node", ""))
			cond.inputs = cond_dict.get("inputs", {}).duplicate()
			cond.negated = cond_dict.get("negated", false)
			cond.actions = [] as Array[FKEventAction]
			act.branch_condition = cond
		act.branch_actions = [] as Array[FKEventAction]
		for sub_dict in act_dict.get("branch_actions", []):
			act.branch_actions.append(_deserialize_action(sub_dict))
	return act

func _deserialize_group_block(dict: Dictionary) -> FKGroupBlock:
	"""Deserialize a dictionary to a group block."""
	var data = FKGroupBlock.new()
	data.title = dict.get("title", "Group")
	data.collapsed = dict.get("collapsed", false)
	data.color = dict.get("color", Color(0.25, 0.22, 0.35, 1.0))
	data.children = []
	
	for child_dict in dict.get("children", []):
		var child_type = child_dict.get("type", "event")
		if child_type == "event":
			var child_data = _deserialize_event_block(child_dict)
			data.children.append({"type": "event", "data": child_data})
		elif child_type == "comment":
			var child_data = _deserialize_comment_block(child_dict)
			data.children.append({"type": "comment", "data": child_data})
		elif child_type == "group":
			var child_data = _deserialize_group_block(child_dict)
			data.children.append({"type": "group", "data": child_data})
	
	return data
	
