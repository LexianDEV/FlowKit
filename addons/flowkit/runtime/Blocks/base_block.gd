extends Resource
class_name FKBaseBlock

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
func duplicate_block() -> FKBaseBlock:
	var copy := self.duplicate(true)
	return copy
