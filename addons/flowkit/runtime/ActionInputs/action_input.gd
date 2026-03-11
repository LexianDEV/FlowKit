extends RefCounted

class_name FKActionInput

func _init(init_name: String = "", init_type: String = "Variant", 
init_desc: String = "", init_default: Variant = null):
	name = init_name
	_type = init_type
	description = init_desc
	_default_value = init_default
	
@export var name: String = ""
var type: String:
	get:
		return _type
	
var _type: String = ""

@export var description: String = ""

@export var default_value: Variant:
	get:
		return _default_value

var _default_value

func get_val(dict: Dictionary) -> Variant:
	var raw_result: Variant = _get_raw(dict)
	var result = _convert(raw_result)
	return result
	
func _get_raw(dict: Dictionary) -> Variant:
	var result
	if dict.has(name):
		result = dict[name]
		
	var lower := name.to_lower()
	if dict.has(lower):
		result = dict[lower]
	
	if _is_valid(result):
		return result
	else:
		return _default_value

func _is_valid(fetched_value):
	return true
	
func _convert(input):
	return input
