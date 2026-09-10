extends GutTest

class Node2DProvider extends FKProvider:
	func get_provider_id() -> String:
		return "node_2d_provider"

	func get_provider_kind() -> String:
		return KIND_ACTION

	func get_supported_types() -> Array[String]:
		return ["Node2D"]

class UniversalProvider extends FKProvider:
	func get_provider_id() -> String:
		return "universal_provider"

	func get_provider_kind() -> String:
		return KIND_EVENT

	func get_supported_types() -> Array[String]:
		return ["Node"]

class InvalidProvider extends FKProvider:
	func get_inputs() -> Array:
		return [{"name": "", "type": ""}]

func test_canonical_id_combines_kind_and_provider_id() -> void:
	var provider := Node2DProvider.new()

	assert_eq(provider.get_canonical_id(), "action:node_2d_provider")

func test_supports_node_class_accepts_inherited_node_type() -> void:
	var provider := Node2DProvider.new()

	assert_true(provider.supports_node_class("CharacterBody2D"))
	assert_false(provider.supports_node_class("Control"))
	assert_false(provider.supports_node_class(""))

func test_node_support_type_matches_every_node_class() -> void:
	var provider := UniversalProvider.new()

	assert_true(provider.supports_node_class("Node"))
	assert_true(provider.supports_node_class("CharacterBody2D"))
	assert_true(provider.supports_node_class("Control"))

func test_validate_definition_reports_missing_provider_metadata() -> void:
	var provider := InvalidProvider.new()
	var errors := provider.validate_definition()

	assert_true(errors.has("Provider id is empty."))
	assert_true(errors.has("Provider kind is empty."))
	assert_true(errors.has("Input #0 is missing a valid 'name'."))
	assert_true(errors.has("Input #0 is missing a valid 'type'."))