extends RefCounted
class_name FKProviderLoader

const DEFAULT_MANIFEST_PATH := "res://addons/flowkit/saved/provider_manifest.tres"

var manifest_path: String = DEFAULT_MANIFEST_PATH
var provider_paths: Dictionary[String, String] = {
	"action": "res://addons/flowkit/actions",
	"condition": "res://addons/flowkit/conditions",
	"event": "res://addons/flowkit/events",
	"behavior": "res://addons/flowkit/behaviors",
	"branch": "res://addons/flowkit/branches",
}

func load_all() -> FKProviderLoadResult:
	var result := FKProviderLoadResult.new()
	if _load_from_manifest(result):
		result.source = "manifest"
	elif OS.has_feature("editor"):
		for kind in provider_paths:
			_scan_directory_recursive(provider_paths[kind], kind, result)
		result.source = "directory"
	else:
		result.source = "unavailable"
		result.errors.append("No provider manifest found and directory scanning is not available in exported builds. Generate the manifest in the editor.")

	_collect_duplicate_id_diagnostics(result.action_providers, "action", result)
	_collect_duplicate_id_diagnostics(result.condition_providers, "condition", result)
	_collect_duplicate_id_diagnostics(result.event_providers, "event", result)
	_collect_duplicate_id_diagnostics(result.behavior_providers, "behavior", result)
	_collect_duplicate_id_diagnostics(result.branch_providers, "branch", result)
	return result

func _load_from_manifest(result: FKProviderLoadResult) -> bool:
	if not ResourceLoader.exists(manifest_path):
		return false

	var manifest: Resource = load(manifest_path)
	if not manifest:
		return false

	_load_manifest_scripts(manifest.get("action_scripts"), "action", result)
	_load_manifest_scripts(manifest.get("condition_scripts"), "condition", result)
	_load_manifest_scripts(manifest.get("event_scripts"), "event", result)
	_load_manifest_scripts(manifest.get("behavior_scripts"), "behavior", result)
	_load_manifest_scripts(manifest.get("branch_scripts"), "branch", result)
	return result.get_total_provider_count() > 0

func _load_manifest_scripts(scripts: Variant, kind: String, result: FKProviderLoadResult) -> void:
	if scripts == null:
		return
	for script in scripts:
		if script is GDScript:
			_try_add_provider(script, kind, result)

func _scan_directory_recursive(path: String, kind: String, result: FKProviderLoadResult) -> void:
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		var file_path := path.path_join(file_name)
		if dir.current_is_dir() and not file_name.begins_with("."):
			_scan_directory_recursive(file_path, kind, result)
		elif file_name.ends_with(".gd") and not file_name.ends_with(".gd.uid"):
			var script: Variant = load(file_path)
			if script is GDScript:
				_try_add_provider(script, kind, result)
		file_name = dir.get_next()
	dir.list_dir_end()

func _try_add_provider(script: GDScript, kind: String, result: FKProviderLoadResult) -> void:
	var instance: Variant = script.new()
	if instance == null:
		result.diagnostics.append("Skipping provider that returned null on new(): %s" % script.resource_path)
		return
	if not instance is FKProvider:
		result.diagnostics.append("Skipping %s script that does not extend FKProvider: %s" % [kind, script.resource_path])
		return
	if instance.is_abstract_provider():
		return

	var provider := instance as FKProvider
	if _provider_id_of(provider).is_empty():
		result.diagnostics.append("Skipping %s provider with empty id: %s" % [kind, script.resource_path])
		return

	match kind:
		"action":
			if provider is FKAction:
				result.action_providers.append(provider)
			else:
				_add_wrong_kind_diagnostic(kind, script, result)
		"condition":
			if provider is FKCondition:
				result.condition_providers.append(provider)
			else:
				_add_wrong_kind_diagnostic(kind, script, result)
		"event":
			if provider is FKEvent:
				result.event_providers.append(provider)
			else:
				_add_wrong_kind_diagnostic(kind, script, result)
		"behavior":
			if provider is FKBehavior:
				result.behavior_providers.append(provider)
			else:
				_add_wrong_kind_diagnostic(kind, script, result)
		"branch":
			if provider is FKBranch:
				result.branch_providers.append(provider)
			else:
				_add_wrong_kind_diagnostic(kind, script, result)

func _add_wrong_kind_diagnostic(kind: String, script: GDScript, result: FKProviderLoadResult) -> void:
	result.diagnostics.append("Skipping script with incompatible %s provider type: %s" % [kind, script.resource_path])

func _provider_id_of(provider: FKProvider) -> String:
	var provider_id := provider.get_provider_id().strip_edges()
	return provider.get_id().strip_edges() if provider_id.is_empty() else provider_id

func _collect_duplicate_id_diagnostics(providers: Array, kind: String, result: FKProviderLoadResult) -> void:
	var sources_by_id: Dictionary[String, String] = {}
	for provider in providers:
		var provider_id := _provider_id_of(provider)
		var source: String = provider.get_script().resource_path
		if sources_by_id.has(provider_id):
			result.diagnostics.append("Duplicate %s provider id '%s' in %s and %s" % [kind, provider_id, sources_by_id[provider_id], source])
		else:
			sources_by_id[provider_id] = source