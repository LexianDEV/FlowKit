extends Node
class_name FKRegistry

# Preload the expression evaluator
const FKExpressionEvaluator = preload("res://addons/flowkit/runtime/expression_evaluator.gd")

# Path to the provider manifest resource
const MANIFEST_PATH = "res://addons/flowkit/saved/provider_manifest.tres"

var action_providers: Array = []
var condition_providers: Array = []
var event_providers: Array = []
var behavior_providers: Array = []

func load_all() -> void:
	# Try to load from manifest first (required for exported builds)
	if _load_from_manifest():
		print("[FlowKit Registry] Loaded providers from manifest: %d actions, %d conditions, %d events, %d behaviors" % [
			action_providers.size(),
			condition_providers.size(),
			event_providers.size(),
			behavior_providers.size()
		])
		return
	
	# Fallback to directory scanning (editor/development only)
	# This will not work in exported builds where DirAccess cannot enumerate files
	if OS.has_feature("editor"):
		_load_folder("actions", action_providers)
		_load_folder("conditions", condition_providers)
		_load_folder("events", event_providers)
		_load_folder("behaviors", behavior_providers)
		
		print("[FlowKit Registry] Loaded providers from directories: %d actions, %d conditions, %d events, %d behaviors" % [
			action_providers.size(),
			condition_providers.size(),
			event_providers.size(),
			behavior_providers.size()
		])
	else:
		push_error("[FlowKit Registry] No provider manifest found and directory scanning is not available in exported builds. Generate the manifest in the editor.")

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
	if manifest.get("action_scripts"):
		for script: GDScript in manifest.action_scripts:
			if script:
				action_providers.append(script.new())
	
	if manifest.get("condition_scripts"):
		for script: GDScript in manifest.condition_scripts:
			if script:
				condition_providers.append(script.new())
	
	if manifest.get("event_scripts"):
		for script: GDScript in manifest.event_scripts:
			if script:
				event_providers.append(script.new())
	
	if manifest.get("behavior_scripts"):
		for script: GDScript in manifest.behavior_scripts:
			if script:
				behavior_providers.append(script.new())
	
	var has_providers = action_providers.size() + condition_providers.size() + event_providers.size() + behavior_providers.size() > 0
	return has_providers

## Directory scanning for editor/development use only.
## This will NOT work in exported builds.
func _load_folder(subpath: String, array: Array) -> void:
	var path: String = "res://addons/flowkit/" + subpath
	_scan_directory_recursive(path, array)

func _scan_directory_recursive(path: String, array: Array) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		var file_path: String = path + "/" + file_name
		
		if dir.current_is_dir():
			# Recursively scan subdirectories
			_scan_directory_recursive(file_path, array)
		elif file_name.ends_with(".gd") and not file_name.ends_with(".uid"):
			# Load the script and instantiate it
			var script: Variant = load(file_path)
			if script:
				var instance: Variant = script.new()
				array.append(instance)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func poll_event(event_id: String, node: Node, inputs: Dictionary = {}, block_id: String = "", scene_root: Node = null) -> bool:
	for provider in event_providers:
		if provider.has_method("get_id") and provider.get_id() == event_id:
			if provider.has_method("poll"):
				# Evaluate expressions in inputs before polling
				var evaluated_inputs: Dictionary = FKExpressionEvaluator.evaluate_inputs(inputs, node, scene_root)
				return provider.poll(node, evaluated_inputs, block_id)
	return false

## Returns the event provider instance for the given event_id, or null.
func get_event_provider(event_id: String) -> Variant:
	for provider in event_providers:
		if provider.has_method("get_id") and provider.get_id() == event_id:
			return provider
	return null

## Call setup() on an event provider so it can connect to signals on the target node.
## trigger_callback is a Callable the provider can call to fire the block immediately.
func setup_event(event_id: String, node: Node, trigger_callback: Callable, block_id: String = "") -> void:
	var provider: Variant = get_event_provider(event_id)
	if provider and provider.has_method("setup"):
		provider.setup(node, trigger_callback, block_id)

## Call teardown() on an event provider so it can disconnect signals / clean up.
func teardown_event(event_id: String, node: Node, block_id: String = "") -> void:
	var provider: Variant = get_event_provider(event_id)
	if provider and provider.has_method("teardown"):
		provider.teardown(node, block_id)

## Returns true if the event provider with the given id is a signal-based event.
func is_signal_event(event_id: String) -> bool:
	var provider: Variant = get_event_provider(event_id)
	if provider and provider.has_method("is_signal_event"):
		return provider.is_signal_event()
	return false

func check_condition(condition_id: String, node: Node, inputs: Dictionary, negated: bool = false, scene_root: Node = null, block_id: String = "") -> bool:
	for provider in condition_providers:
		if provider.has_method("get_id") and provider.get_id() == condition_id:
			if provider.has_method("check"):
				# Evaluate expressions in inputs before checking
				# Use node as context for variable resolution (not scene_root)
				var context = node
				var evaluated_inputs: Dictionary = FKExpressionEvaluator.evaluate_inputs(inputs, context, scene_root)
				var result = provider.check(node, evaluated_inputs, block_id)
				return not result if negated else result
	return false

func execute_action(action_id: String, node: Node, inputs: Dictionary, scene_root: Node = null, block_id: String = "") -> Variant:
	for provider in action_providers:
		if provider.has_method("get_id") and provider.get_id() == action_id:
			if provider.has_method("execute"):
				# Use scene_root as the base instance so get_node() resolves from the scene root
				# Pass original node as target_node so n_ variable lookups resolve on the correct node
				var context = scene_root if scene_root else node
				var evaluated_inputs: Dictionary = FKExpressionEvaluator.evaluate_inputs(inputs, context, scene_root, node)
				
				var is_multi_frame_action: bool = provider.has_method("requires_multi_frames") and provider.requires_multi_frames()
				if is_multi_frame_action:
					_waiting_on_action = true
					provider.exec_completed.connect(_on_exec_completed)
					# ^Need to listen for the completion signal BEFORE we execute the action.
					# Otherwise, under circumstances where the action only needs one frame to work,
					# we'll miss the timing and end up freezing the game.
					
				provider.execute(node, evaluated_inputs, block_id)
				while _waiting_on_action:
					await node.get_tree().process_frame
				
				if is_multi_frame_action:
					provider.exec_completed.disconnect(_on_exec_completed) 
					# ^Signal-hygiene
					
				return provider
	return null

func _on_exec_completed():
	_waiting_on_action = false

var _waiting_on_action: bool = false

func get_behavior(behavior_id: String) -> Variant:
	for provider in behavior_providers:
		if provider.has_method("get_id") and provider.get_id() == behavior_id:
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
