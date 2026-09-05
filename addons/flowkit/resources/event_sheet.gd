@tool
extends Resource
class_name FKEventSheet
## The main event sheet resource that stores all events, comments, and groups for a scene.
##
## The item_order array maintains the visual ordering of all items in the editor.
## Each entry is: {"type": "event"|"comment"|"group", "index": int}
## The index refers to the position within that type's array (events, comments, or groups).

@export var events: Array[FKEventUnit] = []
@export var standalone_conditions: Array[FKConditionUnit] = []
@export var comments: Array[FKComment] = []
@export var groups: Array[FKGroupUnit] = []

## Stores the display order: [{"type": "event"|"comment"|"group", "index": int}, ...]
@export var item_order: Array[Dictionary] = []
@export_storage var _id_assigner: FKIdAssigner

## Returns an array of the top-level FKUnits in the order they were
## appended to this sheet.
var ordered_items: Array[FKUnit]:
	get:
		if _ordered_items.size() != item_order.size():
			_refresh_ordered_items()
			
		return _ordered_items
			
func _refresh_ordered_items():
	_ordered_items.clear()
	
	for item in item_order:
		var item_type = item.get("type", "")
		var item_index: int = item.get("index", 0)
		var to_add: FKUnit = null
		
		if item_type == "event" and item_index < events.size():
			to_add = events[item_index]
		elif item_type == "comment" and item_index < comments.size():
			to_add = comments[item_index]
		elif item_type == "group" and item_index < groups.size():
			to_add = groups[item_index]
			
		if to_add:
			_ordered_items.append(to_add)
			
var _ordered_items: Array[FKUnit] = []

func get_all_events() -> Array:
	var events := []
	events.append_array(self.events)
	_collect_events_from_groups(self.groups, events)
	return events

func _collect_events_from_groups(groups: Array, out_events: Array) -> void:
	for group in groups:
		if not (group is FKGroupUnit):
			continue

		for child in group.children:
			var unit: FKUnit = null

			# Legacy format: { "type": String, "data": FKUnit }
			if child is Dictionary:
				unit = child.get("data")
			else:
				unit = child

			# New format: FKUnit directly
			if unit is FKEventUnit:
				out_events.append(unit)

			elif unit is FKGroupUnit:
				# Recurse into nested groups
				_collect_events_from_groups([unit], out_events)

func get_ordered_items() -> Array:
	"""Get all items in display order as an array of dictionaries with type and data."""
	var items = []
	
	for order_entry in item_order:
		var item_type = order_entry.get("type", "")
		var item_index = order_entry.get("index", 0)
		var data = null
		
		match item_type:
			"event":
				if item_index < events.size():
					data = events[item_index]
			"comment":
				if item_index < comments.size():
					data = comments[item_index]
			"group":
				if item_index < groups.size():
					data = groups[item_index]
		
		if data:
			items.append({"type": item_type, "data": data})
	
	return items

static func from_units(units: Array[FKUnit]) -> FKEventSheet:
	var sheet := FKEventSheet.new()
	for elem in units:
		sheet.append_copy_of(elem)
	return sheet

## Updates the item order as well.
func append_copy_of(unit: FKUnit):
	var copy := unit.duplicate_block()
	
	var where_copy_goes: Array = _array_for(copy)
	where_copy_goes.append(copy)
	
	var order_to_append: Dictionary = \
	{
		"type": copy.block_type,
		"index": where_copy_goes.size() - 1
	}
	item_order.append(order_to_append)

## Returns the array in this sheet that the passed unit is able to go into
func _array_for(unit: FKUnit) -> Array:
	var result: Array = []
	
	if unit is FKEventUnit:
		result = events
		#print("[FKEventSheet] chosen arr: events")
	elif unit is FKComment:
		result = comments
		#print("[FKEventSheet] chosen arr: comments")
	elif unit is FKGroupUnit:
		result = groups
		#print("[FKEventSheet] chosen arr: groups")
	elif unit is FKConditionUnit: 
		# Seems you can't have a top-level FKConditionUnit, but just in 
		# case for the future...
		result = standalone_conditions
		#print("[FKEventSheet] chosen arr: standalone_conditions")
	else:
		print("[FKEventSheet] Unknown block type we can't register: " + unit.block_type)
	
	return result
	
func rebuild_order_from_items(ordered_items: Array) -> void:
	"""Rebuild the events, comments, groups arrays and item_order from an ordered list."""
	events = [] as Array[FKEventUnit]
	comments = [] as Array[FKComment]
	groups = [] as Array[FKGroupUnit]
	item_order = [] as Array[Dictionary]
	
	for item in ordered_items:
		var item_type = item.get("type", "")
		var data = item.get("data")
		
		match item_type:
			"event":
				if data is FKEventUnit:
					item_order.append({"type": "event", "index": events.size()})
					events.append(data)
			"comment":
				if data is FKComment:
					item_order.append({"type": "comment", "index": comments.size()})
					comments.append(data)
			"group":
				if data is FKGroupUnit:
					item_order.append({"type": "group", "index": groups.size()})
					groups.append(data)

func on_loaded_from_disk():
	print("[FKEventSheet]: on_loaded_from_disk called")
	_call_child_on_loaded_from_disk(events)
	_call_child_on_loaded_from_disk(standalone_conditions)
	_call_child_on_loaded_from_disk(comments)
	_call_child_on_loaded_from_disk(groups)
	refresh()

func _call_child_on_loaded_from_disk(children: Array):
	for elem in children:
		var fk_unit := elem as FKUnit
		#print("Calling on_loaded_from_disk for instance of " + fk_unit.get_real_class())
		fk_unit.on_loaded_from_disk()

func refresh():
	if not _id_assigner:
		_id_assigner = FKIdAssigner.new()
		
	_id_assigner.prop_name = "uid"
	_id_assigner._append_array_as_invalid([0, FKUnit.INVALID_ID])

	_id_assigner.reset_taken_caches()
	_refresh_uids()

# For backwards compatibility with older versions of FlowKit
func _refresh_uids():
	print("[FKEventSheet]: Refreshing uids")
	_refresh_uids_in_array(events)
	_refresh_uids_in_array(standalone_conditions)
	_refresh_uids_in_array(comments)
	_refresh_uids_in_array(groups)


func _refresh_uids_in_array(arr: Array):
	for elem in arr:
		var unit := elem as FKUnit
		if unit == null:
			continue

		_assign_uid_recursive(unit)


func _assign_uid_recursive(unit: FKUnit):
	var assigned := _id_assigner.refresh_for([unit])
	# print("Assigning uid " + str(assigned) + " to " + unit.get_real_class())
	var childArr := unit.get_children()

	for child in childArr:
		_assign_uid_recursive(child)


func get_class() -> String:
	return "FKEventSheet"

func _to_string() -> String:
	var result := "FKEventSheet\n"
	result += "Events: " + str(events) + "\n"
	result += "Standalone Conditions: " + str(standalone_conditions) + "\n"
	result += "Comments: " + str(comments) + "\n"
	result += "Groups : " + str(groups) + "\n"
	return result