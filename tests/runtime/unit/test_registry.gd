extends GutTest

class FixtureAction extends FKAction:
	var canonical_id: String
	var legacy_id: String
	var supported_types: Array[String]

	func _init(p_canonical_id: String, p_legacy_id: String, p_supported_types: Array[String]) -> void:
		canonical_id = p_canonical_id
		legacy_id = p_legacy_id
		supported_types = p_supported_types

	func get_provider_id() -> String:
		return canonical_id

	func get_id() -> String:
		return legacy_id

	func get_supported_types() -> Array[String]:
		return supported_types

class FixtureEvent extends FKEvent:
	var canonical_id: String
	var legacy_id: String
	var supported_types: Array[String]

	func _init(p_canonical_id: String, p_legacy_id: String, p_supported_types: Array[String]) -> void:
		canonical_id = p_canonical_id
		legacy_id = p_legacy_id
		supported_types = p_supported_types

	func get_provider_id() -> String:
		return canonical_id

	func get_id() -> String:
		return legacy_id

	func get_supported_types() -> Array[String]:
		return supported_types

func test_canonical_action_id_takes_precedence_over_legacy_id() -> void:
	var registry := FKRegistry.new()
	var legacy_provider := FixtureAction.new("other_action", "shared_action", ["Node"])
	var canonical_provider := FixtureAction.new("shared_action", "different_legacy", ["Node"])
	registry.action_providers.append(legacy_provider)
	registry.action_providers.append(canonical_provider)

	assert_eq(registry.get_action_provider("shared_action"), canonical_provider)

func test_legacy_action_id_uses_the_provider_compatible_with_node_class() -> void:
	var registry := FKRegistry.new()
	var control_provider := FixtureAction.new("control_action", "shared_action", ["Control"])
	var node_2d_provider := FixtureAction.new("node_2d_action", "shared_action", ["Node2D"])
	registry.action_providers.append(control_provider)
	registry.action_providers.append(node_2d_provider)

	assert_eq(registry.get_action_provider_for_node_class("shared_action", "CharacterBody2D"), node_2d_provider)

func test_node_class_queries_return_only_compatible_providers() -> void:
	var registry := FKRegistry.new()
	var universal_action := FixtureAction.new("any_action", "any_action", ["Node"])
	var control_action := FixtureAction.new("control_action", "control_action", ["Control"])
	var timer_event := FixtureEvent.new("timer_event", "timer_event", ["Timer"])
	registry.action_providers.append(universal_action)
	registry.action_providers.append(control_action)
	registry.event_providers.append(timer_event)

	var actions := registry.get_actions_for_node_class("Button")
	var events := registry.get_events_for_node_class("Timer")

	assert_eq(actions.size(), 2)
	assert_true(actions.has(universal_action))
	assert_true(actions.has(control_action))
	assert_eq(events, [timer_event])