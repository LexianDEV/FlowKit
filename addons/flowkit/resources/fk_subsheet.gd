extends Resource
class_name FKSubsheet
## A local, reusable subsheet within an event sheet.
##
## Subsheets are like local functions - they contain a sequence of actions
## that can be called multiple times from different events in the same sheet.
## They are not global assets and exist only within their parent event sheet.

@export var subsheet_id: String = ""  # Unique identifier for this subsheet
@export var name: String = "Subsheet"  # Display name
@export var actions: Array[FKEventAction] = []  # Actions to execute when called


func _init(p_subsheet_id: String = "", p_name: String = "Subsheet") -> void:
	if p_subsheet_id.is_empty():
		subsheet_id = _generate_unique_id()
	else:
		subsheet_id = p_subsheet_id
	name = p_name


func _generate_unique_id() -> String:
	"""Generate a unique ID for this subsheet using timestamp and random component."""
	var timestamp = Time.get_unix_time_from_system()
	return "subsheet_%d_%d" % [int(timestamp), randi()]


func ensure_subsheet_id() -> void:
	"""Ensure this subsheet has a unique ID (called when loading from old saved sheets)."""
	if subsheet_id.is_empty():
		subsheet_id = _generate_unique_id()
