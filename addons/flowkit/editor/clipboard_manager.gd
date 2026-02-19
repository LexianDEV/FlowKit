class_name FKClipboardManager
extends RefCounted

# Clipboard type: "event", "action", "condition", "group", or ""
var _type: String = ""

# Internal stored data (serialized dictionaries)
var _event_data: Array = []
var _action_data: Array = []
var _condition_data: Array = []
var _group_data: Dictionary = {}

# ===========================
# PUBLIC API
# ===========================

func clear() -> void:
	_type = ""
	_event_data.clear()
	_action_data.clear()
	_condition_data.clear()
	_group_data.clear()

func has_data() -> bool:
	return _type != ""

func get_clipboard_type() -> String:
	return _type


# ---------------------------
# COPY API
# ---------------------------

func copy_event(event_data: FKEventBlock) -> void:
	clear()
	_type = "event"
	_event_data.append(_serialize_event_block(event_data))

func copy_action(action_data: FKEventAction) -> void:
	clear()
	_type = "action"
	_action_data.append(_serialize_action(action_data))

func copy_condition(condition_data: FKEventCondition) -> void:
	clear()
	_type = "condition"
	_condition_data.append(_serialize_condition(condition_data))

func copy_group(group_data: FKGroupBlock) -> void:
	clear()
	_type = "group"
	_group_data = _serialize_group_block(group_data)


# ---------------------------
# PASTE API
# ---------------------------

func paste_event() -> Array[FKEventBlock]:
	if _type != "event":
		return []
	var result: Array[FKEventBlock] = []
	for dict in _event_data:
		result.append(_deserialize_event_block(dict))
	return result

func paste_action() -> Array[FKEventAction]:
	if _type != "action":
		return []
	var result: Array[FKEventAction] = []
	for dict in _action_data:
		result.append(_deserialize_action(dict))
	return result

func paste_condition() -> Array[FKEventCondition]:
	if _type != "condition":
		return []
	var result: Array[FKEventCondition] = []
	for dict in _condition_data:
		result.append(_deserialize_condition(dict))
	return result

func paste_group() -> FKGroupBlock:
	if _type != "group":
		return null
	return _deserialize_group_block(_group_data)


# ===========================
# INTERNAL SERIALIZATION
# ===========================

func _serialize_event_block(data: FKEventBlock) -> Dictionary:
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
		result["conditions"].append(_serialize_condition(cond))

	for act in data.actions:
		result["actions"].append(_serialize_action(act))

	return result


func _serialize_condition(cond: FKEventCondition) -> Dictionary:
	return {
		"condition_id": cond.condition_id,
		"target_node": str(cond.target_node),
		"inputs": cond.inputs.duplicate(),
		"negated": cond.negated
	}


func _serialize_action(act: FKEventAction) -> Dictionary:
	var dict = {
		"action_id": act.action_id,
		"target_node": str(act.target_node),
		"inputs": act.inputs.duplicate(),
		"is_branch": act.is_branch,
		"branch_type": act.branch_type
	}

	if act.is_branch:
		if act.branch_condition:
			dict["branch_condition"] = _serialize_condition(act.branch_condition)

		dict["branch_actions"] = []
		for sub in act.branch_actions:
			dict["branch_actions"].append(_serialize_action(sub))

	return dict


func _serialize_group_block(data: FKGroupBlock) -> Dictionary:
	var result := {
		"type": "group",
		"title": data.title,
		"collapsed": data.collapsed,
		"color": data.color,
		"children": []
	}

	for child in data.children:
		var type = child.get("type", "")
		var dataChild = child.get("data")
		var to_append: Variant = null
		var children: Array = result["children"]
		
		if type == "event":
			to_append = 	{
								"type": "event",
								"data": _serialize_event_block(dataChild)
							}
		elif type == "comment":
			to_append = 	{
								"type": "comment",
								"data": _serialize_comment_block(dataChild)
							}
		elif type == "group":
			to_append = 	{
								"type": "group",
								"data": _serialize_group_block(dataChild)
							}
		
		if to_append != null:
			children.append(to_append)

	return result


func _serialize_comment_block(data: FKCommentBlock) -> Dictionary:
	return {
		"type": "comment",
		"text": data.text
	}


# ===========================
# INTERNAL DESERIALIZATION
# ===========================

func _deserialize_event_block(dict: Dictionary) -> FKEventBlock:
	var block_id = dict.get("block_id", "")
	var event_id = dict.get("event_id", "")
	var target_node = NodePath(dict.get("target_node", ""))

	var data = FKEventBlock.new(block_id, event_id, target_node)
	data.inputs = dict.get("inputs", {}).duplicate()
	data.conditions = [] as Array[FKEventCondition]
	data.actions = [] as Array[FKEventAction]

	for cond_dict in dict.get("conditions", []):
		data.conditions.append(_deserialize_condition(cond_dict))

	for act_dict in dict.get("actions", []):
		data.actions.append(_deserialize_action(act_dict))

	return data


func _deserialize_condition(dict: Dictionary) -> FKEventCondition:
	var cond = FKEventCondition.new()
	cond.condition_id = dict.get("condition_id", "")
	cond.target_node = NodePath(dict.get("target_node", ""))
	cond.inputs = dict.get("inputs", {}).duplicate()
	cond.negated = dict.get("negated", false)
	cond.actions = [] as Array[FKEventAction]  # Always empty for conditions
	return cond


func _deserialize_action(dict: Dictionary) -> FKEventAction:
	var act = FKEventAction.new()
	act.action_id = dict.get("action_id", "")
	act.target_node = NodePath(dict.get("target_node", ""))
	act.inputs = dict.get("inputs", {}).duplicate()
	act.is_branch = dict.get("is_branch", false)
	act.branch_type = dict.get("branch_type", "")

	if act.is_branch:
		var cond_dict = dict.get("branch_condition", null)
		if cond_dict:
			act.branch_condition = _deserialize_condition(cond_dict)

		act.branch_actions = [] as Array[FKEventAction]
		for sub_dict in dict.get("branch_actions", []):
			act.branch_actions.append(_deserialize_action(sub_dict))

	return act


func _deserialize_group_block(dict: Dictionary) -> FKGroupBlock:
	var data = FKGroupBlock.new()
	data.title = dict.get("title", "Group")
	data.collapsed = dict.get("collapsed", false)
	data.color = dict.get("color", Color(0.25, 0.22, 0.35, 1.0))
	data.children = []

	for child_dict in dict.get("children", []):
		var child_type = child_dict.get("type", "")
		var child_data = child_dict.get("data")
		var children: Array = data.children
		var to_append: Variant = null

		if child_type == "event":
			to_append = {"type": "event", "data": _deserialize_event_block(child_data)}
		elif child_type == "comment":
			to_append = {"type": "comment", "data": _deserialize_comment_block(child_data)}
		elif child_type == "group":
			to_append = {"type": "group", "data": _deserialize_group_block(child_data)}

		if to_append != null:
			children.append(to_append)

	return data


func _deserialize_comment_block(dict: Dictionary) -> FKCommentBlock:
	var data = FKCommentBlock.new()
	data.text = dict.get("text", "")
	return data
