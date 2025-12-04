extends FKCondition

# Track which blocks have run and their loop iteration state
# Format: {block_id: {last_frame: int, has_run_this_loop: bool}}
var loop_states: Dictionary = {}

func get_description() -> String:
	return "Run this event only once when looped. Resets when the event is no longer being triggered, allowing it to run again in the next loop."

func get_id() -> String:
	return "only_once_when_looped"

func get_name() -> String:
	return "Only Once When Looped"

func get_inputs() -> Array[Dictionary]:
	return []

func get_supported_types() -> Array[String]:
	return ["System"]

func check(node: Node, inputs: Dictionary, block_id: String = "") -> bool:
	var current_frame: int = Engine.get_physics_frames()
	
	# Initialize state for this block if not present
	if not loop_states.has(block_id):
		loop_states[block_id] = {"last_frame": current_frame, "has_run_this_loop": false}
		return true
	
	var state: Dictionary = loop_states[block_id]
	var last_frame: int = state["last_frame"]
	var has_run: bool = state["has_run_this_loop"]
	
	# If this is a new frame (still in the loop), check if we've already run
	if current_frame == last_frame:
		# Same frame: prevent re-execution in the loop
		return false
	else:
		# New frame detected - the loop must be running again
		# Reset the flag to allow execution in this new loop iteration
		state["last_frame"] = current_frame
		state["has_run_this_loop"] = true
		return true