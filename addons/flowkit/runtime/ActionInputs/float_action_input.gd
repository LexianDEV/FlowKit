extends FKActionInput

class_name FKFloatActionInput

func _init(init_name: String = "", init_desc: String = "", init_default: float = 0):
	name = init_name
	_type = "float"
	description = init_desc
	_default_value = init_default

# For Intellisense
func get_val(dict: Dictionary) -> float:
	return super.get_val(dict)
	
func _convert(raw: Variant):
	if (raw is String and raw == ""):
		return _default_value
	return float(raw)
