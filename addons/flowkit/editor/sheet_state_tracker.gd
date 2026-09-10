extends RefCounted
class_name FKSheetStateTracker

const MAX_HISTORY := 50
const DEBUG_MESSAGES := false
var enabled: bool = false

var _history: Array = [] # Past snapshots
var _future: Array = [] # Forward snapshots

func clear() -> void:
	_history.clear()
	_future.clear()

func has_previous() -> bool:
	return not _history.is_empty()

func has_next() -> bool:
	return not _future.is_empty()

func _deep_copy_units(units: Array) -> Array:
	if not enabled:
		return []
	var result: Array = []

	for unitEl in units:
		if unitEl == null:
			result.append(null)
		elif unitEl is FKUnit:
			result.append(unitEl.duplicate_block())
		elif unitEl is Resource:
			result.append(unitEl.duplicate(true))
		elif unitEl is Array or unitEl is Dictionary:
			result.append(unitEl.duplicate(true))
		else:
			result.append(unitEl)

	return result

## Stores a copy of the sheet's current state.
## This function takes the list of FKUnits currently in the editor,
## makes a deep copy of them, and adds that snapshot to the history.
## Each snapshot represents “what the sheet looked like” before a
## change happened. This is what allows the editor to step backward
## through previous states when the user performs an undo.
## After recording the snapshot, the forward history (redo stack) is
## cleared because any new change breaks the redo chain.
func record_snapshot(units: Array) -> void:
	if not enabled:
		return
	var snapshot := _deep_copy_units(units)
	_history.append(snapshot)
	print("[FKSheetStateTracker]: Recorded snapshot. History size =", _history.size())
	_enforce_history_size_cap()
	_future.clear()


func _enforce_history_size_cap():
	while _history.size() > MAX_HISTORY:
		_history.pop_front()


## Returns the most recently recorded snapshot of the sheet.
## This function is used when the user performs an undo. It takes the
## current sheet state, saves a copy of it into the forward history
## (so redo will work), then removes and returns the last snapshot
## from the history list. The returned snapshot represents the sheet
## state from before the most recent change.
## If no snapshots exist, the current sheet state is returned instead.
func get_previous_snapshot(current_units: Array[FKUnit]) -> Array:
	if _history.is_empty() or not enabled:
		return current_units

	var current_snapshot := _deep_copy_units(current_units)
	_future.append(current_snapshot)

	var popped: Array = _history.pop_back()
	return popped

func get_next_snapshot(current_units: Array) -> Array:
	if _future.is_empty() or not enabled:
		return current_units

	var current_snapshot := _deep_copy_units(current_units)
	_history.append(current_snapshot)

	var popped: Array = _future.pop_back()
	return popped
