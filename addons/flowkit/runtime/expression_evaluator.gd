extends RefCounted
class_name FKExpressionEvaluator

## FlowKit Expression Evaluator - Clickteam Fusion style
## Literal values are parsed as their native types:
##   "Hello" → String
##   1 → Int
##   1.0 → Float
##   true/false → Boolean
##   null → Null
##   Vector2(0,0) → Vector2
## 
## Expressions are evaluated as GDScript:
##   node.velocity.x + 10
##   velocity.x > 0
##   position * 2

## Evaluate a string expression and returns the result
## Tries to parse as literal first, then as GDScript expression
## Evaluation is syntax-driven: the expression is parsed/evaluated based on its syntax alone.
## After evaluation, the result type is validated against expected_type (if provided).
## context_node: the base instance for expression execution (determines where get_node() resolves from)
## scene_root: optional scene root node, exposed as 'scene_root' variable in expressions
## target_node: optional action target node, used for n_ variable lookups (falls back to context_node)
## expected_type: optional Variant.Type to validate the result against (-1 = no validation)
static func evaluate(expr_str: String, context_node: Node = null, scene_root: Node = null, \
target_node: Node = null, expected_type: int = -1) -> Variant:
	if expr_str.is_empty():
		return _check_type("", expected_type, expr_str)
	
	# Trim whitespace
	expr_str = expr_str.strip_edges()
	
	# For n_ variable lookups, use target_node if provided; otherwise context_node
	var n_var_node: Node = target_node if target_node else context_node
	
	# Check if this is a standalone node variable reference (n_variable_name)
	if expr_str.begins_with("n_") and n_var_node:
		var var_name = expr_str.substr(2)
		# Only treat as standalone n_ variable if it's a simple identifier (no operators/spaces)
		if var_name.is_valid_identifier():
			var result := _resolve_n_variable(n_var_node, var_name)
			if result.success:
				return _check_type(result.value, expected_type, expr_str)
			# Variable not found - still try as expression below
	
	# Try to parse as a literal value first
	var literal_result := _try_parse_literal(expr_str)
	if literal_result.success:
		return _check_type(literal_result.value, expected_type, expr_str)
	
	# If not a literal, try to evaluate as a GDScript expression
	var expr_result := _evaluate_expression(expr_str, context_node, scene_root, target_node)
	if expr_result.success:
		return _check_type(expr_result.value, expected_type, expr_str)
	
	# Evaluation failed - do not fall back to raw string
	push_error("FlowKit: Failed to evaluate expression: '%s'" % expr_str)
	return null


## Resolve an n_ variable from a node. Checks FlowKitSystem node variables first,
## then node metadata (inspector-defined), then script properties.
## Returns an FKEvalResult to distinguish 'not found' from 'found with value null'.
static func _resolve_n_variable(node: Node, var_name: String) -> FKEvalResult:
	var system = node.get_tree().root.get_node_or_null("/root/FlowKitSystem")
	if system and system.has_method("get_node_var"):
		# Check if the variable exists before getting it
		if system.has_method("has_node_var") and system.has_node_var(node, var_name):
			return FKEvalResult.succeeded(system.get_node_var(node, var_name, null))
	
	# Fallback: check node metadata directly (inspector-defined FlowKit variables)
	if node.has_meta("flowkit_variables"):
		var meta_vars = node.get_meta("flowkit_variables")
		if meta_vars is Dictionary and meta_vars.has(var_name):
			var value = meta_vars[var_name]
			# Apply type conversion if type metadata exists
			if node.has_meta("flowkit_variable_types"):
				var meta_types = node.get_meta("flowkit_variable_types")
				if meta_types is Dictionary and meta_types.has(var_name):
					var var_type: String = meta_types[var_name]
					match var_type:
						"int":
							if value is String:
								value = int(value) if value.is_valid_int() else 0
						"float":
							if value is String:
								value = float(value) if value.is_valid_float() else 0.0
						"bool":
							if value is String:
								value = value.to_lower() == "true"
			return FKEvalResult.succeeded(value)
	
	# Fallback: check if the node itself has this property (script-exported variables)
	if var_name in node:
		return FKEvalResult.succeeded(node.get(var_name))
	
	return FKEvalResult.failed()


## Try to parse the string as a literal value (not an expression)
## Returns an FKEvalResult to distinguish 'not a literal' from a literal null
static func _try_parse_literal(expr: String) -> FKEvalResult:
	# Boolean literals
	if expr.to_lower() == "true":
		return FKEvalResult.succeeded(true)
	if expr.to_lower() == "false":
		return FKEvalResult.succeeded(false)
	
	# Null literal
	if expr.to_lower() == "null":
		return FKEvalResult.succeeded(null)
	
	# String literals (quoted)
	if _is_quoted_string(expr):
		return FKEvalResult.succeeded(_parse_quoted_string(expr))
	
	# Numeric literals
	if _is_numeric(expr):
		if "." in expr or "e" in expr.to_lower():
			return FKEvalResult.succeeded(float(expr))
		else:
			return FKEvalResult.succeeded(int(expr))
	
	# Vector/Color literals (e.g., "Vector2(0,0)", "Color(1,0,0,1)")
	if _is_constructor_literal(expr):
		var result := _evaluate_expression(expr, null)
		if result.success:
			return result
		return FKEvalResult.failed()
	
	# Not a literal
	return FKEvalResult.failed()


## Check if string is a quoted string literal
static func _is_quoted_string(expr: String) -> bool:
	if expr.length() < 2:
		return false
	
	var first_char = expr[0]
	if first_char != '"' and first_char != "'":
		return false
	
	# Find the closing quote (accounting for escapes)
	var i = 1
	while i < expr.length():
		if expr[i] == first_char and (i == 0 or expr[i-1] != "\\"):
			# Found closing quote - must be at end of string
			return i == expr.length() - 1
		i += 1
	
	return false


## Parse a quoted string, removing quotes and handling escape sequences
static func _parse_quoted_string(expr: String) -> String:
	var quote_char = expr[0]
	var content = expr.substr(1, expr.length() - 2)
	
	# Handle escape sequences
	content = content.replace("\\n", "\n")
	content = content.replace("\\t", "\t")
	content = content.replace("\\r", "\r")
	content = content.replace("\\" + quote_char, quote_char)
	content = content.replace("\\\\", "\\")
	
	return content


## Check if string is a numeric literal (int or float)
static func _is_numeric(expr: String) -> bool:
	if expr.is_empty():
		return false
	
	var check_str = expr
	if check_str[0] == "-" or check_str[0] == "+":
		check_str = check_str.substr(1)
	
	if check_str.is_empty():
		return false
	
	var has_dot = false
	var has_e = false
	
	for i in range(check_str.length()):
		var c = check_str[i]
		
		if c == ".":
			if has_dot or has_e:
				return false
			has_dot = true
		elif c.to_lower() == "e":
			if has_e or i == 0 or i == check_str.length() - 1:
				return false
			has_e = true
		elif c == "-" or c == "+":
			if i == 0 or check_str[i-1].to_lower() != "e":
				return false
		elif not c.is_valid_int():
			return false
	
	return true


## Check if string is a constructor literal like "Vector2(0,0)" or "Color(1,0,0)"
static func _is_constructor_literal(expr: String) -> bool:
	var constructors = ["Vector2", "Vector3", "Vector4", "Color", "Rect2", 
	"Transform2D", "Plane", "Quaternion", "AABB", "Basis", "Transform3D"]
	
	for constructor in constructors:
		if expr.begins_with(constructor + "(") and expr.ends_with(")"):
			return true
	
	return false


## Evaluate a GDScript expression using Godot's Expression class
## context_node: used as the base instance for Expression.execute() (where get_node() resolves from)
## scene_root: optional scene root node, exposed as 'scene_root' in expressions
## target_node: optional action target node, exposed as 'node' in expressions (falls back to context_node)
static func _evaluate_expression(expr_str: String, context_node: Node, scene_root: Node = null, \
target_node: Node = null) -> FKEvalResult:
	var expression = Expression.new()
	
	# Build input variables for the expression
	var input_names: Array = []
	var input_values: Array = []
	
	# 'node' variable always points to the action's target node for property access
	var node_var: Node = target_node if target_node else context_node
	if node_var:
		input_names.append("node")
		input_values.append(node_var)
	
	# Provide 'scene_root' for scene-root-relative node lookups
	if scene_root:
		input_names.append("scene_root")
		input_values.append(scene_root)
	
	# Expose ProjectSettings so expressions can read project settings
	input_names.append("ProjectSettings")
	input_values.append(ProjectSettings)
	
	# Try to get FlowKitSystem for accessing global variables
	if context_node:
		var system = context_node.get_tree().root.get_node_or_null("/root/FlowKitSystem")
		if system:
			input_names.append("system")
			input_values.append(system)
			
			# Expose delta from the system (set each frame by the engine)
			input_names.append("delta")
			input_values.append(system.delta)
			
			# Inject n_ (node alterable) variables from the target node
			var n_node: Node = target_node if target_node else context_node
			if n_node:
				# First inject from FlowKitSystem node variables
				if system.has_method("get_node_variable_names"):
					var var_names: Array = system.get_node_variable_names(n_node)
					for vname in var_names:
						var input_key = "n_" + vname
						if not input_names.has(input_key):
							input_names.append(input_key)
							input_values.append(system.get_node_var(n_node, vname, 0))
				
				# Also inject from the node's own script properties (exported @export vars)
				for prop in n_node.get_property_list():
					var pname: String = prop.get("name", "")
					if pname.is_empty():
						continue
					var input_key = "n_" + pname
					if not input_names.has(input_key):
						# Only expose user-defined properties (PROPERTY_USAGE_SCRIPT_VARIABLE)
						var usage: int = prop.get("usage", 0)
						if usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
							input_names.append(input_key)
							input_values.append(n_node.get(pname))
		
		# Also inject from node metadata directly (works even without FlowKitSystem)
		var n_node: Node = target_node if target_node else context_node
		if n_node and n_node.has_meta("flowkit_variables"):
			var meta_vars = n_node.get_meta("flowkit_variables")
			if meta_vars is Dictionary:
				var meta_types: Dictionary = {}
				if n_node.has_meta("flowkit_variable_types"):
					var types_raw = n_node.get_meta("flowkit_variable_types")
					if types_raw is Dictionary:
						meta_types = types_raw
				
				for vname in meta_vars.keys():
					var input_key = "n_" + vname
					if not input_names.has(input_key):
						var value = meta_vars[vname]
						# Apply type conversion
						if meta_types.has(vname):
							var var_type: String = meta_types[vname]
							match var_type:
								"int":
									if value is String:
										value = int(value) if value.is_valid_int() else 0
								"float":
									if value is String:
										value = float(value) if value.is_valid_float() else 0.0
								"bool":
									if value is String:
										value = value.to_lower() == "true"
						input_names.append(input_key)
						input_values.append(value)
			
			# Also expose all system variables directly
			if "variables" in system and system.variables is Dictionary:
				for var_name in system.variables.keys():
					input_names.append(var_name)
					input_values.append(system.variables[var_name])
	
	# Parse the expression
	var parse_error = expression.parse(expr_str, input_names)
	if parse_error != OK:
		# Silently fail - not an expression
		return FKEvalResult.failed()
	
	# Execute it
	var result = expression.execute(input_values, context_node, false)
	
	if expression.has_execute_failed():
		# Silently fail - expression execution failed
		return FKEvalResult.failed()
	
	return FKEvalResult.succeeded(result)


## Convenience method to evaluate all inputs in a dictionary
## Returns a new dictionary with evaluated values
## context_node: the base instance for expression execution
## scene_root: optional scene root node, forwarded to evaluate()
## target_node: optional action target node for n_ variable lookups
## type_hints: optional dictionary mapping input names to Variant.Type int values for post-evaluation validation
static func evaluate_inputs(inputs: Dictionary, context_node: Node = null, \
scene_root: Node = null, target_node: Node = null, type_hints: Dictionary = {}) -> Dictionary:
	var evaluated: Dictionary = {}
	
	for key in inputs.keys():
		var value = inputs[key]
		
		# Only evaluate if the value is a string
		if value is String:
			var expected_type: int = type_hints.get(key, -1)
			evaluated[key] = evaluate(value, context_node, scene_root, target_node, expected_type)
		else:
			evaluated[key] = value
	
	return evaluated


## Validate that a result matches the expected Variant.Type
## Returns the value as-is but pushes an error if type does not match
static func _check_type(value: Variant, expected_type: int, expr_str: String) -> Variant:
	if expected_type < 0:
		return value
	if typeof(value) != expected_type:
		push_error("FlowKit: Expression '%s' evaluated to %s (type %s) but expected type %s" % [
			expr_str, str(value), type_string(typeof(value)), type_string(expected_type)])
	return value


## Convert a type name string (as used in provider get_inputs()) to a Variant.Type int
## Returns -1 for unknown or "Variant" types (no validation)
static func type_name_to_variant_type(type_name: String) -> int:
	match type_name:
		"bool":
			return TYPE_BOOL
		"int":
			return TYPE_INT
		"float":
			return TYPE_FLOAT
		"String":
			return TYPE_STRING
		"Vector2":
			return TYPE_VECTOR2
		"Vector2i":
			return TYPE_VECTOR2I
		"Vector3":
			return TYPE_VECTOR3
		"Vector3i":
			return TYPE_VECTOR3I
		"Vector4":
			return TYPE_VECTOR4
		"Vector4i":
			return TYPE_VECTOR4I
		"Color":
			return TYPE_COLOR
		"Rect2":
			return TYPE_RECT2
		"Transform2D":
			return TYPE_TRANSFORM2D
		"Plane":
			return TYPE_PLANE
		"Quaternion":
			return TYPE_QUATERNION
		"AABB":
			return TYPE_AABB
		"Basis":
			return TYPE_BASIS
		"Transform3D":
			return TYPE_TRANSFORM3D
		"NodePath":
			return TYPE_NODE_PATH
		"Array":
			return TYPE_ARRAY
		"Dictionary":
			return TYPE_DICTIONARY
		"Variant", "":
			return -1
	return -1
