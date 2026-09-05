extends GutTest

func test_action_basic_serialization():
	var act := FKActionUnit.new()
	act.action_id = "Move"
	act.target_node = NodePath("Player")
	act.inputs = {"speed": 10}
	act.is_branch = true
	act.branch_type = "if"
	act.branch_id = "Cond01"
	act.branch_inputs = {"foo": "bar"}

	var cond := FKConditionUnit.new()
	cond.condition_id = "IsReady"
	cond.target_node = NodePath("Player")
	cond.inputs = {"threshold": 5}
	act.branch_condition = cond

	var child := FKActionUnit.new()
	child.action_id = "Jump"
	child.inputs = {"height": 3}
	act.branch_actions.append(child)

	var json := act.serialize()

	assert_eq(json["type"], "action")
	assert_eq(json["action_id"], "Move")
	assert_eq(json["target_node"], "Player")
	assert_eq(json["inputs"], {"speed": 10})
	assert_true(json["is_branch"])
	assert_eq(json["branch_type"], "if")
	assert_eq(json["branch_id"], "Cond01")
	assert_eq(json["branch_inputs"], {"foo": "bar"})

	assert_eq(json["branch_condition"]["condition_id"], "IsReady")
	assert_eq(json["branch_actions"][0]["action_id"], "Jump")


func test_action_roundtrip():
	var act := FKActionUnit.new()
	act.action_id = "Attack"
	act.target_node = NodePath("Enemy")
	var expected_action_inputs := {"damage": 50}
	act.inputs = expected_action_inputs
	act.is_branch = true
	act.branch_type = "elseif"
	act.branch_id = "Cond02"
	var expected_branch_inputs := {"mode": "rage"}
	act.branch_inputs = expected_branch_inputs

	var cond := FKConditionUnit.new()
	cond.condition_id = "HealthLow"
	cond.target_node = NodePath("Enemy")
	
	var expected_cond_inputs := {"hp": 20}
	cond.inputs = expected_cond_inputs
	act.branch_condition = cond

	var child := FKActionUnit.new()
	child.action_id = "Roar"
	var expected_child_action_inputs := {"volume": 100}
	child.inputs = expected_child_action_inputs
	act.branch_actions.append(child)

	var json := act.serialize()

	var restored := FKActionUnit.new()
	restored.deserialize(json)

	assert_eq(restored.action_id, "Attack")
	assert_eq(restored.target_node, NodePath("Enemy"))
	assert_eq(restored.inputs, expected_action_inputs)
	assert_true(restored.is_branch)
	assert_eq(restored.branch_type, "elseif")
	assert_eq(restored.branch_id, "Cond02")
	assert_eq(restored.branch_inputs, expected_branch_inputs)

	assert_eq(restored.branch_condition.condition_id, "HealthLow")
	assert_eq(restored.branch_actions[0].action_id, "Roar")


func test_action_deep_duplication():
	var act := FKActionUnit.new()
	act.action_id = "CastSpell"
	act.target_node = NodePath("Mage")
	var expected_action_inputs := {"mana": 30}
	act.inputs = expected_action_inputs
	act.is_branch = true
	act.branch_type = "if"
	act.branch_id = "Cond03"
	var expected_branch_inputs := {"element": "fire"}
	act.branch_inputs = expected_branch_inputs

	var cond := FKConditionUnit.new()
	cond.condition_id = "ManaHigh"
	cond.target_node = NodePath("Mage")
	var expected_cond_inputs := {"min": 25}
	cond.inputs = expected_cond_inputs
	act.branch_condition = cond

	var child := FKActionUnit.new()
	child.action_id = "Ignite"
	var expected_child_action_inputs := {"power": 7}
	child.inputs = expected_child_action_inputs
	act.branch_actions.append(child)

	var dup := act.duplicate_block() as FKActionUnit

	var deep_copy_success := not is_same(dup, act)
	assert_true(deep_copy_success)

	deep_copy_success = not is_same(dup.inputs, act.inputs)
	assert_true(deep_copy_success)

	deep_copy_success = not is_same(dup.branch_inputs, act.branch_inputs)
	assert_true(deep_copy_success)

	if act.branch_condition != null:
		deep_copy_success = not is_same(dup.branch_condition, act.branch_condition)
		assert_true(deep_copy_success)

	if act.branch_actions.size() > 0:
		deep_copy_success = not is_same(dup.branch_actions[0], act.branch_actions[0])
		assert_true(deep_copy_success)

	assert_eq(dup.action_id, "CastSpell")
	assert_eq(dup.inputs, act.inputs)
	assert_eq(dup.branch_inputs, act.branch_inputs)

	dup.inputs["mana"] = 999
	assert_ne(act.inputs["mana"], dup.inputs["mana"])
