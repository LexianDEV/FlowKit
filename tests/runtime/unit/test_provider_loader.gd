extends GutTest

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