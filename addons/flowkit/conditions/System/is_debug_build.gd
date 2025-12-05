extends FKCondition

func get_description() -> String:
	return "Checks if the game is running in debug mode (not an exported release build)."

func get_id() -> String:
	return "is_debug_build"

func get_name() -> String:
	return "Is Debug Build"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return []

func check(node: Node, inputs: Dictionary, block_id: String = "") -> bool:
	return OS.is_debug_build()
