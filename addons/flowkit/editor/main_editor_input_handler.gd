extends RefCounted
class_name FKMainEditorInputHandler

func initialize(main_ed: FKMainEditor):
	_editor = main_ed
	clipboard = _editor.clipboard
	block_container = _editor.blocks_container
	
var _editor: FKMainEditor
var clipboard: FKClipboardManager
var block_container: BlockContainerUi

func handle_input(event: InputEvent):
	var is_left_click: bool = event is InputEventMouseButton and event.pressed and \
	event.button_index == MOUSE_BUTTON_LEFT
	if is_left_click:
		_on_left_click()
	
	# Only handle key press (not echo/repeat)
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	
	# Handle undo and redo logic when FlowKit panel is visible.
	# This allows undo/redo to work even when keyboard navigating or mouse is outside
	if visible and (_is_mouse_in_editor_area() or _has_focus_in_subtree()):
		var undo_redo_done := _handle_undo_redo_input(event)
		if undo_redo_done:
			viewport.set_input_as_handled()
			return
	
	# Safety: Only act if mouse is within our blocks area for other shortcuts
	if not _is_mouse_in_blocks_area():
		return
	
	# We don't want to go through with any deletion, copying or pasting if the
	# user is editing text.
	if _is_editing_text():
		return
		
	var deleted := false; var copied := false; var pasted := false
	
	if event.keycode == KEY_DELETE:
		deleted = _on_delete_key_pressed()
	elif event.keycode == KEY_C and event.ctrl_pressed:
		copied = _on_copy_input()
	elif event.keycode == KEY_V and event.ctrl_pressed:
		pasted = _on_paste_input()
		
	if deleted or copied or pasted:
		viewport.set_input_as_handled()
	
func _on_left_click():
	var mouse_pos = get_global_mouse_position()
	var anything_selected: bool = selected_row or selected_item
	
	if anything_selected:
		var clicked_outside_all_event_rows = not _is_on_event_row(mouse_pos)
		if clicked_outside_all_event_rows:
			_editor.deselect_all()

# This is a Control func, hence us delegating it to the editor
func get_global_mouse_position() -> Vector2:
	return _editor.get_global_mouse_position() 
	
func _is_on_event_row(mouse_pos: Vector2) -> bool:
	"""Check if the mouse position is over any event row."""
	for block in _editor._get_blocks():
		var global_rect = block.get_global_rect()
		if global_rect.has_point(mouse_pos):
			return true
	return false
	
var visible: bool:
	get:
		return _editor.visible

func _is_mouse_in_editor_area() -> bool:
	"""Check if mouse is hovering over the FlowKit editor panel."""
	var mouse_pos = get_global_mouse_position()
	return _editor.get_global_rect().has_point(mouse_pos)
	
func _has_focus_in_subtree() -> bool:
	"""Check if any child control has focus."""
	var focused = viewport.gui_get_focus_owner()
	if focused == null:
		return false
	return focused == _editor or _editor.is_ancestor_of(focused)
	
func _is_mouse_in_blocks_area() -> bool:
	"""Check if mouse is hovering over the blocks container."""
	var mouse_pos = get_global_mouse_position()
	var global_rect := block_container.get_global_rect()
	return global_rect.has_point(mouse_pos)
		
var selected_item: Variant:
	get:
		return _editor.selected_item
		
var selected_row: Variant:
	get:
		return _editor.selected_row
		
## Takes an input event, applyin undo or redo if appropriate. If any undos or redos 
## were done, this func returns true. False otherwise.
func _handle_undo_redo_input(event: InputEvent) -> bool:
	if not event.ctrl_pressed:
		return false
		
	var is_undo: bool = event.keycode == KEY_Z 
	var is_redo: bool = event.keycode == KEY_Y or (event.keycode == KEY_Z and event.shift_pressed)

	if is_undo:
		_editor.undo()
	elif is_redo:
		_editor.redo()
	
	var applied: bool = is_undo or is_redo
	return applied

func _is_editing_text() -> bool:
	var focused = viewport.gui_get_focus_owner()
	return focused is TextEdit or focused is LineEdit
	
func _on_delete_key_pressed() -> bool:
	var deleted: bool = true
	
	if valid_selected_item:
		_editor._delete_selected_item()
	elif valid_selected_row:
		_editor._delete_selected_row()
	else:
		deleted = false
		
	return deleted
		
var valid_selected_item: bool:
	get:
		return _editor.valid_selected_item
		
var valid_selected_row: bool:
	get:
		return _editor.valid_selected_row

func _on_copy_input() -> bool:
	if valid_selected_item:
		_copy_selected_item()
	elif valid_selected_row:
		_copy_selected_row()
		
	var copied: bool = _editor.has_valid_selection()
	return copied

func _copy_selected_item():
	if selected_item.has_method("get_action_data"):
		clipboard.copy_action(selected_item.get_action_data())
	elif selected_item.has_method("get_condition_data"):
		clipboard.copy_condition(selected_item.get_condition_data())

func _copy_selected_row():
	if selected_row.has_method("get_event_data"):
		clipboard.copy_event(selected_row.get_event_data())
	elif selected_row.has_method("get_group_data"):
		clipboard.copy_group(selected_row.get_group_data())
	
var viewport: Viewport:
	get:
		return _editor.viewport

func _on_paste_input() -> bool:
	var pasted: bool = true
	
	match clipboard.get_clipboard_type():
		"event":
			_editor._paste_events()
		"action":
			_editor._paste_actions()
		"condition":
			_editor._paste_conditions()
		"group":
			_editor._paste_group()
		_:
			pasted = false
	
	return pasted
	
