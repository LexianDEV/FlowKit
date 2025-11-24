@tool
extends RefCounted
class_name FKGenerator

const ACTIONS_DIR = "res://addons/flowkit/actions/"
const CONDITIONS_DIR = "res://addons/flowkit/conditions/"
const EVENTS_DIR = "res://addons/flowkit/events/"

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
	
	# Generate actions for void methods with parameters
	for method in method_list:
		if _is_valid_method_for_action(method):
			_create_method_action(node_type, method)
			count += 1
	
	return count

func _generate_conditions_for_node(node_type: String, node_instance: Node) -> int:
	var count = 0
	var property_list = node_instance.get_property_list()
	
	# Generate comparison conditions for readable properties
	for prop in property_list:
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE or prop.usage & PROPERTY_USAGE_EDITOR:
			if _is_valid_property_for_condition(prop):
				_create_property_comparison_condition(node_type, prop)
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
	
	# Skip methods with too many parameters (keep it simple)
	if method.args.size() > 4:
		return false
	
	# Only include methods from user classes or common useful ones
	if method.flags & METHOD_FLAG_VIRTUAL:
		return false
	
	return true

func _create_setter_action(node_type: String, prop: Dictionary) -> void:
	var prop_name = prop.name
	var action_id = "set_" + prop_name.replace("/", "_").replace(" ", "_").to_lower()
	var action_name = "Set " + _humanize_name(prop_name)
	
	var dir_path = ACTIONS_DIR + node_type
	_ensure_directory_exists(dir_path)
	
	var file_path = dir_path + "/gen_" + action_id + ".gd"
	
	# Skip if file already exists
	if FileAccess.file_exists(file_path):
		return
	
	var type_name = _get_type_name(prop.type)
	var code = """extends FKAction

func get_id() -> String:
	return "%s"

func get_name() -> String:
	return "%s"

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Value", "type": "%s"}
	]

func get_supported_types() -> Array[String]:
	return ["%s"]

func execute(node: Node, inputs: Dictionary) -> void:
	if not node is %s:
		return
	
	var value = inputs.get("Value", %s)
	node.%s = value
""" % [
		action_id,
		action_name,
		type_name,
		node_type,
		node_type,
		_get_default_value(prop.type),
		prop_name
	]
	
	_write_file(file_path, code)

func _create_method_action(node_type: String, method: Dictionary) -> void:
	var method_name = method.name
	var action_id = method_name.to_lower()
	var action_name = _humanize_name(method_name)
	
	var dir_path = ACTIONS_DIR + node_type
	_ensure_directory_exists(dir_path)
	
	var file_path = dir_path + "/gen_" + action_id + ".gd"
	
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
	
	var code = """extends FKAction

func get_id() -> String:
	return "%s"

func get_name() -> String:
	return "%s"

func get_inputs() -> Array[Dictionary]:
	return %s

func get_supported_types() -> Array[String]:
	return ["%s"]

func execute(node: Node, inputs: Dictionary) -> void:
	if not node is %s:
		return
	
	%s
""" % [
		action_id,
		action_name,
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
	var condition_id = "compare_" + prop_name.replace("/", "_").replace(" ", "_").to_lower()
	var condition_name = "Compare " + _humanize_name(prop_name)
	
	var dir_path = CONDITIONS_DIR + node_type
	_ensure_directory_exists(dir_path)
	
	var file_path = dir_path + "/gen_" + condition_id + ".gd"
	
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
	
	var code = """extends FKCondition

func get_id() -> String:
	return "%s"

func get_name() -> String:
	return "%s"

func get_inputs() -> Array[Dictionary]:
	return %s

func get_supported_types() -> Array[String]:
	return ["%s"]

func check(node: Node, inputs: Dictionary) -> bool:
	if not node is %s:
		return false
	
%s
""" % [
		condition_id,
		condition_name,
		inputs_array,
		node_type,
		node_type,
		comparison_logic
	]
	
	_write_file(file_path, code)

# ============================================================================
# EVENT GENERATORS
# ============================================================================

func _create_signal_event(node_type: String, sig: Dictionary) -> void:
	var signal_name = sig.name
	var event_id = "on_" + signal_name.to_lower()
	var event_name = "On " + _humanize_name(signal_name)
	
	var dir_path = EVENTS_DIR + node_type
	_ensure_directory_exists(dir_path)
	
	var file_path = dir_path + "/gen_" + event_id + ".gd"
	
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
	
	# Build signal handler parameters
	var handler_params = []
	for i in range(sig.args.size()):
		var arg = sig.args[i]
		var arg_name = arg.name if arg.name != "" else "arg" + str(i)
		handler_params.append(arg_name)
	
	if handler_params.size() > 0:
		handler_params.append("bound_node")
	else:
		handler_params.append("bound_node")
	
	var handler_params_str = ", ".join(handler_params)
	
	var code = """extends FKEvent

func get_id() -> String:
	return "%s"

func get_name() -> String:
	return "%s"

func get_supported_types() -> Array[String]:
	return ["%s"]

func get_inputs() -> Array:
	return %s

# Signal-based events require connection management
var _connected_nodes: Dictionary = {}

func poll(node: Node, inputs: Dictionary = {}) -> bool:
	if not node:
		return false
	
	# Ensure node is connected
	if not _connected_nodes.has(node):
		if node.has_signal("%s"):
			node.%s.connect(_on_signal_fired.bind(node))
			_connected_nodes[node] = {"fired": false, "args": {}}
		else:
			return false
	
	# Check if signal fired this frame
	var data = _connected_nodes[node]
	if data.fired:
		data.fired = false
		return true
	
	return false

func _on_signal_fired(%s) -> void:
	if _connected_nodes.has(bound_node):
		_connected_nodes[bound_node].fired = true
""" % [
		event_id,
		event_name,
		node_type,
		inputs_str,
		signal_name,
		signal_name,
		handler_params_str
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

func _write_file(path: String, content: String) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		print("[FlowKit Generator] Created: ", path)
	else:
		push_error("[FlowKit Generator] Failed to write: " + path)
