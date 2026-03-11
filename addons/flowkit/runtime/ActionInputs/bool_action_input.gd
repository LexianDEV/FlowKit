extends FKActionInput

class_name FKBoolActionInput

func _init(init_name: String = "", init_desc: String = "", init_default: bool = false):
	name = init_name
	_type = "bool"
	description = init_desc
	_default_value = init_default
	
# For Intellisense
func get_val(dict: Dictionary) -> bool:
	return super.get_val(dict)
	
func _convert(raw: Variant):
	if (raw is String and raw == ""):
		return _default_value
	return bool(raw)
