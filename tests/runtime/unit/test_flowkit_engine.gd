extends GutTest

const TEST_SCENE: PackedScene = preload("res://addons/flowkit/demos/platformer_movement.tscn")

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
