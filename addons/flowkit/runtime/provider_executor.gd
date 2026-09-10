extends RefCounted
class_name FKProviderExecutor

const FKExpressionEvaluator = preload("res://addons/flowkit/runtime/expression_evaluator.gd")

var registry: FKRegistry
var _waiting_on_action: bool = false

func _init(p_registry: FKRegistry) -> void:
	registry = p_registry

func poll_event(event_id: String, node: Node, inputs: Dictionary = {}, unit_id: int = -1, \
scene_root: Node = null) -> bool:
	var provider: Variant = registry.get_event_provider(event_id)
	if not provider or not provider.has_method("poll"):
		return false

	var evaluated_inputs: Dictionary = FKExpressionEvaluator.evaluate_inputs(inputs, node, scene_root)
	return provider.poll(node, evaluated_inputs, unit_id)

func setup_event(event_id: String, node: Node, trigger_callback: Callable, unit_id: int = -1) -> void:
	var provider: Variant = registry.get_event_provider(event_id)
	if provider and provider.has_method("setup"):
		provider.setup(node, trigger_callback, unit_id)

func teardown_event(event_id: String, node: Node, unit_id: int = -1) -> void:
	var provider: Variant = registry.get_event_provider(event_id)
	if provider and provider.has_method("teardown"):
		provider.teardown(node, unit_id)

func is_signal_event(event_id: String) -> bool:
	var provider: Variant = registry.get_event_provider(event_id)
	return provider != null and provider.has_method("is_signal_event") and provider.is_signal_event()

func check_condition(condition_id: String, node: Node, inputs: Dictionary, \
negated: bool = false, scene_root: Node = null, unit_id: int = -1) -> bool:
	var provider := registry.get_condition_provider(condition_id, node)
	if not provider or not provider.has_method("check"):
		return false

	var evaluated_inputs: Dictionary = FKExpressionEvaluator.evaluate_inputs(inputs, node, scene_root, node)
	var result = provider.check(node, evaluated_inputs, unit_id)
	return not result if negated else result

func execute_action(action_id: String, node: Node, inputs: Dictionary, \
scene_root: Node = null, unit_id: int = -1) -> Variant:
	var provider := registry.get_action_provider(action_id, node)
	if not provider or not provider.has_method("execute"):
		return null

	var context := scene_root if scene_root else node
	var evaluated_inputs: Dictionary = FKExpressionEvaluator.evaluate_inputs(inputs, context, scene_root, node)
	var is_multi_frame_action: bool = provider.has_method("requires_multi_frames") and \
	provider.requires_multi_frames()
	if is_multi_frame_action:
		_waiting_on_action = true
		provider.exec_completed.connect(_on_exec_completed)

	provider.execute(node, evaluated_inputs, unit_id)
	while _waiting_on_action:
		await node.get_tree().process_frame

	if is_multi_frame_action:
		provider.exec_completed.disconnect(_on_exec_completed)

	return provider

func apply_behavior(behavior_id: String, node: Node, inputs: Dictionary = {}, scene_root: Node = null) -> void:
	var behavior: Variant = registry.get_behavior(behavior_id)
	if behavior and behavior.has_method("apply"):
		var context := scene_root if scene_root else node
		var evaluated_inputs: Dictionary = FKExpressionEvaluator.evaluate_inputs(inputs, context, scene_root)
		behavior.apply(node, evaluated_inputs)

func remove_behavior(behavior_id: String, node: Node) -> void:
	var behavior: Variant = registry.get_behavior(behavior_id)
	if behavior and behavior.has_method("remove"):
		behavior.remove(node)

func evaluate_branch_inputs(inputs: Dictionary, scene_root: Node) -> Dictionary:
	if inputs.is_empty():
		return {}
	var context := scene_root if scene_root else null
	return FKExpressionEvaluator.evaluate_inputs(inputs, context, scene_root)

func _on_exec_completed() -> void:
	_waiting_on_action = false