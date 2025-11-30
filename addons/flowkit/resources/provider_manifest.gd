extends Resource
class_name FKProviderManifest

## FlowKit Provider Manifest
## Stores preloaded references to all provider scripts for exported builds.
## In exported builds, DirAccess cannot enumerate files, so this manifest
## is generated at edit-time and loaded at runtime.

## Preloaded action provider scripts
@export var action_scripts: Array[GDScript] = []

## Preloaded condition provider scripts
@export var condition_scripts: Array[GDScript] = []

## Preloaded event provider scripts
@export var event_scripts: Array[GDScript] = []

## Preloaded behavior provider scripts
@export var behavior_scripts: Array[GDScript] = []
