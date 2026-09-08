extends GutTest

class RecordingAction extends FKAction:
	var received_node: Node
	var received_inputs: Dictionary = {}
	var received_unit_id: int = -1

	func get_provider_id() -> String:
		return "record_action"

	func get_supported_types() -> Array[String]:
		return ["Node"]

	func execute(node: Node, inputs: Dictionary, unit_id: int = -1) -> void:
		received_node = node
		received_inputs = inputs
		received_unit_id = unit_id

class RecordingCondition extends FKCondition:
	var received_inputs: Dictionary = {}
	var result: bool = true

	func get_provider_id() -> String:
		return "record_condition"

	func get_supported_types() -> Array[String]:
		return ["Node"]

	func check(_node: Node, inputs: Dictionary, _unit_id: int = -1) -> bool:
		received_inputs = inputs
		return result

class RecordingEvent extends FKEvent:
	var received_inputs: Dictionary = {}

	func get_provider_id() -> String:
		return "record_event"

	func get_supported_types() -> Array[String]:
		return ["Node"]

	func poll(_node: Node, inputs: Dictionary = {}, _unit_id: int = -1) -> bool:
		received_inputs = inputs
		return true

class RecordingBehavior extends FKBehavior:
	var applied_to: Node
	var applied_inputs: Dictionary = {}
	var removed_from: Node

	func get_provider_id() -> String:
		return "record_behavior"

	func get_supported_types() -> Array[String]:
		return ["Node"]

	func apply(node: Node, inputs: Dictionary) -> void:
		applied_to = node
		applied_inputs = inputs

	func remove(node: Node) -> void:
		removed_from = node

func test_execute_action_evaluates_inputs_and_forwards_unit_id() -> void:
	var registry := FKRegistry.new()
	var action := RecordingAction.new()
	var target_node := Node.new()
	registry.action_providers.append(action)

	var result = await registry.execute_action("record_action", target_node, {"amount": "21"}, null, 17)

	assert_eq(result, action)
	assert_eq(action.received_node, target_node)
	assert_eq(action.received_inputs, {"amount": 21})
	assert_eq(action.received_unit_id, 17)

func test_check_condition_evaluates_inputs_and_applies_negation() -> void:
	var registry := FKRegistry.new()
	var condition := RecordingCondition.new()
	var target_node := Node.new()
	registry.condition_providers.append(condition)

	var result := registry.check_condition("record_condition", target_node, {"threshold": "3.5"}, true)

	assert_false(result)
	assert_eq(condition.received_inputs, {"threshold": 3.5})

func test_poll_event_evaluates_inputs_before_dispatch() -> void:
	var registry := FKRegistry.new()
	var event := RecordingEvent.new()
	var target_node := Node.new()
	registry.event_providers.append(event)

	assert_true(registry.poll_event("record_event", target_node, {"enabled": "true"}))
	assert_eq(event.received_inputs, {"enabled": true})

func test_behavior_dispatch_evaluates_apply_inputs_and_forwards_remove() -> void:
	var registry := FKRegistry.new()
	var behavior := RecordingBehavior.new()
	var target_node := Node.new()
	registry.behavior_providers.append(behavior)

	registry.apply_behavior("record_behavior", target_node, {"speed": "4"})
	registry.remove_behavior("record_behavior", target_node)

	assert_eq(behavior.applied_to, target_node)
	assert_eq(behavior.applied_inputs, {"speed": 4})
	assert_eq(behavior.removed_from, target_node)