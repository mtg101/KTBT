extends GdUnitTestSuite
## Tests for scripts/rules/groups.gd: customers coming in together (what they are to each other,
## who they are, how they pay).

const Groups = preload("res://scripts/rules/groups.gd")


func test_what_two_people_are_to_each_other() -> void:
	var total := 0.0
	for kind in Groups.KINDS:
		total += float(Groups.KINDS[kind]["chance"])
		var pay: Dictionary = Groups.KINDS[kind]["pay"]
		assert_float(pay.values().reduce(func(a, b): return a + b, 0.0)).is_equal_approx(1.0, 0.001)
	assert_float(total).is_equal_approx(1.0, 0.001)
	assert_str(Groups.pick(0.0)).is_equal("couple")
	assert_str(Groups.pick(0.999)).is_equal("sunbae")
	assert_bool(Groups.info("regulars")["close"]).is_true()
	assert_dict(Groups.info("no such")).is_empty()
	assert_str(Groups.note("colleagues", "Kim Ji-ho")).contains("Kim Ji-ho").contains("hoesik").contains("by name")
	assert_str(Groups.is_to("sunbae")).contains("hoobae")


func test_who_comes_with_whom() -> void:
	assert_str(Groups.second_gender("couple", "woman", 0.5, 0.0)).is_equal("man")
	assert_str(Groups.second_gender("couple", "woman", 0.05, 0.0)).is_equal("woman")  # (now and then)
	assert_str(Groups.second_gender("colleagues", "woman", 0.5, 0.7)).is_equal("man")
	assert_str(Groups.second_age_range("sunbae", "40s", 0.5)).is_equal("30s")  # (the hoobae's younger)
	assert_str(Groups.second_age_range("sunbae", "20s", 0.5)).is_equal("20s")
	assert_str(Groups.second_age_range("couple", "50s", 0.1)).is_equal("50s")
	assert_str(Groups.second_age_range("colleagues", "30s", 0.1)).is_equal("40s")


func test_how_they_pay() -> void:
	assert_str(Groups.pay_style("sunbae", 0.5)).is_equal("one_pays")
	assert_str(Groups.pay_style("sunbae", 0.9)).is_equal("fight")
	assert_str(Groups.pay_style("school_friends", 0.5)).is_equal("fight")
	assert_str(Groups.pay_style("couple", 0.95)).is_equal("split")
	assert_int(Groups.payer("sunbae", 0.9)).is_equal(0)  # (the sunbae pays)
	assert_int(Groups.payer("couple", 0.9)).is_equal(1)
	assert_int(Groups.bill_fight_loser(0.2)).is_equal(0)
	assert_int(Groups.bill_fight_loser(0.7)).is_equal(1)
