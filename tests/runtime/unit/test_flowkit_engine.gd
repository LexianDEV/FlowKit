extends GutTest

const TEST_SCENE: PackedScene = preload("res://addons/flowkit/demos/platformer_movement.tscn")

class InputAwareSignalEvent extends FKEvent:
	var received_inputs: Dictionary = {}

	func is_signal_event() -> bool:
		return true

	func setup_with_inputs(
		_node: Node,
		inputs: Dictionary,
		_trigger_callback: Callable,
		_unit_id: int = -1
	) -> void:
		received_inputs = inputs


func test_collect_scene_roots_keeps_repeated_scene_instances() -> void:
	var engine: FlowKitEngine = FlowKitEngine.new()
	var parent: Node = Node.new()
	var first_instance: Node = TEST_SCENE.instantiate()
	var second_instance: Node = TEST_SCENE.instantiate()
	var scene_roots: Array[Node] = []

	parent.add_child(first_instance)
	parent.add_child(second_instance)

	engine._collect_scene_roots(parent, scene_roots)

	assert_true(scene_roots.has(first_instance))
	assert_true(scene_roots.has(second_instance))

	parent.free()
	engine.free()

func test_event_provider_key_is_unique_per_scene_instance() -> void:
	var engine: FlowKitEngine = FlowKitEngine.new()
	var first_root: Node = Node.new()
	var second_root: Node = Node.new()
	var first_key: String = engine._event_provider_key(123, first_root.get_instance_id(), 7)
	var second_key: String = engine._event_provider_key(123, second_root.get_instance_id(), 7)

	assert_ne(first_key, second_key)

	first_root.free()
	second_root.free()
	engine.free()

func test_signal_event_setup_receives_evaluated_inputs() -> void:
	var engine: FlowKitEngine = FlowKitEngine.new()
	var root_node: Node = Node.new()
	var sheet: FKEventSheet = FKEventSheet.new()
	var event_unit: FKEventUnit = FKEventUnit.new("input_aware_signal", NodePath("."))
	var provider: InputAwareSignalEvent = InputAwareSignalEvent.new()

	event_unit.uid = 7
	event_unit.inputs = {"amount": "21"}
	sheet.events.append(event_unit)

	var entry: FlowKitEngine.SheetEntry = FlowKitEngine.SheetEntry.new(
		sheet,
		root_node,
		"test_scene",
		123
	)
	var key: String = engine._event_provider_key(
		entry.uid,
		root_node.get_instance_id(),
		event_unit.uid
	)
	engine._event_unit_providers[key] = provider

	engine._setup_signal_events(entry)

	assert_eq(provider.received_inputs, {"amount": 21})

	root_node.free()
	engine.free()

