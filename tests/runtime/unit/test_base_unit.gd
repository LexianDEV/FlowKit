extends GutTest

func test_fkunit_basic_serialization():
	var unit := FKUnit.new()
	unit.block_type = "event"
	var expected_id := 5
	unit.uid = expected_id

	var json := unit.serialize()

	assert_eq(json["type"], "event")
	assert_eq(json["uid"], expected_id)


func test_fkunit_roundtrip():
	var unit := FKUnit.new()
	unit.block_type = "comment"
	var expected_id := 42
	unit.uid = expected_id

	var json := unit.serialize()

	var restored := FKUnit.new()
	restored.deserialize(json)

	assert_eq(restored.uid, expected_id)


func test_fkunit_deep_duplication():
	var unit := FKUnit.new()
	unit.block_type = "group"
	var expected_id := 99
	unit.uid = expected_id

	var dup := unit.duplicate_block()

	var deep_copy_success := not is_same(dup, unit)
	assert_true(deep_copy_success)

	assert_eq(dup.block_type, "group")
	assert_eq(dup.uid, expected_id)
