@tool
extends PopupPanel

signal node_selected(node_path: String, node_class: String)

var editor_interface: EditorInterface
var available_events: Array = []

@onready var item_list := $ItemList

func _ready() -> void:
	if item_list:
		item_list.item_activated.connect(_on_item_activated)
		item_list.item_selected.connect(_on_item_selected)
	
	# Load all available events to check compatibility
	_load_available_events()

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
			var event_script: GDScript = load(full_path)
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
	
	item_list.clear()
	
	# Add System option at the top
	item_list.add_item("System")
	var system_index = item_list.item_count - 1
	item_list.set_item_metadata(system_index, "System")
	if editor_interface:
		var icon = editor_interface.get_base_control().get_theme_icon("Node", "EditorIcons")
		if icon:
			item_list.set_item_icon(system_index, icon)
	
	if not scene_root:
		return
	
	_add_node_recursive(scene_root, "", scene_root)

func _add_node_recursive(node: Node, prefix: String, scene_root: Node) -> void:
	var node_name = node.name
	var display_name = prefix + node_name
	var node_class = node.get_class()
	
	# Add the node to the list
	item_list.add_item(display_name)
	var index = item_list.item_count - 1
	
	# Store the path relative to the scene root
	var relative_path = scene_root.get_path_to(node)
	item_list.set_item_metadata(index, str(relative_path))
	
	# Check if any event supports this node type
	var has_compatible_event = _has_compatible_event(node_class)
	if not has_compatible_event:
		item_list.set_item_disabled(index, true)
		item_list.set_item_custom_fg_color(index, Color(0.5, 0.5, 0.5, 0.7))
	
	# Get and set the node's icon from the editor
	if editor_interface:
		var icon = editor_interface.get_base_control().get_theme_icon(node.get_class(), "EditorIcons")
		if icon:
			item_list.set_item_icon(index, icon)
	
	# Add children recursively with indentation
	for child in node.get_children():
		_add_node_recursive(child, prefix + "  ", scene_root)

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
		node_selected.emit("System", "System")
		hide()
		return
	
	var node = _get_node_from_path(node_path_str)
	if node:
		var node_class = node.get_class()
		print("Node selected: ", node_path_str, " (", node_class, ")")
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
