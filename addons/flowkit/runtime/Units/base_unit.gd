@tool
extends Resource
class_name FKUnit

const INVALID_ID := 0

@export var block_type: String = ""   # "event", "comment", "group": 

## This is meant to be relative to the Event Sheet it belongs to, as opposed
## to being globally exclusive.
@export var uid: int = INVALID_ID:
	set(value):
		if uid == null: # This is expected after reading older FKUnits from disk
			uid = INVALID_ID

		if value < INVALID_ID:
			print("[FKUnit] I was passed a negative uid. It may be a sign of an "+\
			"issue elsewhere.")
			uid = INVALID_ID
			return

		uid = value
	get:
		return uid

func may_have_children():
	return false 

## Called after this FKUnit has been fully deserialized from disk 
## into an FKEventSheet instance.
## Makes it easier for this to do things like:
## - Normalize or upgrade legacy serialized data
## - Self-repair
## - Re‑establish metadata
func on_loaded_from_disk():
	_call_children_on_loaded_from_disk()
	
func _call_children_on_loaded_from_disk():
	var message: String = ""
	var children := get_children()
	for elem in children:
		# message = "Instance of %s is calling its %s child's on_loaded_from_disk" \
		# % [self.get_class(), elem.get_real_class()]
		# print(message)
		
		elem.on_loaded_from_disk()

## Accessor for this FKUnit's child units. Child classes (if they are intended to have child units)
## are expected to override this.
func get_children() -> Array[FKUnit]:
	return []

# Editor-friendly name for menus, debugging, etc.
func get_display_name() -> String:
	return block_type.capitalize()

# Subclasses override this to return a Dictionary representation.
func serialize() -> Dictionary:
	var result: Dictionary = {
		"type": block_type,
		"uid": uid
	}
	return result

## Subclasses override this to populate themselves from a Dictionary.
func deserialize(dict: Dictionary) -> void:
	uid = dict.get("uid", dict.get("personal_id", INVALID_ID))

# Deep-copy contract for undo/redo and clipboard.
func duplicate_block() -> FKUnit:
	print("Duplicating an fkunit")
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

## We need this so that even when cast to another type, we get the right
## get_class result.
func get_real_class() -> String:
	return self.get_class()

func _to_string() -> String:
	var self_serialized: Dictionary = self.serialize()
	var result = "(" + self.get_display_name() + ")" + "\n" + JSON.stringify(self_serialized, "\t")
	return result