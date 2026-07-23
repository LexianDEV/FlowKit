@tool
extends Resource
class_name FKIdAssigner

## Highest ID found during the last refresh.
@export_storage var _latest_id_given: int = -1

## It is assumed that all elements inherit from Object
func refresh_for(items: Array) -> int:
	_validate_and_register_init_taken_ids(items)
	_refresh_latest_id_given()
	_assign_new_ids_as_needed(items)
	_refresh_latest_id_given() # To take the new assignments into account

	return _latest_id_given

func _validate_and_register_init_taken_ids(items: Array):
	var error_message := ""
	for elem in items:
		if not elem.has_method("get"):
			error_message = _GET_METHOD_MISSING % elem
			push_error(error_message)
			continue

		var current_id = elem.get(prop_name)

		var wrong_type: bool = current_id != null and typeof(current_id) != TYPE_INT
		if wrong_type:
			error_message = _INVALID_PROP_TYPE % [prop_name, elem]
			push_error(error_message)
			continue

		var found_valid_id: bool = current_id != null
		if found_valid_id:
			_taken_ids.append(current_id)


const _GET_METHOD_MISSING := "[FKIdAssigner]: element does not support get(): %s. " +\
			"Items must each inherit from Object."

const _INVALID_PROP_TYPE := "[FKIdAssigner]: property %s must be an int or null on %s"

## Name of the property that stores the unit's ID, which should be an int.
## Clients are expected to set this.
var prop_name: String = "":
	get:
		return prop_name
	set(value):
		prop_name = value	

func _refresh_latest_id_given():
	_latest_id_given = _taken_ids.min()
	for id in _taken_ids:
		if id > _latest_id_given:
			_latest_id_given = id

func reset_taken_caches():
	_taken_ids.clear()
	_taken_ids.append_array(_invalid_ids) 
	# ^So we don't need to check specifically for invalid ids

	_latest_id_given = _taken_ids.min()
	# ^Helps us avoid assigning needlessly-high ids upon duplication and such

var _taken_ids: Array[int] = []

func _append_array_as_invalid(new_invalids: Array[int]):
	for elem in new_invalids:
		_append_as_invalid(elem)

func _append_as_invalid(new_invalid: int):
	if not _invalid_ids.has(new_invalid):
		_invalid_ids.append(new_invalid)

func _remove_array_as_invalid(invalids: Array[int]):
	for elem in invalids:
		_remove_as_invalid(elem)

func _remove_as_invalid(invalid: int):
	var ind := _invalid_ids.find(invalid)
	if ind >= 0:
		_invalid_ids.remove_at(ind) 

var _invalid_ids: Array[int] = [0, -1]
# ^Any magic numbers here are common values for invalid ids.

func _assign_new_ids_as_needed(items: Array):
	# At this point, we assume that all the contents inherit from Object
	for elem in items:
		var current_id = elem.get(prop_name)

		var has_int_id: bool = current_id != null and typeof(current_id) == TYPE_INT
		var wrong_type: bool = current_id != null and not has_int_id
		var is_dupe: bool = has_int_id and _taken_ids.count(current_id) > 1
		var needs_new_id: bool = (
			current_id == null
			or wrong_type
			or is_dupe
		)

		if needs_new_id:
			current_id = _assign_next_uid_to(elem)

		_taken_ids.append(current_id)

func _assign_next_uid_to(unit: Object) -> int:
	var new_id: int = _latest_id_given + 1
	unit.set(prop_name, new_id)
	_latest_id_given = new_id
	return new_id

func get_real_class() -> String:
	return "FKIdAssigner"