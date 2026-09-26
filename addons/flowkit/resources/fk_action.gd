extends FKProvider
class_name FKAction

func get_description() -> String:
	return "No description provided."

func get_inputs() -> Array[FKActionInput]:
	return []

const GENERAL_INPUT_MODAL_PATH := "res://addons/flowkit/editor/scenes/modals/FKActionCustom/general_action_input_modal.tscn"

## Backwards-compatible editor-only accessor. This stays lazy so exported builds
## do not retain the editor modal as a hard runtime dependency.
static var GENERAL_INPUT_MODAL: PackedScene:
	get:
		if not OS.has_feature("editor"):
			return null
		return load(GENERAL_INPUT_MODAL_PATH) as PackedScene

## Returns an optional editor modal scene for configuring this action's inputs.
func get_input_modal_scene() -> PackedScene:
	return GENERAL_INPUT_MODAL

## Whether or not this Action might need more than one frame to finish doing its thing.
func may_need_multi_frames() -> bool:
	return false

# If may_need_multi_frames is true, you'll want to make sure to emit this when 
# this FKAction is done doing its thing. The executor will then only move on
## to the next action when this is emitted.
signal exec_completed

func execute(node: Node, inputs: Dictionary, unit_id: int = -1) -> void:
	pass

func get_class() -> String:
	return "FKAction"
