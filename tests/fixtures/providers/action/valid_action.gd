extends FKAction

func get_provider_id() -> String:
	return "valid_action"

func get_supported_types() -> Array[String]:
	return ["Node"]