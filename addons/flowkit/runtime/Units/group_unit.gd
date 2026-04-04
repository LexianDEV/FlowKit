@tool
extends FKUnit
class_name FKGroup

## A group container for organizing events, comments, and nested groups in FlowKit.
## Groups provide visual organization and can be collapsed/expanded.
## Children used to be stored as dictionaries with "type" and "data" keys.
## Now, they are stored as FKUnit subresources.

@export var title: String = "Group"
@export var collapsed: bool = false
@export var color: Color = Color(0.25, 0.22, 0.35, 1.0)

@export var children: Array = []

static var _serialization_manager := FKSerializationManager.new()

func _init() -> void:
	block_type = "group"

func normalize_children(force: bool = false) -> void:
	if _is_normalized and not force:
		return
	var normalized: Array = []

	for child in children:
		var unit: FKUnit = null

		if child is Dictionary:
			var data: FKUnit = child.get("data")
			if data is FKUnit:
				unit = data
		elif child is FKUnit:
			unit = child

		if unit:
			normalized.append(unit)

	children.clear()
	children.append_array(normalized)

var _is_normalized := false

# Optional helpers if you still want them, but FKUnit-only now
func add_child_unit(unit: FKUnit) -> void:
	if unit:
		children.append(unit)

func remove_child_at(index: int) -> void:
	if index >= 0 and index < children.size():
		children.remove_at(index)

func get_child_count() -> int:
	return children.size()

func get_child_unit(index: int) -> FKUnit:
	if index >= 0 and index < children.size():
		return children[index]
	return null

func find_child_index(unit: FKUnit) -> int:
	for i in range(children.size()):
		if children[i] == unit:
			return i
	return -1

func serialize() -> Dictionary:
	normalize_children(true)
	
	var result := {
		"type": block_type,
		"title": title,
		"collapsed": collapsed,
		"color": color,
		"children": _get_serialized_children(self)
	}
	return result

static func _get_serialized_children(block: FKGroup) -> Array:
	var result: Array = []
	for unit in block.children:
		if unit:
			var serialized = unit.serialize()
			result.append(serialized)
	return result

func deserialize(dict: Dictionary) -> void:
	title = dict.get("title", "Group")
	collapsed = dict.get("collapsed", false)
	color = dict.get("color", Color(0.25, 0.22, 0.35, 1.0))

	children = []

	for child_dict in dict.get("children", []):
		var child_block := _serialization_manager.deserialize_block(child_dict)
		if child_block:
			children.append(child_block)

	normalize_children(true)

func copy_deep() -> FKGroup:
	var result := duplicate_block()
	return result

func duplicate_block() -> FKGroup:
	#print("[FKGroup] Duplicating!")
	# Make sure we're working with FKUnits, not legacy dicts
	normalize_children(true)

	var copy := FKGroup.new()
	copy.block_type = block_type
	copy.title = title
	copy.collapsed = collapsed
	copy.color = color
	copy.children = []

	for child in children:
		if child and child is FKUnit:
			copy.children.append(child.duplicate_block())

	return copy

func get_class() -> String:
	return "FKGroup"
