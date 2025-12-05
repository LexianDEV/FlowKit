@tool
extends MarginContainer

signal selected(comment_node)
signal delete_requested
signal data_changed
signal insert_comment_above_requested(comment_node)
signal insert_comment_below_requested(comment_node)
signal insert_event_above_requested(comment_node)
signal insert_event_below_requested(comment_node)

var comment_data: FKCommentBlock
var is_selected: bool = false
var is_editing: bool = false

@onready var text_edit: TextEdit = $Panel/MarginContainer/TextEdit
@onready var display_label: Label = $Panel/MarginContainer/DisplayLabel
@onready var panel: PanelContainer = $Panel

const SELECTED_BORDER_COLOR = Color(0.95, 0.85, 0.35, 1.0)
const NORMAL_BORDER_COLOR = Color(0.72, 0.64, 0.3, 1.0)
const SOLID_YELLOW_BG = Color(0.9, 0.8, 0.4, 1.0)
const EDITING_BG = Color(0.55, 0.5, 0.25, 1.0)

func _ready() -> void:
	# Ensure we receive mouse events
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Initialize text_edit with comment_data if available
	if text_edit and comment_data:
		text_edit.text = comment_data.text
	
	if text_edit:
		text_edit.text_changed.connect(_on_text_changed)
	
	_set_display_mode()

func _input(event: InputEvent) -> void:
	# Exit edit mode when clicking anywhere outside this comment
	if is_editing and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		if not get_global_rect().has_point(mouse_pos):
			_set_display_mode()

func set_comment_data(data: FKCommentBlock) -> void:
	comment_data = data
	if text_edit:
		text_edit.text = data.text
	if display_label:
		display_label.text = data.text if data.text != "" else "Add comment..."

func get_comment_data() -> FKCommentBlock:
	return comment_data

func set_selected(value: bool) -> void:
	is_selected = value
	_update_style()

func _set_display_mode() -> void:
	"""Switch to display mode (yellow solid, not editable)."""
	is_editing = false
	
	# Update comment data and emit signal when exiting edit mode
	if text_edit and comment_data:
		var new_text = text_edit.text
		if comment_data.text != new_text:
			comment_data.text = new_text
			data_changed.emit()
	
	if text_edit:
		text_edit.visible = false
	if display_label:
		display_label.visible = true
		if comment_data:
			display_label.text = comment_data.text if comment_data.text != "" else "Add comment..."
	_update_style()

func _set_edit_mode() -> void:
	"""Switch to edit mode (dark bg, editable)."""
	is_editing = true
	if display_label:
		display_label.visible = false
	if text_edit:
		text_edit.visible = true
		text_edit.grab_focus()
		text_edit.set_caret_line(text_edit.get_line_count() - 1)
		text_edit.set_caret_column(text_edit.get_line(text_edit.get_line_count() - 1).length())
	_update_style()

func _update_style() -> void:
	if not panel:
		return
	var style = panel.get_theme_stylebox("panel").duplicate()
	if style is StyleBoxFlat:
		if is_editing:
			style.bg_color = EDITING_BG
		else:
			style.bg_color = SOLID_YELLOW_BG
		
		# Thicker border when selected
		if is_selected:
			style.border_color = SELECTED_BORDER_COLOR
			style.border_width_left = 4
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
		else:
			style.border_color = NORMAL_BORDER_COLOR
			style.border_width_left = 3
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
		
		panel.add_theme_stylebox_override("panel", style)

func _on_text_changed() -> void:
	# Update display label preview but don't save yet
	# Saving happens when edit mode is exited (_set_display_mode)
	pass

func _get_drag_data(_at_position: Vector2):
	if is_editing:
		return null
	
	# Create drag preview
	var preview := Label.new()
	var text = comment_data.text if comment_data else ""
	preview.text = "📝 " + (text.substr(0, 30) if text.length() > 30 else text)
	preview.add_theme_color_override("font_color", Color(0.9, 0.85, 0.3, 0.9))
	set_drag_preview(preview)
	
	return {"node": self, "type": "comment"}

func _can_drop_data(at_position: Vector2, data) -> bool:
	if not data is Dictionary:
		return false
	
	var drag_type = data.get("type", "")
	
	# For event_row, comment, or group drags, forward to parent (blocks_container or group)
	if drag_type in ["event_row", "comment", "group"]:
		var parent = get_parent()
		if parent and parent.has_method("_can_drop_data"):
			var parent_pos = at_position + position
			return parent._can_drop_data(parent_pos, data)
	
	return false

func _drop_data(at_position: Vector2, data) -> void:
	if not data is Dictionary:
		return
	
	var drag_type = data.get("type", "")
	
	# For event_row, comment, or group drags, forward to parent
	if drag_type in ["event_row", "comment", "group"]:
		var parent = get_parent()
		if parent and parent.has_method("_drop_data"):
			var parent_pos = at_position + position
			parent._drop_data(parent_pos, data)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.double_click and not is_editing:
				_set_edit_mode()
				accept_event()
			else:
				selected.emit(self)
				accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_show_context_menu(event.global_position)
			accept_event()

func _show_context_menu(pos: Vector2) -> void:
	var menu = PopupMenu.new()
	menu.add_item("Insert Event Above", 10)
	menu.add_item("Insert Event Below", 11)
	menu.add_separator()
	menu.add_item("Insert Comment Above", 12)
	menu.add_item("Insert Comment Below", 13)
	menu.add_separator()
	menu.add_item("Edit Comment", 1)
	menu.add_separator()
	menu.add_item("Delete Comment", 0)
	add_child(menu)
	menu.position = Vector2i(pos)
	menu.popup()
	menu.id_pressed.connect(func(id):
		match id:
			0:
				delete_requested.emit()
			1:
				_set_edit_mode()
			10:
				insert_event_above_requested.emit(self)
			11:
				insert_event_below_requested.emit(self)
			12:
				insert_comment_above_requested.emit(self)
			13:
				insert_comment_below_requested.emit(self)
		menu.queue_free()
	)
