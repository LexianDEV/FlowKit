@tool
extends Node
class_name DropIndicatorManager
## Centralized manager for drag-and-drop visual indicators in FlowKit.
##
## This singleton ensures only ONE drop indicator exists at any time across
## the entire editor (blocks_container, groups, nested groups, etc.).
## All drop indicator operations should go through this manager.
##
## Usage:
##   DropIndicatorManager.show_indicator(container, y_pos, width)
##   DropIndicatorManager.hide_indicator()
##   DropIndicatorManager.is_indicator(node)
##   DropIndicatorManager.calculate_drop_position(container, mouse_y, exclude)

# === Static Variables ===
static var _indicator: Panel  ## The single drop indicator panel
static var _current_container: Control  ## Container currently showing the indicator

# === Indicator Creation ===

static func _create_indicator() -> Panel:
	"""Create the drop indicator panel with styling."""
	var indicator = Panel.new()
	indicator.name = "GlobalDropIndicator"
	
	# Blue highlight style
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.4, 0.7, 1.0, 1.0)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	indicator.add_theme_stylebox_override("panel", style)
	
	indicator.custom_minimum_size = Vector2(100, 4)
	indicator.visible = false
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.z_index = 100
	
	return indicator

# === Public API ===

static func show_indicator(container: Control, y_position: float, width: float = -1) -> void:
	"""
	Show drop indicator in the specified container at the given Y position.
	
	Args:
		container: The Control to show the indicator in
		y_position: Y coordinate within the container
		width: Optional width (-1 uses container width - 20)
	"""
	# Create indicator if needed
	if not _indicator or not is_instance_valid(_indicator):
		_indicator = _create_indicator()
	
	# Move to new container if different
	if _indicator.get_parent() != container:
		if _indicator.get_parent():
			_indicator.get_parent().remove_child(_indicator)
		container.add_child(_indicator)
	
	_current_container = container
	
	# Position and show
	var indicator_width = width if width > 0 else container.size.x - 20
	_indicator.size = Vector2(indicator_width, 4)
	_indicator.position = Vector2(10, y_position)
	_indicator.visible = true


static func hide_indicator() -> void:
	"""Hide the drop indicator."""
	if _indicator and is_instance_valid(_indicator):
		_indicator.visible = false


static func is_indicator(node: Node) -> bool:
	"""
	Check if a node is the drop indicator.
	Use this when iterating children to exclude the indicator.
	"""
	return node == _indicator


static func calculate_drop_position(container: Control, mouse_y: float, exclude_nodes: Array = []) -> Dictionary:
	"""
	Calculate the drop index and Y position for the indicator.
	
	Args:
		container: The container to calculate position in
		mouse_y: Mouse Y position in container's local coordinates
		exclude_nodes: Nodes to exclude from calculation (e.g., dragged node, hints)
	
	Returns:
		Dictionary with "index" (int) and "y_position" (float)
	"""
	var visible_children = []
	
	# Collect visible children, excluding special nodes
	for child in container.get_children():
		if is_indicator(child):
			continue
		if child.name in ["EmptyLabel", "DropHint"]:
			continue
		if child in exclude_nodes:
			continue
		if child.visible:
			visible_children.append(child)
	
	# Empty container - drop at top
	if visible_children.is_empty():
		return {"index": 0, "y_position": 5.0}
	
	# Find insertion point based on mouse position
	for i in range(visible_children.size()):
		var child = visible_children[i]
		var rect = child.get_rect()
		var mid_y = rect.position.y + rect.size.y * 0.5
		
		if mouse_y < mid_y:
			# Insert before this child
			var y_pos = rect.position.y - 3
			return {"index": i, "y_position": y_pos}
	
	# Insert at end (after last child)
	var last_child = visible_children[visible_children.size() - 1]
	var y_pos = last_child.position.y + last_child.size.y + 2
	return {"index": visible_children.size(), "y_position": y_pos}
