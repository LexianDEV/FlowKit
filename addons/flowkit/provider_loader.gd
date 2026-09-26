extends RefCounted
class_name FKProviderLoader

const DEFAULT_MANIFEST_PATH := "res://addons/flowkit/saved/provider_manifest.tres"
const DEFAULT_PROVIDER_PATH := "res://addons/flowkit/providers"
const DEFAULT_TEST_PROVIDER_PATH := "res://tests/providers"
var manifest_path: String = DEFAULT_MANIFEST_PATH
var default_provider_path: String = DEFAULT_PROVIDER_PATH
var default_test_path := DEFAULT_TEST_PROVIDER_PATH
var project_settings: FKProjectSettings

func load_all() -> FKProviderLoadResult:
	var result := FKProviderLoadResult.new()
	
	if OS.has_feature("editor"):
		for provider_path in _get_provider_paths():
			_scan_directory_recursive(provider_path, result)
		result.source = "directory"
	elif _load_from_manifest(result):
		result.source = "manifest"
	else:
		result.source = "unavailable"
		result.errors.append("No provider manifest found and directory scanning is not available " +\
		"in exported builds. Generate the manifest in the editor.")

	_collect_duplicate_id_diagnostics(result.action_providers, "action", result)
	_collect_duplicate_id_diagnostics(result.condition_providers, "condition", result)
	_collect_duplicate_id_diagnostics(result.event_providers, "event", result)
	_collect_duplicate_id_diagnostics(result.behavior_providers, "behavior", result)
	_collect_duplicate_id_diagnostics(result.branch_providers, "branch", result)
	return result

## Public view used by editor tooling that needs the exact same discovery paths.
func get_provider_paths() -> Array[String]:
	return _get_provider_paths()


func _get_provider_paths() -> Array[String]:
	var result: Array[String] = []
	for provider_path in [default_provider_path, default_test_path]:
		if not provider_path.is_empty() and not result.has(provider_path):
			result.append(provider_path)

	if project_settings:
		for provider_path in project_settings.provider_paths:
			if not provider_path.is_empty() and not result.has(provider_path):
				result.append(provider_path)
	return result

func _load_from_manifest(result: FKProviderLoadResult) -> bool:
	if not ResourceLoader.exists(manifest_path):
		return false

	var manifest: Resource = load(manifest_path)
	if not manifest:
		return false

	_load_manifest_scripts(manifest.get("action_scripts"), result)
	_load_manifest_scripts(manifest.get("condition_scripts"), result)
	_load_manifest_scripts(manifest.get("event_scripts"), result)
	_load_manifest_scripts(manifest.get("behavior_scripts"), result)
	_load_manifest_scripts(manifest.get("branch_scripts"), result)

	var any_provs_found: bool = result.get_total_provider_count() > 0
	return any_provs_found

func _load_manifest_scripts(scripts: Variant, result: FKProviderLoadResult) -> void:
	if scripts == null:
		return
	for script_el in scripts:
		if script_el is GDScript:
			_try_add_provider(script_el, result)

func _try_add_provider(script: GDScript, result: FKProviderLoadResult) -> void:
	var diagnostics := result.diagnostics
	if not _script_extends_provider(script):
		diagnostics.append("[FKProviderLoader] Skipping script that does not " +\
		"extend FKProvider: %s" % script.resource_path)
		return

	var instance: Variant = script.new()
	if instance == null:
		diagnostics.append("[FKProviderLoader] Skipping script that returned " +\
		"null on new(): %s" % script.resource_path)
		return
	if instance.is_abstract_provider():
		return

	var provider := instance as FKProvider
	_register_provider_into(result, provider, script)

func _register_provider_into(result: FKProviderLoadResult, provider: FKProvider, script: GDScript):
	var diagnostics := result.diagnostics

	if _provider_id_of(provider).is_empty():
		diagnostics.append("[FKProviderLoader] Skipping provider with empty id: " +\
		"%s" % script.resource_path)
		return

	if provider is FKAction:
		result.action_providers.append(provider)
	elif provider is FKCondition:
		result.condition_providers.append(provider)
	elif provider is FKEvent:
		result.event_providers.append(provider)
	elif provider is FKBehavior:
		result.behavior_providers.append(provider)
	elif provider is FKBranch:
		result.branch_providers.append(provider)
	else:
		diagnostics.append("[FKProviderLoader] Skipping provider with unsupported " +\
		"type: %s" % script.resource_path)

func _scan_directory_recursive(path: String, result: FKProviderLoadResult) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		var file_path := path.path_join(file_name)
		var found_subdir: bool = dir.current_is_dir() and not file_name.begins_with(".")
		var found_script: bool = not found_subdir and (file_name.ends_with(".gd") and not \
		file_name.ends_with(".gd.uid"))
		if found_subdir:
			_scan_directory_recursive(file_path, result)
		elif found_script:
			var script: Variant = load(file_path)
			if script is GDScript:
				_try_add_provider(script, result)
		file_name = dir.get_next()
	dir.list_dir_end()


func _script_extends_provider(script: GDScript) -> bool:
	var current: GDScript = script
	while current != null:
		if current.get_global_name() == &"FKProvider":
			return true
		current = current.get_base_script()
	return false

func _provider_id_of(provider: FKProvider) -> String:
	var provider_id := provider.get_provider_id().strip_edges()
	return provider.get_id().strip_edges() if provider_id.is_empty() \
	else provider_id

func _collect_duplicate_id_diagnostics(providers: Array, kind: String, result: FKProviderLoadResult) -> void:
	var sources_by_id: Dictionary[String, String] = {}
	for provider_el in providers:
		var provider_id := _provider_id_of(provider_el)
		var source: String = provider_el.get_script().resource_path
		if sources_by_id.has(provider_id):
			result.diagnostics.append("Duplicate %s provider id '%s' in %s and %s" % \
			[kind, provider_id, sources_by_id[provider_id], source])
		else:
			sources_by_id[provider_id] = source