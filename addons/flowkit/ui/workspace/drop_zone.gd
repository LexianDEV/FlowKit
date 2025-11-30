@tool
extends Control

signal item_dropped(drag_data: Dictionary)

@export var accept_type: String = ""  # "condition_item" or "action_item"

func _can_drop_data(at_position: Vector2, data) -> bool:
	if not data is Dictionary:
		return false
	var drag_type = data.get("type", "")
	return drag_type == accept_type

func _drop_data(at_position: Vector2, data) -> void:
	if _can_drop_data(at_position, data):
		item_dropped.emit(data)
