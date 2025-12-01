@tool
extends VBoxContainer
## Container for group children that handles internal drag-drop reordering.

func _can_drop_data(at_position: Vector2, data) -> bool:
	"""Check if we can accept drops for internal reordering."""
	if not data is Dictionary:
		return false
	
	var drag_node = data.get("node")
	var drag_type = data.get("type", "")
	
	if not drag_node or not is_instance_valid(drag_node):
		return false
	
	# Only handle internal reordering (same parent)
	if drag_node.get_parent() == self:
		var parent_group = get_meta("_parent_group", null)
		if parent_group and parent_group.has_method("_show_drop_indicator"):
			parent_group._show_drop_indicator(at_position, drag_node)
		return true
	
	return false


func _drop_data(at_position: Vector2, data) -> void:
	"""Handle drops for internal reordering."""
	DropIndicatorManager.hide_indicator()
	
	if not data is Dictionary:
		return
	
	var drag_node = data.get("node")
	
	if not drag_node or not is_instance_valid(drag_node):
		return
	
	# Only handle internal reorders
	if drag_node.get_parent() == self:
		var parent_group = get_meta("_parent_group", null)
		if parent_group and parent_group.has_method("_handle_internal_reorder"):
			parent_group._handle_internal_reorder(drag_node)
