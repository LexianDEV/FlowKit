@tool
extends FKModalWindow
class_name FKSelectActionModal

var selected_node_path: String = ""
var selected_node_class: String = ""

@export var search_box: LineEdit
@export var item_list: ItemList
@export var description_label: Label
@export var recent_item_list: ItemList

@export var desc_panel: Panel
@export var desc_panel_style: StyleBoxFlat

var _all_items_cache: Array = []
var _recent_items_manager: Variant = null

func _enter_tree() -> void:
	super._enter_tree()
	if is_editor_preview or is_fully_legit:
		return
		
	_recent_items_manager = FKRecentItemsManagerUi.new()

func _ensure_export_fields_filled():
	var path: String
	if not search_box:
		path = "VBoxContainer/SearchBox"
		search_box = get_node(path)
		
	if not item_list:
		path = "VBoxContainer/HSplitContainer/MainPanel/MainVBox/ItemList"
		item_list = get_node(path)
		
	if not description_label:
		path = "VBoxContainer/HSplitContainer/MainPanel/MainVBox/DescriptionPanel/" +\
		"ScrollContainer/DescriptionLabel"
		description_label = get_node(path)
		
	if not recent_item_list:
		path = "VBoxContainer/HSplitContainer/RecentPanel/RecentVBox/RecentItemList"
		recent_item_list = get_node(path)
		
	if not desc_panel:
		path = "VBoxContainer/HSplitContainer/MainPanel/MainVBox/DescriptionPanel"
		desc_panel = get_node(path)
	
func _set_desc_panel_style():
	desc_panel.add_theme_stylebox_override("panel", desc_panel_style)
	
func _toggle_subs(should_sub: bool):
	if should_sub and not _is_subbed:
		search_box.text_changed.connect(_on_search_text_changed)
		item_list.item_activated.connect(_on_item_activated)
		item_list.item_selected.connect(_on_item_selected)
		recent_item_list.item_activated.connect(_on_recent_item_activated)

	elif _is_subbed and !should_sub:
		search_box.text_changed.disconnect(_on_search_text_changed)
		item_list.item_activated.disconnect(_on_item_activated)
		item_list.item_selected.disconnect(_on_item_selected)
		recent_item_list.item_activated.disconnect(_on_recent_item_activated)
		
	_is_subbed = should_sub

func populate_actions(node_path: String, node_class: String) -> void:
	"""Populate the list with actions compatible with the selected node."""
	selected_node_path = node_path
	selected_node_class = node_class
	
	if not item_list:
		return
	
	_all_items_cache.clear()
	description_label.text = ""
	
	# Filter actions that support this node type
	var registry := _get_registry()
	if registry:
		for action in registry.get_actions_for_node_class(node_class):
			_all_items_cache.append({
				"name": action.get_display_name(),
				"metadata": {"id": action.get_provider_id(), "inputs": action.get_inputs()}
			})
			
	_update_list()
	_populate_recent_list()

func _update_list(filter_text: String = "") -> void:
	item_list.clear()
	var filter_lower := filter_text.to_lower()
	
	for item in _all_items_cache:
		if filter_text.is_empty() or filter_lower in item["name"].to_lower():
			item_list.add_item(item["name"])
			var index := item_list.item_count - 1
			item_list.set_item_metadata(index, item["metadata"])
	
	if item_list.item_count == 0:
		if filter_text.is_empty():
			item_list.add_item("No actions available for this node type")
		else:
			item_list.add_item("No actions found")
		item_list.set_item_disabled(0, true)

func _on_search_text_changed(new_text: String) -> void:
	_update_list(new_text)

func _on_item_activated(index: int) -> void:
	"""Handle action selection."""
	if item_list.is_item_disabled(index):
		return
	
	var metadata = item_list.get_item_metadata(index)
	var action_id: String = metadata["id"];
	var inputs = metadata["inputs"];
	
	# Find action name for recent items
	var action_name := "";
	var registry := _get_registry()
	var action: FKAction = registry.get_action_provider_for_node_class(action_id, selected_node_class) if registry else null
	if not action:
		return
	action_name = action.get_display_name()
	
	print("[FKSelectActionModal]: Action selected: ", action_id, " for node: ", selected_node_path)
	_recent_items_manager.add_recent_action(action_id, action_name, selected_node_class)
	_modal_signals.action_selected.emit(selected_node_path, action_id, inputs)
	hide()

func _on_item_selected(index: int) -> void:
	"""Update description when item is selected."""
	if item_list.is_item_disabled(index):
		description_label.text = "";
		return
	
	var metadata = item_list.get_item_metadata(index)
	var action_id: String = metadata["id"];
	
	# Find the action and get description
	var registry := _get_registry()
	var action: FKAction = registry.get_action_provider_for_node_class(action_id, selected_node_class) if registry else null
	description_label.text = action.get_description() if action else ""

func _on_popup_hide() -> void:
	if search_box:
		search_box.clear()

func _populate_recent_list() -> void:
	"""Populate the recent actions list."""
	if not recent_item_list or not _recent_items_manager:
		return
	
	recent_item_list.clear()
	
	# Filter recent actions for current node type
	var recent_for_type = [];
	for recent_action in _recent_items_manager.recent_actions:
		if recent_action["node_class"] == selected_node_class:
			recent_for_type.append(recent_action)
	
	if recent_for_type.is_empty():
		recent_item_list.add_item("(No recent items)")
		recent_item_list.set_item_disabled(0, true)
		return
	
	for recent_action in recent_for_type:
		recent_item_list.add_item(recent_action["name"])
		var index := recent_item_list.item_count - 1;
		recent_item_list.set_item_metadata(index, recent_action)

func _on_recent_item_activated(index: int) -> void:
	"""Handle selection from recent items."""
	if recent_item_list.is_item_disabled(index):
		return
	
	var recent_action = recent_item_list.get_item_metadata(index)
	var action_id: String = recent_action["id"];
	
	# Find the action to get its inputs
	var action_inputs: Array[FKActionInput] = [];
	var registry := _get_registry()
	var action: FKAction = registry.get_action_provider_for_node_class(action_id, selected_node_class) if registry else null
	if not action:
		return
	action_inputs = action.get_inputs()
	
	print("[FKSelectActionModal]: Recent action selected: ", action_id, " for node: ", \
	selected_node_path)
	_modal_signals.action_selected.emit(selected_node_path, action_id, action_inputs)
	hide()
