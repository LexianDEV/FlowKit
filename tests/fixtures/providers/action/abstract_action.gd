extends FKAction

func is_abstract_provider() -> bool:
	return true

func get_provider_id() -> String:
	return "abstract_action"