extends GutTest

const ACTION_FIXTURE_PATH := "res://tests/fixtures/providers/action"

func test_loader_returns_fresh_non_accumulating_results() -> void:
	var loader := FKProviderLoader.new()
	var first_result := loader.load_all()
	var second_result := loader.load_all()

	assert_ne(first_result, second_result)
	assert_eq(first_result.source, second_result.source)
	assert_eq(first_result.get_total_provider_count(), second_result.get_total_provider_count())

func test_registry_reload_replaces_provider_catalog() -> void:
	var registry := FKRegistry.new()
	registry.load_all()
	var first_count := registry.action_providers.size() + registry.condition_providers.size() + \
	registry.event_providers.size() + registry.behavior_providers.size() + registry.branch_providers.size()

	registry.load_all()
	var second_count := registry.action_providers.size() + registry.condition_providers.size() + \
	registry.event_providers.size() + registry.behavior_providers.size() + registry.branch_providers.size()

	assert_eq(first_count, second_count)

func test_new_registry_can_dispatch_an_unknown_action() -> void:
	var registry := FKRegistry.new()
	var target_node := Node.new()

	var result = await registry.execute_action("missing_action", target_node, {})

	assert_null(result)

func test_loader_filters_invalid_providers_and_reports_duplicates() -> void:
	var loader := FKProviderLoader.new()
	loader.provider_paths = {"action": ACTION_FIXTURE_PATH}

	var result := loader.load_all()
	var diagnostics := "\n".join(result.diagnostics)

	assert_eq(result.source, "directory")
	assert_eq(result.action_providers.size(), 3)
	assert_true(diagnostics.contains("does not extend FKProvider"))
	assert_true(diagnostics.contains("empty id"))
	assert_true(diagnostics.contains("incompatible action provider type"))
	assert_true(diagnostics.contains("Duplicate action provider id 'duplicate_action'"))