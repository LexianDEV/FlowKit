extends FKAction

static var _event_name_input: FKStringActionInput:
	get:
		return FKStringActionInput.new(
			"Event Name",
			"The name of the custom event to call."
		)

func get_description() -> String:
	return "Calls a custom event."

func get_id() -> String:
	return "call_custom_event"

func get_display_name() -> String:
	return "Call Custom Event"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[FKActionInput]:
	return [_event_name_input]

func execute(node: Node, inputs: Dictionary, unit_id: int = -1) -> void:
	var event_name: String = _event_name_input.get_val(inputs).strip_edges()

	if event_name.is_empty():
		return

	var system: FKSystem = node as FKSystem

	if system == null:
		push_error("Call Custom Event requires the System object.")
		return

	system.call_custom_event(event_name)