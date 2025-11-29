extends Node
class_name FlowKitEngine

var registry: FKRegistry
var active_sheets: Array = []
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
	for sheet in active_sheets:
		_run_sheet(sheet)
	
	# Process behaviors (process callback)
	_process_behaviors(delta, false)

func _physics_process(delta: float) -> void:
	# Run sheets in physics process for physics-based events
	for sheet in active_sheets:
		_run_sheet(sheet)
	
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
	
	if scene_root == null:
		# Scene unloaded: clear active sheets (optional)
		active_sheets.clear()
		print("[FlowKit] Scene cleared.")
		return

	var scene_path: String = scene_root.scene_file_path
	var scene_name: String = scene_path.get_file().get_basename()
	print("[FlowKit] Scene detected:", scene_name, " (", scene_root.name, ")")
	
	# Sync node variables from metadata to FlowKitSystem
	var system: Node = get_tree().root.get_node_or_null("/root/FlowKitSystem")
	if system and system.has_method("sync_scene_node_variables"):
		system.sync_scene_node_variables(scene_root)
	
	# Scan and activate behaviors for all nodes in the scene
	_scan_and_activate_behaviors(scene_root)
	
	_load_sheet_for_scene(scene_name)


func _load_sheet_for_scene(scene_name: String) -> void:
	# Clear previous sheet(s)
	active_sheets.clear()

	var sheet_path: String = "res://addons/flowkit/saved/event_sheet/%s.tres" % scene_name

	# Debug: show whether the file exists
	if ResourceLoader.exists(sheet_path):
		var sheet: FKEventSheet = load(sheet_path)
		if sheet:
			active_sheets.append(sheet)
			print("[FlowKit] Loaded event sheet for scene: ", scene_name, " with ", sheet.events.size(), " events")
		else:
			print("[FlowKit] Failed to load sheet resource at: ", sheet_path)
	else:
		print("[FlowKit] No sheet found for scene: ", scene_name, " (expected at ", sheet_path, ")")


# --- Event loop ------------------------------------------------------------
func _run_sheet(sheet: FKEventSheet) -> void:
	# Defensive: ensure we have a current scene
	var current_scene: Node = get_tree().current_scene
	if not current_scene:
		return

	# Process standalone conditions (run every frame)
	for standalone_cond in sheet.standalone_conditions:
		var cnode: Node = null
		if str(standalone_cond.target_node) == "System":
			cnode = get_node("/root/FlowKitSystem")
		else:
			cnode = current_scene.get_node_or_null(standalone_cond.target_node)
			if not cnode:
				continue

		var cond_result: bool = registry.check_condition(standalone_cond.condition_id, cnode, standalone_cond.inputs, standalone_cond.negated)
		if cond_result:
			# Execute actions associated with this standalone condition
			for act in standalone_cond.actions:
				var anode: Node = null
				if str(act.target_node) == "System":
					anode = get_node("/root/FlowKitSystem")
				else:
					anode = current_scene.get_node_or_null(act.target_node)
					if not anode:
						print("[FlowKit] Standalone condition action target node not found: ", act.target_node)
						continue
				
				registry.execute_action(act.action_id, anode, act.inputs)

	for block in sheet.events:
		# Resolve target node (relative to the current scene)
		# Handle "System" as the FlowKitSystem singleton
		var node: Node = null
		if str(block.target_node) == "System":
			node = get_node("/root/FlowKitSystem")
		else:
			node = current_scene.get_node_or_null(block.target_node)
			if not node:
				# Optionally debug: print missing node paths if you want
				# print("[FlowKit] Missing target node for block:", block.target_node)
				continue

		# Event trigger
		var event_triggered: bool = registry.poll_event(block.event_id, node, block.inputs)
		if not event_triggered:
			continue

		# Conditions
		var passed: bool = true
		for cond in block.conditions:
			var cnode: Node = null
			if str(cond.target_node) == "System":
				cnode = get_node("/root/FlowKitSystem")
			else:
				cnode = current_scene.get_node_or_null(cond.target_node)
				if not cnode:
					passed = false
					break

			var cond_result: bool = registry.check_condition(cond.condition_id, cnode, cond.inputs, cond.negated)
			if not cond_result:
				passed = false
				break

		if not passed:
			continue

		# Actions
		for act in block.actions:
			var anode: Node = null
			if str(act.target_node) == "System":
				anode = get_node("/root/FlowKitSystem")
			else:
				anode = current_scene.get_node_or_null(act.target_node)
				if not anode:
					print("[FlowKit] Action target node not found: ", act.target_node)
					continue
			
			registry.execute_action(act.action_id, anode, act.inputs)


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
			registry.apply_behavior(behavior_id, node, inputs)
			
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
