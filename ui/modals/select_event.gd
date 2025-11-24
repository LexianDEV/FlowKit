@tool
extends PopupPanel

signal event_selected(node_path: String, event_id: String, event_inputs: Array)

var selected_node_path: String = ""
var selected_node_class: String = ""
var available_events: Array = []

@onready var item_list := $ItemList

func _ready() -> void:
	if item_list:
		item_list.item_activated.connect(_on_item_activated)
	
	# Load all available events
	_load_available_events()

func _load_available_events() -> void:
	"""Load all event scripts from the events folder."""
	available_events.clear()
	var events_path: String = "res://addons/flowkit/events"
	_scan_directory_recursive(events_path)
	print("Loaded ", available_events.size(), " events")

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

func populate_events(node_path: String, node_class: String) -> void:
	"""Populate the list with events compatible with the selected node."""
	selected_node_path = node_path
	selected_node_class = node_class
	
	if not item_list:
		return
	
	item_list.clear()
	
	# Filter events that support this node type
	for event in available_events:
		# Check if this is the new FKEvent pattern or old FKEventProvider pattern
		if event.has_method("get_id"):
			# New FKEvent pattern
			var supported_types = event.get_supported_types()
			if _is_node_compatible(node_class, supported_types):
				var event_name = event.get_name()
				var event_id = event.get_id()
				
				item_list.add_item(event_name)
				var index = item_list.item_count - 1
				item_list.set_item_metadata(index, event_id)
		elif event.has_method("get_events_for"):
			# Old FKEventProvider pattern
			var supported_types = event.get_supported_types()
			if _is_node_compatible(node_class, supported_types):
				var events_list = event.get_events_for(null)
				for event_data in events_list:
					item_list.add_item(event_data["name"])
					var index = item_list.item_count - 1
					item_list.set_item_metadata(index, event_data["id"])
	
	if item_list.item_count == 0:
		item_list.add_item("No events available for this node type")
		item_list.set_item_disabled(0, true)

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
	"""Handle event selection."""
	if item_list.is_item_disabled(index):
		return
	
	var event_id = item_list.get_item_metadata(index)
	
	# Find the event provider to get its inputs
	var event_inputs: Array = []
	for event in available_events:
		if event.has_method("get_id") and event.get_id() == event_id:
			if event.has_method("get_inputs"):
				event_inputs = event.get_inputs()
			break
	
	print("Event selected: ", event_id, " for node: ", selected_node_path, " with inputs: ", event_inputs)
	event_selected.emit(selected_node_path, event_id, event_inputs)
	hide()
