##
## Represents a Comment Block in the editor UI
##
@tool
extends FKUnitUi
class_name FKCommentUi

signal delete_requested
signal insert_comment_above_requested(comment_node)
signal insert_comment_below_requested(comment_node)
signal insert_event_above_requested(comment_node)
signal insert_event_below_requested(comment_node)

@export_category("Controls")
@export var text_edit: TextEdit
## Shown when this Block is not being edited.
@export var display_label: Label
@export var panel: PanelContainer

@export_category("Styles")
@export var normal_style: StyleBoxFlat
@export var selected_style: StyleBoxFlat
# ^Different styles for different modes

func _toggle_subs(on: bool):
	if on && !_is_subbed:
		text_edit.focus_exited.connect(_on_text_edit_focus_exited)
		
	elif !on && _is_subbed:
		text_edit.focus_exited.disconnect(_on_text_edit_focus_exited)
		
	_is_subbed = on

func _on_text_edit_focus_exited():
	_update_block_text()
		
func _update_block_text():
	if not _comment_block:
		printerr("FKCommentUi: I got no block to work with, so I can't update the text")
		return
	
	var new_text = text_edit.text
	if _comment_block.text != new_text:
		_comment_block.text = new_text
		update_display()
		block_contents_changed.emit()
		

var _comment_block: FKComment:
	get:
		if _block is FKComment:
			return _block as FKComment
		else:
			return null

	
func update_display() -> void:
	_update_text_edit()
	_update_display_label()
	_update_styling()

func _update_text_edit():
	text_edit.text = _comment_block.text if _we_have_comment_with_text \
	else ""
	
	text_edit.visible = _edit_mode_on
	
var _we_have_comment_with_text: bool:
	get:
		return _comment_block != null && _comment_block.text.length() > 0	

var _edit_mode_on := false

func _update_display_label():
	display_label.text = _comment_block.text if _we_have_comment_with_text \
	else "Add comment..."
	
	display_label.visible = !_edit_mode_on 

## Of the panel in particular.
func _update_styling() -> void:
	var style: StyleBox = selected_style if is_selected \
	else normal_style
		
	panel.add_theme_stylebox_override("panel", style)
	
func _input(event: InputEvent) -> void:
	# Note that this is triggered _before_ gui-specific handling
	var left_click = event is InputEventMouseButton and event.pressed and \
	event.button_index == MOUSE_BUTTON_LEFT
	if _edit_mode_on and left_click:
		_on_left_click_while_editing()
		
func _on_left_click_while_editing():
	var mouse_pos = get_global_mouse_position()
	var clicked_within_this_comment = get_global_rect().has_point(mouse_pos)
	_set_edit_mode(clicked_within_this_comment)

func _set_edit_mode(on: bool):
	if _edit_mode_on == on:
		return
		
	_edit_mode_on = on
	if !on:
		text_edit.release_focus() 
		# ^This makes sure that we update the block meta with text_edit's contents
		# in time. Without this, our changes to text_edit just get reverted.
		
	update_display()
	if edit_mode_on:
		_focus_end_of_text_edit()
	
var edit_mode_on: bool:
	get:
		return _edit_mode_on
	

func _focus_end_of_text_edit():
	text_edit.grab_focus()
	
	var last_line_index := text_edit.get_line_count() - 1
	text_edit.set_caret_line(last_line_index)
	
	var last_line_text := text_edit.get_line(last_line_index)
	var end_of_last_line := last_line_text.length()
	text_edit.set_caret_column(end_of_last_line)
	
func _gui_input(event: InputEvent) -> void:
	var mouse_press: bool = event is InputEventMouseButton and event.pressed
	if not mouse_press:
		return
		
	if event.button_index == MOUSE_BUTTON_LEFT:
		_on_left_click(event)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_on_right_click(event)
		
func _on_left_click(event: InputEventMouseButton):
	set_selected(true)
	if event.double_click and not _edit_mode_on:
		_set_edit_mode(true)
	accept_event()
	
func _validate_block(to_set: FKUnit):
	var is_valid: bool = to_set == null || to_set is FKComment
	if not is_valid:
		var error_message = "[FKCommentUi _validate_block]: FKCommentUi instances are meant to only " +\
		"handle Comment Blocks, not %s" % [to_set.get_class()]
		printerr(error_message)
	
	if to_set is not FKComment:
		print("FKCommentUi: No longer representing a comment block")
	return is_valid
		
		
func _on_block_changed():
	edit_mode_on = false
	
func _get_drag_data(_at_position: Vector2) -> FKDragData:
	if edit_mode_on:
		return null
	
	var preview := _create_drag_preview()
	set_drag_preview(preview)
	
	var drag_data := FKDragData.new(DragTarget.Type.COMMENT, self)
	return drag_data

func _create_drag_preview() -> Control:
	var preview := Label.new()
	var text = _comment_block.text if _comment_block else ""
	preview.text = "📝 " + (text.substr(0, 30) if text.length() > 30 else text)
	preview.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3, 0.9))
	return preview
	
func _can_drop_data(at_position: Vector2, data) -> bool:
	if data is not FKDragData:
		printerr("FKCommentUi: _can_drop_data was not given an FKDragData. It got: " \
		+ str(data))
		return false
		
	var drag_data = data as FKDragData
	# For event_row, comment, or group drags, forward to parent (blocks_container or group)
	if drag_data.type in [DragTarget.Type.EVENT_ROW, DragTarget.Type.COMMENT, \
	DragTarget.Type.GROUP]:
		var parent = get_parent()
		if parent and parent.has_method("_can_drop_data"):
			var parent_pos = at_position + position
			return parent._can_drop_data(parent_pos, data)
	
	return false

func _drop_data(at_position: Vector2, data) -> void:
	if data is not FKDragData:
		printerr("FKCommentUi: _drop_data was not given an FKDragData. It got: " \
		+ str(data))
		return
		
	var drag_data = data as FKDragData
	
	# For event_row, comment, or group drags, forward to parent
	if drag_data.type in [DragTarget.Type.EVENT_ROW, DragTarget.Type.COMMENT, \
	DragTarget.Type.GROUP]:
		var parent = get_parent()
		if parent and parent.has_method("_drop_data"):
			var parent_pos = at_position + position
			parent._drop_data(parent_pos, data)

func _on_right_click(event: InputEventMouseButton):
	_show_context_menu(event.global_position)
	accept_event()
	
func _show_context_menu(pos: Vector2) -> void:
	_menu = PopupMenu.new()
	_add_context_menu_insertion_indicators(_menu)
	_menu.add_item("Edit Comment", _edit_choice)
	_menu.add_separator()
	_menu.add_item("Delete Comment", _delete_choice)
	add_child(_menu)
	_menu.position = Vector2i(pos)
	_menu.popup()
	_listen_for_context_menu_events(_menu)

var _menu: PopupMenu = null

func _add_context_menu_insertion_indicators(menu: PopupMenu):
	menu.add_item("Insert Event Above", _insert_event_above_choice)
	menu.add_item("Insert Event Below", _insert_event_below_choice)
	menu.add_separator()
	menu.add_item("Insert Comment Above", _insert_comment_above_choice)
	menu.add_item("Insert Comment Below", _insert_comment_below_choice)
	menu.add_separator()

func _listen_for_context_menu_events(menu: PopupMenu):
	menu.id_pressed.connect(_on_context_menu_id_pressed)
	
func _on_context_menu_id_pressed(id: int):
	match id:
		_delete_choice:
			delete_requested.emit()
		_edit_choice:
			_set_edit_mode(true)
		_insert_event_above_choice:
			insert_event_above_requested.emit(self)
		_insert_event_below_choice:
			insert_event_below_requested.emit(self)
		_insert_comment_above_choice:
			insert_comment_above_requested.emit(self)
		_insert_comment_below_choice:
			insert_comment_below_requested.emit(self)
	
	if _menu and is_instance_valid(_menu):
		_menu.id_pressed.disconnect(_on_context_menu_id_pressed)
		_menu.queue_free() # We won't need it around once an option's clicked
		
	_menu = null

# Choice Ids
const _delete_choice: int = 0
const _edit_choice: int = 1
const _insert_event_above_choice: int = 10
const _insert_event_below_choice: int = 11
const _insert_comment_above_choice: int = 12
const _insert_comment_below_choice: int = 13

func get_block() -> FKComment:
	return _block
	
func _to_string() -> String:
	var result := "FKCommentUi"
	
	if _block != null:
		result += "\nhas block: true"
	return result

func _get_class() -> String:
	return "FKCommentUi"
	
func _on_registry_set():
	# No-op
	pass
