extends GutTest

func test_condition_basic_serialization():
    var cond := FKConditionUnit.new()
    cond.condition_id = "IsReady"
    cond.target_node = NodePath("Player")
    cond.inputs = {"threshold": 5}
    cond.negated = true

    var json := cond.serialize()

    assert_eq(json["type"], "condition")
    assert_eq(json["condition_id"], "IsReady")
    assert_eq(json["target_node"], "Player")
    assert_eq(json["inputs"], {"threshold": 5})
    assert_true(json["negated"])


func test_condition_roundtrip():
    var cond := FKConditionUnit.new()
    cond.condition_id = "HealthLow"
    cond.target_node = NodePath("Enemy")
    cond.inputs = {"hp": 20}
    cond.negated = false

    var json := cond.serialize()

    var restored := FKConditionUnit.new()
    restored.deserialize(json)

    assert_eq(restored.condition_id, "HealthLow")
    assert_eq(restored.target_node, NodePath("Enemy"))
    assert_eq(restored.inputs, {"hp": 20})
    assert_false(restored.negated)


func test_condition_deep_duplication():
    var cond := FKConditionUnit.new()
    cond.condition_id = "Check"
    cond.target_node = NodePath("Boss")
    cond.inputs = {"x": 1, "y": 2}
    cond.negated = true

    var dup := cond.duplicate_block() as FKConditionUnit

    var deep_copy_success := not is_same(dup, cond)
    assert_true(deep_copy_success)

    deep_copy_success = not is_same(dup.inputs, cond.inputs)
    assert_true(deep_copy_success)

    assert_eq(dup.inputs, cond.inputs)
    assert_eq(dup.condition_id, "Check")
    assert_eq(dup.target_node, NodePath("Boss"))
    assert_true(dup.negated)

    dup.inputs["x"] = 999
    assert_ne(cond.inputs["x"], dup.inputs["x"])
