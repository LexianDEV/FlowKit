@tool
extends RefCounted
class_name FKRecentItemsManagerUi
"""
Manages recent items for modals (nodes, actions, events, conditions).
Persists data to a config file.
"""

var config_path: String = "user://flowkit_recent_items.cfg"
var recent_nodes: Array = []
var recent_actions: Array = []
var recent_events: Array = []
var recent_conditions: Array = []

const MAX_RECENT_ITEMS: int = 10

func _init() -> void:
	load_from_config()

func add_recent_node(node_path: String, node_class: String) -> void:
	"""Add a node to the recent list."""
	var item = {"path": node_path, "class": node_class}
	_add_to_recent_list(recent_nodes, item)
	save_to_config()

func add_recent_action(action_id: String, action_name: String, node_class: String) -> void:
	"""Add an action to the recent list."""
	var item = {"id": action_id, "name": action_name, "node_class": node_class}
	_add_to_recent_list(recent_actions, item)
	save_to_config()

func add_recent_event(event_id: String, event_name: String, node_class: String) -> void:
	"""Add an event to the recent list."""
	var item = {"id": event_id, "name": event_name, "node_class": node_class}
	_add_to_recent_list(recent_events, item)
	save_to_config()

func add_recent_condition(condition_id: String, condition_name: String, node_class: String) -> void:
	"""Add a condition to the recent list."""
	var item = {"id": condition_id, "name": condition_name, "node_class": node_class}
	_add_to_recent_list(recent_conditions, item)
	save_to_config()

func _add_to_recent_list(list: Array, item: Dictionary) -> void:
	"""Add item to a recent list, removing duplicates and maintaining max size."""
	# Remove duplicates
	for i in range(list.size() - 1, -1, -1):
		if _items_equal(list[i], item):
			list.remove_at(i)
	
	# Add to front
	list.insert(0, item)
	
	# Limit size
	while list.size() > MAX_RECENT_ITEMS:
		list.pop_back()

func _items_equal(item1: Dictionary, item2: Dictionary) -> bool:
	"""Check if two items are equal."""
	if "id" in item1 and "id" in item2:
		return item1["id"] == item2["id"] and item1.get("node_class") == item2.get("node_class")
	elif "path" in item1 and "path" in item2:
		return item1["path"] == item2["path"]
	return false

func save_to_config() -> void:
	"""Save recent items to config file."""
	var config = ConfigFile.new()
	
	# Save nodes
	for i in range(recent_nodes.size()):
		var node = recent_nodes[i]
		config.set_value("recent_nodes", "node_%d" % i, {
			"path": node["path"],
			"class": node["class"]
		})
	
	# Save actions
	for i in range(recent_actions.size()):
		var action = recent_actions[i]
		config.set_value("recent_actions", "action_%d" % i, {
			"id": action["id"],
			"name": action["name"],
			"node_class": action["node_class"]
		})
	
	# Save events
	for i in range(recent_events.size()):
		var event = recent_events[i]
		config.set_value("recent_events", "event_%d" % i, {
			"id": event["id"],
			"name": event["name"],
			"node_class": event["node_class"]
		})
	
	# Save conditions
	for i in range(recent_conditions.size()):
		var condition = recent_conditions[i]
		config.set_value("recent_conditions", "condition_%d" % i, {
			"id": condition["id"],
			"name": condition["name"],
			"node_class": condition["node_class"]
		})
	
	config.save(config_path)

func load_from_config() -> void:
	"""Load recent items from config file."""
	var config = ConfigFile.new()
	var error = config.load(config_path)
	
	if error != OK:
		return  # File doesn't exist or can't be read
	
	# Load nodes
	recent_nodes.clear()
	if config.has_section("recent_nodes"):
		for key in config.get_section_keys("recent_nodes"):
			var node_data = config.get_value("recent_nodes", key)
			recent_nodes.append(node_data)
	
	# Load actions
	recent_actions.clear()
	if config.has_section("recent_actions"):
		for key in config.get_section_keys("recent_actions"):
			var action_data = config.get_value("recent_actions", key)
			recent_actions.append(action_data)
	
	# Load events
	recent_events.clear()
	if config.has_section("recent_events"):
		for key in config.get_section_keys("recent_events"):
			var event_data = config.get_value("recent_events", key)
			recent_events.append(event_data)
	
	# Load conditions
	recent_conditions.clear()
	if config.has_section("recent_conditions"):
		for key in config.get_section_keys("recent_conditions"):
			var condition_data = config.get_value("recent_conditions", key)
			recent_conditions.append(condition_data)
