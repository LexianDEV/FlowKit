@tool
extends FKModalWindow
class_name FKSelectEventModal

var selected_node_path: String = "";
var selected_node_class: String = "";

@export_category("UI")
@export var search_box: LineEdit;
@export var item_list: ItemList;
@export var description_label: Label;
@export var recent_item_list: ItemList;
@export var desc_panel: Panel;

@export_category("Styling")
@export var desc_panel_style: StyleBoxFlat;

var _all_items_cache: Array = [];

func _enter_tree() -> void:
	super._enter_tree()
	
	if is_editor_preview or is_fully_legit:
		return
		
	_recent_items_manager = FKRecentItemsManagerUi.new()

var _recent_items_manager: Variant = null

func _ensure_export_fields_filled():
	var path: String;
	if not search_box:
		path = "VBoxContainer/SearchBox";
		search_box = get_node(path)
		
	if not item_list:
		path = "VBoxContainer/HSplitContainer/MainPanel/MainVBox/ItemList";
		item_list = get_node(path)
		
	if not description_label:
		path = "VBoxContainer/HSplitContainer/MainPanel/MainVBox/DescriptionPanel/" +\
		"ScrollContainer/DescriptionLabel";
		description_label = get_node(path)
	
	if not recent_item_list:
		path = "VBoxContainer/HSplitContainer/RecentPanel/RecentVBox/RecentItemList";
		recent_item_list = get_node(path)
		
	if not desc_panel:
		path = "VBoxContainer/HSplitContainer/MainPanel/MainVBox/DescriptionPanel";
		desc_panel = get_node(path)
		
func _apply_styling():
	desc_panel.add_theme_stylebox_override("panel", desc_panel_style)
		
func _toggle_subs(on: bool):
	if on and not _is_subbed:
		search_box.text_changed.connect(_on_search_text_changed)
		item_list.item_activated.connect(_on_item_activated)
		item_list.item_selected.connect(_on_item_selected)
		recent_item_list.item_activated.connect(_on_recent_item_activated)
	elif _is_subbed and !on:
		search_box.text_changed.disconnect(_on_search_text_changed)
		item_list.item_activated.disconnect(_on_item_activated)
		item_list.item_selected.disconnect(_on_item_selected)
		recent_item_list.item_activated.disconnect(_on_recent_item_activated)
	else:
		return
		
	_is_subbed = on

func populate_events(node_path: String, node_class: String) -> void:
	"""Populate the list with events compatible with the selected node."""
	selected_node_path = node_path;
	selected_node_class = node_class;
	
	if not item_list:
		return
	
	_all_items_cache.clear()
	description_label.text = "";
	
	# Filter events that support this node type
	var registry := _get_registry()
	if registry:
		for event in registry.get_events_for_node_class(node_class):
			_all_items_cache.append({
				"name": event.get_display_name(),
				"metadata": event.get_provider_id()
			})
	
	_update_list()
	_populate_recent_list()

func _update_list(filter_text: String = "") -> void:
	item_list.clear()
	var filter_lower = filter_text.to_lower()
	
	for item in _all_items_cache:
		if filter_text.is_empty() or filter_lower in item["name"].to_lower():
			item_list.add_item(item["name"])
			var index := item_list.item_count - 1;
			item_list.set_item_metadata(index, item["metadata"])
	
	if item_list.item_count == 0:
		if filter_text.is_empty():
			item_list.add_item("No events available for this node type")
		else:
			item_list.add_item("No events found")
		item_list.set_item_disabled(0, true)

func _on_search_text_changed(new_text: String) -> void:
	_update_list(new_text)

func _on_item_activated(index: int) -> void:
	"""Handle event selection."""
	if item_list.is_item_disabled(index):
		return
	
	var event_id = item_list.get_item_metadata(index)
	
	# Find the event provider to get its inputs and name
	var event_inputs: Array = [];
	var event_name = "";
	var registry := _get_registry()
	var event: FKEvent = registry.get_event_provider(event_id) if registry else null
	if not event:
		return
	event_inputs = event.get_inputs()
	event_name = event.get_display_name()
	
	print("[FKSelectEventModal]: Event selected: ", event_id, " for node: ",
	selected_node_path, " with inputs: ", event_inputs)
	_recent_items_manager.add_recent_event(event_id, event_name, selected_node_class)
	_modal_signals.event_selected.emit(selected_node_path, event_id, event_inputs)
	hide()

func _on_item_selected(index: int) -> void:
	"""Update description when item is selected."""
	if item_list.is_item_disabled(index):
		description_label.text = "";
		return
	
	var event_id = item_list.get_item_metadata(index)
	
	# Find the event and get description
	var registry := _get_registry()
	var event: FKEvent = registry.get_event_provider(event_id) if registry else null
	description_label.text = event.get_description() if event else ""

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
		var index = recent_item_list.item_count - 1;
		recent_item_list.set_item_metadata(index, recent_event)

func _on_recent_item_activated(index: int) -> void:
	"""Handle selection from recent items."""
	if recent_item_list.is_item_disabled(index):
		return
	
	var recent_event = recent_item_list.get_item_metadata(index)
	var event_id = recent_event["id"]
	
	# Find the event to get its inputs
	var event_inputs: Array = []
	var registry := _get_registry()
	var event: FKEvent = registry.get_event_provider(event_id) if registry else null
	if not event:
		return
	event_inputs = event.get_inputs()
	
	print("[FKSelectEventModal]: Recent event selected: ", event_id, " for node: ", \
	selected_node_path)
	_modal_signals.event_selected.emit(selected_node_path, event_id, event_inputs)
	hide()
