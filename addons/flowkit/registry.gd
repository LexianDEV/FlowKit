extends Node
class_name FKRegistry

# Preload the expression evaluator
const FKExpressionEvaluator = preload("res://addons/flowkit/runtime/expression_evaluator.gd")

var action_providers: Array[FKAction] = []
var condition_providers: Array[FKCondition] = []
var event_providers: Array[FKEvent] = []
var behavior_providers: Array[FKBehavior] = []
var branch_providers: Array[FKBranch] = []

var actions_by_id: Dictionary[String, FKAction] = {}
var conditions_by_id: Dictionary[String, FKCondition] = {}
var events_by_id: Dictionary[String, FKEvent] = {}
var behaviors_by_id: Dictionary[String, FKBehavior] = {}
var branches_by_id: Dictionary[String, FKBranch] = {}

var action_alias_to_id: Dictionary[String, String] = {}
var condition_alias_to_id: Dictionary[String, String] = {}
var event_alias_to_id: Dictionary[String, String] = {}
var behavior_alias_to_id: Dictionary[String, String] = {}
var branch_alias_to_id: Dictionary[String, String] = {}

func _provider_id_of(provider: FKProvider) -> String:
	var result := "";
	if provider == null:
		return result

	result = provider.get_provider_id()
	result = provider.get_id() if result.is_empty() else result
	result = result.strip_edges()
	return result

func _provider_matches_id(provider: FKProvider, wanted_id: String) -> bool:
	if provider == null:
		return false

	var wanted := wanted_id.strip_edges()
	if wanted.is_empty():
		return false

	var canonical_id := provider.get_provider_id().strip_edges()
	if canonical_id == wanted:
		return true

	# Compatibility with sheets saved before providers got canonical IDs.
	var legacy_id := provider.get_id().strip_edges()
	return legacy_id == wanted

func load_all() -> void:
	var loader := FKProviderLoader.new()
	var result := loader.load_all()
	action_providers = result.action_providers
	condition_providers = result.condition_providers
	event_providers = result.event_providers
	behavior_providers = result.behavior_providers
	branch_providers = result.branch_providers

	for diagnostic in result.diagnostics:
		push_warning("[FKRegistry] %s" % diagnostic)
	for error in result.errors:
		push_error("[FKRegistry] %s" % error)
	print("[FKRegistry] Loaded providers from %s: %d actions, %d conditions, %d events, %d behaviors, %d branches" % [
		result.source,
		action_providers.size(),
		condition_providers.size(),
		event_providers.size(),
		behavior_providers.size(),
		branch_providers.size()
	])

func load_providers() -> void:
	# Alias for load_all() for backward compatibility
	load_all()

func get_actions_for_node_class(node_class: String) -> Array[FKAction]:
	var result: Array[FKAction] = []
	for provider in action_providers:
		if provider.supports_node_class(node_class):
			result.append(provider)
	return result

func get_conditions_for_node_class(node_class: String) -> Array[FKCondition]:
	var result: Array[FKCondition] = []
	for provider in condition_providers:
		if provider.supports_node_class(node_class):
			result.append(provider)
	return result

func get_events_for_node_class(node_class: String) -> Array[FKEvent]:
	var result: Array[FKEvent] = []
	for provider in event_providers:
		if provider.supports_node_class(node_class):
			result.append(provider)
	return result

func poll_event(event_id: String, node: Node, inputs: Dictionary = {}, unit_id: int = -1, 
scene_root: Node = null) -> bool:
	for provider in event_providers:
		if _provider_matches_id(provider, event_id):
			if provider.has_method("poll"):
				# Evaluate expressions in inputs before polling
				var evaluated_inputs: Dictionary 
				evaluated_inputs = FKExpressionEvaluator.evaluate_inputs(inputs, node, scene_root)
				return provider.poll(node, evaluated_inputs, unit_id)
	return false

## Returns the event provider instance for the given event_id, or null.
func get_event_provider(event_id: String) -> Variant:
	for provider in event_providers:
		if _provider_matches_id(provider, event_id):
			return provider
	return null

## Create a new, independent instance of the event provider for the given event_id.
## Each event unit should get its own instance to avoid shared state bugs.
func create_event_instance(event_id: String) -> Variant:
	for provider in event_providers:
		if _provider_matches_id(provider, event_id):
			return provider.get_script().new()
	return null

## Call setup() on an event provider so it can connect to signals on the target node.
## trigger_callback is a Callable the provider can call to fire the unit immediately.
func setup_event(event_id: String, node: Node, trigger_callback: Callable, unit_id: int = -1) -> void:
	var provider: Variant = get_event_provider(event_id)
	if provider and provider.has_method("setup"):
		provider.setup(node, trigger_callback, unit_id)

## Call teardown() on an event provider so it can disconnect signals / clean up.
func teardown_event(event_id: String, node: Node, unit_id: int = -1) -> void:
	var provider: Variant = get_event_provider(event_id)
	if provider and provider.has_method("teardown"):
		provider.teardown(node, unit_id)

## Returns true if the event provider with the given id is a signal-based event.
func is_signal_event(event_id: String) -> bool:
	var provider: Variant = get_event_provider(event_id)
	if provider and provider.has_method("is_signal_event"):
		return provider.is_signal_event()
	return false

func check_condition(condition_id: String, node: Node, inputs: Dictionary, 
negated: bool = false, scene_root: Node = null, unit_id: int = -1) -> bool:
	for provider in condition_providers:
		if _provider_matches_id(provider, condition_id):
			if provider.has_method("check"):
				# Evaluate expressions in inputs before checking
				# Use node as context for variable resolution (not scene_root)
				# Pass node as target_node so n_ variable lookups resolve on the correct node
				var context = node
				var evaluated_inputs: Dictionary = FKExpressionEvaluator.evaluate_inputs(inputs, context, scene_root, node)
				var result = provider.check(node, evaluated_inputs, unit_id)
				return not result if negated else result
	return false

func execute_action(action_id: String, node: Node, inputs: Dictionary, 
scene_root: Node = null, unit_id: int = -1) -> Variant:
	var provider := get_action_provider(action_id, node)
	if not provider or not provider.has_method("execute"):
		return null

	# Use scene_root as the base instance so get_node() resolves from the scene root.
	# Pass the original node as target_node so n_ variable lookups resolve on the correct node.
	var context = scene_root if scene_root else node
	var evaluated_inputs: Dictionary = FKExpressionEvaluator.evaluate_inputs(inputs, context, 
	scene_root, node)

	var is_multi_frame_action: bool = provider.has_method("requires_multi_frames") and \
	provider.requires_multi_frames()
	if is_multi_frame_action:
		_waiting_on_action = true
		provider.exec_completed.connect(_on_exec_completed)
		# Need to listen for completion before execution, otherwise single-frame actions can freeze.

	provider.execute(node, evaluated_inputs, unit_id)
	while _waiting_on_action:
		await node.get_tree().process_frame

	if is_multi_frame_action:
		provider.exec_completed.disconnect(_on_exec_completed)

	return provider

func get_action_provider(action_id: String, target_node: Node = null) -> FKAction:
	# Canonical IDs must be globally unique.
	for provider in action_providers:
		if provider.get_provider_id().strip_edges() == action_id:
			return provider

	# Old IDs may collide, so select the compatible provider.
	for provider in action_providers:
		if provider.get_id().strip_edges() == action_id:
			if target_node == null or provider.supports_node(target_node):
				return provider

	return null

func get_action_provider_for_node_class(action_id: String, node_class: String) -> FKAction:
	for provider in action_providers:
		if provider.get_provider_id().strip_edges() == action_id:
			return provider

	for provider in action_providers:
		if provider.get_id().strip_edges() == action_id and provider.supports_node_class(node_class):
			return provider

	return null

func get_condition_provider(condition_id: String, target_node: Node = null) -> FKCondition:
	# Canonical IDs must be globally unique.
	for provider in condition_providers:
		if provider.get_provider_id().strip_edges() == condition_id:
			return provider

	# Legacy IDs can be reused, so prefer one compatible with the target node.
	for provider in condition_providers:
		if provider.get_id().strip_edges() == condition_id:
			if target_node == null or provider.supports_node(target_node):
				return provider

	return null

func get_condition_provider_for_node_class(condition_id: String, node_class: String) -> FKCondition:
	for provider in condition_providers:
		if provider.get_provider_id().strip_edges() == condition_id:
			return provider

	for provider in condition_providers:
		if provider.get_id().strip_edges() == condition_id and provider.supports_node_class(node_class):
			return provider

	return null
	
func _on_exec_completed():
	_waiting_on_action = false

var _waiting_on_action: bool = false

func get_behavior(behavior_id: String) -> FKBehavior:
	for provider in behavior_providers:
		if _provider_matches_id(provider, behavior_id):
			return provider
	return null

func apply_behavior(behavior_id: String, node: Node, inputs: Dictionary = {}, scene_root: Node = null) -> void:
	var behavior: Variant = get_behavior(behavior_id)
	if behavior and behavior.has_method("apply"):
		# Use scene_root as context if provided, otherwise use the node
		var context = scene_root if scene_root else node
		var evaluated_inputs: Dictionary = FKExpressionEvaluator.evaluate_inputs(inputs, context, scene_root)
		behavior.apply(node, evaluated_inputs)

func remove_behavior(behavior_id: String, node: Node) -> void:
	var behavior: Variant = get_behavior(behavior_id)
	if behavior and behavior.has_method("remove"):
		behavior.remove(node)

# --- Branch providers -------------------------------------------------------

func get_branch_provider(branch_id: String) -> FKBranch:
	for provider in branch_providers:
		if _provider_matches_id(provider, branch_id):
			return provider
	return null

	
## Resolve the branch provider ID for a branch action.
## Provides backward compatibility: legacy sheets stored "if"/"elseif"/"else"
## in branch_type without a separate branch_id field.
func resolve_branch_id(act_branch_id: String, act_branch_type: String) -> String:
	if act_branch_id and not act_branch_id.is_empty():
		return act_branch_id
	# Legacy compatibility
	if act_branch_type in ["if", "elseif", "else"]:
		return "if_branch"
	return ""

## Evaluate branch inputs through the expression evaluator.
func evaluate_branch_inputs(inputs: Dictionary, scene_root: Node) -> Dictionary:
	if inputs.is_empty():
		return {}
	var context = scene_root if scene_root else null
	return FKExpressionEvaluator.evaluate_inputs(inputs, context, scene_root)
