@tool
extends FKUnit
class_name FKConditionUnit

@export var condition_id: String = ""
@export var target_node: NodePath
@export var inputs: Dictionary = {}
@export var negated: bool = false
@export var actions: Array[FKActionUnit] = [] 

func _init() -> void:
	block_type = "condition"

func serialize() -> Dictionary:
	return {
		"type": block_type,
		"condition_id": condition_id,
		"target_node": str(target_node),
		"inputs": inputs.duplicate(),
		"negated": negated,
	}

func deserialize(dict: Dictionary) -> void:
	condition_id = dict.get("condition_id", "")
	target_node = NodePath(dict.get("target_node", ""))
	inputs = dict.get("inputs", {}).duplicate()
	negated = dict.get("negated", false)

func duplicate_block() -> FKUnit:
	#print("[FKConditionUnit]: Duplicating!")
	var result: FKConditionUnit = FKConditionUnit.new()
	result.condition_id = condition_id
	result.target_node = str(target_node)
	result.inputs = inputs.duplicate()
	result.negated = negated
	
	return result
	
func get_id() -> String:
	return condition_id

func get_class() -> String:
	return "FKConditionUnit"
