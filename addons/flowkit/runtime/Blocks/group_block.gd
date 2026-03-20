extends FKBaseBlock
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

func _init() -> void:
	block_type = "group"


func add_child_item(type: String, data: FKBaseBlock) -> void:
	children.append({"type": type, "data": data})


func remove_child_at(index: int) -> void:
	var valid_index: bool = index >= 0 and index < children.size()
	if valid_index:
		children.remove_at(index)


func get_child_count() -> int:
	return children.size()


func get_child_type(index: int) -> String:
	var valid_index: bool = index >= 0 and index < children.size()
	if valid_index:
		return children[index].get("type", "")
	return ""


func get_child_data(index: int) -> FKBaseBlock:
	var valid_index: bool = index >= 0 and index < children.size()
	if valid_index:
		return children[index].get("data")
	return null


func find_child_index(data: FKBaseBlock) -> int:
	for i in range(children.size()):
		if children[i].get("data") == data:
			return i
	return -1


func serialize() -> Dictionary:
	var result := {
		"type": block_type,
		"title": title,
		"collapsed": collapsed,
		"color": color,
		"children": _get_serialized_children(self)
	}
	
	return result

static func _get_serialized_children(block: FKGroupBlock) -> Array:
	var result: Array = []
	
	for child in block.children:
		var child_type = child.get("type", "")
		var child_data: FKBaseBlock = child.get("data")

		if child_data:
			var serialized = child_data.serialize()
			result.append(serialized)
			
	return result
	
func deserialize(dict: Dictionary) -> void:
	title = dict.get("title", "Group")
	collapsed = dict.get("collapsed", false)
	color = dict.get("color", Color(0.25, 0.22, 0.35, 1.0))

	children = []
	for child_dict in dict.get("children", []):
		var child_block := FKSerializationManager.new().deserialize_block(child_dict)
		if child_block:
			children.append({
				"type": child_block.block_type,
				"data": child_block
			})


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
