@tool
extends MenuBar

signal new_sheet
signal save_sheet
signal generate_providers
signal generate_manifest
signal undo_requested
signal redo_requested

func _on_file_id_pressed(id: int) -> void:
	match id:
		0: # New Event Sheet
			emit_signal("new_sheet")
		1: # Save Event Sheet
			emit_signal("save_sheet")

func _on_edit_id_pressed(id: int) -> void:
	match id:
		0: # Undo
			emit_signal("undo_requested")
		1: # Redo
			emit_signal("redo_requested")
		2: # Generate Providers (separator above)
			emit_signal("generate_providers")
		3: # Generate Manifest (for export)
			emit_signal("generate_manifest")
