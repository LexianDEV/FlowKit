extends Resource
class_name FKBehavior

## Base class for FlowKit behaviors
## Behaviors are pre-written scripts that can be attached to nodes to add functionality
## without requiring the user to write code.

func get_description() -> String:
	return ""

func get_id() -> String:
	return ""

func get_name() -> String:
	return ""

func get_inputs() -> Array[Dictionary]:
	## Returns an array of input definitions
	## Each dictionary should have:
	## - "name": String - the input parameter name
	## - "type": String - the type of the input (e.g., "String", "float", "int")
	## - "default": Variant - the default value for this input
	return []

func get_supported_types() -> Array[String]:
	## Returns an array of node class names this behavior supports
	## e.g., ["CharacterBody2D"] or ["Node2D", "Node3D"]
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
