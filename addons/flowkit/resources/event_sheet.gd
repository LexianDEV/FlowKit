extends Resource
class_name FKEventSheet
## The main event sheet resource that stores all events, comments, and groups for a scene.
##
## The item_order array maintains the visual ordering of all items in the editor.
## Each entry is: {"type": "event"|"comment"|"group", "index": int}
## The index refers to the position within that type's array (events, comments, or groups).

@export var events: Array[FKEventBlock] = []
@export var standalone_conditions: Array[FKEventCondition] = []
@export var comments: Array[FKCommentBlock] = []
@export var groups: Array[FKGroupBlock] = []

## Stores the display order: [{"type": "event"|"comment"|"group", "index": int}, ...]
@export var item_order: Array[Dictionary] = []

func get_all_events() -> Array:
	var events := []
	events.append_array(self.events)
	_collect_events_from_groups(self.groups, events)
	return events

func _collect_events_from_groups(groups: Array, out_events: Array) -> void:
	for group in groups:
		if group is not FKGroupBlock:
			continue
			
		for child_item in group.children:
			var child_type: String = child_item.get("type", "")
			var child_data: Variant = child_item.get("data", null)
			
			if child_type == "event" and child_data is FKEventBlock:
				out_events.append(child_data)
			elif child_type == "group" and child_data is FKGroupBlock:
				# Recursively collect from nested groups
				_collect_events_from_groups([child_data], out_events)

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


func rebuild_order_from_items(ordered_items: Array) -> void:
	"""Rebuild the events, comments, groups arrays and item_order from an ordered list."""
	events = [] as Array[FKEventBlock]
	comments = [] as Array[FKCommentBlock]
	groups = [] as Array[FKGroupBlock]
	item_order = [] as Array[Dictionary]
	
	for item in ordered_items:
		var item_type = item.get("type", "")
		var data = item.get("data")
		
		match item_type:
			"event":
				if data is FKEventBlock:
					item_order.append({"type": "event", "index": events.size()})
					events.append(data)
			"comment":
				if data is FKCommentBlock:
					item_order.append({"type": "comment", "index": comments.size()})
					comments.append(data)
			"group":
				if data is FKGroupBlock:
					item_order.append({"type": "group", "index": groups.size()})
					groups.append(data)
