extends RefCounted
class_name ArrayUtils

static func get_fk_units_in(arr: Array) -> Array[FKUnit]:
	var result: Array[FKUnit] = []
	
	for child in arr:
		if child is FKUnit:
			result.append(child)
			
	return result
	
static func make_fk_action_dupes(arr: Array[FKActionUnit]) -> Array[FKActionUnit]:
	var result: Array[FKActionUnit] = []
	for elem in arr:
		if elem is not FKActionUnit:
			continue
		var dupe := elem.duplicate_block()
		result.append(dupe)
	return result
	
static func get_fk_action_units_in(arr: Array) -> Array[FKActionUnit]:
	var result: Array[FKActionUnit] = []
	
	for child in arr:
		if child is FKActionUnit:
			result.append(child)
			
	return result

static func make_fk_condition_dupes(arr: Array[FKConditionUnit]) -> Array[FKConditionUnit]:
	var result: Array[FKConditionUnit] = []
	for elem in arr:
		if elem is not FKConditionUnit:
			# ^Why this weird check? At some point in dev, an FKEventSheet made it into
			# the platformer demo's conditions list. Need to filter such weirdness out.
			continue
		var dupe := elem.duplicate_block()
		result.append(dupe)
	return result
	
static func get_fk_condition_units_in(arr: Array) -> Array[FKConditionUnit]:
	var result: Array[FKConditionUnit] = []
	
	for child in arr:
		if child is FKConditionUnit:
			result.append(child)
			
	return result
