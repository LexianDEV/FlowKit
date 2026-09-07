@tool
extends FKModalWindow
class_name FKSelectNodeModal

@export var search_box: LineEdit  
@export var item_list: ItemList
@export var recent_item_list: ItemList

var _all_items_cache: Array = []

func _enter_tree() -> void:
	super._enter_tree()
	
	if is_editor_preview:
		return
		
	_recent_items_manager = FKRecentItemsManagerUi.new()
	
var _recent_items_manager: Variant = null
	
func _toggle_subs(should_sub: bool):
	if should_sub and not _is_subbed:
		search_box.text_changed.connect(_on_search_text_changed)
		item_list.item_activated.connect(_on_item_activated)
		item_list.item_selected.connect(_on_item_selected)
		recent_item_list.item_activated.connect(_on_recent_item_activated)
	elif _is_subbed and not should_sub:
		search_box.text_changed.disconnect(_on_search_text_changed)
		item_list.item_activated.disconnect(_on_item_activated)
		item_list.item_selected.disconnect(_on_item_selected)
		recent_item_list.item_activated.disconnect(_on_recent_item_activated)
	else:
		return
		
	_is_subbed = should_sub

func _ready() -> void:
	if is_editor_preview:
		return
	_populate_recent_list()

func _populate_recent_list() -> void:
	"""Populate the recent items list."""
	if not _recent_items_manager:
		return
	
	recent_item_list.clear()
	
	if _recent_items_manager.recent_nodes.is_empty():
		recent_item_list.add_item("(No recent items)")
		recent_item_list.set_item_disabled(0, true)
		return
	
	for recent_node in _recent_items_manager.recent_nodes:
		var display_name = recent_node["path"]
		if recent_node["path"] == "System":
			display_name = "System"
		
		recent_item_list.add_item(display_name)
		var index = recent_item_list.item_count - 1
		recent_item_list.set_item_metadata(index, recent_node)

func populate_from_scene(scene_root: Node) -> void:
	if not item_list:
		return
	
	_all_items_cache.clear()
	
	# Add System option at the top
	var system_icon = null
	system_icon = _base_control.get_theme_icon("Node", "EditorIcons")
		
	_all_items_cache.append({
		"display_name": "System",
		"metadata": "System",
		"icon": system_icon,
		"disabled": false,
		"indentation": 0,
		"path": "System"
	})
	
	if scene_root:
		_add_node_recursive(scene_root, scene_root, 0)
		
	_update_list()
	_populate_recent_list()

func _add_node_recursive(node: Node, scene_root: Node, depth: int) -> void:
	var node_name = node.name
	var node_class = node.get_class()
	
	# Store the path relative to the scene root
	var relative_path = scene_root.get_path_to(node)
	
	# Check if any event supports this node type
	var has_compatible_event = _has_compatible_event(node_class)
	
	var icon = null
	icon = _base_control.get_theme_icon(node_class, "EditorIcons")
	
	_all_items_cache.append({
		"display_name": node_name,
		"metadata": str(relative_path),
		"icon": icon,
		"disabled": not has_compatible_event,
		"indentation": depth,
		"path": str(relative_path)
	})
	
	# Add children recursively
	for child in node.get_children():
		_add_node_recursive(child, scene_root, depth + 1)

func _update_list(filter_text: String = "") -> void:
	item_list.clear()
	var filter_lower = filter_text.to_lower()
	
	for item in _all_items_cache:
		var match_search = filter_text.is_empty() or \
		filter_lower in item["path"].to_lower() or \
		filter_lower in item["display_name"].to_lower()
		
		if match_search:
			var display_text = item["display_name"]
			
			if not filter_text.is_empty() and item["metadata"] != "System":
				# Show full path when searching
				display_text = item["path"]
			else:
				# Show indented name when not searching
				display_text = "  ".repeat(item["indentation"]) + display_text
				
			item_list.add_item(display_text)
			var index = item_list.item_count - 1
			
			item_list.set_item_metadata(index, item["metadata"])
			
			if item["icon"]:
				item_list.set_item_icon(index, item["icon"])
				
			if item["disabled"]:
				item_list.set_item_disabled(index, true)
				item_list.set_item_custom_fg_color(index, Color(0.5, 0.5, 0.5, 0.7))

func _on_search_text_changed(new_text: String) -> void:
	_update_list(new_text)

func _has_compatible_event(node_class: String) -> bool:
	var registry := _get_registry()
	return registry != null and not registry.get_events_for_node_class(node_class).is_empty()

func _on_item_activated(index: int) -> void:
	# Don't allow selecting disabled items
	if item_list.is_item_disabled(index):
		return
	
	var node_path_str = item_list.get_item_metadata(index)
	
	# Handle System node
	if node_path_str == "System":
		print("[FKSelectNodeModal]: Node selected: System (System)")
		_recent_items_manager.add_recent_node("System", "System")
		_modal_signals.node_selected.emit("System", "System")
		hide()
		return
	
	var node = _get_node_from_path(node_path_str)
	if node:
		var node_class = node.get_class()
		print("[FKSelectNodeModal]: Node selected: ", node_path_str, " (", node_class, ")")
		_recent_items_manager.add_recent_node(node_path_str, node_class)
		_modal_signals.node_selected.emit(node_path_str, node_class)
		hide()

func _get_node_from_path(node_path_str: String) -> Node:
	"""Get the actual node from the scene by path."""
	var current_scene = _editor_interface.get_edited_scene_root()
	if not current_scene:
		return null
	
	# The path is now relative to scene root
	if node_path_str == ".":
		return current_scene
	return current_scene.get_node_or_null(node_path_str)

func _on_item_selected(index: int) -> void:
	# Optional: handle single click if needed
	pass

func _on_popup_hide() -> void:
	if search_box:
		search_box.clear()

func _on_recent_item_activated(index: int) -> void:
	"""Handle selection from recent items."""
	if recent_item_list.is_item_disabled(index):
		return
	
	var recent_node = recent_item_list.get_item_metadata(index)
	var node_path_str = recent_node["path"]
	var node_class = recent_node["class"]
	
	print("[FKSelectNodeModal]: Recent node selected: ", node_path_str, " (", node_class, ")")
	_modal_signals.node_selected.emit(node_path_str, node_class)
	hide()
