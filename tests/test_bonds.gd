extends GdUnitTestSuite
## Tests for scripts/rules/bonds.gd: one record for every pair that matters (the owner and a
## regular, two regulars), and moving a bar from before bonds into them.

const Bonds = preload("res://scripts/rules/bonds.gd")


func test_a_bond_is_one_record_whichever_way_round() -> void:
	var bar := {}
	assert_str(Bonds.key("b", "a")).is_equal(Bonds.key("a", "b"))
	assert_dict(Bonds.find(bar, "a", "b")).is_empty()  # (never met)
	var bond := Bonds.between(bar, "a", "b")
	assert_bool(Bonds.find(bar, "b", "a") == bond).is_true()
	assert_str(str(bond["how"])).is_equal("met at the counter")
	assert_bool(Bonds.meet(bond, 3)).is_true()
	assert_bool(Bonds.meet(bond, 3)).is_false()  # (once a night)
	Bonds.meet(bond, 5)
	assert_int(int(bond["meetings"])).is_equal(2)
	assert_int(int(bond["first_night"])).is_equal(3)
	assert_int(int(bond["last_night"])).is_equal(5)
	Bonds.learn_name(bond, "a")  # (a knows b's name...)
	assert_bool(Bonds.knows_name(bond, "a")).is_true()
	assert_bool(Bonds.knows_name(bond, "b")).is_false()  # (...not the other way round)
	assert_str(Bonds.other(bond, "a")).is_equal("b")
	Bonds.forget(bar, "b")  # (b's no longer a regular: their bonds go)
	assert_dict(Bonds.find(bar, "a", "b")).is_empty()


func test_each_side_remembers_and_older_memories_blur() -> void:
	var bond := Bonds.between({}, Bonds.OWNER, "ji-ho")
	for night in range(1, 6):
		Bonds.remember(bond, night, {Bonds.OWNER: "Night %d: the exam. Laughed a lot." % night, "ji-ho": "Night %d: kind owner. Good odeng." % night})
	assert_int(bond["memories"].size()).is_equal(Bonds.RECENT_MEMORIES)
	assert_array(Bonds.memories_by(bond, "ji-ho").map(func(m): return int(m["night"]))).is_equal([3, 4, 5])
	assert_str(Bonds.impression_of(bond, Bonds.OWNER)).is_equal("Night 1: the exam. Night 2: the exam.")  # (first sentences, oldest first)
	assert_str(Bonds.impression_of(bond, "ji-ho")).contains("kind owner").not_contains("odeng")


func test_how_close_from_what_the_game_knows() -> void:
	var bar := {}
	var owner_bond := Bonds.between(bar, Bonds.OWNER, "ji-ho")
	assert_str(Bonds.level_word(owner_bond)).is_equal("stranger")
	owner_bond["meetings"] = 1
	assert_str(Bonds.level_word(owner_bond)).is_equal("acquaintance")
	owner_bond["warmth"] = 1
	assert_str(Bonds.level_word(owner_bond)).is_equal("friendly")
	owner_bond["warmth"] = 5
	assert_str(Bonds.level_word(owner_bond)).is_equal("friendly")  # (warm, but only met once: 19 Nov, close after two visits)
	owner_bond["meetings"] = Bonds.OWNER_FRIENDLY
	assert_str(Bonds.level_word(owner_bond)).is_equal("close")  # (friendly by now, and warm)
	owner_bond["warmth"] = 0
	owner_bond["meetings"] = Bonds.OWNER_CLOSE
	assert_str(Bonds.level_word(owner_bond)).is_equal("close")
	owner_bond["meetings"] = Bonds.OLD_FRIENDS
	assert_str(Bonds.level_word(owner_bond)).is_equal("old friend")
	var founding := Bonds.between(bar, Bonds.OWNER, "young-ja", "founding")
	founding["meetings"] = 3
	assert_str(Bonds.level_word(founding)).is_equal("old friend")
	var pair := Bonds.between(bar, "ji-ho", "da-eun")
	pair["meetings"] = Bonds.FRIENDLY
	assert_str(Bonds.level_word(pair)).is_equal("friendly")
	pair["close"] = true
	assert_str(Bonds.level_word(pair)).is_equal("close")
	assert_dict(Bonds.count_by_level(bar)).is_equal({"old friend": 2, "close": 1})


func test_a_bar_from_before_bonds_is_moved_into_them_once() -> void:
	var bar := {"regulars": [
		{"id": "ji-ho", "name": "Kim Ji-ho", "visits": 5, "first_night": 2, "last_night": 9, "owner_knows_name": true, "knows_owner_name": false, "warmth": 2,
			"memories": [{"night": 9, "owner": "Talked about her exam.", "them": "The owner made her eat."}], "impression": "A quiet one.",
			"facts": {"job": "student", "home": "Busan"}, "friends": {"da-eun": {"meetings": 3, "names": true, "close": true, "night": 8, "last": "See you!"}}},
		{"id": "da-eun", "name": "Kang Da-eun", "visits": 600, "founding": true, "owner_knows_name": true, "knows_owner_name": true,
			"friends": {"ji-ho": {"meetings": 3, "names": false, "close": true, "night": 8}}},
	]}
	assert_bool(Bonds.upgrade(bar)).is_true()
	var ji_ho: Dictionary = bar["regulars"][0]
	for key in Bonds.OLD_FIELDS:
		assert_bool(ji_ho.has(key)).override_failure_message("%s still on the regular" % key).is_false()
	var owner_bond := Bonds.with_owner(bar, "ji-ho")
	assert_int(int(owner_bond["meetings"])).is_equal(5)
	assert_bool(Bonds.knows_name(owner_bond, Bonds.OWNER)).is_true()
	assert_bool(Bonds.knows_name(owner_bond, "ji-ho")).is_false()
	assert_int(int(owner_bond["warmth"])).is_equal(2)
	assert_str(str(Bonds.memories_by(owner_bond, "ji-ho")[0]["text"])).is_equal("The owner made her eat.")
	assert_str(Bonds.impression_of(owner_bond, Bonds.OWNER)).is_equal("A quiet one.")
	assert_dict(ji_ho["facts"]["job"]).is_equal({"text": "student", "night": 9, "known_by": ["owner"]})  # (all said to the owner, before)
	assert_str(Bonds.level_word(Bonds.with_owner(bar, "da-eun"))).is_equal("old friend")  # (a founding regular)
	var pair := Bonds.find(bar, "ji-ho", "da-eun")
	assert_int(int(pair["meetings"])).is_equal(3)
	assert_bool(bool(pair["close"])).is_true()
	assert_bool(Bonds.knows_name(pair, "ji-ho")).is_true()
	assert_bool(Bonds.knows_name(pair, "da-eun")).is_false()
	assert_str(str(pair["last"])).is_equal("See you!")
	assert_bool(Bonds.upgrade(bar)).is_false()  # (once)
