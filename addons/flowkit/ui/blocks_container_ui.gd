@tool
extends VBoxContainer
class_name BlockContainerUi
## Container for event blocks, comments, and groups in the FlowKit editor.
##
## Handles drag-and-drop reordering of blocks and accepts drops from
## nested groups. Uses DropIndicatorManager for visual feedback.

# === Signals ===
signal block_moved  ## Emitted after a block is moved/reordered
signal empty_area_clicked  ## Emitted when clicking empty space (for deselection)
signal before_block_moved  ## Emitted before block move for undo state capture

# === Internal State ===
var _suppress_block_moved := false  ## Suppress block_moved emission during multi-step operations

# === State ===
var current_drop_index: int = -1  ## Current calculated drop position

# === Lifecycle ===

func _ready() -> void:
	pass


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		_hide_drop_indicator()

# === Block Management ===

func _get_visible_blocks() -> Array[Control]:
	"""Get all visible block children (excluding indicator and labels)."""
	var blocks: Array[Control] = []
	for child in get_children():
		if DropIndicatorManager.is_indicator(child):
			continue
		# Skip invalid or deleted children
		if not is_instance_valid(child) or child.is_queued_for_deletion():
			continue
		if child.visible and child.name != "EmptyLabel":
			blocks.append(child)
	return blocks

# === Drop Indicator ===

func _show_drop_indicator(at_position: Vector2, dragged_node: Node) -> void:
	"""Show drop indicator at the appropriate position."""
	var visible_blocks = _get_visible_blocks()
	if visible_blocks.is_empty():
		DropIndicatorManager.hide_indicator()
		current_drop_index = -1
		return
	
	var result = DropIndicatorManager.calculate_drop_position(self, at_position.y, [dragged_node])
	var target_idx = result["index"]
	var dragged_visual_idx = visible_blocks.find(dragged_node)
	
	# Don't show indicator if dropping at same position
	if dragged_visual_idx >= 0 and (target_idx == dragged_visual_idx or target_idx == dragged_visual_idx + 1):
		DropIndicatorManager.hide_indicator()
		current_drop_index = -1
		return
	
	current_drop_index = target_idx
	DropIndicatorManager.show_indicator(self, result["y_position"], size.x - 20)


func _hide_drop_indicator() -> void:
	"""Hide the drop indicator."""
	DropIndicatorManager.hide_indicator()
	current_drop_index = -1

# === Drag and Drop ===

func _get_drag_node(data) -> Control:
	"""Extract the dragged node from drag data."""
	if data is Dictionary and data.has("node"):
		var drag_type = data.get("type", "")
		if drag_type not in ["event_row", "comment", "group"]:
			return null
		return data["node"]
	elif data is Control:
		return data
	return null


func _calculate_visual_drop_index(at_position: Vector2, visible_blocks: Array) -> int:
	"""Calculate drop index based on mouse Y position."""
	for i in range(visible_blocks.size()):
		var child = visible_blocks[i]
		var rect = child.get_rect()
		if at_position.y < rect.position.y + rect.size.y * 0.5:
			return i
	return visible_blocks.size()


func _can_drop_data(at_position: Vector2, data) -> bool:
	"""Check if drop is allowed and show indicator."""
	var node = _get_drag_node(data)
	if node == null or not is_instance_valid(node):
		_hide_drop_indicator()
		return false
	
	_show_drop_indicator(at_position, node)
	return true


func _drop_data(at_position: Vector2, data) -> void:
	"""Handle the drop operation."""
	_hide_drop_indicator()
	
	var node = _get_drag_node(data)
	if node == null or not is_instance_valid(node):
		return
	
	var visible_blocks = _get_visible_blocks()
	var target_visual_idx = _calculate_visual_drop_index(at_position, visible_blocks)
	var is_from_different_parent = node.get_parent() != self
	
	if is_from_different_parent:
		_handle_external_drop(node, visible_blocks, target_visual_idx)
	else:
		_handle_internal_reorder(node, visible_blocks, target_visual_idx)


func _handle_external_drop(node: Node, visible_blocks: Array, target_idx: int) -> void:
	"""Handle drop from a different parent (e.g., from inside a group)."""
	before_block_moved.emit()
	
	# Remove from original parent and notify it
	var original_parent = node.get_parent()
	if original_parent:
		original_parent.remove_child(node)
		
		# Find the group that owns this container (traverse up the tree)
		var group_owner = original_parent
		var max_depth = 5  # Prevent infinite loops
		var depth = 0
		while group_owner and not group_owner.has_method("_sync_children_to_data") and depth < max_depth:
			group_owner = group_owner.get_parent()
			depth += 1
		
		# Sync the group's data to match its remaining UI children
		if group_owner and group_owner.has_method("_sync_children_to_data"):
			group_owner._sync_children_to_data()
	
	# Add to this container
	add_child(node)
	
	# Calculate and apply target position
	var target_child_idx: int
	if target_idx >= visible_blocks.size():
		target_child_idx = get_child_count() - 1
	else:
		target_child_idx = visible_blocks[target_idx].get_index()
	
	move_child(node, target_child_idx)
	
	# Defer block_moved to ensure all data is synced before save/reload
	call_deferred("emit_signal", "block_moved")

func _handle_internal_reorder(node: Node, visible_blocks: Array, target_idx: int) -> void:
	"""Handle reordering within this container."""
	var current_visual_idx = visible_blocks.find(node)
	
	# No-op if same position
	if target_idx == current_visual_idx or target_idx == current_visual_idx + 1:
		return
	
	# Calculate actual child index
	var target_child_idx: int
	if target_idx >= visible_blocks.size():
		target_child_idx = get_child_count()
	else:
		target_child_idx = visible_blocks[target_idx].get_index()
	
	var current_child_idx = node.get_index()
	
	# Adjust for moving down
	if target_child_idx > current_child_idx:
		target_child_idx -= 1
	
	before_block_moved.emit()
	move_child(node, target_child_idx)
	block_moved.emit()

# === Input Handling ===

func _gui_input(event: InputEvent) -> void:
	"""Handle clicks on empty area for deselection."""
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = event.position
		var clicked_on_child = false
		
		for child in get_children():
			if DropIndicatorManager.is_indicator(child):
				continue
			# Skip invalid or deleted children
			if not is_instance_valid(child) or child.is_queued_for_deletion():
				continue
			if child.visible and child.name != "EmptyLabel":
				if child.get_rect().has_point(mouse_pos):
					clicked_on_child = true
					break
		
		if not clicked_on_child:
			empty_area_clicked.emit()
