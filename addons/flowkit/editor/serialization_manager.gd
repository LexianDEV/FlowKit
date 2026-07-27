@tool
class_name FKSerializationManager
# Note: we serialize to Dictionaries (instead of Resources) for the sake of the undo/redo
# system. Of course, we _de_serialize to Resources since that's what we most
# want to use in RAM.

# Serialization #

## Capture the state of the passed FKUnit Nodes as serialized data.
func capture_state(unit_arr: Array[FKUnitUi]) -> Array[Dictionary]:
	#print("FKSerializationManager: units gotten: " + str(unit_arr))
	var state: Array[Dictionary] = []

	for unit in unit_arr:
		# Double-check the unit is still valid and not queued for deletion
		if not is_instance_valid(unit) or unit.is_queued_for_deletion():
			continue
		
		var serialized := serialize_unit(unit)
		state.append(serialized)
			
	return state
	
	
func serialize_unit(unit_ui: Node) -> Dictionary:
	# At the time of this writing, all unit node classes except group_ui implement FKUnitUi
	print("Serializer working with " + str(unit_ui))
	var data: FKUnit = null
	if unit_ui.has_method("_to_string"):
		print("Serializing unit node of type " + unit_ui.get_class())
		
	if unit_ui is FKUnitUi:
		data = unit_ui.get_unit()
	else:
		printerr("FKSerializationManager serialize_unit: Node does not expose unit data.")
		return {}

	return data.serialize()


# Deserialization #
func restore_state(state: Array[Dictionary]) -> Array[FKUnit]:
	var result: Array[FKUnit] = []

	for dict in state:
		var unit := deserialize_unit(dict)
		if unit:
			result.append(unit)
			
	return result
	
	
func deserialize_unit(dict: Dictionary) -> FKUnit:
	var unit_type := dict.get("type", "")
	
	print("Deserializing dict with its type being " + unit_type)
	var unit := _instantiate_unit(unit_type)
	if unit == null:
		printerr("FKSerializationManager deserialize_unit: Unknown FKUnit type '%s'" % unit_type)
		return null

	unit.deserialize(dict)
	return unit

func _instantiate_unit(unit_type: String) -> FKUnit:
	match unit_type:
		"event":
			return FKEventUnit.new()
		"action": 
			return FKActionUnit.new()
		"comment":
			return FKComment.new()
		"group":
			return FKGroupUnit.new()
		"condition": 
			return FKConditionUnit.new()
		_:
			return null


	
