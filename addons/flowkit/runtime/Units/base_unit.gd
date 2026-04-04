@tool
extends Resource
class_name FKUnit

@export var block_type: String = ""   # "event", "comment", "group"

# Optional: editor-friendly name for menus, debugging, etc.
func get_display_name() -> String:
	return block_type.capitalize()

# Subclasses override this to return a Dictionary representation.
func serialize() -> Dictionary:
	push_error("serialize() not implemented for %s" % block_type)
	return {}

## Subclasses override this to populate themselves from a Dictionary.
##
##
func deserialize(dict: Dictionary) -> void:
	push_error("deserialize() not implemented for %s" % block_type)

# Deep-copy contract for undo/redo and clipboard.
func duplicate_block() -> FKUnit:
	var copy := self.duplicate(true)
	return copy
	
func get_id() -> String:
	return ""

static func _duplicate_blocks(to_duplicate: Array[FKUnit]) -> Array[FKUnit]:
	var result: Array[FKUnit] = []
	for elem in to_duplicate:
		if elem:
			var elem_copy := elem.duplicate_block()
			result.append(elem)
	return result

static func _to_base_unit_arr(arr: Array) -> Array[FKUnit]:
	var result: Array[FKUnit] = []
	
	for child in arr:
		if child is FKUnit:
			result.append(child)
			
	return result

func get_class() -> String:
	return "FKUnit"
