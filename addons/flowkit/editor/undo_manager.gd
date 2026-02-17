extends RefCounted
class_name FKUndoManager

const MAX_UNDO_STATES: int = 50

var _undo_stack: Array = []
var _redo_stack: Array = []

func clear() -> void:
	_undo_stack.clear()
	_redo_stack.clear()

func can_undo() -> bool:
	return not _undo_stack.is_empty()

func can_redo() -> bool:
	return not _redo_stack.is_empty()

func push_state(state: Array) -> void:
	# Store a deep copy so later mutations don't affect history
	_undo_stack.append(state.duplicate(true))
	while _undo_stack.size() > MAX_UNDO_STATES:
		_undo_stack.pop_front()
	_redo_stack.clear()

func undo(current_state: Array) -> Array:
	if _undo_stack.is_empty():
		return current_state
	_redo_stack.append(current_state.duplicate(true))
	return _undo_stack.pop_back()

func redo(current_state: Array) -> Array:
	if _redo_stack.is_empty():
		return current_state
	_undo_stack.append(current_state.duplicate(true))
	return _redo_stack.pop_back()
