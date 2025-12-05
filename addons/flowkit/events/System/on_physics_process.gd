extends FKEvent

func get_description() -> String:
	return "Triggers on every physics frame (every _physics_process call)."

func get_id() -> String:
	return "on_physics_process"

func get_name() -> String:
	return "On Physics Process"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array:
	return []

func poll(node: Node, inputs: Dictionary = {}, block_id: String = "") -> bool:
	# This will be called during physics processing
	return true
