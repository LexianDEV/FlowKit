@tool
extends Window

signal subsheet_added(subsheet_name: String)
signal subsheet_edited(subsheet_id: String, new_name: String)
signal subsheet_deleted(subsheet_id: String)
signal edit_subsheet_actions(subsheet_id: String)

var current_sheet: FKEventSheet = null
var editor_interface: EditorInterface

@onready var subsheet_list := $VBoxContainer/SubsheetList
@onready var add_button := $VBoxContainer/ButtonContainer/AddButton
@onready var close_button := $VBoxContainer/ButtonContainer/CloseButton

func _ready() -> void:
	if add_button:
		add_button.pressed.connect(_on_add_button_pressed)
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	
	# Set window properties
	title = "Manage Subsheets"
	size = Vector2i(500, 400)
	min_size = Vector2i(400, 300)

func set_editor_interface(interface: EditorInterface) -> void:
	editor_interface = interface

func set_sheet(sheet: FKEventSheet) -> void:
	current_sheet = sheet
	_refresh_list()

## Refresh the subsheet list display.
func _refresh_list() -> void:
	# Clear existing items
	for child in subsheet_list.get_children():
		child.queue_free()
	
	if not current_sheet:
		return
	
	# Add subsheets
	for subsheet in current_sheet.subsheets:
		var item = _create_subsheet_item(subsheet)
		subsheet_list.add_child(item)

## Create a UI item for a subsheet.
func _create_subsheet_item(subsheet: FKSubsheet) -> HBoxContainer:
	var container = HBoxContainer.new()
	container.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	
	# Name label
	var name_label = Label.new()
	name_label.text = subsheet.name
	name_label.set_h_size_flags(Control.SIZE_EXPAND_FILL)
	container.add_child(name_label)
	
	# Edit button
	var edit_btn = Button.new()
	edit_btn.text = "Edit Actions"
	edit_btn.pressed.connect(func(): emit_signal("edit_subsheet_actions", subsheet.subsheet_id))
	container.add_child(edit_btn)
	
	# Rename button
	var rename_btn = Button.new()
	rename_btn.text = "Rename"
	rename_btn.pressed.connect(func(): _on_rename_subsheet(subsheet))
	container.add_child(rename_btn)
	
	# Delete button
	var delete_btn = Button.new()
	delete_btn.text = "Delete"
	delete_btn.pressed.connect(func(): _on_delete_subsheet(subsheet))
	container.add_child(delete_btn)
	
	return container

## Handle add subsheet button press.
func _on_add_button_pressed() -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "New Subsheet"
	dialog.ok_button_text = "Create"
	
	var vbox = VBoxContainer.new()
	var label = Label.new()
	label.text = "Subsheet Name:"
	vbox.add_child(label)
	
	var line_edit = LineEdit.new()
	line_edit.text = "New Subsheet"
	line_edit.select_all()
	vbox.add_child(line_edit)
	
	dialog.add_child(vbox)
	dialog.confirmed.connect(func():
		var name = line_edit.text.strip_edges()
		if name.is_empty():
			name = "New Subsheet"
		emit_signal("subsheet_added", name)
		_refresh_list()
	)
	
	add_child(dialog)
	dialog.popup_centered(Vector2i(300, 150))
	line_edit.grab_focus()

## Handle renaming a subsheet.
func _on_rename_subsheet(subsheet: FKSubsheet) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "Rename Subsheet"
	dialog.ok_button_text = "Rename"
	
	var vbox = VBoxContainer.new()
	var label = Label.new()
	label.text = "New Name:"
	vbox.add_child(label)
	
	var line_edit = LineEdit.new()
	line_edit.text = subsheet.name
	line_edit.select_all()
	vbox.add_child(line_edit)
	
	dialog.add_child(vbox)
	dialog.confirmed.connect(func():
		var new_name = line_edit.text.strip_edges()
		if not new_name.is_empty():
			emit_signal("subsheet_edited", subsheet.subsheet_id, new_name)
			_refresh_list()
	)
	
	add_child(dialog)
	dialog.popup_centered(Vector2i(300, 150))
	line_edit.grab_focus()

## Handle deleting a subsheet.
func _on_delete_subsheet(subsheet: FKSubsheet) -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "Delete Subsheet"
	dialog.dialog_text = "Are you sure you want to delete '%s'?" % subsheet.name
	dialog.ok_button_text = "Delete"
	
	dialog.confirmed.connect(func():
		emit_signal("subsheet_deleted", subsheet.subsheet_id)
		_refresh_list()
	)
	
	add_child(dialog)
	dialog.popup_centered()

func _on_close_button_pressed() -> void:
	hide()
