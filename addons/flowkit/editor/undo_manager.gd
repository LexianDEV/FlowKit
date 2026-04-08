# FKUndoManager.gd
extends RefCounted
class_name FKUndoManager

const MAX_UNDO_STATES := 50

var _undo_stack: Array = []
var _redo_stack: Array = []

func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()

func can_undo() -> bool:
	return not _undo_stack.is_empty()

func can_redo() -> bool:
	return not _redo_stack.is_empty()

func _deep_copy_units(units: Array) -> Array:
	var result: Array = []
	for u in units:
		if u == null:
			result.append(null)
		elif u is FKUnit:
			#print("[UndoManager]: Deep copying an FKUnit of type " + u.get_class())
			result.append(u.duplicate_block())
		elif u is Resource:
			#print("[UndoManager]: Deep copying some non-FKUnit resource")
			result.append(u.duplicate(true))
		else:
			#print("[UndoManager]: Deep copying a dict")
			if u is Array or u is Dictionary:
				result.append(u.duplicate(true))
			else:
				result.append(u)
	return result

func push_state(units: Array) -> void:
	#print("[UndoManager]: Deep copying units")
	var snapshot := _deep_copy_units(units)
	
	_undo_stack.append(snapshot)
	#print("[FKMainEditor]: Snapshot appended to undo stack:")
	#print(str(snapshot))
	#if snapshot.size() == 1 and snapshot[0] is FKGroup:
		#print("Its children:")
		#var group: FKGroup = snapshot[0]
		#for elem in group.children:
			#print(elem.get_class() + ": " + str(elem))

	while _undo_stack.size() > MAX_UNDO_STATES:
		_undo_stack.pop_front()

	_redo_stack.clear()

# Returns a previous snapshot of the units' state
func undo(current_units: Array[FKUnit]) -> Array:
	if _undo_stack.is_empty():
		print("[UndoManager]: Current stack is empty. Returning passed units.")
		return current_units
	
	var current_snapshot := _deep_copy_units(current_units)
	_redo_stack.append(current_snapshot)
	#print("[FKMainEditor]: Snapshot given to redo stack:")
	#print(str(current_snapshot))
	
	var to_pop_back: Array = _undo_stack.pop_back()
	#print("[FKMainEditor]: Popped back from undo stack:")
	#for elem in to_pop_back:
		#print(elem.get_class() + ":|" + str(elem))
		
	if to_pop_back.size() == 1 and to_pop_back[0] is FKGroup:
		var group: FKGroup = to_pop_back[0]
		#print("Group children of to_pop_back in undo:")
		#for elem in group.children:
			#print(str(elem) + " of type " + elem.get_class())
		
	return to_pop_back

func redo(current_units: Array) -> Array:
	if _redo_stack.is_empty():
		return current_units

	var current_snapshot := _deep_copy_units(current_units)
	_undo_stack.append(current_snapshot)
	
	var to_pop_back: Array = _redo_stack.pop_back()
	#print("[FKMainEditor]: Popped back from redo stack:")
	#for elem in to_pop_back:
		#print(str(elem))
	return to_pop_back
	
