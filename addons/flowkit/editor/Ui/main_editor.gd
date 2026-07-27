@tool
extends Control
class_name FKMainEditor

## Whether or not FlowKit auto-saves sheets in response to things
## like adding or editing Actions.
@export var auto_save_sheets: bool = true

# UI References
@export_category("UI")
@export var scroll_container: ScrollContainer
@export var blocks_container: FKUnitContainerUi
@export var empty_label: Label
@export var add_event_btn: Button
@export var menu_bar: FKMenuBar

# Drag spacer state
var drag_spacer_top: Control = null  # Temporary spacer at top during drag
var drag_spacer_bottom: Control = null  # Temporary spacer at bottom during drag
const DRAG_SPACER_HEIGHT := 50  # Height of temporary drop zone

# Workflow state
var pending_block_type: String = ""  # "event", "condition", "action", "event_replace", "event_in_group", etc.
var pending_node_path: String = ""
var pending_id: String = ""
var pending_target_row: FKUnitUi = null  # The event row being modified
var pending_target_item: FKUnitUi = null  # The specific condition/action item being edited
var pending_target_group: Control = null  # The group to add content to (for event_in_group workflow)
var pending_target_branch: FKBranchUnitUi = null  # The branch item for branch sub-action workflows
var pending_branch_id: String = ""  # The branch provider ID for the current workflow
var selected_row: FKUnitUi = null  # Currently selected event row
var selected_item: FKUnitUi = null  # Currently selected condition/action item

# Submodules local to us
var sheet_state_tracker: FKSheetStateTracker
var clipboard := FKClipboardManager.new()
var input_manager: FKMainEditorInputHandler = FKMainEditorInputHandler.new()

var serializer := FKSerializationManager.new()
var unit_ui_factory: FKUnitUiFactory
var sheet_auto_saver: FKSheetAutoSaver = FKSheetAutoSaver.new()
var modal_manager: FKModalManager

func legitimize():
	if !is_editor_preview:
		return
	
	_is_editor_preview = false
	_enter_tree()
	_is_fully_legit = true

var is_editor_preview: bool:
	get:
		return _is_editor_preview
		
var _is_editor_preview := true

func _enter_tree() -> void:
	var instance_id := str(get_instance_id())
	if is_editor_preview:
		print("[FKMainEditor]: Entered tree as editor preview instance. " +\
		"Instance id: " + instance_id)
		return
	if is_fully_legit:
		return
	print("[FKMainEditor]: Entered tree as legit instance. Instance id: " + instance_id)
	
	sheet_state_tracker = FKSheetStateTracker.new()
	editor_globals.get_main_editor_tree = func() -> SceneTree:
		print("In the get_main_editor_tree func, self is " + str(self.get_class()))
		return self.get_tree()
	editor_globals.block_container_ui = blocks_container
	editor_globals.sheet_editor_visible = self.visible
	editor_globals.sheet_auto_saver = self.sheet_auto_saver
	self.sheet_auto_saver.init(editor_globals)
	blocks_container.globals = editor_globals
	unit_ui_factory = FKUnitUiFactory.new(editor_globals)
	
	input_manager.initialize(self)
	
	_modal_related_prep()
	_toggle_subs(true)

func _ready() -> void:
	if is_fully_legit:
		await _disable_sheet_tracker_for(1)
		

func _disable_sheet_tracker_for(duration: float):
	sheet_state_tracker.enabled = false 
	await get_tree().create_timer(duration).timeout
	sheet_state_tracker.enabled = true
	# ^We apply this delay to make sure that no snapshots are recorded before the 
		# full ui is initially built

func _apply_auto_save_enablement():
	var auto_save_setting_registered: bool = \
	_editor_settings.has_setting(FKEditorGlobals.AUTO_SAVE_TOGGLE_KEY)
	var enable_auto_save: bool = false if not auto_save_setting_registered \
	else _editor_settings.get_setting(FKEditorGlobals.AUTO_SAVE_TOGGLE_KEY)
	
	sheet_auto_saver.enabled = enable_auto_save

var _editor_settings: EditorSettings:
	get:
		return editor_globals._editor_settings
		
var sheet_io : FKSheetIO:
	get:
		return editor_globals.sheet_io
		
var is_fully_legit: bool:
	get:
		return _is_fully_legit

var _is_fully_legit := false 
# ^Need this to keep the same main editor instance from entering the tree twice

var editor_globals: FKEditorGlobals
var modal_signals: FKModalSignals:
	get:
		return editor_globals.modal_signals

func _modal_related_prep():
	modal_manager = FKModalManager.new()
	add_child(modal_manager)
	modal_manager.initialize(editor_globals)
	
func _toggle_subs(on: bool):
	if not modal_signals:
		# This means that either this isn't a legit instance, or the signals object
		# exited the tree before we did.
		return
	
	_toggle_modal_signal_subs(on)
	
	if on and !_is_subbed:
		# For undo state on drag-and-drop reorder
		visibility_changed.connect(_on_visibility_changed)
		blocks_container.before_unit_moved.connect(_push_undo_state)
		menu_bar.save_sheet.connect(_save_sheet)
		add_event_btn.pressed.connect(_on_add_event_button_pressed)
	elif !on and _is_subbed:
		visibility_changed.disconnect(_on_visibility_changed)
		blocks_container.before_unit_moved.disconnect(_push_undo_state)
		menu_bar.save_sheet.disconnect(_save_sheet)
		add_event_btn.pressed.disconnect(_on_add_event_button_pressed)
	else:
		return
	
	_is_subbed = on

var _is_subbed := false
	
func _on_visibility_changed():
	editor_globals.sheet_editor_visible = self.visible

func _toggle_modal_signal_subs(on: bool):
	if on and !_is_subbed:
		modal_signals.node_selected.connect(_on_node_selected)
		modal_signals.event_selected.connect(_on_event_selected)
		modal_signals.action_selected.connect(_on_action_selected_in_modal)
		modal_signals.condition_selected.connect(_on_condition_selected)
		modal_signals.expressions_confirmed.connect(_on_expressions_confirmed)
	elif !on and _is_subbed:
		modal_signals.node_selected.disconnect(_on_node_selected)
		modal_signals.event_selected.disconnect(_on_event_selected)
		modal_signals.action_selected.disconnect(_on_action_selected_in_modal)
		modal_signals.condition_selected.disconnect(_on_condition_selected)
		modal_signals.expressions_confirmed.disconnect(_on_expressions_confirmed)
		
func _show_empty_state() -> void:
	"""Show empty state UI (no scene loaded)."""
	empty_label.visible = true
	add_event_btn.visible = false
	
func _exit_tree() -> void:
	if is_editor_preview:
		print("[FKMainEditor]: Exiting tree as editor preview. Instance id: " + str(get_instance_id()))
		return
	print("[FKMainEditor]: Exiting tree as legit instance. Instance id: " + str(get_instance_id()))
	_toggle_subs(false)

func _popup_centered_on_editor(popup: Window) -> void:
	"""Center popup on the same window as the editor, supporting multi-monitor setups."""
	var editor_window: Window = null
	var base_control := editor_interface.get_base_control()
	editor_window = base_control.get_window()
	
	if not editor_window:
		# Fallback to default behavior if window not available
		popup.popup_centered()
		return
	
	var window_pos: Vector2i = editor_window.position
	var window_size: Vector2i = editor_window.size
	var popup_size: Vector2i = popup.size
	
	var centered_pos: Vector2i = window_pos + (window_size - popup_size) / 2
	
	# Ensure popup stays within editor window bounds 
	# (and handle cases where the popup is larger than the window)
	centered_pos.x = maxi(centered_pos.x, window_pos.x)
	centered_pos.y = maxi(centered_pos.y, window_pos.y)
	
	popup.position = centered_pos
	popup.popup()

var editor_interface: EditorInterface:
	get:
		var result: EditorInterface = null
		if editor_globals:
			result = editor_globals.editor_interface
			
		return result

func _input(event: InputEvent) -> void:
	input_manager.handle_input(event)
	
func has_valid_selection() -> bool:
	return valid_selected_item or valid_selected_row

var valid_selected_item: bool:
	get:
		return selected_item and is_instance_valid(selected_item)
		
var valid_selected_row: bool:
	get:
		return selected_row and is_instance_valid(selected_row)

var viewport: Viewport:
	get:
		return get_viewport()

func _paste_events() -> void:
	var new_events = clipboard.paste_event()
	if new_events.is_empty():
		return

	_on_pre_ui_change()
	
	var insert_idx = blocks_container.get_child_count()
	if selected_row:
		insert_idx = selected_row.get_index() + 1

	var first_row: FKUnitUi = null
	for ev in new_events:
		var row := _create_unit_ui(ev)
		blocks_container.add_child(row)
		blocks_container.move_child(row, insert_idx)
		insert_idx += 1
		if first_row == null:
			first_row = row

	if first_row:
		_on_row_selected(first_row)
	_on_ui_change_done()

func _find_parent_branch(node: Control) -> FKBranchUnitUi:
	"""Find the branch_item that contains this node, or null if at top level."""
	var current := node.get_parent()
	while current:
		if current is FKBranchUnitUi:
			return current
		if current is FKEventRowUi:
			return null  # Reached event_row, no branch parent
		current = current.get_parent()
	return null
	
func _paste_actions() -> void:
	var target_row := selected_row

	# If only an item is selected, find its parent row
	if not target_row and selected_item:
		target_row = _find_parent_event_row(selected_item)

	if not target_row:
		return

	var new_actions = clipboard.paste_action()
	if new_actions.is_empty():
		return

	_on_pre_ui_change()

	# Check if pasting into a branch
	var target_branch: FKBranchUnitUi = null
	if selected_item:
		target_branch = _find_parent_branch(selected_item)

	if target_branch:
		var branch_data = target_branch.get_unit()
		for act in new_actions:
			branch_data.branch_actions.append(act)
		target_row.update_display()
		_on_row_selected(target_row)
		return

	# Normal paste into event row
	var data := target_row.get_unit() as FKEventUnit
	for act in new_actions:
		data.actions.append(act)

	target_row.update_display()
	_on_row_selected(target_row)
	_on_ui_change_done()

func _paste_conditions() -> void:
	var target_row := selected_row

	# If only an item is selected, find its parent row
	if not target_row and selected_item:
		target_row = _find_parent_event_row(selected_item)

	if not target_row:
		return

	var new_conditions = clipboard.paste_condition()
	if new_conditions.is_empty():
		return

	_on_pre_ui_change()

	var data := target_row.get_unit() as FKEventUnit
	for cond in new_conditions:
		data.conditions.append(cond)

	target_row.update_display()
	_on_row_selected(target_row)
	_on_ui_change_done()

func _paste_group() -> void:
	var new_group := clipboard.paste_group()
	if not new_group:
		return
	
	print("[FKMainEditor]: Pasting group")
	_on_pre_ui_change()

	var target_group: FKGroupUi = null

	# Case 1: selected row *is* a group
	if selected_row is FKGroupUi:
		target_group = selected_row

	# Case 2: selected row is inside a group
	elif selected_row:
		var parent = selected_row.get_parent()
		while parent:
			if parent is FKGroupUi:
				target_group = parent
				break
			parent = parent.get_parent()

	# Paste inside a group if we found one
	if target_group:
		if target_group.has_method("add_group_to_group"):
			target_group.add_group_to_group(new_group)
		else:
			# Fallback: append to children manually
			var block := target_group.get_unit()
			block.children.append({
				"type": "group",
				"data": new_group
			})
		target_group.update_display()
		_on_row_selected(target_group)
		return

	# Otherwise paste at root level
	var group_node := unit_ui_factory.unit_ui_from(new_group)
	_wire_signals(group_node)
	blocks_container.add_child(group_node)

	_on_row_selected(group_node)
	_on_ui_change_done()
	
# === Undo/Redo System ===
func _push_undo_state() -> void:
	if not is_fully_legit:
		print("[FKMainEditor]: Cannot push undo state without being fully legit")
		return
	if _is_in_undo_redo || _is_in_editor_rebuild || not sheet_state_tracker.enabled:
		return
	
	print("[FKMainEditor]: Pushing undo state")
	var units := blocks_container.units
	sheet_state_tracker.record_snapshot(units)

func _clear_undo_history() -> void:
	"""Clear undo/redo history (called when switching scenes)."""
	sheet_state_tracker.clear()

func _undo() -> void:
	print("[FKMainEditor]: Undo requested. Has previous = ", sheet_state_tracker.has_previous())
	if _is_in_editor_rebuild or not sheet_state_tracker.has_previous() or \
	_is_in_undo_redo or not sheet_state_tracker.enabled:
		return

	_is_in_editor_rebuild = true
	_is_in_undo_redo = true

	var current_units := blocks_container.units
	var prev_state := sheet_state_tracker.get_previous_snapshot(current_units)
	var restored_units := ArrayUtils.get_fk_units_in(prev_state)
	_restore_unit_uis(restored_units)
	
	await get_tree().process_frame
	_is_in_undo_redo = false 
	_is_in_editor_rebuild = false
	
	print("[FKMainEditor]: Undo performed")

var _is_in_editor_rebuild: bool = false

var _is_in_undo_redo: bool:
	get:
		return editor_globals.is_in_undo_redo
	set(value):
		editor_globals.is_in_undo_redo = value
	
func _redo() -> void:
	print("[FKMainEditor]: Redo requested. Has next = ", sheet_state_tracker.has_next())
	if not sheet_state_tracker.has_next() or _is_in_undo_redo or \
		not sheet_state_tracker.enabled or _is_in_editor_rebuild:
		return
	
	_is_in_editor_rebuild = true
	_is_in_undo_redo = true

	# 🔥 Step 1: pop the next snapshot
	var next_snapshot := sheet_state_tracker._future.pop_back()

	# 🔥 Step 2: restore the UI
	var restored_units := ArrayUtils.get_fk_units_in(next_snapshot)
	_restore_unit_uis(restored_units)

	# 🔥 Step 3: AFTER UI is restored, capture the new current state
	await get_tree().process_frame
	var current_units := blocks_container.units

	# 🔥 Step 4: push current state into history
	var current_snapshot := sheet_state_tracker._deep_copy_units(current_units)
	sheet_state_tracker._history.append(current_snapshot)

	_is_in_undo_redo = false
	_is_in_editor_rebuild = false

	print("[FKMainEditor]: Redo performed")


func _restore_unit_uis(units: Array[FKUnit]) -> void:
	_on_pre_ui_restoration()
	blocks_container.clear_unit_nodes()

	for unit in units:
		var node := _create_unit_ui(unit)
		blocks_container.add_child(node)

	if units.size() > 0:
		_show_content_state()
	else:
		_show_empty_blocks_state()
	_on_ui_restoration_done()

func _on_pre_ui_restoration():
	_is_in_editor_rebuild = true

func _on_ui_restoration_done():
	_is_in_editor_rebuild = false
		
func _create_unit_ui(unit: FKUnit) -> FKUnitUi:
	var result: FKUnitUi = unit_ui_factory.unit_ui_from(unit)
	if result:
		_wire_signals(result)
	return result

func _delete_selected_row() -> void:
	"""Delete the currently selected event row."""
	if not selected_row or not is_instance_valid(selected_row):
		return
	
	_on_pre_ui_change()
	
	var row_to_delete := selected_row
	
	# Clear selection first
	row_to_delete.set_selected(false)
	selected_row = null
	
	# Check if row is a direct child of blocks_container or inside a group
	if row_to_delete.get_parent() == blocks_container:
		# Direct child of blocks_container - delete it
		blocks_container.remove_child(row_to_delete)
		row_to_delete.queue_free()
	else:
		# Row is inside a group - emit the appropriate delete signal
		if row_to_delete is FKGroupUi:
			# It's a nested group
			row_to_delete.delete_requested.emit(row_to_delete)
		elif row_to_delete is FKCommentUi:
			# It's a comment
			row_to_delete.delete_requested.emit(row_to_delete)
		else:
			# It's an event row
			row_to_delete.delete_event_requested.emit(row_to_delete)
	
	_on_ui_change_done()

## Meant to fire right before we try making any change to the editor ui.
func _on_pre_ui_change():
	if _is_in_editor_rebuild:
		return 
	_push_undo_state()
	_is_in_editor_rebuild = true

## Meant to fire when we;re done making a change to the editor ui.
func _on_ui_change_done():
	_is_in_editor_rebuild = false

func _delete_selected_item() -> void:
	"""Delete the currently selected condition or action item."""
	if not selected_item or not is_instance_valid(selected_item):
		return
	
	var item_to_delete := selected_item
	
	# Find the parent event_row
	var parent_row := _find_parent_event_row(item_to_delete)
	if not parent_row:
		return
	
	_on_pre_ui_change()
	
	# Check if it's a condition or action
	if item_to_delete is FKConditionUnitUi:
		var cond_data := item_to_delete.get_unit() as FKConditionUnit
		var event_data := parent_row.get_unit()
		if cond_data and event_data:
			var idx = event_data.conditions.find(cond_data)
			if idx >= 0:
				event_data.conditions.remove_at(idx)
	elif item_to_delete is FKActionUnitUi or item_to_delete is FKBranchUnitUi:
		var act_data := item_to_delete.get_unit() as FKActionUnit
		var event_data := parent_row.get_unit()
		if act_data and event_data:
			var idx = event_data.actions.find(act_data)
			if idx >= 0:
				event_data.actions.remove_at(idx)
			else:
				# Action might be inside a branch - search recursively
				_recursive_remove_action_from_list(event_data.actions, act_data)
	
	# Clear selection
	_deselect_item()
	
	# Update display and save
	parent_row.update_display()
	_on_ui_change_done()

func _recursive_remove_action_from_list(actions: Array, target_action) -> bool:
	"""Recursively search and remove an action from actions array and branch sub-actions."""
	var idx := actions.find(target_action)
	if idx >= 0:
		actions.remove_at(idx)
		return true
	for act in actions:
		if act.is_branch and _recursive_remove_action_from_list(act.branch_actions, target_action):
			return true
	return false

func _find_parent_event_row(node: Control) -> FKEventRowUi:
	"""Find the event_row that contains this node."""
	var current := node.get_parent()
	while current:
		if current is FKEventRowUi:
			return current
		current = current.get_parent()
	return null

func undo(): _undo()
func redo(): _redo()
func deselect_all(): _deselect_all()

func _process(delta: float) -> void:
	if not is_fully_legit or not editor_interface:
		return
	
	# Handle drag spacers - add temporary space only when needed
	if viewport.gui_is_dragging():
		if scroll_container and blocks_container:
			var mouse_pos := scroll_container.get_local_mouse_position()
			var scroll_rect := scroll_container.get_rect()
			var blocks_size := blocks_container.size
			var scroll_pos := scroll_container.scroll_vertical
			
			# Check if we need top spacer (dragging near top)
			# Always show if near top, regardless of scroll position
			var need_top_spacer := mouse_pos.y < DRAG_SPACER_HEIGHT
			
			# Check if we need bottom spacer (dragging near bottom AND not enough space below)
			var visible_bottom := scroll_pos + scroll_rect.size.y
			var content_bottom := blocks_size.y
			var need_bottom_spacer := mouse_pos.y > scroll_rect.size.y - DRAG_SPACER_HEIGHT and \
			visible_bottom >= content_bottom - DRAG_SPACER_HEIGHT
			
			# Create/remove top spacer
			if need_top_spacer and not drag_spacer_top:
				drag_spacer_top = Control.new()
				drag_spacer_top.custom_minimum_size = Vector2(0, DRAG_SPACER_HEIGHT)
				drag_spacer_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
				blocks_container.add_child(drag_spacer_top)
				blocks_container.move_child(drag_spacer_top, 0)
			elif not need_top_spacer and drag_spacer_top and is_instance_valid(drag_spacer_top):
				drag_spacer_top.queue_free()
				drag_spacer_top = null
			
			# Create/remove bottom spacer
			if need_bottom_spacer and not drag_spacer_bottom:
				drag_spacer_bottom = Control.new()
				drag_spacer_bottom.custom_minimum_size = Vector2(0, DRAG_SPACER_HEIGHT)
				drag_spacer_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
				blocks_container.add_child(drag_spacer_bottom)
				blocks_container.move_child(drag_spacer_bottom, blocks_container.get_child_count() - 1)
			elif not need_bottom_spacer and drag_spacer_bottom and is_instance_valid(drag_spacer_bottom):
				drag_spacer_bottom.queue_free()
				drag_spacer_bottom = null
	else:
		if drag_spacer_top and is_instance_valid(drag_spacer_top):
			drag_spacer_top.queue_free()
			drag_spacer_top = null
		if drag_spacer_bottom and is_instance_valid(drag_spacer_bottom):
			drag_spacer_bottom.queue_free()
			drag_spacer_bottom = null
	
	var scene_root := editor_interface.get_edited_scene_root()
	if not scene_root:
		if current_scene_uid != 0:
			current_scene_uid = 0
			blocks_container.clear_unit_nodes()
			_clear_undo_history()
			_show_empty_state()
		return

	var scene_path := scene_root.scene_file_path
	if scene_path == "":
		if current_scene_uid != 0:
			current_scene_uid = 0
			blocks_container.clear_unit_nodes()
			_clear_undo_history()
			_show_empty_state()
		return

	var scene_uid := ResourceLoader.get_resource_uid(scene_path)
	if scene_uid != current_scene_uid:
		_reset_for_new_scene(scene_uid)
		
var current_scene_uid: int:
	get:
		return editor_globals.current_scene_uid
	set(value):
		editor_globals.current_scene_uid = value

func _reset_for_new_scene(scene_uid: int):
	current_scene_uid = scene_uid
	_disable_sheet_tracker_for(1)
	_clear_undo_history()
	editor_globals.sheet_editor_ready = false
	_refresh_ui()
	sheet_auto_saver.refresh()
	if auto_save_sheets:
		_set_as_ready(30) 
		# ^Surprisingly, 10 frames aren't enough.
	
func _set_as_ready(frames_to_wait: int = 0):
	if frames_to_wait > 0:
		var frames_waited: int = 0
		while frames_waited < frames_to_wait:
			await get_tree().process_frame
			frames_waited += 1
	
	editor_globals.sheet_editor_ready = true

# === Block Management ===

func _show_empty_blocks_state() -> void:
	"""Show state when scene is loaded but has no blocks."""
	empty_label.visible = false
	add_event_btn.visible = true

func _show_content_state() -> void:
	"""Show content state UI."""
	empty_label.visible = false
	add_event_btn.visible = true

func _get_unit_nodes() -> Array[FKUnitUi]:
	return blocks_container.unit_uis
	
# === File Operations ===
	
func _populate_from_sheet(sheet: FKEventSheet) -> void:
	blocks_container.clear_unit_nodes()

	# Use the sheet’s own ordered_items list
	for unit in sheet.ordered_items:
		var ui := unit_ui_factory.unit_ui_from(unit)
		_wire_signals(ui)
		blocks_container.add_child(ui)
	
	if sheet.ordered_items.is_empty():
		_show_empty_blocks_state()
	else:
		_show_content_state()

func _wire_signals(unit: FKUnitUi):
	if unit is FKCommentUi:
		_connect_comment_signals(unit)
	elif unit is FKGroupUi:
		_connect_group_signals(unit)
	else:
		_connect_event_row_signals(unit)
		
## Saves the sheet to disk before returning it.
## If saving fails, this returns null.
func _save_sheet() -> FKEventSheet:
	var is_scene_open := current_scene_uid != 0
	if not is_scene_open or _is_in_undo_redo:
		push_warning("[FKMainEditor] No scene open to save event sheet.")
		return

	var units := blocks_container.units
		
	var sheet := FKEventSheet.from_units(units)
	var err := sheet_io.save_sheet(current_scene_uid, sheet)
	var result: FKEventSheet = null
	if err == OK:
		print("[FKMainEditor]: ✓ Event sheet saved")
		result = sheet
	else:
		push_error("[FKMainEditor]: Failed to save event sheet: ", err)
	
	return result
	
# Refreshes the Event Sheet Ui based on the sheet passed. If none is passed, 
# this goes for the sheet tied to the current scene uid.
func _refresh_ui(sheet: FKEventSheet = null):
	_on_pre_ui_restoration()
	if not sheet:
		# Why this fallback? We want other parts of this script to be able to
		# refresh the ui without having to look for the sheet first.
		sheet = sheet_io.load_sheet(current_scene_uid)
		
	_refresh_sheet_ui(sheet)
	_on_ui_restoration_done()
	
func _refresh_sheet_ui(sheet: FKEventSheet):
	blocks_container.clear_unit_nodes()
	
	if not sheet:
		_show_empty_blocks_state()
		return
		
	_populate_from_sheet(sheet)
	_show_content_state()
	_is_in_editor_rebuild = false
	
func _new_sheet() -> void:
	"""Create new empty sheet."""
	if current_scene_uid == 0:
		push_warning("No scene open to create event sheet for.")
		return
	_is_in_editor_rebuild = true
	blocks_container.clear_unit_nodes()
	_show_content_state()
	_is_in_editor_rebuild = false

# === Event Row Creation ===

func _connect_comment_signals(comment: FKCommentUi) -> void:
	comment.selected.connect(_on_comment_selected)
	comment.delete_requested.connect(_on_comment_delete_requested)

	comment.insert_comment_above_requested.connect(_on_comment_insert_above.bind(comment))
	comment.insert_comment_below_requested.connect(_on_comment_insert_below.bind(comment))
	comment.insert_event_above_requested.connect(_on_comment_insert_event_above.bind(comment))
	comment.insert_event_below_requested.connect(_on_comment_insert_event_below.bind(comment))


func _connect_group_signals(group: FKGroupUi) -> void:
	group.selected.connect(_on_group_selected)
	group.delete_requested.connect(_on_group_delete_requested)

	group.before_contents_changed.connect(_on_group_before_contents_changed)
	group.add_event_requested.connect(_on_group_add_event_requested)
	# Connect edit signals from children inside groups
	group.condition_edit_requested.connect(_on_condition_edit_requested)
	group.action_edit_requested.connect(_on_action_edit_requested)
	group.insert_event_below_requested.connect(func(row): _on_row_insert_below(row, row))
	group.insert_event_above_requested.connect(func(target): _on_comment_insert_event_above(target, target))
	group.insert_comment_below_requested.connect(func(row): _on_row_insert_comment_below(row, row))
	group.insert_comment_above_requested.connect(func(target): _on_comment_insert_above(target, target))
	group.replace_event_requested.connect(func(row): _on_row_replace(row, row))
	group.edit_event_requested.connect(func(row): _on_row_edit(row, row))
	group.add_condition_requested.connect(func(row): _on_row_add_condition(row, row))
	group.add_action_requested.connect(func(row): _on_row_add_action(row, row))
	group.condition_dropped.connect(_on_condition_dropped)
	group.action_dropped.connect(_on_action_dropped)
	# Branch signals from groups

	group.add_branch_requested.connect(func(row, bid): _on_row_add_branch(row, bid, row))
	group.add_elseif_requested.connect(_on_branch_add_elseif)
	group.add_else_requested.connect(_on_branch_add_else)
	group.branch_condition_edit_requested.connect(_on_branch_condition_edit)
	group.branch_action_add_requested.connect(_on_branch_action_add)
	group.branch_action_edit_requested.connect(_on_branch_action_edit)
	group.nested_branch_add_requested.connect(_on_nested_branch_add)

func _on_group_before_contents_changed(n):
	_push_undo_state()

func _on_group_add_event_requested(group_node: FKGroupUi) -> void:
	"""Handle request to add an event inside a group."""
	pending_target_group = group_node
	_start_add_workflow("event_in_group")


func _on_group_selected(node) -> void:
	"""Handle selection from group (could be the group itself or a child)."""
	# Check if it's a condition or action item
	if node is FKConditionUnitUi:
		_on_condition_selected_in_row(node)
		return
	
	if node is FKActionUnitUi:
		_on_action_selected_in_row(node)
		return
	
	# Check if it's an event_row inside the group
	if node is FKEventRowUi:
		_on_row_selected(node)
		return
	
	# Check if it's a comment inside the group
	if node is FKCommentUi:
		_on_comment_selected(node)
		return
	
	# It's a group (or nested group)
	_deselect_item()
	
	if valid_selected_row and selected_row is FKUnitUi:
		selected_row.set_selected(false)
	
	selected_row = node
	if selected_row is FKUnitUi:
		selected_row.set_selected(true)

func _on_group_delete_requested(group: FKGroupUi) -> void:
	"""Delete a group block."""
	_push_undo_state()
	
	if selected_row == group:
		selected_row = null
	
	blocks_container.remove_child(group)
	group.queue_free()

func _on_add_group_button_pressed() -> void:
	"""Add a new group block."""
	_push_undo_state()
	
	var data := FKGroupUnit.new()
	data.title = "New Group"
	data.collapsed = false
	data.color = Color(0.25, 0.22, 0.35, 1.0)
	data.children = []
	
	var group := _create_unit_ui(data)
	blocks_container.add_child(group)
	
	_show_content_state()

# === Signal Connections ===

func _connect_event_row_signals(row: FKEventRowUi) -> void:
	row.insert_event_below_requested.connect(_on_row_insert_below.bind(row))
	row.insert_comment_below_requested.connect(_on_row_insert_comment_below.bind(row))
	row.replace_event_requested.connect(_on_row_replace.bind(row))
	row.delete_event_requested.connect(_on_row_delete.bind(row))
	row.edit_event_requested.connect(_on_row_edit.bind(row))
	row.add_condition_requested.connect(_on_row_add_condition.bind(row))
	row.add_action_requested.connect(_on_row_add_action.bind(row))
	row.selected.connect(_on_row_selected)
	row.condition_selected.connect(_on_condition_selected_in_row)
	row.action_selected.connect(_on_action_selected_in_row)
	row.condition_edit_requested.connect(_on_condition_edit_requested.bind(row))
	row.action_edit_requested.connect(_on_action_edit_requested.bind(row))
	row.condition_dropped.connect(_on_condition_dropped)
	row.action_dropped.connect(_on_action_dropped)

	row.before_contents_changed.connect(func(n): _push_undo_state())
	# Branch signals
	row.add_branch_requested.connect(_on_row_add_branch.bind(row))
	row.add_elseif_requested.connect(_on_branch_add_elseif)
	row.add_else_requested.connect(_on_branch_add_else)
	row.branch_condition_edit_requested.connect(_on_branch_condition_edit)
	row.branch_action_add_requested.connect(_on_branch_action_add)
	row.branch_action_edit_requested.connect(_on_branch_action_edit)
	row.nested_branch_add_requested.connect(_on_nested_branch_add)

func _on_row_before_contents_changed(n):
	_push_undo_state()

# === Menu Button Handlers ===

func _on_new_sheet() -> void:
	_new_sheet()

func _on_generate_providers() -> void:
	if not generator:
		print("[FKMainEditor]: Generator not available")
		return
	
	print("[FKMainEditor]: Starting provider generation...")
	
	var result = generator.generate_all()
	
	var message := "[FKMainEditor]: Generation complete!\n"
	message += "Actions: %d\n" % result.actions
	message += "Conditions: %d\n" % result.conditions
	message += "Events: %d\n" % result.events
	
	if result.errors.size() > 0:
		message += "\nErrors:\n"
		for error in result.errors:
			message += "- " + error + "\n"
	
	message += "\nRestart Godot editor to load new providers?"
	
	print(message)
	
	# Show confirmation dialog with restart option
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = message
	dialog.title = "FlowKit Generator"
	dialog.ok_button_text = "Restart Editor"
	dialog.cancel_button_text = "Not Now"
	add_child(dialog)
	_popup_centered_on_editor(dialog)
	
	dialog.confirmed.connect(func():
		# Restart the editor
		if editor_interface:
			editor_interface.restart_editor()
		dialog.queue_free()
	)
	
	dialog.canceled.connect(func():
		# Just reload registry without restart
		if registry:
			registry.load_all()
		dialog.queue_free()
	)

var registry: FKRegistry:
	get:
		var result: FKRegistry = null
		if editor_globals:
			result = editor_globals.registry
		return result

var generator: FKGenerator:
	get:
		var result: FKGenerator = null
		if editor_globals:
			result = editor_globals.generator
		return result

func _on_generate_manifest() -> void:
	if not generator:
		print("[FKMainEditor]: Generator not available")
		return

	print("[FKMainEditor]: Generating optimized provider manifest for export...")

	var result = generator.generate_manifest()

	var message := "[FKMainEditor]: Optimized manifest generated!\n\n"
	message += "Included providers (actively used):\n"
	message += "  Actions:	%d\n" % result.actions
	message += "  Conditions: %d\n" % result.conditions
	message += "  Events:	 %d\n" % result.events
	message += "  Behaviors:  %d\n" % result.behaviors
	message += "  Branches:   %d\n" % result.branches
	message += "\nBuild optimization:\n"
	message += "  Total available: %d providers\n" % result.total_available
	message += "  Included:		%d providers\n" % result.total_included
	message += "  Excluded:		%d unused providers\n" % result.total_excluded

	if result.total_available > 0:
		var pct: float = (float(result.total_excluded) / float(result.total_available)) * 100.0
		message += "  Size reduction:  ~%.0f%%\n" % pct

	if result.errors.size() > 0:
		message += "\nErrors:\n"
		for error in result.errors:
			message += "- " + error + "\n"
	else:
		message += "\nThe manifest has been saved. Unused provider files\n"
		message += "will be automatically excluded from exported builds."

	print(message)

	# Show info dialog
	var dialog := AcceptDialog.new()
	dialog.dialog_text = message
	dialog.title = "FlowKit Build Optimizer"
	dialog.ok_button_text = "OK"
	add_child(dialog)
	_popup_centered_on_editor(dialog)

	dialog.confirmed.connect(func():
		dialog.queue_free()
	)

func _on_add_event_button_pressed() -> void:
	if not editor_interface:
		return
	_start_add_workflow("event")

func _on_add_comment_button_pressed() -> void:
	"""Add a new comment block."""
	_push_undo_state()
	
	var data := FKComment.new()
	data.text = ""
	
	var comment := _create_unit_ui(data)
	blocks_container.add_child(comment)
	
	_show_content_state()

func _on_row_selected(row: FKUnitUi) -> void:
	"""Handle row selection with visual feedback."""
	# Deselect previous item (condition/action)
	_deselect_item()
	
	# Deselect previous row
	if valid_selected_row:
		selected_row.set_selected(false)
	
	# Select new row
	selected_row = row
	if selected_row:
		selected_row.set_selected(true)

func _on_comment_selected(comment_node: FKCommentUi) -> void:
	"""Handle comment block selection."""
	_deselect_item()
	
	if valid_selected_row:
		selected_row.set_selected(false)
	
	selected_row = comment_node
	if selected_row:
		selected_row.set_selected(true)

func _on_comment_delete_requested(comment: FKCommentUi) -> void:
	"""Delete a comment block."""

	if selected_row == comment:
		selected_row = null
	
	_on_pre_ui_change()
	blocks_container.remove_child(comment)
	comment.queue_free()
	# ^To make sure we have a snapshot ready in time
	_on_ui_change_done()

func _on_comment_insert_above(signal_node, bound_comment: FKCommentUi) -> void:
	"""Insert a new comment above the specified comment."""
	_insert_comment_relative_to(bound_comment, 0)

func _on_comment_insert_below(signal_node, bound_comment: FKCommentUi) -> void:
	"""Insert a new comment below the specified comment."""
	_insert_comment_relative_to(bound_comment, 1)

func _on_comment_insert_event_above(signal_node, bound_comment: FKCommentUi) -> void:
	"""Insert a new event above the specified comment."""
	pending_target_row = bound_comment
	_start_add_workflow("event_above_target", bound_comment)

func _on_comment_insert_event_below(signal_node, bound_comment: FKCommentUi) -> void:
	"""Insert a new event below the specified comment."""
	pending_target_row = bound_comment
	_start_add_workflow("event", bound_comment)

func _on_row_insert_comment_below(signal_row, bound_row: FKEventRowUi) -> void:
	"""Insert a new comment below the specified event row."""
	_insert_comment_relative_to(bound_row, 1)

func _insert_comment_relative_to(target_unit: Node, offset: int) -> void:
	"""Insert a new comment relative to a target block (0 = above, 1 = below)."""
	_push_undo_state()
	
	var data := FKComment.new()
	data.text = ""
	
	var comment := _create_unit_ui(data)
	blocks_container.add_child(comment)
	
	# Calculate insert position
	var insert_idx := target_unit.get_index() + offset
	blocks_container.move_child(comment, insert_idx)
	
	_show_content_state()

func _on_condition_selected_in_row(condition_node: FKConditionUnitUi) -> void:
	"""Handle condition item selection."""
	# Deselect previous row
	if valid_selected_row and selected_row.has_method("set_selected"):
		selected_row.set_selected(false)
	selected_row = null
	
	# Deselect previous item
	_deselect_item()
	
	# Select new item
	selected_item = condition_node
	if selected_item and selected_item.has_method("set_selected"):
		selected_item.set_selected(true)

func _on_action_selected_in_row(action_node: FKActionUnitUi) -> void:
	"""Handle action item selection."""
	# Deselect previous row
	if valid_selected_row and selected_row.has_method("set_selected"):
		selected_row.set_selected(false)
	selected_row = null
	
	# Deselect previous item
	_deselect_item()
	
	# Select new item
	selected_item = action_node
	if action_node:
		action_node.set_selected(true)

func _deselect_item() -> void:
	"""Deselect current condition/action item."""
	if valid_selected_item and selected_item is FKUnitUi:
		selected_item.set_selected(false)
	selected_item = null

func _deselect_all() -> void:
	"""Deselect all rows and items."""
	if valid_selected_row and selected_row is FKUnitUi:
		selected_row.set_selected(false)
	selected_row = null
	_deselect_item()

# === Workflow System ===

func _start_add_workflow(block_type: String, target_row: Node = null) -> void:
	"""Start workflow to add a new block."""
	if not editor_interface:
		return
	pending_block_type = block_type
	pending_target_row = target_row
	
	var scene_root := editor_interface.get_edited_scene_root()
	if not scene_root:
		return
	
	select_node_modal.populate_from_scene(scene_root)
	_popup_centered_on_editor(select_node_modal)

var select_node_modal: FKSelectNodeModal:
	get:
		return modal_manager.select_node_modal
		
var select_condition_modal: FKSelectConditionModal:
	get:
		return modal_manager.select_condition_modal

var select_action_modal: FKSelectActionModal:
	get:
		return modal_manager.select_action_modal
		
var select_event_modal: FKSelectEventModal:
	get:
		return modal_manager.select_event_modal
		
var expression_modal: FKExpressionEditorModal:
	get:
		return modal_manager.expression_modal

func _on_node_selected(node_path: String, node_class: String) -> void:
	"""
	Node selected in workflow. This should execute when it's time to edit an FKUnit
	through the editor.
	"""
	pending_node_path = node_path
	select_node_modal.hide()
	
	match pending_block_type:
		"event", "event_replace", "event_in_group":
			select_event_modal.populate_events(node_path, node_class)
			_popup_centered_on_editor(select_event_modal)
		"condition", "condition_replace":
			select_condition_modal.populate_conditions(node_path, node_class)
			_popup_centered_on_editor(select_condition_modal)
		"action", "action_replace":
			select_action_modal.populate_actions(node_path, node_class)
			_popup_centered_on_editor(select_action_modal)
		"branch_condition", "branch_condition_edit", "elseif_condition":
			select_condition_modal.populate_conditions(node_path, node_class)
			_popup_centered_on_editor(select_condition_modal)
		"branch_action":
			select_action_modal.populate_actions(node_path, node_class)
			_popup_centered_on_editor(select_action_modal)

func _on_event_selected(node_path: String, event_id: String, inputs: Array) -> void:
	"""Event type selected."""
	pending_id = event_id
	select_event_modal.hide()
	
	if inputs.size() > 0:
		expression_modal.populate_inputs(node_path, event_id, inputs)
		_popup_centered_on_editor(expression_modal)
	else:
		if pending_block_type == "event_replace":
			_replace_event({})
		elif pending_block_type == "event_in_group":
			_finalize_event_in_group({})
		elif pending_block_type == "event_above_target":
			_finalize_event_above_target({})
		else:
			_finalize_event_creation({})

func _on_condition_selected(node_path: String, condition_id: String, inputs: Array) -> void:
	"""Condition type selected."""
	pending_id = condition_id
	select_condition_modal.hide()
	
	if inputs.size() > 0:
		expression_modal.populate_inputs(node_path, condition_id, inputs)
		_popup_centered_on_editor(expression_modal)
	else:
		if pending_block_type == "condition_replace":
			_replace_condition({})
		elif pending_block_type == "branch_condition":
			_finalize_branch_creation({})
		elif pending_block_type == "branch_condition_edit":
			_update_branch_condition({})
		elif pending_block_type == "elseif_condition":
			_finalize_elseif_creation({})
		else:
			_finalize_condition_creation({})

func _on_action_selected_in_modal(node_path: String, action_id: String, inputs: Array) -> void:
	"""For right when the user chooses what type of Action to add to a block."""
	pending_id = action_id
	select_action_modal.hide()
	
	if inputs.size() > 0:
		expression_modal.populate_inputs(node_path, action_id, inputs)
		_popup_centered_on_editor(expression_modal)
	else:
		if pending_block_type == "action_replace":
			_replace_action({})
		elif pending_block_type == "branch_action":
			_finalize_branch_action_creation({})
		else:
			_finalize_action_creation({})

func _on_expressions_confirmed(_node_path: String, _id: String, expressions: Dictionary) -> void:
	"""Expressions entered."""
	expression_modal.hide()
	
	match pending_block_type:
		"event":
			_finalize_event_creation(expressions)
		"event_in_group":
			_finalize_event_in_group(expressions)
		"event_above_target":
			_finalize_event_above_target(expressions)
		"condition":
			_finalize_condition_creation(expressions)
		"action":
			_finalize_action_creation(expressions)
		"event_edit":
			_update_event_inputs(expressions)
		"condition_edit":
			_update_condition_inputs(expressions)
		"action_edit":
			_update_action_inputs(expressions)
		"event_replace":
			_replace_event(expressions)
		"condition_replace":
			_replace_condition(expressions)
		"action_replace":
			_replace_action(expressions)
		"branch_condition":
			_finalize_branch_creation(expressions)
		"branch_condition_edit":
			_update_branch_condition(expressions)
		"elseif_condition":
			_finalize_elseif_creation(expressions)
		"branch_action":
			_finalize_branch_action_creation(expressions)
		"branch_evaluation":
			_finalize_branch_evaluation_creation(expressions)
		"branch_evaluation_edit":
			_update_branch_evaluation(expressions)
		"elseif_evaluation":
			_finalize_elseif_evaluation_creation(expressions)

func _finalize_event_creation(inputs: Dictionary) -> void:
	"""Create and add event row (GDevelop-style)."""
	# Push undo state before adding event
	_push_undo_state()
	
	# Generate new block_id for new events (pass empty string to auto-generate)
	var data := FKEventUnit.new(pending_id, pending_node_path)
	data.inputs = inputs
	data.conditions = [] as Array[FKConditionUnit]
	data.actions = [] as Array[FKActionUnit]
	
	var row := _create_unit_ui(data)
	
	if pending_target_row:
		var insert_idx := pending_target_row.get_index() + 1
		blocks_container.add_child(row)
		blocks_container.move_child(row, insert_idx)
	else:
		blocks_container.add_child(row)
	
	_show_content_state()
	_reset_workflow()

func _finalize_event_above_target(inputs: Dictionary) -> void:
	"""Create and add event row above the target (GDevelop-style)."""

	# Push undo state before adding event
	_push_undo_state()
	
	# Generate new block_id for new events (pass empty string to auto-generate)
	var data := FKEventUnit.new(pending_id, pending_node_path)
	data.inputs = inputs
	data.conditions = [] as Array[FKConditionUnit]
	data.actions = [] as Array[FKActionUnit]
	
	var row := _create_unit_ui(data)
	
	if pending_target_row:
		var insert_idx := pending_target_row.get_index()  # Insert at same position (above)
		blocks_container.add_child(row)
		blocks_container.move_child(row, insert_idx)
	else:
		blocks_container.add_child(row)
	
	_show_content_state()
	_reset_workflow()


func _finalize_event_in_group(inputs: Dictionary) -> void:
	"""Create and add event inside a group."""
	if not pending_target_group:
		_reset_workflow()
		return
	
	# Push undo state before adding event
	_push_undo_state()
	
	# Generate new block_id for new events (pass empty string to auto-generate)
	var data := FKEventUnit.new(pending_id, pending_node_path)
	data.inputs = inputs
	data.conditions = [] as Array[FKConditionUnit]
	data.actions = [] as Array[FKActionUnit]
	
	# Add the event data to the group
	if pending_target_group.has_method("add_event_to_group"):
		pending_target_group.add_event_to_group(data)
	
	_show_content_state()
	_reset_workflow()

func _finalize_condition_creation(inputs: Dictionary) -> void:
	"""Add condition to the current event row."""
	# Push undo state before adding condition
	_push_undo_state()
	
	var data := FKConditionUnit.new()
	data.condition_id = pending_id
	data.target_node = pending_node_path
	data.inputs = inputs
	data.negated = false
	data.actions = [] as Array[FKActionUnit]
	
	if pending_target_row and pending_target_row.has_method("add_condition"):
		pending_target_row.add_condition(data)
	
	_show_content_state()
	_reset_workflow()

func _finalize_action_creation(inputs: Dictionary) -> void:
	"""Add action to the current event row."""
	# Push undo state before adding action
	_push_undo_state()
	
	var data := FKActionUnit.new()
	data.action_id = pending_id
	data.target_node = pending_node_path
	data.inputs = inputs
	
	if pending_target_row and pending_target_row.has_method("add_action"):
		pending_target_row.add_action(data)
	
	_show_content_state()
	_reset_workflow()

func _update_event_inputs(expressions: Dictionary) -> void:
	"""Update existing event row with new inputs."""
	# Push undo state before editing event
	_push_undo_state()
	
	if pending_target_row:
		var data: FKUnit = pending_target_row.get_unit()
		if data:
			data.inputs = expressions
			pending_target_row.update_display()
	_reset_workflow()
	_save_sheet()

func _update_condition_inputs(expressions: Dictionary) -> void:
	"""Update existing condition item with new inputs."""
	# Push undo state before editing condition
	_push_undo_state()
	
	if pending_target_item:
		var data := pending_target_item.get_unit()
		if data:
			data.inputs = expressions
			pending_target_item.update_display()
	_reset_workflow()
	_save_sheet()

func _update_action_inputs(expressions: Dictionary) -> void:
	"""Update existing action item with new inputs."""
	# Push undo state before editing action
	_push_undo_state()
	
	if pending_target_item:
		var data := pending_target_item.get_unit()
		if data:
			data.inputs = expressions
			pending_target_item.update_display()
	_reset_workflow()
	_save_sheet()

func _replace_event(expressions: Dictionary) -> void:
	"""Replace existing event row with new type."""
	if not pending_target_row:
		_reset_workflow()
		return
	
	# Push undo state before replacing event
	_push_undo_state()
	
	# Get old row's position and conditions/actions
	var old_unit: FKUnit = pending_target_row.get_unit()
	var old_index := pending_target_row.get_index()
	var old_parent := pending_target_row.get_parent()
	
	# Create new event data, preserving personal id
	var old_unit_id: int = old_unit.uid
	var new_unit := FKEventUnit.new(pending_id, pending_node_path)
	new_unit.uid = old_unit_id
	new_unit.inputs = expressions
	new_unit.conditions = old_unit.conditions if old_unit else ([] as Array[FKConditionUnit])
	new_unit.actions = old_unit.actions if old_unit else ([] as Array[FKActionUnit])
	
	# Create new row
	var new_row := _create_unit_ui(new_unit)
	
	# Remove old row and insert new one at same position
	if old_parent:
		old_parent.remove_child(pending_target_row)
		
	pending_target_row.queue_free()
	
	# Add to the same parent (blocks_container or children_container within group)
	if old_parent:
		if old_parent is FKUnitContainerUi and new_row is FKUnitUi:
			old_parent.add_child(new_row)
		else:
			old_parent.add_child(new_row)
		old_parent.move_child(new_row, old_index)
	else:
		# Fallback if no parent found
		blocks_container.add_child(new_row)
		blocks_container.move_child(new_row, old_index)
	
	# If parent is a container inside a group, find the group and sync its data
	if old_parent:
		var parent_to_sync := old_parent
		# If parent is children_container (inside a group), get the group from metadata
		if old_parent.has_meta("_parent_group"):
			parent_to_sync = old_parent.get_meta("_parent_group")
		
		if parent_to_sync and parent_to_sync.has_method("_sync_children_to_data"):
			parent_to_sync._sync_children_to_data()
	
	_reset_workflow()
	_save_sheet()

func _replace_condition(expressions: Dictionary) -> void:
	"""Replace condition is not used in GDevelop-style layout."""
	_reset_workflow()

func _replace_action(expressions: Dictionary) -> void:
	"""Replace action is not used in GDevelop-style layout."""
	_reset_workflow()

func _reset_workflow() -> void:
	"""Clear workflow state."""
	pending_block_type = ""
	pending_node_path = ""
	pending_id = ""
	pending_target_row = null
	pending_target_item = null
	pending_target_group = null
	pending_target_branch = null
	pending_branch_id = ""

# === Event Row Handlers ===

func _on_row_insert_below(signal_row, bound_row: FKEventRowUi) -> void:
	pending_target_row = bound_row
	_start_add_workflow("event", bound_row)

func _on_row_replace(signal_row, bound_row: FKEventRowUi) -> void:
	pending_target_row = bound_row
	pending_block_type = "event_replace"
	
	# Get current node path from the row being replaced
	var data := bound_row.get_unit()
	if data:
		pending_node_path = str(data.target_node)
	
	# Open node selector
	var scene_root := editor_interface.get_edited_scene_root()
	if not scene_root:
		return
	
	select_node_modal.populate_from_scene(scene_root)
	_popup_centered_on_editor(select_node_modal)

func _on_row_delete(signal_row, bound_row) -> void:
	# Push undo state before deleting row
	_push_undo_state()
	
	# Only delete if this row is a direct child of blocks_container
	# (event rows inside groups are handled by the group itself)
	if bound_row.get_parent() == blocks_container:
		blocks_container.remove_child(bound_row)
		bound_row.queue_free()

func _on_row_edit(signal_row, bound_row: FKEventRowUi) -> void:
	var data: FKUnit = bound_row.get_unit() if bound_row != null \
	else null
	if not data:
		return
	
	# Get event provider to check if it has inputs
	var provider_inputs = []
	for provider in registry.event_providers:
		if provider.has_method("get_id") and provider.get_id() == data.event_id:
			if provider.has_method("get_inputs"):
				provider_inputs = provider.get_inputs()
			break
	
	if provider_inputs.size() > 0:
		# Set up editing mode
		pending_target_row = bound_row
		pending_block_type = "event_edit"
		pending_id = data.event_id
		pending_node_path = str(data.target_node)
		
		# Open expression modal with current values
		expression_modal.populate_inputs(str(data.target_node), data.event_id, provider_inputs, data.inputs)
		_popup_centered_on_editor(expression_modal)
	else:
		print("[FKMainEditor]: Event has no inputs to edit")
		pass

func _on_row_add_condition(signal_row, bound_row: FKEventRowUi) -> void:
	pending_target_row = bound_row
	pending_target_branch = null
	_start_add_workflow("condition", bound_row)

func _on_row_add_action(signal_row, bound_row: FKEventRowUi) -> void:
	pending_target_row = bound_row
	pending_target_branch = null
	_start_add_workflow("action", bound_row)

# === Branch Handlers ===

func _on_row_add_branch(signal_row, branch_id: String, bound_row: FKEventRowUi) -> void:
	"""Start adding a branch to the event row."""
	pending_target_row = bound_row
	pending_target_branch = null  # Ensure no stale branch target from previous workflow
	pending_branch_id = branch_id
	_start_branch_workflow(branch_id, bound_row)

func _on_branch_add_elseif(branch_item: FKBranchUnitUi, event_row: FKUnitUi) -> void:
	"""Add an Else If branch below an existing branch."""
	pending_target_row = event_row
	pending_target_branch = branch_item

	# Determine the branch provider to pick the right workflow
	var act_data := branch_item.get_unit()
	var bid: String = registry.resolve_branch_id(act_data.branch_id if act_data \
	else "", act_data.branch_type if act_data else "")
	pending_branch_id = bid
	var branch_provider = registry.get_branch_provider(bid) if registry else null
	var input_type: String = branch_provider.get_input_type() if branch_provider and \
	branch_provider.has_method("get_input_type") \
	else "condition"

	if input_type == "condition":
		_start_add_workflow("elseif_condition", event_row)
	else:
		var branch_inputs_def = branch_provider.get_inputs() if branch_provider and \
		branch_provider.has_method("get_inputs") \
		else []
		pending_block_type = "elseif_evaluation"
		if branch_inputs_def.size() > 0:
			expression_modal.populate_inputs("", bid, branch_inputs_def)
			_popup_centered_on_editor(expression_modal)
		else:
			_finalize_elseif_evaluation_creation({})

func _on_nested_branch_add(branch_item: FKBranchUnitUi, branch_id: String, 
event_row: FKEventRowUi) -> void:
	"""Start adding a nested branch inside a branch."""
	pending_target_row = event_row
	pending_target_branch = branch_item
	pending_branch_id = branch_id
	_start_branch_workflow(branch_id, event_row)

func _on_branch_add_else(branch_item: FKBranchUnitUi, event_row: FKEventRowUi) -> void:
	"""Add an Else branch below an existing branch."""
	_push_undo_state()

	var branch_data := branch_item.get_unit()
	if not branch_data or not event_row:
		return

	# Create an else branch action
	var else_data := FKActionUnit.new()
	else_data.is_branch = true
	else_data.branch_type = "else"
	else_data.branch_id = registry.resolve_branch_id(branch_data.branch_id, branch_data.branch_type)
	else_data.branch_condition = null
	else_data.branch_actions = [] as Array[FKActionUnit]

	# Find the array containing this branch (could be nested)
	var actions_array: Array
	if branch_item.parent_branch:
		actions_array = branch_item.parent_branch.get_unit().branch_actions
	else:
		var event_data = event_row.get_event_data()
		if not event_data:
			return
		actions_array = event_data.actions

	# Insert after the current branch
	var idx = actions_array.find(branch_data)
	if idx >= 0:
		actions_array.insert(idx + 1, else_data)
	else:
		actions_array.append(else_data)

	event_row.update_display()

func _on_branch_condition_edit(branch_item: FKBranchUnitUi, event_row: FKEventRowUi) -> void:
	"""Edit the condition or inputs of a branch."""
	var act_data := branch_item.get_unit()
	if not act_data:
		return

	# Determine the branch provider and input type
	var bid: String = registry.resolve_branch_id(act_data.branch_id, act_data.branch_type)
	var branch_provider = registry.get_branch_provider(bid)
	var input_type: String = branch_provider.get_input_type() if branch_provider and branch_provider.has_method("get_input_type") \
	else "condition"

	pending_target_row = event_row
	pending_target_branch = branch_item
	pending_branch_id = bid

	if input_type == "condition":
		if not act_data.branch_condition:
			return
		var cond := act_data.branch_condition
		var provider_inputs = []
		for provider in registry.condition_providers:
			if provider.has_method("get_id") and provider.get_id() == cond.condition_id:
				if provider.has_method("get_inputs"):
					provider_inputs = provider.get_inputs()
				break

		pending_block_type = "branch_condition_edit"
		pending_id = cond.condition_id
		pending_node_path = str(cond.target_node)

		if provider_inputs.size() > 0:
			expression_modal.populate_inputs(str(cond.target_node), cond.condition_id, provider_inputs, cond.inputs)
			_popup_centered_on_editor(expression_modal)
		else:
			# No inputs but user wants to change condition type - open node selector
			_start_add_workflow("branch_condition_edit", event_row)
	else:
		# Evaluation type — open expression modal with the branch's inputs
		var branch_inputs_def: Array = branch_provider.get_inputs() if branch_provider and \
		branch_provider.has_method("get_inputs") \
		else []
		pending_block_type = "branch_evaluation_edit"
		if branch_inputs_def.size() > 0:
			expression_modal.populate_inputs("", bid, branch_inputs_def, act_data.branch_inputs)
			_popup_centered_on_editor(expression_modal)
		else:
			_update_branch_evaluation({})

func _on_branch_action_add(branch_item: FKBranchUnitUi, event_row: FKEventRowUi) -> void:
	"""Add an action inside a branch."""
	pending_target_row = event_row
	pending_target_branch = branch_item
	_start_add_workflow("branch_action", event_row)

func _on_branch_action_edit(action_item: FKActionUnitUi, branch_item: FKBranchUnitUi, 
event_row: FKEventRowUi) -> void:
	"""Edit an action inside a branch."""
	var act_data := action_item.get_unit()
	if not act_data:
		return

	var provider_inputs: Array = []
	for provider in registry.action_providers:
		if provider.has_method("get_id") and provider.get_id() == act_data.action_id:
			if provider.has_method("get_inputs"):
				provider_inputs = provider.get_inputs()
			break

	if provider_inputs.size() > 0:
		pending_target_row = event_row
		pending_target_item = action_item
		pending_target_branch = branch_item
		pending_block_type = "action_edit"
		pending_id = act_data.action_id
		pending_node_path = str(act_data.target_node)
		expression_modal.populate_inputs(str(act_data.target_node), act_data.action_id, provider_inputs, act_data.inputs)
		_popup_centered_on_editor(expression_modal)
	else:
		print("[FKMainEditor]: Action has no inputs to edit")

func _finalize_branch_creation(inputs: Dictionary) -> void:
	"""Create a condition-type branch and add it to the target's actions."""
	_push_undo_state()

	var cond := _create_new_cond_for_branch(inputs)
	var branch_data := _create_new_branch_unit(cond)
	_add_branch_to_event_row(branch_data)

	_show_content_state()
	_reset_workflow()

func _create_new_cond_for_branch(inputs: Dictionary) -> FKConditionUnit:
	var cond := FKConditionUnit.new()
	cond.condition_id = pending_id
	cond.target_node = pending_node_path
	cond.inputs = inputs
	cond.negated = false
	return cond
	
func _create_new_branch_unit(cond: FKConditionUnit) -> FKActionUnit:
	var branch_data := FKActionUnit.new()
	branch_data.is_branch = true
	branch_data.branch_type = "if"
	branch_data.branch_id = pending_branch_id
	branch_data.branch_condition = cond
	branch_data.branch_actions = [] as Array[FKActionUnit]
	return branch_data
	
func _add_branch_to_event_row(branch_data: FKActionUnit):
	# Not necessarily directly, though. Where _exactly_ we add
	# it depends on what's pending.
	var branch_ui: FKBranchUnitUi = null
	var event_ui: FKEventRowUi = null
	
	if pending_target_branch is FKBranchUnitUi:
		branch_ui = pending_target_branch
	elif pending_target_row is FKEventRowUi:
		event_ui = pending_target_row
	
	var add_as_nested_branch: bool = branch_ui != null
	var add_as_top_level_branch: bool = event_ui != null
	if add_as_nested_branch:
		branch_ui.add_branch_action(branch_data)
	elif add_as_top_level_branch:
		event_ui.add_action(branch_data)


func _finalize_elseif_creation(inputs: Dictionary) -> void:
	"""Create an ELSE IF branch and insert it after the current branch."""
	_push_undo_state()

	var cond := FKConditionUnit.new()
	cond.condition_id = pending_id
	cond.target_node = pending_node_path
	cond.inputs = inputs
	cond.negated = false

	var elseif_data := FKActionUnit.new()
	elseif_data.is_branch = true
	elseif_data.branch_type = "elseif"
	elseif_data.branch_id = registry.resolve_branch_id(
		pending_target_branch.get_unit().branch_id if pending_target_branch else "",
		pending_target_branch.get_unit().branch_type if pending_target_branch else ""
	)
	elseif_data.branch_condition = cond
	elseif_data.branch_actions = [] as Array[FKActionUnit]

	if pending_target_branch and pending_target_row:
		var branch_act_data := pending_target_branch.get_unit()
		# Find the array containing this branch (could be nested)
		var actions_array: Array
		if pending_target_branch.parent_branch:
			actions_array = pending_target_branch.parent_branch.get_unit().branch_actions
		else:
			var event_data: FKUnit = pending_target_row.get_unit()
			if not event_data:
				_reset_workflow()
				return
			actions_array = event_data.actions
		if branch_act_data:
			var idx := actions_array.find(branch_act_data)
			if idx >= 0:
				actions_array.insert(idx + 1, elseif_data)
			else:
				actions_array.append(elseif_data)
			pending_target_row.update_display()

	_show_content_state()
	_reset_workflow()

func _update_branch_condition(expressions: Dictionary) -> void:
	"""Update an existing branch's condition inputs."""
	_push_undo_state()

	if pending_target_branch:
		var act_data := pending_target_branch.get_unit()
		if act_data:
			# Check input type to update the right field
			var bid: String = registry.resolve_branch_id(act_data.branch_id, act_data.branch_type)
			var branch_provider = registry.get_branch_provider(bid)
			var input_type: String = branch_provider.get_input_type() if branch_provider and branch_provider.has_method("get_input_type") else "condition"
			
			if input_type == "condition" and act_data.branch_condition:
				act_data.branch_condition.inputs = expressions
			pending_target_branch.update_display()

	_reset_workflow()
	_save_sheet()

func _finalize_branch_action_creation(inputs: Dictionary) -> void:
	"""Add an action inside a branch."""
	_push_undo_state()

	var data := FKActionUnit.new()
	data.action_id = pending_id
	data.target_node = pending_node_path
	data.inputs = inputs

	if pending_target_branch and pending_target_branch.has_method("add_branch_action"):
		pending_target_branch.add_branch_action(data)
	elif pending_target_branch is FKBranchUnitUi:
		print("[FKMainEditor]: Pending target branch has no add_branch_action method, " +\
		"but it is a FKBranchUnitUi.")
		
	_show_content_state()
	_reset_workflow()

## Start the correct workflow for a branch provider (condition or evaluation).
func _start_branch_workflow(branch_id: String, target_row) -> void:
	var branch_provider = registry.get_branch_provider(branch_id) if registry else null
	if not branch_provider:
		return

	var input_type: String = branch_provider.get_input_type() if branch_provider.has_method("get_input_type") \
	else "condition"

	if input_type == "condition":
		_start_add_workflow("branch_condition", target_row)
	else:
		# Evaluation type — skip node selector, go directly to expression modal
		var branch_inputs_def: Array = branch_provider.get_inputs() if branch_provider.has_method("get_inputs") \
		else []
		pending_block_type = "branch_evaluation"
		pending_target_row = target_row
		if branch_inputs_def.size() > 0:
			expression_modal.populate_inputs("", branch_id, branch_inputs_def)
			_popup_centered_on_editor(expression_modal)
		else:
			_finalize_branch_evaluation_creation({})

## Create an evaluation-type branch (e.g., Repeat).
func _finalize_branch_evaluation_creation(inputs: Dictionary) -> void:
	_push_undo_state()

	var branch_data := FKActionUnit.new()
	branch_data.is_branch = true
	branch_data.branch_type = "if"
	branch_data.branch_id = pending_branch_id
	branch_data.branch_inputs = inputs
	branch_data.branch_actions = [] as Array[FKActionUnit]

	# If pending_target_branch is set, add as nested branch
	if pending_target_branch and pending_target_branch.has_method("add_branch_action"):
		pending_target_branch.add_branch_action(branch_data)
	elif pending_target_row and pending_target_row.has_method("add_action"):
		pending_target_row.add_action(branch_data)

	_show_content_state()
	_reset_workflow()

## Update evaluation inputs on an existing branch.
func _update_branch_evaluation(expressions: Dictionary) -> void:
	_push_undo_state()

	if pending_target_branch:
		var act_data = pending_target_branch.get_unit()
		if act_data:
			act_data.branch_inputs = expressions
			pending_target_branch.update_display()

	_reset_workflow()
	_save_sheet()

## Create an ELSE IF for an evaluation-type branch chain.
func _finalize_elseif_evaluation_creation(expressions: Dictionary) -> void:
	_push_undo_state()

	var elseif_data := FKActionUnit.new()
	elseif_data.is_branch = true
	elseif_data.branch_type = "elseif"
	elseif_data.branch_id = pending_branch_id
	elseif_data.branch_inputs = expressions
	elseif_data.branch_actions = [] as Array[FKActionUnit]

	if pending_target_branch and pending_target_row:
		var branch_act_data := pending_target_branch.get_unit()
		var actions_array: Array
		if pending_target_branch.parent_branch:
			actions_array = pending_target_branch.parent_branch.get_unit().branch_actions
		else:
			var event_data: FKUnit = pending_target_row.get_unit()
			if not event_data:
				_reset_workflow()
				return
			actions_array = event_data.actions
		if branch_act_data:
			var idx = actions_array.find(branch_act_data)
			if idx >= 0:
				actions_array.insert(idx + 1, elseif_data)
			else:
				actions_array.append(elseif_data)
			pending_target_row.update_display()

	_show_content_state()
	_reset_workflow()

# === Condition/Action Edit Handlers ===

func _on_condition_edit_requested(condition_item: FKConditionUnitUi, bound_row) -> void:
	"""Handle double-click on condition to edit its inputs."""
	var cond_data := condition_item.get_unit()
	if not cond_data:
		return
	
	# Get condition provider to check if it has inputs
	var provider_inputs: Array = []
	for provider in registry.condition_providers:
		if provider.has_method("get_id") and provider.get_id() == cond_data.condition_id:
			if provider.has_method("get_inputs"):
				provider_inputs = provider.get_inputs()
			break
	
	if provider_inputs.size() > 0:
		pending_target_row = bound_row
		pending_target_item = condition_item
		pending_block_type = "condition_edit"
		pending_id = cond_data.condition_id
		pending_node_path = str(cond_data.target_node)
		expression_modal.populate_inputs(str(cond_data.target_node), cond_data.condition_id, provider_inputs, cond_data.inputs)
		_popup_centered_on_editor(expression_modal)
	else:
		print("[FKMainEditor]: Condition has no inputs to edit")

func _on_action_edit_requested(action_item: FKActionUnitUi, bound_row: FKUnitUi) -> void:
	"""Handle double-click on action to edit its inputs."""
	var act_data := action_item.get_unit()
	if not act_data:
		return
	
	# Get action provider to check if it has inputs
	var provider_inputs: Array[FKActionInput] = []
	for provider in registry.action_providers:
		if provider.has_method("get_id") and provider.get_id() == act_data.action_id:
			if provider is FKAction:
				provider_inputs = provider.get_inputs()
			break
	
	if provider_inputs.size() > 0:
		pending_target_row = bound_row
		pending_target_item = action_item
		pending_block_type = "action_edit"
		pending_id = act_data.action_id
		pending_node_path = str(act_data.target_node)
		var node_path := str(act_data.target_node)
		expression_modal.populate_inputs(node_path, act_data.action_id, provider_inputs, \
		act_data.inputs)
		_popup_centered_on_editor(expression_modal)
	else:
		print("[FKMainEditor]: Action has no inputs to edit")

# === Drag and Drop Handlers ===

func _on_condition_dropped(source_row: FKEventRowUi, condition_data: FKConditionUnit, 
target_row: FKEventRowUi) -> void:
	"""Handle condition dropped from one event row to another."""
	if not source_row or not target_row or not condition_data:
		return
	
	# Remove from source
	var source_data := source_row.get_unit()
	if source_data:
		var idx := source_data.conditions.find(condition_data)
		if idx >= 0:
			source_data.conditions.remove_at(idx)
			source_row.update_display()
	
	# Add to target
	var target_data := target_row.get_unit()
	if target_data:
		var cond_copy := condition_data.duplicate_block()
		
		target_data.conditions.append(cond_copy)
		target_row.update_display()
	

func _on_action_dropped(source_row: FKEventRowUi, action_data: FKActionUnit, target_row: FKUnitUi) -> void:
	"""Handle action dropped from one event row to another."""
	if not source_row or not target_row or not action_data:
		return
	
	# Remove from source (search recursively in case it's inside a branch)
	var source_data := source_row.get_unit()
	if source_data:
		var idx := source_data.actions.find(action_data)
		if idx >= 0:
			source_data.actions.remove_at(idx)
		else:
			_recursive_remove_action_from_list(source_data.actions, action_data)
		source_row.update_display()
	
	# Add to target
	var target_data := target_row.get_unit()
	if target_data:
		# Create a copy of the action data
		var act_copy := FKActionUnit.new()
		act_copy.action_id = action_data.action_id
		act_copy.target_node = action_data.target_node
		act_copy.inputs = action_data.inputs.duplicate()
		
		target_data.actions.append(act_copy)
		target_row.update_display()
	

func _generate_unique_block_id(event_id: String) -> String:
	"""Generate a unique ID for an event block."""
	return "%s_%d_%d" % [event_id, Time.get_ticks_msec(), randi()]

func get_class() -> String:
	return "FKMainEditor"
