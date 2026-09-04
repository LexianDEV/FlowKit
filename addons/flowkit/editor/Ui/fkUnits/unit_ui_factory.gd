extends Node
class_name FKUnitUiFactory

func _init(editor_globals: FKEditorGlobals) -> void:
	self._globals = editor_globals

var _globals: FKEditorGlobals

##
## Currently only able to output these:
## FKEventRowUi
## FKCommentUi
## FKGroupUi
##
func unit_ui_from(unit: FKUnit, inputs: Dictionary = {}) -> FKUnitUi:
	var result: FKUnitUi = null
	
	if unit is FKEventUnit:
		result = _create_event_row(unit)
	elif unit is FKComment:
		result = _create_comment_ui(unit)
	elif unit is FKGroup:
		result = _create_group_block(unit)
		
	return result
		
func _create_event_row(data: FKEventUnit) -> FKEventRowUi:
	"""Create event row node from data (GDevelop-style)."""
	#print("[FKUnitUiFactory] Creating event row node")
	var row: FKEventRowUi = EVENT_ROW_SCENE.instantiate()
	var copy := sheet_io.copy_event_block(data)
	
	row.legitimize(copy, _globals)
	return row
	
var registry: FKRegistry:
	get:
		return _globals.registry
	
const EVENT_ROW_SCENE = preload(FKEditorGlobals.EVENT_ROW_SCENE_PATH)
var sheet_io : FKSheetIO:
	get:
		return _globals.sheet_io
		
func _create_comment_ui(data: FKComment) -> FKCommentUi:
	"""Create comment block node from data."""
	#print("[FKUnitUiFactory]: Creating comment block node")
	var comment: FKCommentUi = COMMENT_SCENE.instantiate()
	var copy := FKComment.new()
	copy.text = data.text
	
	comment.legitimize(copy, _globals)
	return comment

const COMMENT_SCENE = preload(FKEditorGlobals.COMMENT_SCENE_PATH)

func _create_group_block(data: FKGroup) -> FKGroupUi:
	"""Create group block node from data."""
	#print("[FKUnitUiFactory]: Creating group block node")
	var group: FKGroupUi = GROUP_SCENE.instantiate()
	var copy := data.copy_deep()
	copy.normalize_children()
	group.legitimize(copy, _globals)
	return group
	
const GROUP_SCENE = preload(FKEditorGlobals.GROUP_SCENE_PATH)
