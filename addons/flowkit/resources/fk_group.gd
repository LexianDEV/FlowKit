extends Resource
class_name FKGroupBlock
## A group container for organizing events, comments, and nested groups in FlowKit.
##
## Groups provide visual organization and can be collapsed/expanded.
## Children are stored as dictionaries with "type" and "data" keys.

@export var title: String = "Group"
@export var collapsed: bool = false
@export var color: Color = Color(0.25, 0.22, 0.35, 1.0)

## Child items stored as: [{"type": "event"|"comment"|"group", "data": Resource}, ...]
@export var children: Array = []


func add_child_item(type: String, data: Resource) -> void:
	"""Add a child item to this group."""
	children.append({"type": type, "data": data})


func remove_child_at(index: int) -> void:
	"""Remove child at the specified index."""
	if index >= 0 and index < children.size():
		children.remove_at(index)


func get_child_count() -> int:
	"""Get the number of children in this group."""
	return children.size()


func get_child_type(index: int) -> String:
	"""Get the type of child at index."""
	if index >= 0 and index < children.size():
		return children[index].get("type", "")
	return ""


func get_child_data(index: int) -> Resource:
	"""Get the data resource of child at index."""
	if index >= 0 and index < children.size():
		return children[index].get("data")
	return null


func find_child_index(data: Resource) -> int:
	"""Find the index of a child by its data resource."""
	for i in range(children.size()):
		if children[i].get("data") == data:
			return i
	return -1


func copy_deep() -> FKGroupBlock:
	"""Create a deep copy of this group and all its children."""
	var copy = FKGroupBlock.new()
	copy.title = title
	copy.collapsed = collapsed
	copy.color = color
	copy.children = []
	
	for child_dict in children:
		var child_type = child_dict.get("type", "")
		var child_data = child_dict.get("data")
		
		if child_data and child_data.has_method("duplicate"):
			var child_copy = child_data.duplicate()
			# Deep copy for nested groups
			if child_type == "group" and child_data is FKGroupBlock:
				child_copy = child_data.copy_deep()
			copy.children.append({"type": child_type, "data": child_copy})
	
	return copy
