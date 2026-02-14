extends FKAction

func get_description() -> String:
	return "Calls a local subsheet, executing its actions in sequence."

func get_id() -> String:
	return "call_subsheet"

func get_name() -> String:
	return "Call Subsheet"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "subsheet_id", "type": "String", "description": "The ID of the subsheet to call."},
	]

func requires_multi_frames() -> bool:
	# This action may await if subsheet contains multi-frame actions
	return true

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	var subsheet_id: String = str(inputs.get("subsheet_id", ""))
	if subsheet_id.is_empty():
		push_error("[FlowKit] call_subsheet: subsheet_id is empty")
		emit_signal("exec_completed")
		return
	
	# Get the FlowKit engine to access the current event sheet
	var engine = node.get_tree().root.get_node_or_null("/root/FlowKit")
	if not engine:
		push_error("[FlowKit] call_subsheet: FlowKit engine not found")
		emit_signal("exec_completed")
		return
	
	# Call the engine's method to execute the subsheet
	if engine.has_method("execute_subsheet"):
		await engine.execute_subsheet(subsheet_id, node)
		emit_signal("exec_completed")
	else:
		push_error("[FlowKit] call_subsheet: execute_subsheet method not found on engine")
		emit_signal("exec_completed")

