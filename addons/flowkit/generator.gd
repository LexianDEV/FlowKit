@tool
extends RefCounted
class_name FKGenerator

const ACTIONS_DIR = "res://addons/flowkit/actions/"
const CONDITIONS_DIR = "res://addons/flowkit/conditions/"
const EVENTS_DIR = "res://addons/flowkit/events/"
const BEHAVIORS_DIR = "res://addons/flowkit/behaviors/"
const BRANCHES_DIR = "res://addons/flowkit/branches/"
const MANIFEST_PATH = "res://addons/flowkit/saved/provider_manifest.tres"
const PROVIDER_MANIFEST_SCRIPT = "res://addons/flowkit/resources/provider_manifest.gd"

var editor_interface: EditorInterface

func _init(p_editor_interface: EditorInterface) -> void:
	editor_interface = p_editor_interface

func generate_all() -> Dictionary:
	var result = {
		"actions": 0,
		"conditions": 0,
		"events": 0,
		"errors": []
	}
	
	var current_scene = editor_interface.get_edited_scene_root()
	if not current_scene:
		result.errors.append("No scene is currently open")
		return result
	
	# Collect all unique node types in the scene
	var node_types: Dictionary = {}
	_collect_node_types(current_scene, node_types)
	
	print("[FlowKit Generator] Found ", node_types.size(), " unique node types")
	
	# Generate providers for each node type
	for node_type in node_types.keys():
		var node_instance = node_types[node_type]
		
		# Generate actions
		var actions = _generate_actions_for_node(node_type, node_instance)
		result.actions += actions
		
		# Generate conditions
		var conditions = _generate_conditions_for_node(node_type, node_instance)
		result.conditions += conditions
		
		# Generate events (signals)
		var events = _generate_events_for_node(node_type, node_instance)
		result.events += events
	
	return result

func _collect_node_types(node: Node, types: Dictionary) -> void:
	var node_class = node.get_class()
	if not types.has(node_class):
		types[node_class] = node
	
	for child in node.get_children():
		_collect_node_types(child, types)

func _generate_actions_for_node(node_type: String, node_instance: Node) -> int:
	var count = 0
	var property_list = node_instance.get_property_list()
	var method_list = node_instance.get_method_list()
	
	# Generate setters for writable properties
	for prop in property_list:
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE or prop.usage & PROPERTY_USAGE_EDITOR:
			if not (prop.usage & PROPERTY_USAGE_READ_ONLY):
				if _is_valid_property_for_action(prop):
					_create_setter_action(node_type, prop)
					count += 1
	
	# Generate actions for void/non-bool methods (actions DO something)
	for method in method_list:
		if _is_valid_method_for_action(method):
			_create_method_action(node_type, method)
			count += 1
	
	return count

func _generate_conditions_for_node(node_type: String, node_instance: Node) -> int:
	var count = 0
	var property_list = node_instance.get_property_list()
	var method_list = node_instance.get_method_list()
	
	# Generate comparison conditions for readable properties
	for prop in property_list:
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE or prop.usage & PROPERTY_USAGE_EDITOR:
			if _is_valid_property_for_condition(prop):
				_create_property_comparison_condition(node_type, prop)
				count += 1
	
	# Generate conditions for boolean-returning methods (is_*, has_*, can_*, etc.)
	for method in method_list:
		if _is_valid_method_for_condition(method):
			_create_method_condition(node_type, method)
			count += 1
	
	return count

func _generate_events_for_node(node_type: String, node_instance: Node) -> int:
	var count = 0
	var signal_list = node_instance.get_signal_list()
	
	# Generate events for each signal
	for sig in signal_list:
		# Skip built-in tree signals that are too generic
		if sig.name in ["ready", "tree_entered", "tree_exiting", "tree_exited"]:
			continue
		
		_create_signal_event(node_type, sig)
		count += 1
	
	return count

# ============================================================================
# ACTION GENERATORS
# ============================================================================

func _is_valid_property_for_action(prop: Dictionary) -> bool:
	# Skip internal/private properties
	if prop.name.begins_with("_"):
		return false
	
	# Skip read-only properties
	if prop.usage & PROPERTY_USAGE_READ_ONLY:
		return false
	
	# Skip properties with "/" (nested/theme properties are hard to access)
	if "/" in prop.name:
		return false
	
	# Only include basic types that can be easily set
	var valid_types = [
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING,
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_COLOR,
		TYPE_RECT2, TYPE_QUATERNION
	]
	
	return prop.type in valid_types

func _is_valid_method_for_action(method: Dictionary) -> bool:
	# Skip private methods
	if method.name.begins_with("_"):
		return false
	
	# Skip getters/setters
	if method.name.begins_with("get_") or method.name.begins_with("set_"):
		return false
	
	# Skip condition-like methods (these should be conditions, not actions)
	# Methods like is_on_floor(), has_node(), can_process() are state checks
	if method.name.begins_with("is_") or method.name.begins_with("has_") or method.name.begins_with("can_"):
		return false
	
	# Skip methods with too many parameters (keep it simple)
	if method.args.size() > 4:
		return false
	
	# Only include methods from user classes or common useful ones
	if method.flags & METHOD_FLAG_VIRTUAL:
		return false
	
	return true

func _is_valid_method_for_condition(method: Dictionary) -> bool:
	# Skip private methods
	if method.name.begins_with("_"):
		return false
	
	# Skip getters/setters (handled by property conditions)
	if method.name.begins_with("get_") or method.name.begins_with("set_"):
		return false
	
	# Skip methods with too many parameters
	if method.args.size() > 4:
		return false
	
	# Skip virtual methods
	if method.flags & METHOD_FLAG_VIRTUAL:
		return false
	
	# Only include methods named like conditions (is_*, has_*, can_*)
	# These are state-checking methods, not action methods that happen to return bool
	# e.g., is_on_floor() = condition, move_and_slide() = action (even though it returns bool)
	var is_condition_name = method.name.begins_with("is_") or method.name.begins_with("has_") or method.name.begins_with("can_")
	
	return is_condition_name

func _create_setter_action(node_type: String, prop: Dictionary) -> void:
	var prop_name = prop.name
	var base_id = "set_" + prop_name.replace("/", "_").replace(" ", "_").to_lower()
	var action_id = "gen_" + base_id
	var action_name = "Set " + _humanize_name(prop_name) + " (Generated)"
	
	var dir_path = ACTIONS_DIR + node_type
	_ensure_directory_exists(dir_path)
	
	var file_path = dir_path + "/gen_" + base_id + ".gd"
	
	# Skip if file already exists
	if FileAccess.file_exists(file_path):
		return
	
	var type_name = _get_type_name(prop.type)
	var description = _get_property_description(node_type, prop_name, true)
	var code = """extends FKAction

func get_id() -> String:
	return "%s"

func get_name() -> String:
	return "%s"

func get_description() -> String:
	return "%s"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Value", "type": "%s"}
	]

func get_supported_types() -> Array[String]:
	return ["%s"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	if not node is %s:
		return
	
	var value = inputs.get("Value", %s)
	node.%s = value
""" % [
		action_id,
		action_name,
		description,
		type_name,
		node_type,
		node_type,
		_get_default_value(prop.type),
		prop_name
	]
	
	_write_file(file_path, code)

func _create_method_action(node_type: String, method: Dictionary) -> void:
	var method_name = method.name
	var base_id = method_name.to_lower()
	var action_id = "gen_" + base_id
	var action_name = _humanize_name(method_name) + " (Generated)"
	
	var dir_path = ACTIONS_DIR + node_type
	_ensure_directory_exists(dir_path)
	
	var file_path = dir_path + "/gen_" + base_id + ".gd"
	
	# Skip if file already exists
	if FileAccess.file_exists(file_path):
		return
	
	var inputs = []
	var call_args = []
	for i in range(method.args.size()):
		var arg = method.args[i]
		var arg_name = arg.name if arg.name != "" else "Arg" + str(i)
		var type_name = _get_type_name(arg.type)
		inputs.append('{"name": "%s", "type": "%s"}' % [_humanize_name(arg_name), type_name])
		call_args.append('inputs.get("%s", %s)' % [_humanize_name(arg_name), _get_default_value(arg.type)])
	
	var inputs_str = "[" + ", ".join(inputs) + "]" if inputs.size() > 0 else "[]"
	var call_str = "node.%s(%s)" % [method_name, ", ".join(call_args)]
	var description = _get_method_description(node_type, method)
	
	var code = """extends FKAction

func get_id() -> String:
	return "%s"

func get_name() -> String:
	return "%s"

func get_description() -> String:
	return "%s"

func get_inputs() -> Array[Dictionary]:
	return %s

func get_supported_types() -> Array[String]:
	return ["%s"]

func execute(node: Node, inputs: Dictionary, block_id: String = "") -> void:
	if not node is %s:
		return
	
	%s
""" % [
		action_id,
		action_name,
		description,
		inputs_str,
		node_type,
		node_type,
		call_str
	]
	
	_write_file(file_path, code)

# ============================================================================
# CONDITION GENERATORS
# ============================================================================

func _is_valid_property_for_condition(prop: Dictionary) -> bool:
	# Skip internal/private properties
	if prop.name.begins_with("_"):
		return false
	
	# Skip properties with "/" (nested/theme properties are hard to access)
	if "/" in prop.name:
		return false
	
	# Only include comparable types
	var valid_types = [
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING
	]
	
	return prop.type in valid_types

func _create_property_comparison_condition(node_type: String, prop: Dictionary) -> void:
	var prop_name = prop.name
	var base_id = "compare_" + prop_name.replace("/", "_").replace(" ", "_").to_lower()
	var condition_id = "gen_" + base_id
	var condition_name = "Compare " + _humanize_name(prop_name) + " (Generated)"
	
	var dir_path = CONDITIONS_DIR + node_type
	_ensure_directory_exists(dir_path)
	
	var file_path = dir_path + "/gen_" + base_id + ".gd"
	
	# Skip if file already exists
	if FileAccess.file_exists(file_path):
		return
	
	var type_name = _get_type_name(prop.type)
	
	var comparison_logic = ""
	if prop.type == TYPE_BOOL:
		comparison_logic = """	var value = inputs.get("Value", false)
	return node.%s == value""" % prop_name
	else:
		comparison_logic = """	var comparison: String = str(inputs.get("Comparison", "=="))
	var value = inputs.get("Value", %s)
	
	match comparison:
		"==": return node.%s == value
		"!=": return node.%s != value
		"<": return node.%s < value
		">": return node.%s > value
		"<=": return node.%s <= value
		">=": return node.%s >= value
		_: return node.%s == value""" % [
			_get_default_value(prop.type),
			prop_name, prop_name, prop_name, prop_name, prop_name, prop_name, prop_name
		]
	
	var inputs_array = ""
	if prop.type == TYPE_BOOL:
		inputs_array = '[{"name": "Value", "type": "Bool"}]'
	else:
		inputs_array = '[{"name": "Comparison", "type": "String"}, {"name": "Value", "type": "%s"}]' % type_name
	
	var description = _get_property_description(node_type, prop_name, false)
	
	var code = """extends FKCondition

func get_id() -> String:
	return "%s"

func get_name() -> String:
	return "%s"

func get_description() -> String:
	return "%s"

func get_inputs() -> Array[Dictionary]:
	return %s

func get_supported_types() -> Array[String]:
	return ["%s"]

func check(node: Node, inputs: Dictionary, block_id: String = "") -> bool:
	if not node is %s:
		return false
	
%s
""" % [
		condition_id,
		condition_name,
		description,
		inputs_array,
		node_type,
		node_type,
		comparison_logic
	]
	
	_write_file(file_path, code)

func _create_method_condition(node_type: String, method: Dictionary) -> void:
	var method_name = method.name
	var base_id = method_name.to_lower()
	var condition_id = "gen_" + base_id
	var condition_name = _humanize_name(method_name) + " (Generated)"
	
	var dir_path = CONDITIONS_DIR + node_type
	_ensure_directory_exists(dir_path)
	
	var file_path = dir_path + "/gen_" + base_id + ".gd"
	
	# Skip if file already exists
	if FileAccess.file_exists(file_path):
		return
	
	# Build inputs from method parameters
	var inputs = []
	var call_args = []
	for i in range(method.args.size()):
		var arg = method.args[i]
		var arg_name = arg.name if arg.name != "" else "Arg" + str(i)
		var type_name = _get_type_name(arg.type)
		inputs.append('{"name": "%s", "type": "%s"}' % [_humanize_name(arg_name), type_name])
		call_args.append('inputs.get("%s", %s)' % [_humanize_name(arg_name), _get_default_value(arg.type)])
	
	var inputs_str = "[" + ", ".join(inputs) + "]" if inputs.size() > 0 else "[]"
	var call_str = "node.%s(%s)" % [method_name, ", ".join(call_args)]
	var description = _get_method_description(node_type, method)
	
	var code = """extends FKCondition

func get_id() -> String:
	return "%s"

func get_name() -> String:
	return "%s"

func get_description() -> String:
	return "%s"

func get_inputs() -> Array[Dictionary]:
	return %s

func get_supported_types() -> Array[String]:
	return ["%s"]

func check(node: Node, inputs: Dictionary, block_id: String = "") -> bool:
	if not node is %s:
		return false
	
	return %s
""" % [
		condition_id,
		condition_name,
		description,
		inputs_str,
		node_type,
		node_type,
		call_str
	]
	
	_write_file(file_path, code)

# ============================================================================
# EVENT GENERATORS
# ============================================================================

func _create_signal_event(node_type: String, sig: Dictionary) -> void:
	var signal_name = sig.name
	var base_id = "on_" + signal_name.to_lower()
	var event_id = "gen_" + base_id
	var event_name = "On " + _humanize_name(signal_name) + " (Generated)"
	
	var dir_path = EVENTS_DIR + node_type
	_ensure_directory_exists(dir_path)
	
	var file_path = dir_path + "/gen_" + base_id + ".gd"
	
	# Skip if file already exists
	if FileAccess.file_exists(file_path):
		return
	
	# Build inputs from signal parameters
	var inputs = []
	for arg in sig.args:
		var arg_name = arg.name if arg.name != "" else "Arg"
		var type_name = _get_type_name(arg.type)
		inputs.append('{"name": "%s", "type": "%s"}' % [_humanize_name(arg_name), type_name])
	
	var inputs_str = "[" + ", ".join(inputs) + "]" if inputs.size() > 0 else "[]"
	var description = _get_signal_description(node_type, sig)
	
	# Build lambda parameters to match the signal's argument count.
	# Signals like body_entered(body) pass arguments; the lambda must accept them
	# even though we don't use them — otherwise Godot errors at emit time.
	var lambda_params = ""
	if sig.args.size() > 0:
		var parts: Array = []
		for i in range(sig.args.size()):
			parts.append("_arg%d" % i)
		lambda_params = ", ".join(parts)
	
	var code = """extends FKEvent

func get_id() -> String:
	return "%s"

func get_name() -> String:
	return "%s"

func get_description() -> String:
	return "%s"

func get_supported_types() -> Array[String]:
	return ["%s"]

func get_inputs() -> Array:
	return %s

func is_signal_event() -> bool:
	return true

# Store connections so we can disconnect in teardown.
# Key: block_id -> Callable
var _connections: Dictionary = {}

func setup(node: Node, trigger_callback: Callable, block_id: String = "") -> void:
	if not node or not node.is_inside_tree():
		return
	if not node.has_signal("%s"):
		return

	var cb: Callable = func(%s): trigger_callback.call()
	_connections[block_id] = cb
	node.%s.connect(cb)

func teardown(node: Node, block_id: String = "") -> void:
	if not node or not is_instance_valid(node):
		_connections.erase(block_id)
		return
	if _connections.has(block_id):
		var cb: Callable = _connections[block_id]
		if node.has_signal("%s") and node.%s.is_connected(cb):
			node.%s.disconnect(cb)
		_connections.erase(block_id)
""" % [
		event_id,
		event_name,
		description,
		node_type,
		inputs_str,
		signal_name,
		lambda_params,
		signal_name,
		signal_name,
		signal_name,
		signal_name
	]
	
	_write_file(file_path, code)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

func _humanize_name(name: String) -> String:
	# Convert snake_case or camelCase to Title Case
	var result = name.replace("_", " ").capitalize()
	return result

func _get_type_name(type: int) -> String:
	match type:
		TYPE_BOOL: return "Bool"
		TYPE_INT: return "Int"
		TYPE_FLOAT: return "Float"
		TYPE_STRING: return "String"
		TYPE_VECTOR2: return "Vector2"
		TYPE_VECTOR3: return "Vector3"
		TYPE_COLOR: return "Color"
		TYPE_RECT2: return "Rect2"
		TYPE_QUATERNION: return "Quaternion"
		TYPE_OBJECT: return "Object"
		_: return "Variant"

func _get_default_value(type: int) -> String:
	match type:
		TYPE_BOOL: return "false"
		TYPE_INT: return "0"
		TYPE_FLOAT: return "0.0"
		TYPE_STRING: return '""'
		TYPE_VECTOR2: return "Vector2.ZERO"
		TYPE_VECTOR3: return "Vector3.ZERO"
		TYPE_COLOR: return "Color.WHITE"
		TYPE_RECT2: return "Rect2()"
		TYPE_QUATERNION: return "Quaternion.IDENTITY"
		_: return "null"

func _ensure_directory_exists(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		DirAccess.make_dir_recursive_absolute(path)

func _get_property_description(node_type: String, prop_name: String, is_setter: bool) -> String:
	if is_setter:
		return "Sets the '%s' property on %s." % [prop_name, node_type]
	else:
		return "Compares the '%s' property on %s." % [prop_name, node_type]

func _get_method_description(node_type: String, method: Dictionary) -> String:
	var method_name = method.name
	
	# Build parameter list string
	var params_str = ""
	if method.args.size() > 0:
		var param_parts = []
		for arg in method.args:
			var arg_name = arg.name if arg.name != "" else "arg"
			var type_name = _get_type_name(arg.type)
			param_parts.append("%s: %s" % [arg_name, type_name])
		params_str = " Parameters: " + ", ".join(param_parts) + "."
	
	# Generate a description based on method name patterns
	if method_name.begins_with("is_"):
		var state = method_name.substr(3).replace("_", " ")
		return "Checks if the %s %s.%s" % [node_type, state, params_str]
	elif method_name.begins_with("has_"):
		var thing = method_name.substr(4).replace("_", " ")
		return "Checks if the %s has %s.%s" % [node_type, thing, params_str]
	elif method_name.begins_with("can_"):
		var ability = method_name.substr(4).replace("_", " ")
		return "Checks if the %s can %s.%s" % [node_type, ability, params_str]
	else:
		return "Calls %s() on %s.%s" % [method_name, node_type, params_str]

func _get_signal_description(node_type: String, sig: Dictionary) -> String:
	var signal_name = sig.name
	
	# Build parameter list string
	var params_str = ""
	if sig.args.size() > 0:
		var param_parts = []
		for arg in sig.args:
			var arg_name = arg.name if arg.name != "" else "arg"
			var type_name = _get_type_name(arg.type)
			param_parts.append("%s: %s" % [arg_name, type_name])
		params_str = " Signal parameters: " + ", ".join(param_parts) + "."
	
	return "Triggered when %s emits the '%s' signal.%s" % [node_type, signal_name, params_str]

func _write_file(path: String, content: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		print("[FlowKit Generator] Created: ", path)
	else:
		push_error("[FlowKit Generator] Failed to write: " + path)

# ============================================================================
# MANIFEST GENERATION
# ============================================================================

const EVENT_SHEET_DIR = "res://addons/flowkit/saved/event_sheet/"

## Generates an optimized provider manifest resource for exported builds.
## Only includes providers that are actively used in the project's event sheets,
## dramatically reducing the build size.
func generate_manifest() -> Dictionary:
	var result = {
		"actions": 0,
		"conditions": 0,
		"events": 0,
		"behaviors": 0,
		"branches": 0,
		"total_available": 0,
		"total_included": 0,
		"total_excluded": 0,
		"errors": []
	}

	# Ensure saved directory exists
	_ensure_directory_exists("res://addons/flowkit/saved")

	# Step 1: Scan all event sheets and scenes to find actively used provider IDs
	var used_ids: Dictionary = _scan_used_provider_ids()
	print("[FlowKit Generator] Used provider IDs:")
	print("  Actions:    ", used_ids.action_ids)
	print("  Conditions: ", used_ids.condition_ids)
	print("  Events:     ", used_ids.event_ids)
	print("  Branches:   ", used_ids.branch_ids)
	print("  Behaviors:  ", used_ids.behavior_ids)

	# Step 2: Collect all available provider scripts
	var all_action_scripts: Array[GDScript] = []
	var all_condition_scripts: Array[GDScript] = []
	var all_event_scripts: Array[GDScript] = []
	var all_behavior_scripts: Array[GDScript] = []
	var all_branch_scripts: Array[GDScript] = []

	_collect_scripts_recursive(ACTIONS_DIR, all_action_scripts)
	_collect_scripts_recursive(CONDITIONS_DIR, all_condition_scripts)
	_collect_scripts_recursive(EVENTS_DIR, all_event_scripts)
	_collect_scripts_recursive(BEHAVIORS_DIR, all_behavior_scripts)
	_collect_scripts_recursive(BRANCHES_DIR, all_branch_scripts)

	var total_available: int = all_action_scripts.size() + all_condition_scripts.size() + all_event_scripts.size() + all_behavior_scripts.size() + all_branch_scripts.size()

	# Step 3: Filter to only the providers that are actively used
	var action_scripts: Array[GDScript] = []
	var condition_scripts: Array[GDScript] = []
	var event_scripts: Array[GDScript] = []
	var behavior_scripts: Array[GDScript] = []
	var branch_scripts: Array[GDScript] = []

	var included_paths: Array[String] = []
	var excluded_paths: Array[String] = []

	_filter_scripts_by_usage(all_action_scripts, used_ids.action_ids, action_scripts, included_paths, excluded_paths)
	_filter_scripts_by_usage(all_condition_scripts, used_ids.condition_ids, condition_scripts, included_paths, excluded_paths)
	_filter_scripts_by_usage(all_event_scripts, used_ids.event_ids, event_scripts, included_paths, excluded_paths)
	_filter_scripts_by_usage(all_behavior_scripts, used_ids.behavior_ids, behavior_scripts, included_paths, excluded_paths)
	_filter_scripts_by_usage(all_branch_scripts, used_ids.branch_ids, branch_scripts, included_paths, excluded_paths)

	result.actions = action_scripts.size()
	result.conditions = condition_scripts.size()
	result.events = event_scripts.size()
	result.behaviors = behavior_scripts.size()
	result.branches = branch_scripts.size()
	result.total_available = total_available
	result.total_included = included_paths.size()
	result.total_excluded = excluded_paths.size()

	# Step 4: Create and save the manifest
	var manifest: Resource = load(PROVIDER_MANIFEST_SCRIPT).new()
	manifest.set("action_scripts", action_scripts)
	manifest.set("condition_scripts", condition_scripts)
	manifest.set("event_scripts", event_scripts)
	manifest.set("behavior_scripts", behavior_scripts)
	manifest.set("branch_scripts", branch_scripts)
	manifest.set("included_script_paths", included_paths)
	manifest.set("excluded_script_paths", excluded_paths)

	var error = ResourceSaver.save(manifest, MANIFEST_PATH)
	if error != OK:
		result.errors.append("Failed to save manifest: " + str(error))
		push_error("[FlowKit Generator] Failed to save manifest: " + str(error))
	else:
		print("[FlowKit Generator] Manifest saved to: ", MANIFEST_PATH)
		print("[FlowKit Generator] Included: %d / %d providers (excluded %d unused)" % [
			result.total_included, result.total_available, result.total_excluded
		])

	return result


## Scan all saved event sheets and scene files to collect the set of
## provider IDs that are actively used in the project.
func _scan_used_provider_ids() -> Dictionary:
	var used = {
		"action_ids": {},    # Dictionary used as a set: id -> true
		"condition_ids": {},
		"event_ids": {},
		"branch_ids": {},
		"behavior_ids": {},
	}

	# Scan event sheets
	var sheet_dir: DirAccess = DirAccess.open(EVENT_SHEET_DIR)
	if sheet_dir:
		sheet_dir.list_dir_begin()
		var file_name: String = sheet_dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var sheet_path: String = EVENT_SHEET_DIR + file_name
				var sheet: Resource = load(sheet_path)
				if sheet is FKEventSheet:
					_extract_ids_from_sheet(sheet, used)
			file_name = sheet_dir.get_next()
		sheet_dir.list_dir_end()

	# Scan scene files for behavior metadata
	_scan_scenes_for_behaviors(used)

	return used


## Extract all provider IDs from a single event sheet.
func _extract_ids_from_sheet(sheet: FKEventSheet, used: Dictionary) -> void:
	# Process top-level events
	for event_block in sheet.events:
		_extract_ids_from_event_block(event_block, used)

	# Process events inside groups (recursively)
	for group in sheet.groups:
		_extract_ids_from_group(group, used)


## Extract IDs from a group block (which can contain events, nested groups, etc.)
func _extract_ids_from_group(group: FKGroupBlock, used: Dictionary) -> void:
	for child in group.children:
		var child_type: String = child.get("type", "")
		var child_data = child.get("data", null)
		if not child_data:
			continue
		match child_type:
			"event":
				if child_data is FKEventBlock:
					_extract_ids_from_event_block(child_data, used)
			"group":
				if child_data is FKGroupBlock:
					_extract_ids_from_group(child_data, used)


## Extract IDs from a single event block and all its contents.
func _extract_ids_from_event_block(block: FKEventBlock, used: Dictionary) -> void:
	# Event provider
	if block.event_id and not block.event_id.is_empty():
		used.event_ids[block.event_id] = true

	# Conditions on the block
	for cond in block.conditions:
		_extract_ids_from_condition(cond, used)

	# Actions on the block
	for action in block.actions:
		_extract_ids_from_action(action, used)


## Extract IDs from a condition (which may itself contain standalone-condition actions).
func _extract_ids_from_condition(cond: FKEventCondition, used: Dictionary) -> void:
	if cond.condition_id and not cond.condition_id.is_empty():
		used.condition_ids[cond.condition_id] = true
	# Standalone conditions may have nested actions
	for action in cond.actions:
		_extract_ids_from_action(action, used)


## Extract IDs from an action (including branch sub-actions).
func _extract_ids_from_action(action: FKEventAction, used: Dictionary) -> void:
	if action.action_id and not action.action_id.is_empty():
		used.action_ids[action.action_id] = true

	# Branch handling
	if action.is_branch:
		var resolved_branch: String = action.branch_id
		if resolved_branch.is_empty() and action.branch_type in ["if", "elseif", "else"]:
			resolved_branch = "if_branch"
		if not resolved_branch.is_empty():
			used.branch_ids[resolved_branch] = true
		# Branch condition
		if action.branch_condition:
			_extract_ids_from_condition(action.branch_condition, used)
		# Nested branch actions
		for sub_action in action.branch_actions:
			_extract_ids_from_action(sub_action, used)


## Scan all .tscn files in the project for flowkit_behavior metadata.
func _scan_scenes_for_behaviors(used: Dictionary) -> void:
	_scan_directory_for_behaviors("res://", used)


## Recursively scan a directory for .tscn files containing behavior metadata.
func _scan_directory_for_behaviors(path: String, used: Dictionary) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.begins_with("."):
			file_name = dir.get_next()
			continue
		var file_path: String = path.path_join(file_name)
		if dir.current_is_dir():
			_scan_directory_for_behaviors(file_path, used)
		elif file_name.ends_with(".tscn"):
			_scan_tscn_for_behaviors(file_path, used)
		file_name = dir.get_next()
	dir.list_dir_end()


## Parse a single .tscn file for flowkit_behavior metadata entries.
func _scan_tscn_for_behaviors(tscn_path: String, used: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(tscn_path, FileAccess.READ)
	if not file:
		return

	while not file.eof_reached():
		var line: String = file.get_line()
		if "flowkit_behavior" in line:
			# Next line should contain the behavior id
			var next_line: String = file.get_line()
			var regex: RegEx = RegEx.new()
			regex.compile('"id"\\s*:\\s*"([^"]+)"')
			var match_result: RegExMatch = regex.search(next_line)
			if match_result:
				used.behavior_ids[match_result.get_string(1)] = true
			else:
				# id might be on the same line
				match_result = regex.search(line)
				if match_result:
					used.behavior_ids[match_result.get_string(1)] = true
	file.close()


## Filter an array of provider scripts, keeping only those whose get_id()
## matches one of the used IDs. Populates included/excluded path arrays.
## Base/utility scripts (those without get_id()) are always included if any
## of their subclass providers are kept, to avoid missing-superclass errors.
func _filter_scripts_by_usage(
	all_scripts: Array[GDScript],
	used_ids: Dictionary,
	out_scripts: Array[GDScript],
	included_paths: Array[String],
	excluded_paths: Array[String]
) -> void:
	# First pass: categorise scripts into providers (have get_id) and base classes (don't)
	var providers: Array[GDScript] = []
	var base_classes: Array[GDScript] = []  # Scripts without get_id — utility / base classes

	for script in all_scripts:
		var instance = script.new()
		if instance.has_method("get_id"):
			providers.append(script)
		else:
			base_classes.append(script)

	# Second pass: keep providers whose id is in the used set
	var kept_provider_paths: Dictionary = {}  # path -> true
	for script in providers:
		var instance = script.new()
		var script_id: String = instance.get_id()
		if used_ids.has(script_id):
			out_scripts.append(script)
			included_paths.append(script.resource_path)
			kept_provider_paths[script.resource_path] = true
		else:
			excluded_paths.append(script.resource_path)

	# Third pass: include base classes that are ancestors of any kept provider
	for base_script in base_classes:
		var base_path: String = base_script.resource_path
		var is_needed: bool = false
		# Check if any kept provider extends (directly or transitively) this base class
		for provider_script in out_scripts:
			if _script_extends(provider_script, base_script):
				is_needed = true
				break
		if is_needed:
			out_scripts.append(base_script)
			included_paths.append(base_path)
		else:
			excluded_paths.append(base_path)


## Check whether child_script inherits from ancestor_script (directly or transitively).
func _script_extends(child_script: GDScript, ancestor_script: GDScript) -> bool:
	var current: GDScript = child_script.get_base_script()
	while current:
		if current.resource_path == ancestor_script.resource_path:
			return true
		current = current.get_base_script()
	return false


## Recursively collect all GDScript files from a directory
func _collect_scripts_recursive(path: String, scripts: Array[GDScript]) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		var file_path: String = path + "/" + file_name

		if dir.current_is_dir():
			# Recursively scan subdirectories
			_collect_scripts_recursive(file_path, scripts)
		elif file_name.ends_with(".gd") and not file_name.ends_with(".uid"):
			# Load the script
			var script: Variant = load(file_path)
			if script:
				scripts.append(script)

		file_name = dir.get_next()

	dir.list_dir_end()
