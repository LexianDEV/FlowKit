extends RefCounted
class_name FKEditorGlobals

const EVENT_ROW_SCENE = preload("res://addons/flowkit/ui/workspace/event_row_ui.tscn")
const COMMENT_SCENE = preload("res://addons/flowkit/ui/workspace/comment_ui.tscn")
const CONDITION_ITEM_SCENE = preload("res://addons/flowkit/ui/workspace/condition_item_ui.tscn")
const ACTION_ITEM_SCENE = preload("res://addons/flowkit/ui/workspace/action_item_ui.tscn")
const BRANCH_ITEM_SCENE = preload("res://addons/flowkit/ui/workspace/branch_item_ui.tscn")

static var event_row_scene: Resource:
	get:
		return EVENT_ROW_SCENE


static var comment_scene: Resource:
	get:
		return COMMENT_SCENE

static var condition_item_scene: Resource:
	get:
		return CONDITION_ITEM_SCENE
		
static var action_item_scene: Resource:
	get:
		return ACTION_ITEM_SCENE

static var branch_item_scene: Resource:
	get:
		return BRANCH_ITEM_SCENE
