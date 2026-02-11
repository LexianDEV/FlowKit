extends Node
class_name FlowKitEngine

var registry: FKRegistry
var active_sheets: Array = []  # Each entry: {"sheet": FKEventSheet, "root": Node, "scene_name": String, "uid": int}
var last_scene: Node = null
var active_behavior_nodes: Array = []  # Track nodes with active behaviors

func _ready() -> void:
	# Load registry
	registry = FKRegistry.new()
	registry.load_all()

	print("[FlowKit] Engine initialized.")

	# Do a deferred check in case the scene is already present at startup.
	call_deferred("_check_current_scene")

func _process(delta: float) -> void:
	# Regularly check if the current_scene changed (robust against timing issues).
	_check_for_scene_change()
	for entry in active_sheets:
		_run_sheet(entry)
	
	# Process behaviors (process callback)
	_process_behaviors(delta, false)

func _physics_process(delta: float) -> void:
	# Run sheets in physics process for physics-based events
	for entry in active_sheets:
		_run_sheet(entry)
	
	# Process behaviors (physics_process callback)
	_process_behaviors(delta, true)


# --- Scene detection helpers -----------------------------------------------
func _check_current_scene() -> void:
	var cs: Node = get_tree().current_scene
	if cs:
		_on_scene_changed(cs)

func _check_for_scene_change() -> void:
	var cs: Node = get_tree().current_scene
	if cs != last_scene:
		# Scene changed (including from null -> scene)
		_on_scene_changed(cs)


func _on_scene_changed(scene_root: Node) -> void:
	last_scene = scene_root
	active_behavior_nodes.clear()  # Clear behavior tracking on scene change
	
	# Teardown signal events on previous sheets before clearing
	_teardown_all_signal_events()
	
	if scene_root == null:
		# Scene unloaded: clear active sheets (optional)
		active_sheets.clear()
		print("[FlowKit] Scene cleared.")
		return

	var scene_path: String = scene_root.scene_file_path
	var scene_uid = ResourceLoader.get_resource_uid(scene_path)
	var scene_name: String = scene_path.get_file().get_basename()
	print("[FlowKit] Scene detected:", scene_name, " (", scene_root.name, ") UID:", scene_uid)

	# Sync node variables from metadata to FlowKitSystem
	var system: Node = get_tree().root.get_node_or_null("/root/FlowKitSystem")
	if system and system.has_method("sync_scene_node_variables"):
		system.sync_scene_node_variables(scene_root)

	# Scan and activate behaviors for all nodes in the scene
	_scan_and_activate_behaviors(scene_root)

	# Load event sheets for the scene root and any instanced child scenes
	_load_sheets_for_scene(scene_root)



func _load_sheets_for_scene(scene_root: Node) -> void:
	# Clear previous sheets
	active_sheets.clear()

	# Collect unique scene_file_path UIDs and map to their root node instances
	var uid_to_node: Dictionary = {}

	# Start from the scene root
	_collect_node_paths(scene_root, uid_to_node)

	# Load sheets for each discovered scene UID
	for uid in uid_to_node.keys():
		var node_root: Node = uid_to_node[uid]
		var scene_path: String = node_root.scene_file_path
		var scene_name: String = scene_path.get_file().get_basename()
		var sheet_path: String = "res://addons/flowkit/saved/event_sheet/%d.tres" % uid

		if ResourceLoader.exists(sheet_path):
			var sheet: FKEventSheet = load(sheet_path)
			if sheet:
				# Ensure all blocks have unique IDs (for backward compatibility with old saved sheets)
				for block in sheet.events:
					if block:
						block.ensure_block_id()
				# Also ensure block IDs for events inside groups
				_ensure_block_ids_in_groups(sheet.groups)
				var entry := {"sheet": sheet, "root": node_root, "scene_name": scene_name, "uid": uid}
				active_sheets.append(entry)
				# Setup signal-based events so they can connect to node signals
				_setup_signal_events(entry)
				print("[FlowKit] Loaded event sheet for scene: ", scene_name, " (node: ", node_root.name, ") with ", sheet.events.size(), " events")
			else:
				print("[FlowKit] Failed to load sheet resource at: ", sheet_path)
		else:
			print("[FlowKit] No sheet found for scene: ", scene_name, " (expected at ", sheet_path, ")")


# Helper method moved outside
func _collect_node_paths(node: Node, uid_to_node: Dictionary) -> void:
	var path: String = node.scene_file_path
	if path and path != "":
		# Only consider nodes that are the topmost root of their instanced scene
		var parent = node.get_parent()
		var parent_path: String = ""
		if parent:
			parent_path = parent.scene_file_path

		if parent_path != path:
			var uid = ResourceLoader.get_resource_uid(path)
			if uid >= 0 and not uid_to_node.has(uid):
				uid_to_node[uid] = node

	for child in node.get_children():
		_collect_node_paths(child, uid_to_node)


func _run_sheet(entry: Dictionary) -> void:
	# Entry is a dictionary with keys: "sheet" and "root"
	var sheet: FKEventSheet = entry.get("sheet", null)
	var root_node: Node = entry.get("root", null)

	if not sheet:
		return

	# Root node for resolving node paths in this sheet
	var current_root: Node = root_node
	if not current_root or not is_instance_valid(current_root):
		# If the root is invalid, skip this sheet
		return

	# Process standalone conditions (run every frame)
	for standalone_cond in sheet.standalone_conditions:
		var cnode: Node = null
		if str(standalone_cond.target_node) == "System":
			cnode = get_node("/root/FlowKitSystem")
		else:
			cnode = current_root.get_node_or_null(standalone_cond.target_node)
			if not cnode:
				continue

		var cond_result: bool = registry.check_condition(standalone_cond.condition_id, cnode, standalone_cond.inputs, standalone_cond.negated, current_root, "")
		if cond_result:
			# Execute actions associated with this standalone condition
			for act in standalone_cond.actions:
				var anode: Node = null
				if str(act.target_node) == "System":
					anode = get_node("/root/FlowKitSystem")
				else:
					anode = current_root.get_node_or_null(act.target_node)
					if not anode:
						print("[FlowKit] Standalone condition action target node not found: ", act.target_node)
						continue
				var provider: Variant = await registry.execute_action(act.action_id, anode, act.inputs, current_root, "")


	# Collect all events from the sheet (both top-level and nested in groups)
	var all_events: Array = []
	all_events.append_array(sheet.events)
	_collect_events_from_groups(sheet.groups, all_events)

	# Process each block individually
	for block in all_events:
		# Resolve target node for polling
		var node: Node = null
		if str(block.target_node) == "System":
			node = get_node("/root/FlowKitSystem")
		else:
			node = current_root.get_node_or_null(block.target_node)
			if not node:
				print("[FlowKit] Event polling target node not found: ", block.target_node, " in scene root: ", current_root.name)
				continue

		# Signal events fire via callback — skip them in the poll loop
		if registry.is_signal_event(block.event_id):
			continue

		# Poll the event with the block's inputs
		var event_triggered = registry.poll_event(block.event_id, node, block.inputs, block.block_id, current_root)
		if not event_triggered:
			continue

		# Execute the block's conditions and actions
		_execute_block(block, current_root)
# --- Signal event lifecycle -------------------------------------------------

## Set up signal-based events for a loaded sheet entry.
## For each event block, calls registry.setup_event() with a trigger callback
## so signal events can connect to Godot signals and fire immediately.
func _setup_signal_events(entry: Dictionary) -> void:
	var sheet: FKEventSheet = entry.get("sheet", null)
	var root_node: Node = entry.get("root", null)
	if not sheet or not root_node or not is_instance_valid(root_node):
		return

	var all_events: Array = []
	all_events.append_array(sheet.events)
	_collect_events_from_groups(sheet.groups, all_events)

	for block in all_events:
		var node: Node = null
		if str(block.target_node) == "System":
			node = get_node("/root/FlowKitSystem")
		else:
			node = root_node.get_node_or_null(block.target_node)
			if not node:
				continue

		# Build a trigger callback that runs this block's conditions & actions
		var trigger_cb: Callable = _make_trigger_callback(block, root_node)
		registry.setup_event(block.event_id, node, trigger_cb, block.block_id)

## Teardown all signal events across every active sheet.
func _teardown_all_signal_events() -> void:
	for entry in active_sheets:
		var sheet: FKEventSheet = entry.get("sheet", null)
		var root_node: Node = entry.get("root", null)
		if not sheet or not root_node or not is_instance_valid(root_node):
			continue

		var all_events: Array = []
		all_events.append_array(sheet.events)
		_collect_events_from_groups(sheet.groups, all_events)

		for block in all_events:
			var node: Node = null
			if str(block.target_node) == "System":
				node = get_node_or_null("/root/FlowKitSystem")
			else:
				node = root_node.get_node_or_null(block.target_node)
				if not node:
					continue
			registry.teardown_event(block.event_id, node, block.block_id)

## Create a Callable that evaluates a block's conditions and runs its actions.
## This is what signal events call when their signal fires.
func _make_trigger_callback(block: FKEventBlock, current_root: Node) -> Callable:
	return func() -> void:
		if not is_instance_valid(current_root):
			return
		_execute_block(block, current_root)

## Execute a single event block: check all conditions, then run all actions.
## Shared by both the poll loop and signal-based trigger callbacks.
func _execute_block(block: FKEventBlock, current_root: Node) -> void:
	# Conditions
	var passed: bool = true
	for cond in block.conditions:
		var cnode: Node = null
		if str(cond.target_node) == "System":
			cnode = get_node("/root/FlowKitSystem")
		else:
			cnode = current_root.get_node_or_null(cond.target_node)
			if not cnode:
				passed = false
				break

		var cond_result: bool = registry.check_condition(cond.condition_id, cnode, cond.inputs, cond.negated, current_root, block.block_id)
		if not cond_result:
			passed = false
			break

	if not passed:
		return

	# Actions
	for act in block.actions:
		var anode: Node = null
		if str(act.target_node) == "System":
			anode = get_node("/root/FlowKitSystem")
		else:
			anode = current_root.get_node_or_null(act.target_node)
			if not anode:
				print("[FlowKit] Action target node not found: ", act.target_node)
				continue
		var provider: Variant = await registry.execute_action(act.action_id, anode, act.inputs, current_root, block.block_id)
		#if _is_multi_frame_provider(provider):
		#	print("Awaiting async provider in _execute_block")
		#	await provider.exec_completed

func _is_multi_frame_provider(provider: Variant) -> bool:
	return provider and provider.has_method("requires_multi_frames") and provider.requires_multi_frames()

func _collect_events_from_groups(groups: Array, out_events: Array) -> void:
	for group in groups:
		if group is FKGroupBlock:
			for child_item in group.children:
				var child_type: String = child_item.get("type", "")
				var child_data: Variant = child_item.get("data", null)
				
				if child_type == "event" and child_data is FKEventBlock:
					out_events.append(child_data)
				elif child_type == "group" and child_data is FKGroupBlock:
					# Recursively collect from nested groups
					_collect_events_from_groups([child_data], out_events)


func _ensure_block_ids_in_groups(groups: Array) -> void:
	"""Recursively ensure all event blocks inside groups have unique IDs."""
	for group in groups:
		if group is FKGroupBlock:
			for child_item in group.children:
				var child_type: String = child_item.get("type", "")
				var child_data: Variant = child_item.get("data", null)
				
				if child_type == "event" and child_data is FKEventBlock:
					child_data.ensure_block_id()
				elif child_type == "group" and child_data is FKGroupBlock:
					_ensure_block_ids_in_groups([child_data])

# --- Behavior processing ---------------------------------------------------
func _scan_and_activate_behaviors(scene_root: Node) -> void:
	# Recursively scan all nodes in the scene for behaviors
	_scan_node_for_behavior(scene_root)

func _scan_node_for_behavior(node: Node) -> void:
	# Check if this node has a behavior set
	if node.has_meta("flowkit_behavior"):
		var behavior_data: Dictionary = node.get_meta("flowkit_behavior", {})
		var behavior_id: String = behavior_data.get("id", "")
		var inputs: Dictionary = behavior_data.get("inputs", {})
		
		if not behavior_id.is_empty():
			# Apply the behavior
			var scene_root = get_tree().current_scene
			registry.apply_behavior(behavior_id, node, inputs, scene_root)
			
			# Track this node for behavior processing
			if not active_behavior_nodes.has(node):
				active_behavior_nodes.append(node)
			
			print("[FlowKit] Activated behavior '%s' on node: %s" % [behavior_id, node.name])
	
	# Recursively scan children
	for child in node.get_children():
		_scan_node_for_behavior(child)

func _process_behaviors(delta: float, is_physics: bool) -> void:
	# Process all active behaviors
	# First, clean up invalid nodes
	var valid_nodes: Array = []
	for node in active_behavior_nodes:
		if is_instance_valid(node):
			valid_nodes.append(node)
	active_behavior_nodes = valid_nodes
	
	for node in active_behavior_nodes:
		if not node.has_meta("flowkit_behavior"):
			continue
		
		var behavior_data: Dictionary = node.get_meta("flowkit_behavior", {})
		var behavior_id: String = behavior_data.get("id", "")
		var inputs: Dictionary = behavior_data.get("inputs", {})
		
		if behavior_id.is_empty():
			continue
		
		var behavior: Variant = registry.get_behavior(behavior_id)
		if not behavior:
			continue
		
		# Call the appropriate process method
		if is_physics:
			if behavior.has_method("physics_process"):
				behavior.physics_process(node, delta, inputs)
		else:
			if behavior.has_method("process"):
				behavior.process(node, delta, inputs)
