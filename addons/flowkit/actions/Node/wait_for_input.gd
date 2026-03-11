extends FKAction

func get_description() -> String:
	return "Waits for a specified input to happen before moving on to the next Action."

func get_id() -> String:
	return "Wait For Input"

func get_name() -> String:
	return "Wait For Input"

func get_supported_types() -> Array:
	return ["System"]
	
func requires_multi_frames() -> bool:
	return true
	
func get_inputs() -> Array[FKActionInput]:
	return [_name_input]
	
static var _name_input: FKStringActionInput:
	get:
		return FKStringActionInput.new("Input Binding Name", 
		"You can find the binding names in Project->Input Map. Careful not to leave this empty!")

func execute(target_node: Node, inputs: Dictionary, _str := "") -> void:
	var binding := _name_input.get_val(inputs)
	var tree := target_node.get_tree()
	
	while true:
		var pressed := Input.is_action_just_pressed(binding)
		if pressed:
			break
		await tree.process_frame
		
	exec_completed.emit()
