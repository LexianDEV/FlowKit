@tool
extends PopupPanel
class_name FKSelectEventModal

signal event_selected(node_path: String, event_id: String, event_inputs: Array)

var selected_node_path: String = ""
var selected_node_class: String = ""
var available_events: Array = []

@onready var search_box := $VBoxContainer/SearchBox
@onready var item_list := $VBoxContainer/HSplitContainer/MainPanel/MainVBox/ItemList
@onready var description_label := $VBoxContainer/HSplitContainer/MainPanel/MainVBox/DescriptionPanel/ScrollContainer/DescriptionLabel
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
	
	# Set description panel style
	var panel = $VBoxContainer/HSplitContainer/MainPanel/MainVBox/DescriptionPanel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	panel.add_theme_stylebox_override("panel", style)
	
	# Load recent items manager
	_recent_items_manager = load("res://addons/flowkit/ui/modals/recent_items_manager.gd").new()
	
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
			var event_script: Variant = load(full_path)
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
	
	_all_items_cache.clear()
	description_label.text = ""
	
	# Filter events that support this node type
	for event in available_events:
		# Check if this is the new FKEvent pattern or old FKEventProvider pattern
		if event.has_method("get_id"):
			# New FKEvent pattern
			var supported_types = event.get_supported_types()
			if _is_node_compatible(node_class, supported_types):
				var event_name = event.get_name()
				var event_id = event.get_id()
				
				_all_items_cache.append({
					"name": event_name,
					"metadata": event_id
				})
		elif event.has_method("get_events_for"):
			# Old FKEventProvider pattern
			var supported_types = event.get_supported_types()
			if _is_node_compatible(node_class, supported_types):
				var events_list = event.get_events_for(null)
				for event_data in events_list:
					_all_items_cache.append({
						"name": event_data["name"],
						"metadata": event_data["id"]
					})
	
	_update_list()
	_populate_recent_list()

func _update_list(filter_text: String = "") -> void:
	item_list.clear()
	var filter_lower = filter_text.to_lower()
	
	for item in _all_items_cache:
		if filter_text.is_empty() or filter_lower in item["name"].to_lower():
			item_list.add_item(item["name"])
			var index = item_list.item_count - 1
			item_list.set_item_metadata(index, item["metadata"])
	
	if item_list.item_count == 0:
		if filter_text.is_empty():
			item_list.add_item("No events available for this node type")
		else:
			item_list.add_item("No events found")
		item_list.set_item_disabled(0, true)

func _on_search_text_changed(new_text: String) -> void:
	_update_list(new_text)

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
	
	# Find the event provider to get its inputs and name
	var event_inputs: Array = []
	var event_name = ""
	for event in available_events:
		if event.has_method("get_id") and event.get_id() == event_id:
			if event.has_method("get_inputs"):
				event_inputs = event.get_inputs()
			if event.has_method("get_name"):
				event_name = event.get_name()
			break
	
	print("Event selected: ", event_id, " for node: ", selected_node_path, " with inputs: ", event_inputs)
	_recent_items_manager.add_recent_event(event_id, event_name, selected_node_class)
	event_selected.emit(selected_node_path, event_id, event_inputs)
	hide()

func _on_item_selected(index: int) -> void:
	"""Update description when item is selected."""
	if item_list.is_item_disabled(index):
		description_label.text = ""
		return
	
	var event_id = item_list.get_item_metadata(index)
	
	# Find the event and get description
	for event in available_events:
		if event.has_method("get_id") and event.get_id() == event_id:
			description_label.text = event.get_description()
			break

func _on_popup_hide() -> void:
	if search_box:
		search_box.clear()

func _populate_recent_list() -> void:
	"""Populate the recent events list."""
	if not recent_item_list or not _recent_items_manager:
		return
	
	recent_item_list.clear()
	
	# Filter recent events for current node type
	var recent_for_type = []
	for recent_event in _recent_items_manager.recent_events:
		if recent_event["node_class"] == selected_node_class:
			recent_for_type.append(recent_event)
	
	if recent_for_type.is_empty():
		recent_item_list.add_item("(No recent items)")
		recent_item_list.set_item_disabled(0, true)
		return
	
	for recent_event in recent_for_type:
		recent_item_list.add_item(recent_event["name"])
		var index = recent_item_list.item_count - 1
		recent_item_list.set_item_metadata(index, recent_event)

func _on_recent_item_activated(index: int) -> void:
	"""Handle selection from recent items."""
	if recent_item_list.is_item_disabled(index):
		return
	
	var recent_event = recent_item_list.get_item_metadata(index)
	var event_id = recent_event["id"]
	
	# Find the event to get its inputs
	var event_inputs: Array = []
	for event in available_events:
		if event.has_method("get_id") and event.get_id() == event_id:
			if event.has_method("get_inputs"):
				event_inputs = event.get_inputs()
			break
	
	print("Recent event selected: ", event_id, " for node: ", selected_node_path)
	event_selected.emit(selected_node_path, event_id, event_inputs)
	hide()
