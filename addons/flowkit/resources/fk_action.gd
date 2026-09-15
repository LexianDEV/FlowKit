extends FKProvider
class_name FKAction

func get_description() -> String:
	return "No description provided."

func get_inputs() -> Array[FKActionInput]:
	return []

## Whether or not this Action might need more than one frame to finish doing its thing.
func may_need_multi_frames() -> bool:
	return false

# If may_need_multi_frames is true, you'll want to make sure to emit this when 
# this FKAction is done doing its thing. The executor will then only move on
## to the next action when this is emitted.
signal exec_completed

func execute(node: Node, inputs: Dictionary, unit_id: int = -1) -> void:
	pass

func get_class() -> String:
	return "FKAction"
