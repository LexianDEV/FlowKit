@tool
extends EditorExportPlugin
class_name FKExportPlugin

## FlowKit Export Plugin
## Rebuilds the provider manifest for every export and removes editor-only
## FlowKit files plus unused providers from the packaged project.

const MANIFEST_PATH := "res://addons/flowkit/saved/provider_manifest.tres"
const EXPORTED_MANIFEST_PATH := "res://addons/flowkit/saved/provider_manifest.export.tres"
const EXPORT_MANIFEST_TEMP_PATH := "user://flowkit_provider_manifest_export.tres"
const EDITOR_PREFIX := "res://addons/flowkit/editor/"
const DEMOS_PREFIX := "res://addons/flowkit/demos/"

# Runtime still loads these settings, so keep only this small editor-side island
# until project settings are moved into a runtime-neutral location.
const EDITOR_RUNTIME_ALLOWLIST := {
	"res://addons/flowkit/editor/_fk_project_settings.tres": true,
	"res://addons/flowkit/editor/fk_project_settings.gd": true,
	"res://addons/flowkit/editor/fk_project_settings.gd.uid": true,
}

const ALWAYS_EXCLUDED := {
	"res://addons/flowkit/flowkit.gd": true,
	"res://addons/flowkit/flowkit.gd.uid": true,
	"res://addons/flowkit/generator.gd": true,
	"res://addons/flowkit/generator.gd.uid": true,
	"res://addons/flowkit/plugin.cfg": true,
}

var _excluded_provider_paths: Dictionary = {}
var _fresh_manifest_bytes: PackedByteArray = PackedByteArray()
var _manifest_injected: bool = false
var _exclude_count: int = 0
var _strip_demos: bool = true
var _generator = null


func set_generator(gen) -> void:
	_generator = gen


func _get_name() -> String:
	return "FlowKit"


func _export_begin(
	features: PackedStringArray,
	is_debug: bool,
	path: String,
	flags: int
) -> void:
	_excluded_provider_paths.clear()
	_fresh_manifest_bytes = PackedByteArray()
	_manifest_injected = false
	_cleanup_manifest_temp()
	_exclude_count = 0
	_strip_demos = not _main_scene_uses_flowkit_demos()
	if not _strip_demos:
		print("[FlowKit Export] Keeping FlowKit demos because the project's main scene is a demo.")

	if not _generator:
		push_warning(
			"[FlowKit Export] Generator unavailable. " +
			"Editor-only files will still be stripped, but provider pruning is disabled."
		)
		return

	print("[FlowKit Export] Rebuilding provider manifest before export...")
	var result: Dictionary = _generator.generate_manifest()
	var errors: Array = result.get("errors", [])
	if not errors.is_empty():
		push_warning(
			"[FlowKit Export] Manifest generation reported errors. " +
			"Provider pruning is disabled for this export: %s" % str(errors)
		)
		return

	# Consume the exact data produced by this generation pass. Do not reload the
	# saved manifest: the editor and export pipeline can both retain cached
	# representations of that path.
	var manifest_variant: Variant = result.get("manifest", null)
	var manifest: Resource = manifest_variant as Resource
	if manifest == null:
		push_warning(
			"[FlowKit Export] Generator did not return a fresh manifest object. " +
			"Provider pruning is disabled for this export."
		)
		return

	var expected_included: int = int(result.get("total_included", 0))
	var included_variant: Variant = manifest.get("included_script_paths")
	var included: Array = included_variant if included_variant is Array else []
	if included.size() != expected_included:
		push_warning(
			(
				"[FlowKit Export] Fresh manifest verification failed: generator reported %d providers, " +
				"but the in-memory manifest contains %d. Provider pruning is disabled for this export."
			) % [expected_included, included.size()]
		)
		return

	print("[FlowKit Export] Fresh in-memory manifest verified: %d provider paths." % included.size())

	var excluded_variant: Variant = result.get("excluded_script_paths", [])
	var excluded: Array = excluded_variant if excluded_variant is Array else []

	for script_path_variant in excluded:
		var script_path: String = str(script_path_variant)
		_excluded_provider_paths[script_path] = true
		_excluded_provider_paths[script_path + ".uid"] = true
		_excluded_provider_paths[script_path + ".import"] = true

	# Serialize the fresh in-memory Resource to a user:// scratch file, then keep
	# its bytes for add_file(). This path is deliberately unrelated to the saved
	# project manifest, so neither ResourceLoader nor Godot's export conversion
	# cache can substitute an older provider set.
	var save_error: Error = ResourceSaver.save(manifest, EXPORT_MANIFEST_TEMP_PATH)
	if save_error != OK:
		_excluded_provider_paths.clear()
		push_warning(
			"[FlowKit Export] Could not serialize the fresh provider manifest. " +
			"Provider pruning is disabled for this export: %s" % error_string(save_error)
		)
		_cleanup_manifest_temp()
		return

	var manifest_file: FileAccess = FileAccess.open(EXPORT_MANIFEST_TEMP_PATH, FileAccess.READ)
	if manifest_file == null:
		_excluded_provider_paths.clear()
		push_warning(
			"[FlowKit Export] Serialized provider manifest could not be opened. " +
			"Provider pruning is disabled for this export."
		)
		_cleanup_manifest_temp()
		return

	_fresh_manifest_bytes = manifest_file.get_buffer(manifest_file.get_length())
	manifest_file.close()
	_cleanup_manifest_temp()

	if _fresh_manifest_bytes.is_empty():
		_excluded_provider_paths.clear()
		push_warning(
			"[FlowKit Export] Serialized provider manifest was empty. " +
			"Provider pruning is disabled for this export."
		)
		return

	print(
		"[FlowKit Export] Manifest ready: %d providers included, %d unused providers excluded."
		% [
			int(result.get("total_included", 0)),
			int(result.get("total_excluded", 0)),
		]
	)


func _export_file(
	path: String,
	type: String,
	features: PackedStringArray
) -> void:
	# Replace the normal converted manifest with the exact text resource just
	# generated for this export. Using a different virtual path with remap=true
	# makes Godot omit the cached original and point MANIFEST_PATH at this file.
	if path == MANIFEST_PATH and not _fresh_manifest_bytes.is_empty():
		add_file(EXPORTED_MANIFEST_PATH, _fresh_manifest_bytes, true)
		_manifest_injected = true
		print("[FlowKit Export] Injected fresh provider manifest into the export package.")
		return

	if _should_exclude(path):
		skip()
		_exclude_count += 1


func _should_exclude(path: String) -> bool:
	if _excluded_provider_paths.has(path):
		return true

	if ALWAYS_EXCLUDED.has(path):
		return true

	if _strip_demos and path.begins_with(DEMOS_PREFIX):
		return true

	if path.begins_with(EDITOR_PREFIX) and not EDITOR_RUNTIME_ALLOWLIST.has(path):
		return true

	return false


func _cleanup_manifest_temp() -> void:
	if not FileAccess.file_exists(EXPORT_MANIFEST_TEMP_PATH):
		return
	var user_dir: DirAccess = DirAccess.open("user://")
	if user_dir:
		user_dir.remove(EXPORT_MANIFEST_TEMP_PATH.get_file())


func _main_scene_uses_flowkit_demos() -> bool:
	var main_scene_ref: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	if main_scene_ref.is_empty():
		return false

	var main_scene_path: String = main_scene_ref
	if main_scene_ref.begins_with("uid://"):
		var uid: int = ResourceUID.text_to_id(main_scene_ref)
		if uid != ResourceUID.INVALID_ID:
			var resolved_path: String = ResourceUID.get_id_path(uid)
			if not resolved_path.is_empty():
				main_scene_path = resolved_path

	return main_scene_path.begins_with(DEMOS_PREFIX)


func _export_end() -> void:
	if not _fresh_manifest_bytes.is_empty() and not _manifest_injected:
		push_warning(
			"[FlowKit Export] A fresh provider manifest was generated, but Godot did not visit " +
			"the manifest during export. Check the export preset's resource filters."
		)

	print("[FlowKit Export] Stripped %d FlowKit files from the exported build." % _exclude_count)
	_excluded_provider_paths.clear()
	_fresh_manifest_bytes = PackedByteArray()
	_manifest_injected = false
	_exclude_count = 0
	_strip_demos = true
