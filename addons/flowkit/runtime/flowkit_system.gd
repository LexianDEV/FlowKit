extends Node
class_name FKSystem

## The System object - a global singleton accessible in every scene
## Similar to Clickteam Fusion's System object

# Signals that can be used with events
signal on_ready_triggered
signal on_process_triggered

var _ready_fired: bool = false

# Delta value (updated each frame by FlowKitEngine)
var delta: float = 0.0

# Global variable storage
var variables: Dictionary = {}

# Node variable storage (per-node variables using metadata)
var node_variables: Dictionary = {}

var global_signals: FKGlobalSignals = FKGlobalSignals.new()

func _ready() -> void:
	if not _ready_fired:
		_ready_fired = true
		on_ready_triggered.emit()

func _process(_delta: float) -> void:
	on_process_triggered.emit()

# Global print function
func print_message(message: String) -> void:
	print("[System]: %s" % message)

# Variable management
func set_var(name: String, value: Variant) -> void:
	variables[name] = value

func get_var(name: String, default: Variant = null) -> Variant:
	return variables.get(name, default)

func has_var(name: String) -> bool:
	return variables.has(name)

func clear_var(name: String) -> void:
	variables.erase(name)

func clear_all_vars() -> void:
	variables.clear()

# Node variable management
func set_node_var(node: Node, var_name: String, value: Variant) -> void:
	if not node:
		push_error("Cannot set node variable: node is null")
		return
	
	var node_path: String = str(node.get_path())
	
	if not node_variables.has(node_path):
		node_variables[node_path] = {}
	
	node_variables[node_path][var_name] = value
	
	# Also store in node metadata for persistence
	if node.has_meta("flowkit_variables"):
		var meta_vars: Dictionary = node.get_meta("flowkit_variables")
		meta_vars[var_name] = value
		node.set_meta("flowkit_variables", meta_vars)
	else:
		node.set_meta("flowkit_variables", {var_name: value})

func get_node_var(node: Node, var_name: String, default: Variant = null) -> Variant:
	if not node:
		push_error("Cannot get node variable: node is null")
		return default
	
	var node_path: String = str(node.get_path())
	
	# Check memory first
	if node_variables.has(node_path) and node_variables[node_path].has(var_name):
		return node_variables[node_path][var_name]
	
	# Check node metadata
	if node.has_meta("flowkit_variables"):
		var meta_vars: Dictionary = node.get_meta("flowkit_variables")
		if meta_vars.has(var_name):
			var value = meta_vars[var_name]
			
			# Apply type conversion if type metadata exists
			if node.has_meta("flowkit_variable_types"):
				var var_types: Dictionary = node.get_meta("flowkit_variable_types")
				if var_types.has(var_name):
					value = _convert_to_type(value, var_types[var_name])
			
			# Sync to memory
			if not node_variables.has(node_path):
				node_variables[node_path] = {}
			node_variables[node_path][var_name] = value
			return value
	
	return default

func has_node_var(node: Node, var_name: String) -> bool:
	if not node:
		return false
	
	var node_path: String = str(node.get_path())
	
	# Check memory
	if node_variables.has(node_path) and node_variables[node_path].has(var_name):
		return true
	
	# Check metadata
	if node.has_meta("flowkit_variables"):
		var meta_vars: Dictionary = node.get_meta("flowkit_variables")
		return meta_vars.has(var_name)
	
	return false

func clear_node_var(node: Node, var_name: String) -> void:
	if not node:
		return
	
	var node_path: String = str(node.get_path())
	
	# Clear from memory
	if node_variables.has(node_path):
		node_variables[node_path].erase(var_name)
	
	# Clear from metadata
	if node.has_meta("flowkit_variables"):
		var meta_vars: Dictionary = node.get_meta("flowkit_variables")
		meta_vars.erase(var_name)
		node.set_meta("flowkit_variables", meta_vars)

func clear_all_node_vars(node: Node) -> void:
	if not node:
		return
	
	var node_path: String = str(node.get_path())
	
	# Clear from memory
	node_variables.erase(node_path)
	
	# Clear from metadata
	if node.has_meta("flowkit_variables"):
		node.remove_meta("flowkit_variables")

func get_node_variable_names(node: Node) -> Array:
	if not node:
		return []
	
	var node_path: String = str(node.get_path())
	var var_names: Array = []
	
	# Get from memory
	if node_variables.has(node_path):
		for var_name in node_variables[node_path].keys():
			if not var_names.has(var_name):
				var_names.append(var_name)
	
	# Get from metadata
	if node.has_meta("flowkit_variables"):
		var meta_vars: Dictionary = node.get_meta("flowkit_variables")
		for var_name in meta_vars.keys():
			if not var_names.has(var_name):
				var_names.append(var_name)
	
	return var_names

# Sync all node variables from metadata (call this at scene load)
func sync_scene_node_variables(scene_root: Node) -> void:
	if not scene_root:
		return
	
	_sync_node_recursive(scene_root)

func _sync_node_recursive(node: Node) -> void:
	# Sync this node's metadata variables to memory
	if node.has_meta("flowkit_variables"):
		var meta_vars: Dictionary = node.get_meta("flowkit_variables")
		if not meta_vars.is_empty():
			var node_path: String = str(node.get_path())
			if not node_variables.has(node_path):
				node_variables[node_path] = {}
			
			# Get type metadata if available
			var var_types: Dictionary = {}
			if node.has_meta("flowkit_variable_types"):
				var_types = node.get_meta("flowkit_variable_types", {})
			
			for var_name in meta_vars.keys():
				var value = meta_vars[var_name]
				
				# Apply type conversion if type metadata exists
				if var_types.has(var_name):
					value = _convert_to_type(value, var_types[var_name])
				
				node_variables[node_path][var_name] = value
			
			print("[FlowKitSystem] Synced %d variables for node: %s" % [meta_vars.size(), node.name])
	
	# Recursively sync children
	for child in node.get_children():
		_sync_node_recursive(child)

# ProjectSettings helpers
func get_project_setting(path: String, default: Variant = null) -> Variant:
	if ProjectSettings.has_setting(path):
		return ProjectSettings.get_setting(path)
	return default

func set_project_setting(path: String, value: Variant) -> void:
	ProjectSettings.set_setting(path, value)

func has_project_setting(path: String) -> bool:
	return ProjectSettings.has_setting(path)

## Convert a value to the specified type
func _convert_to_type(value: Variant, target_type: String) -> Variant:
	match target_type:
		"int":
			if value is int:
				return value
			if value is float:
				return int(value)
			if value is String:
				return int(value) if value.is_valid_int() else 0
			if value is bool:
				return 1 if value else 0
			return 0
		"float":
			if value is float:
				return value
			if value is int:
				return float(value)
			if value is String:
				return float(value) if value.is_valid_float() else 0.0
			if value is bool:
				return 1.0 if value else 0.0
			return 0.0
		"bool":
			if value is bool:
				return value
			if value is int:
				return value != 0
			if value is float:
				return value != 0.0
			if value is String:
				return value.to_lower() == "true"
			return false
		_:  # String or unknown type
			return str(value)
