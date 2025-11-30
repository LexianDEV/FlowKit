@tool
extends VBoxContainer

signal block_moved
signal empty_area_clicked
signal before_block_moved  # Emitted before block is moved for undo state capture

func _can_drop_data(at_position: Vector2, data) -> bool:
	if not data is Dictionary:
		return false
	if not data.has("node"):
		return false
	
	var node = data["node"]
	return is_instance_valid(node) and node.get_parent() == self

func _drop_data(at_position: Vector2, data) -> void:
	if not data is Dictionary or not data.has("node"):
		return
	
	var node = data["node"]
	if not is_instance_valid(node) or node.get_parent() != self:
		return
	
	# In GDevelop-style, each event row is self-contained (no children to move with it)
	var current_idx = node.get_index()
	var target_idx = _calculate_drop_index(at_position)
	
	# No-op if target is the same position
	if target_idx == current_idx or target_idx == current_idx + 1:
		return
	
	# Adjust target if moving down (index shifts after removal)
	if target_idx > current_idx:
		target_idx -= 1
	
	# Emit before signal for undo state capture
	before_block_moved.emit()
	
	# Move the block
	remove_child(node)
	add_child(node)
	move_child(node, target_idx)
	
	block_moved.emit()

func _calculate_drop_index(at_position: Vector2) -> int:
	for i in range(get_child_count()):
		var child = get_child(i)
		if not child.visible or child.name == "EmptyLabel":
			continue
		
		var rect = child.get_rect()
		if at_position.y < rect.position.y + rect.size.y * 0.5:
			return i
	
	return get_child_count()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if click is on empty area (not on any child)
		var mouse_pos = event.position
		var clicked_on_child = false
		for child in get_children():
			if child.visible and child.name != "EmptyLabel":
				if child.get_rect().has_point(mouse_pos):
					clicked_on_child = true
					break
		
		if not clicked_on_child:
			empty_area_clicked.emit()
