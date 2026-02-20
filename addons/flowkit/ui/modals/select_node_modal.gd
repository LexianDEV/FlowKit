@tool
extends PopupPanel
class_name FKSelectNodeModal

signal node_selected(node_path: String, node_class: String)

var editor_interface: EditorInterface
var available_events: Array = []

@onready var search_box := $VBoxContainer/SearchBox
@onready var item_list := $VBoxContainer/HSplitContainer/MainPanel/MainVBox/ItemList
@onready var recent_item_list := $VBoxContainer/HSplitContainer/RecentPanel/RecentVBox/RecentItemList

var _all_items_cache: Array = []
var _recent_items_manager: Variant = null

func _ready() -> void:
	if search_box:
		search_box.text_changed.connect(_on_search_text_changed)
		
	if item_list:
		item_list.item_activated.connect(_on_item_activated)
		item_list.item_selected.connect(_on_item_selected)
	
	if recent_item_list:
		recent_item_list.item_activated.connect(_on_recent_item_activated)
	
	# Load recent items manager
	_recent_items_manager = load("res://addons/flowkit/ui/modals/recent_items_manager.gd").new()
	
	# Load all available events to check compatibility
	_load_available_events()
	_populate_recent_list()

func _load_available_events() -> void:
	"""Load all event scripts from the events folder."""
	available_events.clear()
	var events_path: String = "res://addons/flowkit/events"
	_scan_directory_recursive(events_path)

func _scan_directory_recursive(path: String) -> void:
	"""Recursively scan directories for event scripts."""
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return
	
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	
	while file_name != "":
		var full_path: String = path + "/" + file_name
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			# Recursively scan subdirectory
			_scan_directory_recursive(full_path)
		elif file_name.ends_with(".gd") and not file_name.ends_with(".gd.uid"):
			var event_script: Variant = load(full_path)
			if event_script:
				var event_instance: Variant = event_script.new()
				available_events.append(event_instance)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func set_editor_interface(interface: EditorInterface):
	editor_interface = interface

func populate_from_scene(scene_root: Node) -> void:
	if not item_list:
		return
	
	_all_items_cache.clear()
	
	# Add System option at the top
	var system_icon = null
	if editor_interface:
		system_icon = editor_interface.get_base_control().get_theme_icon("Node", "EditorIcons")
		
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
	if editor_interface:
		icon = editor_interface.get_base_control().get_theme_icon(node.get_class(), "EditorIcons")
	
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
		var match_search = filter_text.is_empty() or filter_lower in item["path"].to_lower() or filter_lower in item["display_name"].to_lower()
		
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
	"""Check if any available event supports this node type."""
	for event in available_events:
		if event.has_method("get_supported_types"):
			var supported_types = event.get_supported_types()
			if _is_node_compatible(node_class, supported_types):
				return true
	return false

func _is_node_compatible(node_class: String, supported_types: Array) -> bool:
	"""Check if a node class is compatible with the supported types."""
	if supported_types.is_empty():
		return false
	
	# Check for exact match
	if node_class in supported_types:
		return true
	
	# Check for "Node" which should match all nodes
	if "Node" in supported_types:
		return true
	
	# Check inheritance
	for supported_type in supported_types:
		if ClassDB.is_parent_class(node_class, supported_type):
			return true
	
	return false

func _on_item_activated(index: int) -> void:
	# Don't allow selecting disabled items
	if item_list.is_item_disabled(index):
		return
	
	var node_path_str = item_list.get_item_metadata(index)
	
	# Handle System node
	if node_path_str == "System":
		print("Node selected: System (System)")
		_recent_items_manager.add_recent_node("System", "System")
		node_selected.emit("System", "System")
		hide()
		return
	
	var node = _get_node_from_path(node_path_str)
	if node:
		var node_class = node.get_class()
		print("Node selected: ", node_path_str, " (", node_class, ")")
		_recent_items_manager.add_recent_node(node_path_str, node_class)
		node_selected.emit(node_path_str, node_class)
		hide()

func _get_node_from_path(node_path_str: String) -> Node:
	"""Get the actual node from the scene by path."""
	if not editor_interface:
		return null
	
	var current_scene = editor_interface.get_edited_scene_root()
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

func _populate_recent_list() -> void:
	"""Populate the recent items list."""
	if not recent_item_list or not _recent_items_manager:
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

func _on_recent_item_activated(index: int) -> void:
	"""Handle selection from recent items."""
	if recent_item_list.is_item_disabled(index):
		return
	
	var recent_node = recent_item_list.get_item_metadata(index)
	var node_path_str = recent_node["path"]
	var node_class = recent_node["class"]
	
	print("Recent node selected: ", node_path_str, " (", node_class, ")")
	node_selected.emit(node_path_str, node_class)
	hide()
