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

func copy_event(event_data: FKEventUnit) -> void:
	clear()
	_type = "event"
	_event_data.append(_serialize_event_block(event_data))

func copy_action(action_data: FKActionUnit) -> void:
	clear()
	_type = "action"
	_action_data.append(_serialize_action(action_data))

func copy_condition(condition_data: FKConditionUnit) -> void:
	clear()
	_type = "condition"
	_condition_data.append(_serialize_condition(condition_data))

func copy_group(group_data: FKGroup) -> void:
	clear()
	_type = "group"
	_group_data = _serialize_group_block(group_data)


# ---------------------------
# PASTE API
# ---------------------------

func paste_event() -> Array[FKEventUnit]:
	if _type != "event":
		return []
	var result: Array[FKEventUnit] = []
	for dict in _event_data:
		result.append(_deserialize_event_block(dict))
	return result

func paste_action() -> Array[FKActionUnit]:
	if _type != "action":
		return []
	var result: Array[FKActionUnit] = []
	for dict in _action_data:
		result.append(_deserialize_action(dict))
	return result

func paste_condition() -> Array[FKConditionUnit]:
	if _type != "condition":
		return []
	var result: Array[FKConditionUnit] = []
	for dict in _condition_data:
		result.append(_deserialize_condition(dict))
	return result

func paste_group() -> FKGroup:
	if _type != "group":
		return null
	return _deserialize_group_block(_group_data)


# ===========================
# INTERNAL SERIALIZATION
# ===========================

func _serialize_event_block(unit: FKEventUnit) -> Dictionary:
	var result = {
		"type": "event",
		"uid": unit.uid,
		"event_id": unit.event_id,
		"event_provider_id": unit.get_resolved_provider_id(),
		"target_node": str(unit.target_node),
		"inputs": unit.inputs.duplicate(),
		"conditions": [],
		"actions": []
	}

	for cond in unit.conditions:
		result["conditions"].append(_serialize_condition(cond))

	for act in unit.actions:
		result["actions"].append(_serialize_action(act))

	return result


func _serialize_condition(cond: FKConditionUnit) -> Dictionary:
	return {
		"condition_id": cond.condition_id,
		"condition_provider_id": cond.get_resolved_provider_id(),
		"target_node": str(cond.target_node),
		"inputs": cond.inputs.duplicate(),
		"negated": cond.negated
	}


func _serialize_action(act: FKActionUnit) -> Dictionary:
	var dict = {
        "action_id": act.action_id,
        "action_provider_id": "" if act.is_branch else act.get_resolved_provider_id(),
        "target_node": str(act.target_node),
        "inputs": act.inputs.duplicate(),
        "is_branch": act.is_branch,
        "branch_type": act.branch_type,
        "branch_id": act.branch_id,
        "branch_provider_id": act.get_resolved_provider_id() if act.is_branch else ""
    }

	if act.is_branch:
		if act.branch_condition:
			dict["branch_condition"] = _serialize_condition(act.branch_condition)

		dict["branch_actions"] = []
		for sub in act.branch_actions:
			dict["branch_actions"].append(_serialize_action(sub))

	return dict


func _serialize_group_block(data: FKGroup) -> Dictionary:
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


func _serialize_comment_block(data: FKComment) -> Dictionary:
	return {
		"type": "comment",
		"text": data.text
	}


# ===========================
# INTERNAL DESERIALIZATION
# ===========================

func _deserialize_event_block(dict: Dictionary) -> FKEventUnit:
	var unit_id: int = dict.get("uid", dict.get("personal_id", -1))
	var event_id: String = dict.get("event_id", "").strip_edges()
	var fallback_provider_id: String = dict.get("event_provider_id", "").strip_edges()
	if event_id.is_empty():
		event_id = fallback_provider_id

	var target_node = NodePath(dict.get("target_node", ""))
	var data = FKEventUnit.new(event_id, target_node)
	data.uid = unit_id
	data.inputs = dict.get("inputs", {}).duplicate()
	data.conditions = [] as Array[FKConditionUnit]
	data.actions = [] as Array[FKActionUnit]

	for cond_dict in dict.get("conditions", []):
		data.conditions.append(_deserialize_condition(cond_dict))

	for act_dict in dict.get("actions", []):
		data.actions.append(_deserialize_action(act_dict))

	return data


func _deserialize_condition(dict: Dictionary) -> FKConditionUnit:
	var cond = FKConditionUnit.new()
	var condition_id: String = dict.get("condition_id", "").strip_edges()
	if condition_id.is_empty():
		condition_id = dict.get("condition_provider_id", "").strip_edges()

	cond.condition_id = condition_id
	cond.target_node = NodePath(dict.get("target_node", ""))
	cond.inputs = dict.get("inputs", {}).duplicate()
	cond.negated = dict.get("negated", false)
	cond.actions = [] as Array[FKActionUnit]
	return cond


func _deserialize_action(dict: Dictionary) -> FKActionUnit:
	var act = FKActionUnit.new()
	act.is_branch = dict.get("is_branch", false)

	var action_id: String = dict.get("action_id", "").strip_edges()
	var action_provider_id: String = dict.get("action_provider_id", "").strip_edges()
	var branch_id: String = dict.get("branch_id", "").strip_edges()
	var branch_provider_id: String = dict.get("branch_provider_id", "").strip_edges()

	if act.is_branch:
		if branch_id.is_empty():
			branch_id = branch_provider_id
		act.branch_id = branch_id
	else:
		if action_id.is_empty():
			action_id = action_provider_id
		act.action_id = action_id

	act.target_node = NodePath(dict.get("target_node", ""))
	act.inputs = dict.get("inputs", {}).duplicate()
	act.branch_type = dict.get("branch_type", "")
	act.branch_id = branch_id

	if act.is_branch:
		var cond_dict = dict.get("branch_condition", null)
		if cond_dict:
			act.branch_condition = _deserialize_condition(cond_dict)

		act.branch_actions = [] as Array[FKActionUnit]
		for sub_dict in dict.get("branch_actions", []):
			act.branch_actions.append(_deserialize_action(sub_dict))

	return act


func _deserialize_group_block(dict: Dictionary) -> FKGroup:
	var data = FKGroup.new()
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


func _deserialize_comment_block(dict: Dictionary) -> FKComment:
	var data = FKComment.new()
	data.text = dict.get("text", "")
	return data
