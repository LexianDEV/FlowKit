extends GutTest


func test_group_basic_serialization():
	var grp := FKGroup.new()
	grp.uid = 5
	grp.title = "MyGroup"
	grp.collapsed = true
	grp.color = Color(0.1, 0.2, 0.3, 1.0)

	var child_list := _make_child_units()
	for child in child_list:
		grp.add_child_unit(child)

	var grp_as_dict := grp.serialize()

	assert_eq(grp_as_dict["type"], "group")
	assert_eq(grp_as_dict["title"], "MyGroup")
	assert_true(grp_as_dict["collapsed"])
	assert_eq(grp_as_dict["color"], Color(0.1, 0.2, 0.3, 1.0))

	assert_eq(grp_as_dict["children"].size(), 3)
	assert_eq(grp_as_dict["children"][0]["type"], "condition")
	assert_eq(grp_as_dict["children"][1]["type"], "action")
	assert_eq(grp_as_dict["children"][2]["type"], "event")


func _make_child_units() -> Array[FKUnit]:
	var cond := FKConditionUnit.new()
	cond.condition_id = "Check"
	cond.target_node = NodePath("Player")
	cond.inputs = {"x": 1}

	var act := FKActionUnit.new()
	act.action_id = "DoThing"
	act.target_node = NodePath("Player")
	act.inputs = {"y": 2}

	var ev := FKEventUnit.new("on_ready", NodePath("Player"))
	ev.inputs = {"z": 3}

	return [cond, act, ev]

func test_group_roundtrip():
	var grp := FKGroup.new()
	grp.uid = 77
	grp.title = "RoundTrip"
	grp.collapsed = false
	grp.color = Color(0.5, 0.4, 0.3, 1.0)

	var child_list := _make_child_units()
	for child in child_list:
		grp.add_child_unit(child)

	var json := grp.serialize()

	var restored := FKGroup.new()
	restored.deserialize(json)

	assert_eq(restored.title, "RoundTrip")
	assert_eq(restored.collapsed, false)
	assert_eq(restored.color, Color(0.5, 0.4, 0.3, 1.0))

	assert_eq(restored.children.size(), 3)
	assert_eq(restored.children[0].get_class(), "FKConditionUnit")
	assert_eq(restored.children[1].get_class(), "FKActionUnit")
	assert_eq(restored.children[2].get_class(), "FKEventUnit")


func test_group_deep_duplication():
	var grp := FKGroup.new()
	grp.uid = 123
	grp.title = "DeepCopy"
	grp.collapsed = true
	grp.color = Color(0.9, 0.8, 0.7, 1.0)

	var children := _make_child_units()
	for c in children:
		grp.add_child_unit(c)

	var dup := grp.duplicate_block()

	# Base object must be different
	assert_true(not is_same(dup, grp))

	# Children array must be different
	assert_true(not is_same(dup.children, grp.children))
	assert_eq(dup.children.size(), grp.children.size())

	# Each child must be deep-copied
	var grp_children := grp.get_children()
	for i in range(grp.get_child_count()):
		var original_child: FKUnit = grp_children[i]
		var copied_child: FKUnit = dup.children[i]

		assert_true(not is_same(copied_child, original_child))
		assert_eq(copied_child.get_class(), original_child.get_class())

		# Inputs must be deep-copied if present
		if original_child.has_method("serialize"):
			var orig_json := original_child.serialize()
			var copy_json := copied_child.serialize()
			assert_eq(orig_json, copy_json)

	# Mutate duplicate to ensure independence
	dup.title = "Changed"
	assert_ne(grp.title, dup.title)

	if dup.children[0] is FKConditionUnit:
		dup.children[0].inputs["x"] = 999
		assert_ne(grp.children[0].inputs["x"], dup.children[0].inputs["x"])
