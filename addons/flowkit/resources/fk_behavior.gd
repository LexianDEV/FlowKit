extends FKProviderBase

## Base class for FlowKit behaviors
## Behaviors are pre-written scripts that can be attached to nodes to add functionality
## without requiring the user to write code.
class_name FKBehavior

func get_provider_kind() -> String:
	return KIND_BEHAVIOR

## Returns an array of input definitions
## Each dictionary should have:
## - "name": String - the input parameter name
## - "type": String - the type of the input (e.g., "String", "float", "int")
## - "default": Variant - the default value for this input
func get_inputs() -> Array[Dictionary]:
	return []

func apply(node: Node, inputs: Dictionary) -> void:
	## Called to apply/activate this behavior on a node
	## This is where the behavior logic should be implemented
	pass

func remove(node: Node) -> void:
	## Called to remove/deactivate this behavior from a node
	pass

func process(node: Node, delta: float, inputs: Dictionary) -> void:
	## Called every frame while the behavior is active on a node
	## Override this for behaviors that need per-frame updates
	pass

func physics_process(node: Node, delta: float, inputs: Dictionary) -> void:
	## Called every physics frame while the behavior is active on a node
	## Override this for behaviors that need physics-based updates
	pass

func get_class() -> String:
	return "FKBehavior"
