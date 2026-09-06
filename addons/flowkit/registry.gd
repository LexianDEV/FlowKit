extends Node
class_name FKRegistry

# Preload the expression evaluator
const FKExpressionEvaluator = preload("res://addons/flowkit/runtime/expression_evaluator.gd")

# Path to the provider manifest resource
const MANIFEST_PATH = "res://addons/flowkit/saved/provider_manifest.tres"

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

func _provider_source_of(provider: Variant) -> String:
	if provider == null:
		return "<null>"

	if provider is Object and provider.has_method("get_script"):
		var script: Variant = provider.get_script()
		if script is Script and not script.resource_path.is_empty():
			return script.resource_path

	if provider is Script and not provider.resource_path.is_empty():
		return provider.resource_path

	return str(provider)

func _warn_registry_duplicates() -> void:
	_warn_duplicate_ids(action_providers, "action")
	_warn_duplicate_ids(condition_providers, "condition")
	_warn_duplicate_ids(event_providers, "event")
	_warn_duplicate_ids(behavior_providers, "behavior")
	_warn_duplicate_ids(branch_providers, "branch")

func _warn_duplicate_ids(providers: Array, label: String) -> void:
	var seen: Dictionary = {}
	for p in providers:
		var pid := _provider_id_of(p)
		var source := _provider_source_of(p)
		if pid.is_empty():
			push_warning("[FKRegistry] %s provider has empty id in %s" % [label, source])
			continue
		if seen.has(pid):
			push_warning("[FKRegistry] Duplicate %s provider id '%s' in %s and %s" % [label, pid, seen[pid], source])
		else:
			seen[pid] = source

func load_all() -> void:
	# Try to load from manifest first (required for exported builds)
	if _load_from_manifest():
		_warn_registry_duplicates()
		print("[FKRegistry] Loaded providers from manifest: %d actions, %d conditions, %d events, %d behaviors, %d branches" % [
			action_providers.size(),
			condition_providers.size(),
			event_providers.size(),
			behavior_providers.size(),
			branch_providers.size()
		])
		return
	
	# Fallback to directory scanning (editor/development only)
	# This will not work in exported builds where DirAccess cannot enumerate files
	if OS.has_feature("editor"):
		_load_folder("actions", "action")
		_load_folder("conditions", "condition")
		_load_folder("events", "event")
		_load_folder("behaviors", "behavior")
		_load_folder("branches", "branch")
		
		_warn_registry_duplicates()
		print("[FKRegistry]: Loaded providers from directories: %d actions, %d conditions, %d events, %d behaviors, %d branches" % [
			action_providers.size(),
			condition_providers.size(),
			event_providers.size(),
			behavior_providers.size(),
			branch_providers.size()
		])
	else:
		push_error("[FKRegistry]: No provider manifest found and directory scanning is not available in exported builds. Generate the manifest in the editor.")

func load_providers() -> void:
	# Alias for load_all() for backward compatibility
	load_all()

## Load providers from the pre-generated manifest resource.
## Returns true if successful, false if manifest not found or invalid.
func _load_from_manifest() -> bool:
	if not ResourceLoader.exists(MANIFEST_PATH):
		return false
	
	var manifest: Resource = load(MANIFEST_PATH)
	if not manifest:
		return false
	
	# Instantiate providers from the manifest scripts
	# Base classes (no get_id) may be in the manifest to satisfy inheritance
	# but should not be instantiated as providers.
	if manifest.get("action_scripts"):
		for script: GDScript in manifest.action_scripts:
			_try_instantiate_provider(script, "action")

	if manifest.get("condition_scripts"):
		for script: GDScript in manifest.condition_scripts:
			_try_instantiate_provider(script, "condition")

	if manifest.get("event_scripts"):
		for script: GDScript in manifest.event_scripts:
			_try_instantiate_provider(script, "event")

	if manifest.get("behavior_scripts"):
		for script: GDScript in manifest.behavior_scripts:
			_try_instantiate_provider(script, "behavior")

	if manifest.get("branch_scripts"):
		for script: GDScript in manifest.branch_scripts:
			_try_instantiate_provider(script, "branch")
	
	var has_providers = action_providers.size() + condition_providers.size() + event_providers.size() + behavior_providers.size() + branch_providers.size() > 0
	return has_providers


## Safely instantiate a provider from a script, adding it to the passed
## array if it has a valid provider ID. Skips base classes and scripts that fail to load.
func _try_instantiate_provider(script: GDScript, kind: String) -> void:
	if not script:
		return

	# can_instantiate() can be false during load-order warmup; try anyway.
	var instance: Variant = script.new()
	
	if instance == null:
		push_warning("[FlowKit Registry] Skipping provider that returned null on new(): %s" % script.resource_path)
		return

	var found_abstract_provider: bool = instance is FKProvider and \
	instance.is_abstract_provider()
	if found_abstract_provider:
		return

	var prov: FKProvider = null
	match kind:
		"action":
			if instance is FKAction:
				prov = instance as FKAction
				if _provider_id_of(prov).is_empty():
					push_warning("[FlowKit Registry] Skipping action provider with empty id: %s" % script.resource_path)
					return
				action_providers.append(prov)
		"condition":
			if instance is FKCondition:
				prov = instance as FKCondition
				if _provider_id_of(prov).is_empty():
					push_warning("[FlowKit Registry] Skipping condition provider with empty id: %s" % script.resource_path)
					return
				condition_providers.append(prov)
		"event":
			if instance is FKEvent:
				prov = instance as FKEvent
				if _provider_id_of(prov).is_empty():
					push_warning("[FlowKit Registry] Skipping event provider with empty id: %s" % script.resource_path)
					return
				event_providers.append(prov)
		"behavior":
			if instance is FKBehavior:
				prov = instance as FKBehavior
				if _provider_id_of(prov).is_empty():
					push_warning("[FlowKit Registry] Skipping behavior provider with empty id: %s" % script.resource_path)
					return
				behavior_providers.append(prov)
		"branch":
			if instance is FKBranch:
				prov = instance as FKBranch
				if _provider_id_of(prov).is_empty():
					push_warning("[FlowKit Registry] Skipping branch provider with empty id: %s" % script.resource_path)
					return
				branch_providers.append(prov)

## Directory scanning for editor/development use only.
## This will NOT work in exported builds.
func _load_folder(subpath: String, kind: String) -> void:
	var path: String = "res://addons/flowkit/" + subpath
	_scan_directory_recursive(path, kind) 

func _scan_directory_recursive(path: String, kind: String) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		var file_path: String = path + "/" + file_name
		
		if dir.current_is_dir():
			# Recursively scan subdirectories
			_scan_directory_recursive(file_path, kind)
		elif file_name.ends_with(".gd") and not file_name.ends_with(".uid"):
			# Load the script and instantiate it
			var script: Variant = load(file_path)
			if script is GDScript:
				_try_instantiate_provider(script, kind)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

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
