extends FKCondition

func get_description() -> String:
	return "Checks if the game is running on a mobile device (Android or iOS)."

func get_id() -> String:
	return "is_mobile"

func get_name() -> String:
	return "Is Mobile"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return []

func check(node: Node, inputs: Dictionary, block_id: String = "") -> bool:
	var os_name: String = OS.get_name()
	return os_name == "Android" or os_name == "iOS"
