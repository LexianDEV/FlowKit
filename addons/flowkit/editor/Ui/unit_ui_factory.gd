extends Node
class_name FKUnitUiFactory

func _init(p_sheet_io: FKSheetIO) -> void:
	sheet_io = p_sheet_io
	
var sheet_io : FKSheetIO 
var registry: FKRegistry

##
## Currently only able to output these:
## FKEventRowUi
## FKCommentUi
#3 FKGroupUi
##
func unit_ui_from(unit: FKUnit, inputs: Dictionary = {}) -> FKUnitUi:
	var result: FKUnitUi = null
	
	if unit is FKEventBlock:
		result = _create_event_row(unit)
	elif unit is FKComment:
		result = _create_comment_ui(unit)
	elif unit is FKGroup:
		result = _create_group_block(unit)
		
	return result
		
	
func _create_event_row(data: FKEventBlock) -> FKEventRowUi:
	"""Create event row node from data (GDevelop-style)."""
	#print("[FKUnitUiFactory] Creating event row node")
	var row: FKEventRowUi = EVENT_ROW_SCENE.instantiate()
	var copy := sheet_io.copy_event_block(data)
	
	row.legitimize(copy, registry)
	return row
	
const EVENT_ROW_SCENE = preload("res://addons/flowkit/ui/workspace/event_row_ui.tscn")

func _create_comment_ui(data: FKComment) -> FKCommentUi:
	"""Create comment block node from data."""
	#print("[FKUnitUiFactory]: Creating comment block node")
	var comment: FKCommentUi = COMMENT_SCENE.instantiate()
	var copy := FKComment.new()
	copy.text = data.text
	
	comment.legitimize(copy, registry)
	return comment

const COMMENT_SCENE = preload("res://addons/flowkit/ui/workspace/comment_ui.tscn")

func _create_group_block(data: FKGroup) -> FKGroupUi:
	"""Create group block node from data."""
	#print("[FKUnitUiFactory]: Creating group block node")
	var group: FKGroupUi = GROUP_SCENE.instantiate()
	var copy := data.copy_deep()
	copy.normalize_children()
	group.legitimize(copy, registry)
	return group
	
const GROUP_SCENE = preload("res://addons/flowkit/ui/workspace/group_ui.tscn")
