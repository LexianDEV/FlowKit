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

func may_have_children():
	return true 
	
func get_children() -> Array[FKUnit]:
	var defensive_copy: Array[FKUnit] = [] as Array[FKUnit]
	defensive_copy.append_array(actions)
	return defensive_copy
	
func serialize() -> Dictionary:
	var result := super.serialize()
	var our_added_fields := {
		"condition_id": condition_id,
		"target_node": str(target_node),
		"inputs": inputs.duplicate(),
		"negated": negated,
	}
	result.merge(our_added_fields)
	
	return result

func deserialize(dict: Dictionary) -> void:
	super.deserialize(dict)
	condition_id = dict.get("condition_id", "")
	target_node = NodePath(dict.get("target_node", ""))
	inputs = dict.get("inputs", {}).duplicate()
	negated = dict.get("negated", false)

func duplicate_block() -> FKUnit:
	var result := self.duplicate(true)
	return result
	
func get_id() -> String:
	return condition_id

func get_class() -> String:
	return "FKConditionUnit"
