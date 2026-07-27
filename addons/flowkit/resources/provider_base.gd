extends Resource
class_name FKProviderBase

const KIND_CONDITION := "condition"
const KIND_ACTION := "action"
const KIND_EVENT := "event"
const KIND_BRANCH := "branch"
const KIND_BEHAVIOR := "behavior"

const VALID_KINDS := [
	KIND_CONDITION,
	KIND_ACTION,
	KIND_EVENT,
	KIND_BRANCH,
	KIND_BEHAVIOR,
]

## So that the system knows whether this Provider is meant to be 
## instantiated or used as a base. We need this because 
## (at the time of this writing) GDScript doesn't have anything
## like C#'s "abstract" keyword.
func is_abstract_provider() -> bool:
	return false

## Used to identify a provider in the registry. Should be globally unique across 
## all providers of the same kind.
func get_provider_id() -> String:
	# Backward-compatible bridge: existing providers override get_id()
	return get_id()

func get_provider_kind() -> String:
	return ""

## [Deprecated] Best use get_provider_id() and get_provider_kind() instead. 
func get_id() -> String:
	return ""

## [Deprecated] Best use get_display_name instead.
func get_name() -> String:
	return "Invalid" 

func get_display_name() -> String:
	return "Invalid" # So we can tell right away if a provider is missing a name in the registry.

func get_description() -> String:
	return "No description provided."

## Keep untyped during migration because existing providers return mixed types
## (Array[Dictionary] and Array[FKActionInput]).
func get_inputs() -> Array:
	return []

## Returns an array of node class names this provider supports
## e.g., ["CharacterBody2D"] or ["Node2D", "Node3D"]
func get_supported_types() -> Array[String]:
	return []

func get_canonical_id() -> String:
	var kind := get_provider_kind().strip_edges()
	var pid := get_provider_id().strip_edges()
	if kind.is_empty() or pid.is_empty():
		return ""
	return "%s:%s" % [kind, pid]

func supports_node(node: Node) -> bool:
	if not node:
		return false
	return supports_node_class(node.get_class())

func supports_node_class(node_class: String) -> bool:
	if node_class.is_empty():
		return false

	var supported := get_supported_types()
	if supported.is_empty():
		return false

	if "Node" in supported:
		return true

	if node_class in supported:
		return true

	for supported_type in supported:
		if ClassDB.class_exists(supported_type) and ClassDB.is_parent_class(node_class, supported_type):
			return true

	return false

## Normalized input metadata view for validation/UI.
## Supports both Dictionary-style and FKActionInput-style definitions.
func get_input_definitions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in get_inputs():
		if item is Dictionary:
			result.append(item)
		elif item is FKActionInput:
			result.append({
				"name": item.name,
				"type": item.type,
				"description": item.description,
				"default": item.default_value,
			})
	return result

func validate_definition() -> Array[String]:
	var errors: Array[String] = []

	var pid := get_provider_id().strip_edges()
	var kind := get_provider_kind().strip_edges()

	if pid.is_empty():
		errors.append("Provider id is empty.")

	if kind.is_empty():
		errors.append("Provider kind is empty.")
	elif not VALID_KINDS.has(kind):
		errors.append("Provider kind '%s' is invalid." % kind)

	var inputs := get_input_definitions()
	for i in range(inputs.size()):
		var input_def = inputs[i]
		var has_name := input_def.has("name") and input_def["name"] is String and not String(input_def["name"]).is_empty()
		var has_type := input_def.has("type") and input_def["type"] is String and not String(input_def["type"]).is_empty()
		if not has_name:
			errors.append("Input #%d is missing a valid 'name'." % i)
		if not has_type:
			errors.append("Input #%d is missing a valid 'type'." % i)

	for t in get_supported_types():
		if not (t is String):
			errors.append("supported_types must contain only String values.")
			break

	return errors

func get_real_class() -> String:
	return self.get_class()