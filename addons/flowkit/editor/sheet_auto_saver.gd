##
## Handles automatically saving Event Sheets in response to certain events.
##

extends RefCounted
class_name FKSheetAutoSaver

func init(main_editor: FKMainEditor, enabled: bool = true):
	self._main_editor = main_editor
	self.enabled = enabled
	_prep_cooldown_timer()
	
var _main_editor: FKMainEditor 
# ^Used as a context to access other modules as needed
var enabled: bool = false
# ^Decides whether or not this can do any saving

func _prep_cooldown_timer():
	if _cooldown_timer:
		return
		
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = false
	_cooldown_timer.wait_time = COOLDOWN
	_main_editor.add_child(_cooldown_timer)
	_cooldown_timer.timeout.connect(_on_cooldown_finished)
	
var _cooldown_timer: Timer
const COOLDOWN := 0.2

func _on_cooldown_finished():
	_cooldown_active = false

	if _save_scheduled:
		_save_scheduled = false
		_handle_save_as_needed()

var _cooldown_active: bool = false
var _save_scheduled: bool = false

func _handle_save_as_needed():
	if not _cooldown_active:
		_save_after_one_frame()
		_start_cooldown()
	else:
		_save_scheduled = true

func _save_after_one_frame():
	# Why one frame? To give time for any setup that the unit uis need upon
	# being added, removed, etc.
	if enabled:
		await _main_editor.get_tree().process_frame 
		_save_sheet()

## Saves the sheet to disk before returning it.
## If saving fails, this returns null.
func _save_sheet() -> FKEventSheet:
	if not enabled:
		return
		
	var current_scene_uid = _main_editor.current_scene_uid
	var is_scene_open: bool = current_scene_uid > 0
	var in_undo_redo := _main_editor._is_in_undo_redo
	if not is_scene_open or in_undo_redo:
		push_warning("[FKSheetAutoSaver] No scene open to save event sheet.")
		return

	var units := _block_container.units
	var sheet := FKEventSheet.from_units(units)
	
	var result: FKEventSheet = null
	var sheet_io := _main_editor.sheet_io
	var err := sheet_io.save_sheet(current_scene_uid, sheet)

	if err == OK:
		print("[FKSheetAutoSaver] ✓ Event sheet saved")
		result = sheet
	else:
		push_error("[FKSheetAutoSaver] Failed to save event sheet: ", err)
	
	return result

var _block_container: FKBlockContainerUi:
	get:
		var result: FKBlockContainerUi = null
		if _main_editor:
			result = _main_editor.blocks_container
		return result
		
func _start_cooldown():
	_cooldown_active = true
	_cooldown_timer.start()
	
## Ensures that the auto-saver is properly in sync with things.
func refresh():
	_toggle_subs(false)
	_units_listening_for.clear()
	var current_uis := _block_container.unit_uis
	_units_listening_for.append_array(current_uis)
	_toggle_subs(true)
	_prep_cooldown_timer()
	
func _toggle_subs(on: bool):
	for unit_ui in _units_listening_for:
		if not is_instance_valid(unit_ui):
			continue
		
		if unit_ui is FKCommentUi:
			_toggle_subs_comment(on, unit_ui)
		elif unit_ui is FKGroupUi:
			_toggle_subs_group(on, unit_ui)
		elif unit_ui is FKEventRowUi:
			_toggle_subs_event_row(on, unit_ui)
			
	_toggle_block_container_subs(on)
	
var _units_listening_for: Array[FKUnitUi] = []

func _toggle_subs_comment(on: bool, comment: FKCommentUi):
	var currently_subbed: bool = _comments_subbed_to.get(comment) == true
	
	if on and not currently_subbed:
		comment.block_contents_changed.connect(_on_block_state_changed)
		_comments_subbed_to[comment] = true
	elif !on and currently_subbed:
		comment.block_contents_changed.disconnect(_on_block_state_changed)
		_comments_subbed_to.erase(comment)

var _comments_subbed_to: Dictionary[FKCommentUi, bool] = {}

func _on_block_state_changed():
	if not enabled:
		return
	
	_handle_save_as_needed()


func _toggle_subs_group(on: bool, group: FKGroupUi):
	var currently_subbed: bool = _groups_subbed_to.get(group) == true
	
	if on and not currently_subbed:
		group.data_changed.connect(_on_block_state_changed)
		_groups_subbed_to[group] = true
	elif !on and currently_subbed:
		group.data_changed.disconnect(_on_block_state_changed)
		_groups_subbed_to.erase(group)

var _groups_subbed_to: Dictionary[FKGroupUi, bool] = {}

func _toggle_subs_event_row(on: bool, event_row: FKEventRowUi):
	var currently_subbed: bool = _event_rows_subbed_to.get(event_row) == true
	
	if on and not currently_subbed:
		event_row.data_changed.connect(_on_block_state_changed)
		_event_rows_subbed_to[event_row] = true
	elif !on and currently_subbed:
		event_row.data_changed.disconnect(_on_block_state_changed)
		_event_rows_subbed_to.erase(event_row)

var _event_rows_subbed_to: Dictionary[FKEventRowUi, bool] = {}

func _toggle_block_container_subs(on: bool):
	if on and not _subbed_to_block_container:
		_block_container.child_entered_tree.connect(_on_child_entered_block_container)
		_block_container.child_exiting_tree.connect(_on_child_exiting_block_container)
		_block_container.child_order_changed.connect(_on_block_container_children_reordered)
	elif _subbed_to_block_container && !on:
		_block_container.child_entered_tree.disconnect(_on_child_entered_block_container)
		_block_container.child_exiting_tree.disconnect(_on_child_exiting_block_container)
		_block_container.child_order_changed.disconnect(_on_block_container_children_reordered)
		
	_subbed_to_block_container = on
		
var _subbed_to_block_container := false

func _on_child_entered_block_container(child: Node):
	if child is FKUnitUi:
		_handle_save_as_needed()

func _on_child_exiting_block_container(child: Node):
	if child is FKUnitUi:
		_handle_save_as_needed()
	
func _on_block_container_children_reordered():
	_handle_save_as_needed()
	
func reset():
	_comments_subbed_to.clear()
	_groups_subbed_to.clear()
