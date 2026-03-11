extends FKAction

func get_description() -> String:
	return "Waits for a specified number of frames (not seconds!) to pass before moving on to the next Action."

func get_id() -> String:
	return "Wait For Frames"

func get_name() -> String:
	return "Wait For Frames"

func get_supported_types() -> Array:
	return ["System"]
	
func requires_multi_frames() -> bool:
	return true
	
func get_inputs() -> Array[FKActionInput]:
	return [_frame_input]

static var _frame_input: FKIntActionInput:
	get:
		return FKIntActionInput.new("Frame Count", "What you'd expect")

func execute(target_node: Node, inputs: Dictionary, _str := "") -> void:
	var frame_count: float = _frame_input.get_val(inputs)
	var tree := target_node.get_tree()
	
	var valid_input := frame_count > 0
	if (valid_input):
		while frame_count > 0:
			await tree.process_frame
			frame_count -= 1
	else:
		var message := "[color=red][FlowKit] Frame Count input passed to Wait For Frames Action ("
		message += str(frame_count) + ") is not valid. Skipping.[/color]" 
		print_rich(message)
		
	exec_completed.emit()
	
