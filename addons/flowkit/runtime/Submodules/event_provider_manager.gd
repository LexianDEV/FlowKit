extends RefCounted
class_name FKEventProviderManager

var registry: FKRegistry
var fk_engine: FlowKitEngine

# block_id -> provider instance
var providers: Dictionary = {}

func initialize(owner: FlowKitEngine):
	fk_engine = owner
	registry = owner.registry
	
func clear_providers() -> void:
	providers.clear()
	
# -------------------------------------------------------------------------
# Provider Creation (matches _create_block_providers)
# -------------------------------------------------------------------------

func create_providers(entry: Dictionary) -> void:
	var sheet: FKEventSheet = entry.get("sheet", null)
	if not sheet:
		return

	var all_events := sheet.get_all_events()

	for block in all_events:
		if block.block_id and not providers.has(block.block_id):
			var instance = registry.create_event_instance(block.event_id)
			if instance:
				providers[block.block_id] = instance

# -------------------------------------------------------------------------
# Signal Event Setup (matches _setup_signal_events)
# -------------------------------------------------------------------------

func setup_signal_events(entry: Dictionary) -> void:
	var sheet: FKEventSheet = entry.get("sheet", null)
	var root_node: Node = entry.get("root", null)

	if not sheet or not root_node or not is_instance_valid(root_node):
		return

	var all_events := sheet.get_all_events()

	for block in all_events:
		var provider = providers.get(block.block_id)
		if not provider:
			continue

		if not (provider.has_method("is_signal_event") and provider.is_signal_event()):
			continue

		var target := str(block.target_node)
		var node := fk_engine._resolve_target(target, root_node)
		if not node:
			continue

		var trigger_cb := _make_trigger_callback(block, root_node)

		if provider.has_method("setup"):
			provider.setup(node, trigger_cb, block.block_id)

# -------------------------------------------------------------------------
# Signal Event Teardown (matches _teardown_all_signal_events)
# -------------------------------------------------------------------------

func teardown_signal_events(entry: Dictionary) -> void:
	var sheet: FKEventSheet = entry.get("sheet", null)
	var root_node: Node = entry.get("root", null)

	if not sheet or not root_node or not is_instance_valid(root_node):
		return

	var all_events := sheet.get_all_events()

	for block in all_events:
		var provider = providers.get(block.block_id)
		if not provider:
			continue

		var target := str(block.target_node)
		var node := fk_engine._resolve_target(target, root_node)
		if not node:
			continue

		if provider.has_method("teardown"):
			provider.teardown(node, block.block_id)

# -------------------------------------------------------------------------
# Provider Lookup
# -------------------------------------------------------------------------

func get_provider(block_id: String) -> Variant:
	return providers.get(block_id)

# -------------------------------------------------------------------------
# Trigger Callback Builder
# -------------------------------------------------------------------------

func _make_trigger_callback(block: FKEventBlock, current_root: Node) -> Callable:
	return func() -> void:
		if not is_instance_valid(current_root):
			return
		fk_engine._execute_block(block, current_root)
