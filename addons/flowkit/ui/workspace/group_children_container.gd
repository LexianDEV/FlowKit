@tool
extends VBoxContainer
## Container for group children that handles drag-drop reordering.
## Handles both internal reordering and external drops from outside the group.

func _can_drop_data(at_position: Vector2, data) -> bool:
	"""Check if we can accept drops."""
	if not data is Dictionary:
		return false
	
	var drag_node = data.get("node")
	var drag_type = data.get("type", "")
	
	if not drag_node or not is_instance_valid(drag_node):
		return false
	
	# Only accept block types (event_row, comment, group)
	if drag_type not in ["event_row", "comment", "group"]:
		return false
	
	var parent_group = get_meta("_parent_group", null)
	
	# Prevent dropping a group into itself or its descendants
	# Check if this group (parent_group) is a descendant of the dragged group
	if drag_type == "group" and parent_group:
		var current = parent_group
		while current:
			if current == drag_node:
				DropIndicatorManager.hide_indicator()
				return false
			current = current.get_parent()
	
	# Show drop indicator via parent group
	if parent_group and parent_group.has_method("_show_drop_indicator"):
		parent_group._show_drop_indicator(at_position, drag_node)
	
	return true


func _drop_data(at_position: Vector2, data) -> void:
	"""Handle drops."""
	DropIndicatorManager.hide_indicator()
	
	if not data is Dictionary:
		return
	
	var drag_node = data.get("node")
	var drag_type = data.get("type", "")
	
	if not drag_node or not is_instance_valid(drag_node):
		return
	
	# Only accept block types
	if drag_type not in ["event_row", "comment", "group"]:
		return
	
	var parent_group = get_meta("_parent_group", null)
	if not parent_group:
		return
	
	# Internal reorder (same parent)
	if drag_node.get_parent() == self:
		if parent_group.has_method("_handle_internal_reorder"):
			parent_group._handle_internal_reorder(drag_node)
	else:
		# External drop - delegate to parent group
		if parent_group.has_method("_handle_drop"):
			parent_group._handle_drop(drag_node, drag_type)
