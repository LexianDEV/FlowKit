##
## Handles automatically saving Event Sheets in response to certain events.
##

extends RefCounted
class_name FKSheetAutoSaver

func init(editor_globals: FKEditorGlobals, enabled: bool = true):
	self._globals = editor_globals
	self._editor_settings = editor_globals.editor_settings
	self.enabled = enabled
	_prep_cooldown_timer.call_deferred()
	_toggle_subs(true)
	print("[FKSheetAutoSaver]: Initialized.")
	
var _globals: FKEditorGlobals
# ^Used as a context to access other modules as needed
var _editor_settings: EditorSettings
var enabled: bool = false
# ^Decides whether or not this can do any saving.

func _prep_cooldown_timer():
	if _cooldown_timer:
		return
		
	_cooldown_timer = Timer.new()
	_cooldown_timer.one_shot = true
	_cooldown_timer.wait_time = COOLDOWN
	_base_control.add_child(_cooldown_timer)
	_cooldown_timer.timeout.connect(_on_cooldown_finished)

var _cooldown_timer: Timer
const COOLDOWN := 0.2

var _base_control: Control:
	get:
		return _globals.base_control
		
func _on_cooldown_finished():
	_cooldown_active = false

var _cooldown_active: bool = false

func _handle_save_as_needed():
	if not _allowed_to_save:
		return
		
	_save_after_one_frame()
	_start_timer_and_cooldown()
	
var _allowed_to_save: bool:
	get:
		return self.enabled and not _cooldown_active and \
	_globals.sheet_editor_visible and _globals.sheet_editor_ready
	
func _save_after_one_frame():
	# Why one frame? To give time for any setup that the unit uis need upon
	# being added, removed, etc.
	var tree := _base_control.get_tree()
	await tree.process_frame
	_save_sheet()

## Saves the sheet to disk before returning it.
## If saving fails, this returns null.
func _save_sheet() -> FKEventSheet:
	# No enablement checks here, what with the one-frame lag between the saving and
	# the start of the cooldown timer
	var current_scene_uid = _globals.current_scene_uid
	var is_scene_open: bool = current_scene_uid > 0
	var in_undo_redo := _globals.is_in_undo_redo
	if not is_scene_open or in_undo_redo:
		push_warning("[FKSheetAutoSaver] No scene open to save event sheet.")
		return

	var units := _block_container.units
	var sheet := FKEventSheet.from_units(units)
	
	var result: FKEventSheet = null
	var sheet_io := _globals.sheet_io
	var err := sheet_io.save_sheet(current_scene_uid, sheet)

	if err == OK:
		print("[FKSheetAutoSaver] ✓ Event sheet saved")
		result = sheet
	else:
		push_error("[FKSheetAutoSaver] Failed to save event sheet: ", err)
	
	return result

var _block_container: FKUnitContainerUi:
	get:
		var result: FKUnitContainerUi = null
		if _globals:
			result = _globals.block_container_ui
		return result
		
func _start_timer_and_cooldown():
	_cooldown_active = true
	_cooldown_timer.start()
	
## Ensures that the auto-saver is properly in sync with things.
func refresh():
	# No-op for now, thanks to the new signal bus approach
	pass
	
func _toggle_subs(on: bool):
	if on and not _is_subbed:
		_unit_ui_signals.contents_changed.connect(_on_unit_contents_changed)
		_unit_ui_signals.entered_sheet_ui.connect(_on_child_entered_block_container)
		_unit_ui_signals.exiting_sheet_ui.connect(_on_child_exiting_block_container)
		_unit_ui_signals.moved_in_sheet_ui.connect(_on_block_container_children_reordered)
	elif _is_subbed and not on:
		_unit_ui_signals.contents_changed.disconnect(_on_unit_contents_changed)
		_unit_ui_signals.entered_sheet_ui.disconnect(_on_child_entered_block_container)
		_unit_ui_signals.exiting_sheet_ui.disconnect(_on_child_exiting_block_container)
		_unit_ui_signals.moved_in_sheet_ui.disconnect(_on_block_container_children_reordered)
	else:
		return
		
	_is_subbed = on

var _is_subbed := false

var _unit_ui_signals: FKUnitUiSignals:
	get:
		return _globals.unit_ui_signals
		
func _on_unit_contents_changed(unit_ui: FKUnitUi):
	_handle_save_as_needed()

func _on_child_entered_block_container(child: FKUnitUi):
	_handle_save_as_needed()

func _on_child_exiting_block_container(child: FKUnitUi):
	_handle_save_as_needed()
	
func _on_block_container_children_reordered():
	_handle_save_as_needed()
	
