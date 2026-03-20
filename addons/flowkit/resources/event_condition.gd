extends Resource
class_name FKEventCondition

@export var condition_id: String
@export var target_node: NodePath
@export var inputs: Dictionary = {}
@export var negated: bool = false
@export var actions: Array[FKEventAction] = []

func serialize() -> Variant:
	var result = {
		"condition_id": self.condition_id,
		"target_node": str(self.target_node),
		"inputs": self.inputs.duplicate(),
		"negated": self.negated
	}
	
	return result
