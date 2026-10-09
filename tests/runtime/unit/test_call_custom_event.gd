extends GutTest

const EVENT_NAME_KEY := "Event Name"

var _action: FKCallCustomEvent
var _system: FKSystem

func before_each() -> void:
	_action = FKCallCustomEvent.new()
	_system = FKSystem.new()
	watch_signals(_system)

func after_each() -> void:
	_system.free()

func test_execute_emits_custom_event_called_with_name() -> void:
	_action.execute(_system, {EVENT_NAME_KEY: "coin"})

	assert_signal_emit_count(_system, "custom_event_called", 1)
	assert_signal_emitted_with_parameters(_system, "custom_event_called", ["coin"])

func test_execute_trims_event_name() -> void:
	_action.execute(_system, {EVENT_NAME_KEY: "  coin  "})

	assert_signal_emitted_with_parameters(_system, "custom_event_called", ["coin"])

func test_execute_ignores_empty_event_name() -> void:
	_action.execute(_system, {EVENT_NAME_KEY: ""})

	assert_signal_not_emitted(_system, "custom_event_called")

func test_execute_ignores_whitespace_only_event_name() -> void:
	_action.execute(_system, {EVENT_NAME_KEY: "   "})

	assert_signal_not_emitted(_system, "custom_event_called")

func test_execute_ignores_missing_event_name_input() -> void:
	_action.execute(_system, {})

	assert_signal_not_emitted(_system, "custom_event_called")

func test_execute_on_non_system_node_pushes_error_and_emits_nothing() -> void:
	var plain_node: Node = Node.new()

	_action.execute(plain_node, {EVENT_NAME_KEY: "coin"})

	assert_push_error("requires the System object")
	assert_signal_not_emitted(_system, "custom_event_called")
	plain_node.free()

func test_execute_emits_each_time_it_is_called() -> void:
	_action.execute(_system, {EVENT_NAME_KEY: "coin"})
	_action.execute(_system, {EVENT_NAME_KEY: "coin"})

	assert_signal_emit_count(_system, "custom_event_called", 2)

func test_metadata() -> void:
	assert_eq(_action.get_id(), "call_custom_event")
	assert_eq(_action.get_supported_types(), ["System"] as Array[String])
	assert_eq(_action.get_inputs().size(), 1)
	assert_eq(_action.get_inputs()[0].name, EVENT_NAME_KEY)
