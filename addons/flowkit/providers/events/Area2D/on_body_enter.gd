extends FKEvent

var _connections: Dictionary = {}

func get_description() -> String:
	return "Executes when a body enters the area."

func get_id() -> String:
	return "on_body_enter"

func get_name() -> String:
	return "On Body Enter"

func get_supported_types() -> Array[String]:
	return ["Area2D"]

func is_signal_event() -> bool:
	return true

func get_inputs() -> Array:
	return []

func setup(node: Node, trigger_callback: Callable, unit_id: int = -1) -> void:
	var area: Area2D = node as Area2D

	if area == null:
		push_error("On Body Enter requires an Area2D node.")
		return

	var callback: Callable = func(_body: Node2D) -> void:
		trigger_callback.call()

	_connections[unit_id] = callback
	area.body_entered.connect(callback)

func teardown(node: Node, unit_id: int = -1) -> void:
	var area: Area2D = node as Area2D

	if area == null:
		return

	if not _connections.has(unit_id):
		return

	var callback: Callable = _connections[unit_id]

	if area.body_entered.is_connected(callback):
		area.body_entered.disconnect(callback)

	_connections.erase(unit_id)