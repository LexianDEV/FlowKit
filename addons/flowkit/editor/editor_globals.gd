extends RefCounted
class_name FKEditorGlobals

const EVENT_ROW_SCENE_PATH := "res://addons/flowkit/editor/scenes/unitUis/event_row_ui.tscn"
const COMMENT_SCENE_PATH := "res://addons/flowkit/editor/scenes/unitUis/comment_ui.tscn"
const CONDITION_SCENE_PATH := "res://addons/flowkit/editor/scenes/unitUis/condition_unit_ui.tscn"
const ACTION_ITEM_SCENE_PATH := "res://addons/flowkit/editor/scenes/unitUis/action_unit_ui.tscn"
const BRANCH_ITEM_SCENE_PATH := "res://addons/flowkit/editor/scenes/unitUis/branch_unit_ui.tscn"
const GROUP_SCENE_PATH := "res://addons/flowkit/editor/scenes/unitUis/group_ui.tscn"
const SETTINGS_WINDOW_SCENE_PATH := "res://addons/flowkit/editor/scenes/fk_editor_settings.tscn"
const PATH_TO_EVENTS_FOLDER := "res://addons/flowkit/events"

const MAIN_EDITOR_SCENE_PATH := "res://addons/flowkit/editor/scenes/main_editor.tscn"
const SETTINGS_WINDOW_TOOL_MENU_PATH = "FlowKit/Settings"

const EVENT_ROW_SCENE := preload(EVENT_ROW_SCENE_PATH)
const COMMENT_SCENE := preload(COMMENT_SCENE_PATH)
const CONDITION_ITEM_SCENE := preload(CONDITION_SCENE_PATH)
const ACTION_ITEM_SCENE := preload(ACTION_ITEM_SCENE_PATH)
const BRANCH_ITEM_SCENE := preload(BRANCH_ITEM_SCENE_PATH)

const AUTO_SAVE_TOGGLE_KEY = "flowkit/auto_save_enabled"

var editor_interface: EditorInterface
var editor_settings: EditorSettings:
	get:
		return editor_interface.get_editor_settings()
		
var generator: FKGenerator
var registry: FKRegistry 
var modal_signals: FKModalSignals = FKModalSignals.new()
var unit_ui_signals := FKUnitUiSignals.new()
var current_scene_uid: int = 0

## Should return a SceneTree object. No args.
var get_main_editor_tree: Callable

var is_in_undo_redo := false
var sheet_auto_saver: FKSheetAutoSaver
var sheet_io: FKSheetIO = FKSheetIO.new()
var block_container_ui: FKUnitContainerUi

var base_control: Control:
	get:
		return editor_interface.get_base_control()
		
var sheet_editor_visible: bool = false

## Ready to let the user do things like add and reorder Actions
var sheet_editor_ready := false
