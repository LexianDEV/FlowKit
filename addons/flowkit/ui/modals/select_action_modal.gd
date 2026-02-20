@tool
extends PopupPanel
class_name FKSelectActionModal

signal action_selected(node_path: String, action_id: String, action_inputs: Array)

var selected_node_path: String = ""
var selected_node_class: String = ""
var available_actions: Array = []

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
	
	# Load all available actions
	_load_available_actions()

func _load_available_actions() -> void:
	"""Load all action scripts from the actions folder."""
	available_actions.clear()
	var actions_path: String = "res://addons/flowkit/actions"
	_scan_directory_recursive(actions_path)
	print("Loaded ", available_actions.size(), " actions")

func _scan_directory_recursive(path: String) -> void:
	"""Recursively scan directories for action scripts."""
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
			var action_script: Variant = load(full_path)
			if action_script:
				var action_instance: Variant = action_script.new()
				available_actions.append(action_instance)
		
		file_name = dir.get_next()
	
	dir.list_dir_end()

func populate_actions(node_path: String, node_class: String) -> void:
	"""Populate the list with actions compatible with the selected node."""
	selected_node_path = node_path
	selected_node_class = node_class
	
	if not item_list:
		return
	
	_all_items_cache.clear()
	description_label.text = ""
	
	# Filter actions that support this node type
	for action in available_actions:
		var supported_types = action.get_supported_types()
		if _is_node_compatible(node_class, supported_types):
			var action_name = action.get_name()
			var action_id = action.get_id()
			
			_all_items_cache.append({
				"name": action_name,
				"metadata": {"id": action_id, "inputs": action.get_inputs()}
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
			item_list.add_item("No actions available for this node type")
		else:
			item_list.add_item("No actions found")
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
	"""Handle action selection."""
	if item_list.is_item_disabled(index):
		return
	
	var metadata = item_list.get_item_metadata(index)
	var action_id = metadata["id"]
	var inputs = metadata["inputs"]
	
	# Find action name for recent items
	var action_name = ""
	for action in available_actions:
		if action.get_id() == action_id:
			action_name = action.get_name()
			break
	
	print("Action selected: ", action_id, " for node: ", selected_node_path)
	_recent_items_manager.add_recent_action(action_id, action_name, selected_node_class)
	action_selected.emit(selected_node_path, action_id, inputs)
	hide()

func _on_item_selected(index: int) -> void:
	"""Update description when item is selected."""
	if item_list.is_item_disabled(index):
		description_label.text = ""
		return
	
	var metadata = item_list.get_item_metadata(index)
	var action_id = metadata["id"]
	
	# Find the action and get description
	for action in available_actions:
		if action.get_id() == action_id:
			description_label.text = action.get_description()
			break

func _on_popup_hide() -> void:
	if search_box:
		search_box.clear()

func _populate_recent_list() -> void:
	"""Populate the recent actions list."""
	if not recent_item_list or not _recent_items_manager:
		return
	
	recent_item_list.clear()
	
	# Filter recent actions for current node type
	var recent_for_type = []
	for recent_action in _recent_items_manager.recent_actions:
		if recent_action["node_class"] == selected_node_class:
			recent_for_type.append(recent_action)
	
	if recent_for_type.is_empty():
		recent_item_list.add_item("(No recent items)")
		recent_item_list.set_item_disabled(0, true)
		return
	
	for recent_action in recent_for_type:
		recent_item_list.add_item(recent_action["name"])
		var index = recent_item_list.item_count - 1
		recent_item_list.set_item_metadata(index, recent_action)

func _on_recent_item_activated(index: int) -> void:
	"""Handle selection from recent items."""
	if recent_item_list.is_item_disabled(index):
		return
	
	var recent_action = recent_item_list.get_item_metadata(index)
	var action_id = recent_action["id"]
	
	# Find the action to get its inputs
	var action_inputs: Array = []
	for action in available_actions:
		if action.get_id() == action_id:
			action_inputs = action.get_inputs()
			break
	
	print("Recent action selected: ", action_id, " for node: ", selected_node_path)
	action_selected.emit(selected_node_path, action_id, action_inputs)
	hide()
