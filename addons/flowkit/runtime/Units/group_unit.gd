@tool
extends FKUnit

## A group container for organizing events, comments, and nested groups in FlowKit.
## Groups provide visual organization and can be collapsed/expanded.
## Children used to be stored as dictionaries with "type" and "data" keys.
## Now, they are stored as FKUnit subresources.
class_name FKGroup

@export var title: String = "Group"
@export var collapsed: bool = false
@export var color: Color = Color(0.25, 0.22, 0.35, 1.0)

## If accessing from outside FKGroupUnit, best use get_children instead.
@export var children: Array = []

static var _serialization_manager := FKSerializationManager.new()

func _init() -> void:
	block_type = "group"

func may_have_children() -> bool:
	return true

func get_children() -> Array[FKUnit]:
	normalize_children()
	var defensive_copy: Array[FKUnit] = [] as Array[FKUnit]
	defensive_copy.append_array(children)
	return defensive_copy

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

func add_child_unit(unit: FKUnit) -> void:
	if unit:
		children.append(unit)

func remove_child_at(index: int) -> void:
	if index >= 0 and index < children.size():
		children.remove_at(index)

func get_child_count() -> int:
	return children.size()

func get_child_unit(index: int) -> FKUnit:
	var valid_index: bool = index >= 0 and index < children.size()
	if valid_index:
		return children[index]
	return null

func find_child_index(unit: FKUnit) -> int:
	for i in range(children.size()):
		if children[i] == unit:
			return i
	return -1

func serialize() -> Dictionary:
	normalize_children(true)

	var result := super.serialize()
	var our_added_fields := {
		"title": title,
		"collapsed": collapsed,
		"color": color,
		"children": _get_serialized_children(self)
	}
	result.merge(our_added_fields)

	return result

static func _get_serialized_children(block: FKGroup) -> Array:
	var result: Array = []
	for unit in block.children:
		if unit:
			var serialized = unit.serialize()
			result.append(serialized)
	return result

func deserialize(dict: Dictionary) -> void:
	super.deserialize(dict)
	title = dict.get("title", "Group")
	collapsed = dict.get("collapsed", false)
	color = dict.get("color", Color(0.25, 0.22, 0.35, 1.0))

	children.clear()

	for child_dict in dict.get("children", []):
		var child_block := _serialization_manager.deserialize_unit(child_dict)
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
