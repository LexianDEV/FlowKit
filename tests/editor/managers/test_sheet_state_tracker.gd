extends GutTest

var state_tracker: FKSheetStateTracker

func before_each() -> void:
	state_tracker = FKSheetStateTracker.new()
	state_tracker.enabled = true

func test_undo_basic_behavior():
	var firstSnapshot: Array[FKUnit] = [FKEventUnit.new()]
	var secondSnapshot: Array[FKUnit] = [FKEventUnit.new(), FKConditionUnit.new()]

	state_tracker.record_snapshot(firstSnapshot)
	state_tracker.record_snapshot(secondSnapshot)

	assert_true(state_tracker.has_previous())

	var result := state_tracker.get_previous_snapshot(secondSnapshot)

	# Should return the most recently recorded snapshot (s2).
	assert_eq(result.size(), secondSnapshot.size())
	assert_true(result[0] is FKEventUnit)

	# Redo stack should now contain a deep copy of s2
	assert_true(state_tracker.has_next())

func test_undo_manager_deep_copy():
	var evBlock := FKEventUnit.new()
	evBlock.inputs = {"x": 1}
	var state: Array[FKUnit] = [evBlock]

	state_tracker.record_snapshot(state)

	# Mutate original after pushing
	evBlock.inputs["x"] = 999

	var popped := state_tracker.get_previous_snapshot(state)

	# The snapshot must NOT reflect the mutation
	assert_eq(popped[0].inputs["x"], 1)

	# And must not be the same instance
	var deep_copy_success := not is_same(popped[0], evBlock)
	assert_true(deep_copy_success)

func test_redo_restores_state():
	var firstSnapshot: Array[FKUnit] = [FKEventUnit.new()]
	var secondSnapshot: Array[FKUnit] = [FKEventUnit.new(), FKActionUnit.new()]

	state_tracker.record_snapshot(firstSnapshot)
	state_tracker.record_snapshot(secondSnapshot)

	var undo_result := state_tracker.get_previous_snapshot(secondSnapshot)
	assert_eq(undo_result.size(), secondSnapshot.size())
	# Since the first get_previous_snapshot should return the latest element
	# in the list (in this case, secondSnapshot).

	# After the redo, we expect the history to go back to having both elements
	var redo_result := state_tracker.get_next_snapshot(undo_result)
	assert_eq(redo_result.size(), secondSnapshot.size())
	assert_true(redo_result[1] is FKActionUnit)

func test_disabled_tracker_does_not_record_history():
	var disabled_tracker := FKSheetStateTracker.new()

	disabled_tracker.record_snapshot([FKEventUnit.new()])

	assert_false(disabled_tracker.has_previous())
