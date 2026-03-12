extends RefCounted
class_name FKBranchExecutor

var registry: FKRegistry
var fk_engine: FlowKitEngine

func _resolve_target(target: String, root: Node) -> Node:
	if target == _sys_node_name:
		return fk_engine.get_node(_path_to_sys)
	return root.get_node_or_null(target)

const _sys_node_name := "System"
const _path_to_sys := NodePath("/root/FlowKitSystem")

## Evaluate a branch's condition. Returns true if the condition passes.
func _evaluate_condition(act: FKEventAction, current_root: Node, block_id: String) -> bool:
	if not act.branch_condition:
		return false

	var cond = act.branch_condition
	var target := str(cond.target_node)
	var cnode: Node = _resolve_target(target, current_root)
	if not cnode:
		return false

	return registry.check_condition(cond.condition_id, cnode, cond.inputs, cond.negated, current_root, block_id)

## Execute a list of actions, handling branch chains via providers.
## Used by both _execute_block (top-level actions) and nested branches.
func _execute_actions(actions: Array, current_root: Node, block_id: String) -> void:
	var branch_taken: bool = false
	var in_branch_chain: bool = false

	for act in actions:
		if act.is_branch:
			var branch_id: String = registry.resolve_branch_id(act.branch_id, act.branch_type)
			var provider = registry.get_branch_provider(branch_id)

			if not provider:
				# Unknown branch provider — skip
				continue

			match act.branch_type:
				"if":
					branch_taken = false
					in_branch_chain = provider.get_type() == "chain" if provider.has_method("get_type") else false
					var should_exec = _should_execute_branch(act, provider, current_root, block_id)
					if should_exec:
						branch_taken = true
						var evaluated = _get_branch_inputs(act, current_root)
						var count: int = provider.get_execution_count(evaluated, block_id) if provider.has_method("get_execution_count") else 1
						for i in count:
							await _execute_actions(act.branch_actions, current_root, block_id)
				"elseif":
					if in_branch_chain and not branch_taken:
						var should_exec = _should_execute_branch(act, provider, current_root, block_id)
						if should_exec:
							branch_taken = true
							var evaluated = _get_branch_inputs(act, current_root)
							var count: int = provider.get_execution_count(evaluated, block_id) if provider.has_method("get_execution_count") else 1
							for i in count:
								await _execute_actions(act.branch_actions, current_root, block_id)
				"else":
					if in_branch_chain and not branch_taken:
						branch_taken = true
						await _execute_actions(act.branch_actions, current_root, block_id)
					in_branch_chain = false
				_:
					# Standalone branch (no chain position) — treat like "if"
					var should_exec = _should_execute_branch(act, provider, current_root, block_id)
					if should_exec:
						var evaluated = _get_branch_inputs(act, current_root)
						var count: int = provider.get_execution_count(evaluated, block_id) if provider.has_method("get_execution_count") else 1
						for i in count:
							await _execute_actions(act.branch_actions, current_root, block_id)
					in_branch_chain = false
					branch_taken = false
		else:
			in_branch_chain = false
			branch_taken = false
				
			var target := str(act.target_node)
			var anode: Node = _resolve_target(target, current_root)
			if not anode:
				print("[FlowKit] Action target node not found: ", act.target_node)
				continue
			var provider: Variant = await registry.execute_action(act.action_id, anode, act.inputs, current_root, block_id)

## Determine whether a branch should execute, delegating to the branch provider.
## Handles both condition-type and evaluation-type branches.
func _should_execute_branch(act: FKEventAction, provider: Variant, 
current_root: Node, block_id: String) -> bool:
	if not provider:
		return false

	var input_type: String = provider.get_input_type() if provider.has_method("get_input_type") else "condition"

	if input_type == "condition":
		var cond_result: bool = _evaluate_condition(act, current_root, block_id)
		return provider.should_execute(cond_result, {}, block_id)
	else:
		# Evaluation type: evaluate branch_inputs and let the provider decide
		var evaluated_inputs: Dictionary = registry.evaluate_branch_inputs(act.branch_inputs, current_root)
		return provider.should_execute(false, evaluated_inputs, block_id)

## Get evaluated branch inputs for execution-count queries.
func _get_branch_inputs(act: FKEventAction, current_root: Node) -> Dictionary:
	return registry.evaluate_branch_inputs(act.branch_inputs, current_root)
