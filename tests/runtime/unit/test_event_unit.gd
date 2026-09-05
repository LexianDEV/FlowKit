extends GutTest

func test_event_basic_serialization():
    var ev := FKEventUnit.new("on_ready", NodePath("Player"))
    ev.uid = 10
    ev.inputs = {"speed": 5}

    var cond := FKConditionUnit.new()
    cond.condition_id = "IsReady"
    cond.target_node = NodePath("Player")
    cond.inputs = {"threshold": 3}
    ev.conditions.append(cond)

    var act := FKActionUnit.new()
    act.action_id = "Move"
    act.target_node = NodePath("Player")
    act.inputs = {"amount": 2}
    ev.actions.append(act)

    var json := ev.serialize()

    assert_eq(json["type"], "event")
    assert_eq(json["event_id"], "on_ready")
    assert_eq(json["target_node"], "Player")
    assert_eq(json["inputs"], {"speed": 5})

    assert_eq(json["conditions"].size(), 1)
    assert_eq(json["conditions"][0]["condition_id"], "IsReady")

    assert_eq(json["actions"].size(), 1)
    assert_eq(json["actions"][0]["action_id"], "Move")


func test_event_roundtrip():
    var ev := FKEventUnit.new("on_process", NodePath("Enemy"))
    ev.uid = 77
    ev.inputs = {"delta": 0.016}

    var cond := FKConditionUnit.new()
    cond.condition_id = "HealthLow"
    cond.target_node = NodePath("Enemy")
    cond.inputs = {"hp": 20}
    ev.conditions.append(cond)

    var act := FKActionUnit.new()
    act.action_id = "Attack"
    act.target_node = NodePath("Enemy")
    act.inputs = {"damage": 50}
    ev.actions.append(act)

    var json := ev.serialize()

    var restored := FKEventUnit.new()
    restored.deserialize(json)

    assert_eq(restored.event_id, "on_process")
    assert_eq(restored.target_node, NodePath("Enemy"))
    assert_eq(restored.inputs, {"delta": 0.016})

    assert_eq(restored.conditions.size(), 1)
    assert_eq(restored.conditions[0].condition_id, "HealthLow")

    assert_eq(restored.actions.size(), 1)
    assert_eq(restored.actions[0].action_id, "Attack")


func test_event_deep_duplication():
    var ev := FKEventUnit.new("on_custom", NodePath("Mage"))
    ev.uid = 123
    ev.inputs = {"mana": 30}

    var cond := FKConditionUnit.new()
    cond.condition_id = "ManaHigh"
    cond.target_node = NodePath("Mage")
    cond.inputs = {"min": 25}
    ev.conditions.append(cond)

    var act := FKActionUnit.new()
    act.action_id = "CastSpell"
    act.target_node = NodePath("Mage")
    act.inputs = {"power": 7}
    ev.actions.append(act)

    var dup := ev.duplicate_block() as FKEventUnit

    # Base object must be a different instance
    assert_true(not is_same(dup, ev))

    # Inputs must be deep-copied
    assert_true(not is_same(dup.inputs, ev.inputs))
    assert_eq(dup.inputs, ev.inputs)

    # Conditions must be deep-copied
    assert_eq(dup.conditions.size(), 1)
    assert_true(not is_same(dup.conditions[0], ev.conditions[0]))
    assert_eq(dup.conditions[0].inputs, ev.conditions[0].inputs)

    # Actions must be deep-copied
    assert_eq(dup.actions.size(), 1)
    assert_true(not is_same(dup.actions[0], ev.actions[0]))
    assert_eq(dup.actions[0].inputs, ev.actions[0].inputs)

    # Mutate duplicate to ensure independence
    dup.inputs["mana"] = 999
    assert_ne(ev.inputs["mana"], dup.inputs["mana"])
