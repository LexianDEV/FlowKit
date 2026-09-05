extends FKAction

func get_description() -> String:
	return "Sets the wait time of the timer."

func get_id() -> String:
	return "set_wait_time"

func get_display_name() -> String:
	return "Set Wait Time"

func get_inputs() -> Array[FKActionInput]:
	return [_wait_time_input]

static var _wait_time_input: FKFloatActionInput:
	get:
		return FKFloatActionInput.new("Wait Time",
		"The wait time in seconds to set for the timer.",
		1.0)

func get_supported_types() -> Array[String]:
	return ["Timer"]

func execute(node: Node, inputs: Dictionary, block_id: int = -1) -> void:
	if node and node is Timer:
		var wait_time: float = _wait_time_input.get_val(inputs)
		node.wait_time = wait_time
