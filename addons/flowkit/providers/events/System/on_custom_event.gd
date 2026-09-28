extends FKEvent

static var _event_name_input: FKStringActionInput:
	get:
		return FKStringActionInput.new(
			"Event Name",
			"The name of the custom event to listen for."
		)

var _callback: Callable

func get_description() -> String:
	return "Triggers when a custom event with the specified name is fired."

func get_id() -> String:
	return "on_custom_event"

func get_name() -> String:
	return "On Custom Event"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[FKActionInput]:
	return [_event_name_input]

func is_signal_event() -> bool:
	return true

func setup_with_inputs(
	node: Node,
	inputs: Dictionary,
	trigger_callback: Callable,
	unit_id: int = -1
) -> void:
	var system: FKSystem = node as FKSystem

	if system == null:
		push_error("On Custom Event requires the System object.")
		return

	var event_name: String = _event_name_input.get_val(inputs).strip_edges()

	if event_name.is_empty():
		return

	_callback = func(called_event_name: String) -> void:
		if called_event_name == event_name:
			trigger_callback.call()

	system.custom_event_called.connect(_callback)

func teardown(node: Node, unit_id: int = -1) -> void:
	var system: FKSystem = node as FKSystem

	if system == null:
		return

	if not _callback.is_valid():
		return

	if system.custom_event_called.is_connected(_callback):
		system.custom_event_called.disconnect(_callback)