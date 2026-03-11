extends FKAction

func get_description() -> String:
	return "Waits for a specified number of seconds to pass before moving on to the next Action."

func get_id() -> String:
	return "Wait For Seconds"

func get_name() -> String:
	return "Wait For Seconds"

func get_supported_types() -> Array:
	return ["System"]
	
func requires_multi_frames() -> bool:
	return true
	
func get_inputs() -> Array[FKActionInput]:
	return [_duration_input]

static var _duration_input: FKFloatActionInput:
	get:
		return FKFloatActionInput.new("Duration", "What you'd expect.")

func execute(target_node: Node, inputs: Dictionary, _str := "") -> void:
	var duration: float = _duration_input.get_val(inputs)
	var valid_input := duration > 0
	var tree := target_node.get_tree()
	
	if (valid_input):
		var timer := tree.create_timer(duration)
		await timer.timeout
	else:
		var message := "[color=red][FlowKit] Duration input passed to Wait For Seconds Action ("
		message += str(duration) + ") is not valid. Skipping.[/color]" 
		print_rich(message)
		
	exec_completed.emit()
	
