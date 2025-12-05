extends FKCondition

func get_description() -> String:
	return "Checks if the game is running on a specific platform (e.g., Windows, Linux, macOS, Android, iOS, Web)."

func get_id() -> String:
	return "is_platform"

func get_name() -> String:
	return "Is Platform"

func get_supported_types() -> Array[String]:
	return ["System"]

func get_inputs() -> Array[Dictionary]:
	return [
		{"name": "Platform", "type": "String", "description": "The platform to check: 'windows', 'linux', 'macos', 'android', 'ios', 'web'."}
	]

func check(node: Node, inputs: Dictionary, block_id: String = "") -> bool:
	var platform_str: String = str(inputs.get("Platform", "")).to_lower()
	
	match platform_str:
		"windows": return OS.get_name() == "Windows"
		"linux": return OS.get_name() == "Linux"
		"macos", "osx": return OS.get_name() == "macOS"
		"android": return OS.get_name() == "Android"
		"ios": return OS.get_name() == "iOS"
		"web", "html5": return OS.get_name() == "Web"
		_: return false
