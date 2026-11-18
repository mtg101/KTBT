extends GdUnitTestSuite
## Tests for scripts/bar/autopilot.gd: the autopilot PD's choices, on their own (it playing a
## night in a batch is in test_night.gd).

const Autopilot = preload("res://scripts/bar/autopilot.gd")
const Plants = preload("res://scripts/rules/plants.gd")


func test_its_cards_are_spread_over_the_evening_and_the_same_for_the_same_night() -> void:
	var pilot := Autopilot.new("bar-1 nights 3")
	pilot.plan(["phone", "rain", "cue_card", "ppl"], 18 * 60)
	assert_int(pilot.schedule.size()).is_equal(4)
	for k in pilot.schedule.size():
		assert_float(float(pilot.schedule[k]["at"])).is_between(float(Autopilot.FIRST_CARD), float(Autopilot.LAST_CARD))
		if k > 0:
			assert_float(float(pilot.schedule[k]["at"])).is_greater_equal(float(pilot.schedule[k - 1]["at"]))  # (soonest first)
	var again := Autopilot.new("bar-1 nights 3")
	again.plan(["phone", "rain", "cue_card", "ppl"], 18 * 60)
	assert_array(again.schedule).is_equal(pilot.schedule)  # (its own dice: the same night, the same plan)


func test_a_card_is_due_then_played_or_tried_again_later() -> void:
	var pilot := Autopilot.new("x")
	pilot.plan(["phone"], 18 * 60)
	var at := float(pilot.schedule[0]["at"])
	assert_dict(pilot.card_due(at - 1)).is_empty()  # (not yet)
	assert_str(str(pilot.card_due(at)["card"])).is_equal("phone")
	pilot.card_tried("phone", false, at)  # (couldn't be played: nobody with time left)
	assert_float(float(pilot.schedule[0]["at"])).is_equal(at + Autopilot.RETRY_MINUTES)
	pilot.card_tried("phone", true, at + Autopilot.RETRY_MINUTES)
	assert_array(pilot.schedule).is_empty()
	assert_int(int(pilot.counts["cards"])).is_equal(1)
	# Too late to try again: dropped.
	pilot.plan(["rain"], 18 * 60)
	pilot.card_tried("rain", false, Autopilot.GIVE_UP_AT - 1)
	assert_array(pilot.schedule).is_empty()


func test_its_write_ins_pass_the_checks_a_players_do() -> void:
	for card in Autopilot.WRITE_INS:
		assert_bool(Plants.is_write(card)).is_true()
		for words in Autopilot.WRITE_INS[card]:
			assert_str(str(Plants.check_written(card, words)["problem"])).override_failure_message("%s: %s" % [card, words]).is_empty()
	var pilot := Autopilot.new("y")
	pilot.plan(["cue_card"], 18 * 60)
	var due := pilot.card_due(Autopilot.LAST_CARD)
	assert_array(Autopilot.WRITE_INS["cue_card"]).contains([due["text"]])


func test_the_camera_pins_and_spins_now_and_then() -> void:
	var pilot := Autopilot.new("z")
	pilot.plan([], 18 * 60)
	var moves := 0
	var minutes := float(Autopilot.FIRST_CARD)
	for k in 40:
		minutes += Autopilot.CAMERA_EVERY
		var move := pilot.camera_due(minutes, 4, k % 2 == 1)
		if not move.is_empty():
			moves += 1
			if str(move["do"]) == "follow":
				assert_int(int(move["who"])).is_between(0, 3)
	assert_int(moves).is_between(5, 39)  # (now and then: not never, not every time)
	assert_dict(pilot.camera_due(minutes + 1, 4, false)).is_empty()  # (not again so soon)
	var pins := 0
	for k in 1000:
		pins += 1 if pilot.pins_it() else 0
	assert_int(pins).is_equal(Autopilot.MOST_PINS)
	var spins: Array = []
	for k in 50:
		spins.append(pilot.spin_for(3))
	assert_array(spins).contains([-1, 0, 2])  # (left to the AI sometimes, any spin other times)
	assert_int(pilot.spin_for(0)).is_equal(-1)


func test_the_cut_picks_from_whats_there_and_never_writes_its_own() -> void:
	var pilot := Autopilot.new("w")
	for k in 30:
		var chosen := pilot.cut_choices(3, 2, 5)
		assert_int(int(chosen["title"])).is_between(0, 2)
		assert_int(int(chosen["cliffhanger"])).is_between(0, 2)  # (0: the writers'; then the game's two; never "your own")
		var scenes: Array = chosen["scenes"]
		assert_int(scenes.size()).is_less_equal(3)
		for scene in scenes:
			assert_int(int(scene)).is_between(0, 4)
			assert_int(scenes.count(scene)).is_equal(1)
	assert_int(int(pilot.cut_choices(0, 0, 0)["title"])).is_equal(-1)  # (no titles drafted: it leaves the title)
