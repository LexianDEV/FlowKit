extends GutTest

const EVENT_NAME_KEY := "Event Name"

var _event: FKCustomEvent
var _system: FKSystem
var _trigger_count: int

func before_each() -> void:
	_event = FKCustomEvent.new()
	_system = FKSystem.new()
	_trigger_count = 0

func after_each() -> void:
	_system.free()

func _on_trigger() -> void:
	_trigger_count += 1

func _connection_count() -> int:
	return _system.custom_event_called.get_connections().size()

func test_matching_name_triggers_callback() -> void:
	_event.setup_with_inputs(_system, {EVENT_NAME_KEY: "coin"}, _on_trigger)

	_system.call_custom_event("coin")

	assert_eq(_trigger_count, 1)

func test_other_name_does_not_trigger_callback() -> void:
	_event.setup_with_inputs(_system, {EVENT_NAME_KEY: "coin"}, _on_trigger)

	_system.call_custom_event("jump")

	assert_eq(_trigger_count, 0)

func test_name_match_is_case_sensitive() -> void:
	_event.setup_with_inputs(_system, {EVENT_NAME_KEY: "coin"}, _on_trigger)

	_system.call_custom_event("Coin")

	assert_eq(_trigger_count, 0)

func test_configured_name_is_trimmed() -> void:
	_event.setup_with_inputs(_system, {EVENT_NAME_KEY: "  coin "}, _on_trigger)

	_system.call_custom_event("coin")

	assert_eq(_trigger_count, 1)

func test_triggers_every_time_event_is_called() -> void:
	_event.setup_with_inputs(_system, {EVENT_NAME_KEY: "coin"}, _on_trigger)

	_system.call_custom_event("coin")
	_system.call_custom_event("coin")

	assert_eq(_trigger_count, 2)

func test_empty_configured_name_connects_nothing() -> void:
	_event.setup_with_inputs(_system, {EVENT_NAME_KEY: "   "}, _on_trigger)

	_system.call_custom_event("")

	assert_eq(_connection_count(), 0)
	assert_eq(_trigger_count, 0)

func test_non_system_node_pushes_error_and_connects_nothing() -> void:
	var plain_node: Node = Node.new()

	_event.setup_with_inputs(plain_node, {EVENT_NAME_KEY: "coin"}, _on_trigger)

	assert_push_error("requires the System object")
	assert_eq(_connection_count(), 0)
	plain_node.free()

func test_teardown_disconnects_listener() -> void:
	_event.setup_with_inputs(_system, {EVENT_NAME_KEY: "coin"}, _on_trigger)

	_event.teardown(_system)
	_system.call_custom_event("coin")

	assert_eq(_connection_count(), 0)
	assert_eq(_trigger_count, 0)

func test_teardown_before_setup_is_safe() -> void:
	_event.teardown(_system)

	assert_eq(_connection_count(), 0)

func test_teardown_twice_is_safe() -> void:
	_event.setup_with_inputs(_system, {EVENT_NAME_KEY: "coin"}, _on_trigger)

	_event.teardown(_system)
	_event.teardown(_system)

	assert_eq(_connection_count(), 0)

func test_teardown_with_non_system_node_is_safe() -> void:
	var plain_node: Node = Node.new()
	_event.setup_with_inputs(_system, {EVENT_NAME_KEY: "coin"}, _on_trigger)

	_event.teardown(plain_node)
	_system.call_custom_event("coin")

	assert_eq(_trigger_count, 1)
	plain_node.free()

func test_separate_events_with_same_name_both_trigger() -> void:
	var other_event: FKCustomEvent = FKCustomEvent.new()
	var other_count: Array[int] = [0]
	var other_cb: Callable = func() -> void: other_count[0] += 1
	_event.setup_with_inputs(_system, {EVENT_NAME_KEY: "coin"}, _on_trigger)
	other_event.setup_with_inputs(_system, {EVENT_NAME_KEY: "coin"}, other_cb)

	_system.call_custom_event("coin")

	assert_eq(_trigger_count, 1)
	assert_eq(other_count[0], 1)

func test_tearing_down_one_event_leaves_the_other_connected() -> void:
	var other_event: FKCustomEvent = FKCustomEvent.new()
	var other_count: Array[int] = [0]
	var other_cb: Callable = func() -> void: other_count[0] += 1
	_event.setup_with_inputs(_system, {EVENT_NAME_KEY: "coin"}, _on_trigger)
	other_event.setup_with_inputs(_system, {EVENT_NAME_KEY: "coin"}, other_cb)

	_event.teardown(_system)
	_system.call_custom_event("coin")

	assert_eq(_trigger_count, 0)
	assert_eq(other_count[0], 1)

func test_call_action_triggers_listener_end_to_end() -> void:
	var action: FKCallCustomEvent = FKCallCustomEvent.new()
	_event.setup_with_inputs(_system, {EVENT_NAME_KEY: "coin"}, _on_trigger)

	action.execute(_system, {EVENT_NAME_KEY: "coin"})
	action.execute(_system, {EVENT_NAME_KEY: "jump"})

	assert_eq(_trigger_count, 1)

func test_metadata() -> void:
	assert_eq(_event.get_id(), "on_custom_event")
	assert_true(_event.is_signal_event())
	assert_eq(_event.get_supported_types(), ["System"] as Array[String])
	assert_eq(_event.get_inputs().size(), 1)
	assert_eq(_event.get_inputs()[0].name, EVENT_NAME_KEY)
