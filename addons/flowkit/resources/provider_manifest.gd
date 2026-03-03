extends Resource
class_name FKProviderManifest

## FlowKit Provider Manifest
## Stores preloaded references to only the provider scripts that are actively
## used in the project's event sheets. In exported builds, DirAccess cannot
## enumerate files, so this manifest is generated at edit-time and loaded at
## runtime. Unused providers are excluded from the build automatically.

## Preloaded action provider scripts (only those referenced by event sheets)
@export var action_scripts: Array[GDScript] = []

## Preloaded condition provider scripts (only those referenced by event sheets)
@export var condition_scripts: Array[GDScript] = []

## Preloaded event provider scripts (only those referenced by event sheets)
@export var event_scripts: Array[GDScript] = []

## Preloaded behavior provider scripts (only those referenced by scenes)
@export var behavior_scripts: Array[GDScript] = []

## Preloaded branch provider scripts (only those referenced by event sheets)
@export var branch_scripts: Array[GDScript] = []

## Resource paths of all scripts included in this manifest (used by export plugin)
@export var included_script_paths: Array[String] = []

## Resource paths of all provider scripts that were excluded (for reporting)
@export var excluded_script_paths: Array[String] = []
