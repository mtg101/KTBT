extends GdUnitTestSuite
## Tests for scripts/regulars.gd: who comes back, how often, and how they fade (the game's
## rules, with their dice rolls passed in), plus a simulated hundred nights to make sure
## the bar settles rather than filling up with regulars.

const Regulars = preload("res://scripts/regulars.gd")
const NightRules = preload("res://scripts/rules/night_rules.gd")


func test_who_becomes_a_regular_follows_how_the_visit_went() -> void:
	assert_bool(Regulars.becomes_regular("loved", false, 0.05)).is_true()
	assert_bool(Regulars.becomes_regular("loved", true, 0.07)).is_false()  # rushed: half the chance
	assert_bool(Regulars.becomes_regular("enjoyed", false, 0.03)).is_true()
	assert_bool(Regulars.becomes_regular("enjoyed", false, 0.05)).is_false()
	assert_bool(Regulars.becomes_regular("fine", false, 0.01)).is_false()
	assert_bool(Regulars.becomes_regular("didnt", false, 0.0)).is_false()  # never


func test_pull_rises_falls_and_fades() -> void:
	assert_float(Regulars.pull_after_visit(0.5, "loved", false)).is_greater(0.5)
	assert_float(Regulars.pull_after_visit(0.5, "fine", false)).is_equal(0.5)
	assert_float(Regulars.pull_after_visit(0.5, "didnt", false)).is_less(0.5)
	assert_float(Regulars.pull_after_visit(0.5, "fine", true)).is_less(0.5)  # a rushed visit
	assert_float(Regulars.pull_after_visit(0.95, "loved", false)).is_equal(1.0)  # never past 1
	assert_float(Regulars.pull_after_visit(0.05, "didnt", true)).is_equal(0.0)
	var new_pull := Regulars.pull_after_absence(0.5, false)
	var founding_pull := Regulars.pull_after_absence(0.5, true)
	assert_float(new_pull).is_less(founding_pull)  # founding regulars fade more slowly
	assert_float(founding_pull).is_less(0.5)
	assert_bool(Regulars.still_regular(0.1)).is_true()
	assert_bool(Regulars.still_regular(0.09)).is_false()


func test_someone_who_stops_coming_fades_out() -> void:
	var pull := Regulars.NEW_PULL
	var nights := 0
	while Regulars.still_regular(pull):
		pull = Regulars.pull_after_absence(pull, false)
		nights += 1
	assert_int(nights).is_between(7, 30)  # a few weeks of game nights


func test_favourite_nights_and_usual_hours() -> void:
	assert_float(Regulars.visit_chance(0.4, 4, [4])).is_greater(Regulars.visit_chance(0.4, 2, [4]))
	assert_float(Regulars.visit_chance(1.0, 4, [4])).is_less_equal(Regulars.MOST_LIKELY)
	# Someone who's just become a regular is keen for their first week.
	assert_float(Regulars.visit_chance(0.25, 2, [4], true)).is_equal_approx(Regulars.visit_chance(0.25, 2, [4]) * 2.0, 0.001)
	assert_bool(Regulars.keen({"visits": 1, "first_night": 5}, 9)).is_true()
	assert_bool(Regulars.keen({"visits": 1, "first_night": 5}, 13)).is_false()  # over a week
	assert_bool(Regulars.keen({"visits": 2, "first_night": 5}, 6)).is_false()  # been back already
	assert_bool(Regulars.keen({"visits": 1, "first_night": 0, "founding": true}, 1)).is_false()
	for roll in [0.0, 0.5, 1.0]:
		var when := Regulars.arrival_time(21 * 60, roll)
		assert_float(absf(when - 21 * 60)).is_less_equal(Regulars.USUAL_HOUR_SPREAD)
	assert_float(Regulars.arrival_time(26 * 60 + 20, 1.0)).is_less(float(NightRules.LAST_ARRIVAL_MINUTES))  # never after 2:30am


func test_a_usual_only_once_it_is_real() -> void:
	var regular := {"orders": [["soju", "tteokbokki"], ["tteokbokki", "soju"]]}
	assert_array(Regulars.usual_of(regular)).is_empty()  # twice isn't a usual
	regular["orders"].append(["soju", "tteokbokki"])
	assert_array(Regulars.usual_of(regular)).contains_exactly(["soju", "tteokbokki"])
	assert_array(Regulars.usual_of({"usual": ["beer", "pajeon"], "orders": []})).contains_exactly(["beer", "pajeon"])  # founding regulars have one


func test_closeness_marks_and_words() -> void:
	assert_str(Regulars.closeness_mark({})).is_empty()
	assert_str(Regulars.closeness_mark({"visits": 1})).is_equal("☆")
	assert_str(Regulars.closeness_mark({"visits": 5})).is_equal("★")
	assert_str(Regulars.closeness_mark({"visits": 2, "founding": true})).is_equal("★★")
	assert_str(Regulars.closeness_word({"visits": 5})).is_equal("Regular")
	assert_str(Regulars.nights_ago_text(1)).is_equal("last night")
	assert_str(Regulars.nights_ago_text(9)).is_equal("a week ago")
	assert_str(Regulars.ordinal(2)).is_equal("2nd")
	assert_str(Regulars.ordinal(11)).is_equal("11th")
	assert_str(Regulars.ordinal(23)).is_equal("23rd")


func test_the_game_judges_a_visit_for_now() -> void:
	assert_str(Regulars.game_verdict(14, false, false, "chatty")).is_equal("loved")
	assert_str(Regulars.game_verdict(10, false, false, "owner")).is_equal("loved")
	assert_str(Regulars.game_verdict(9, false, false, "chatty")).is_equal("enjoyed")
	assert_str(Regulars.game_verdict(2, true, false, "chatty")).is_equal("enjoyed")
	assert_str(Regulars.game_verdict(4, false, true, "chatty")).is_equal("fine")
	assert_str(Regulars.game_verdict(2, false, true, "quiet")).is_equal("didnt")
	assert_bool(Regulars.rushed(true, 2)).is_true()
	assert_bool(Regulars.rushed(false, 2)).is_false()


func test_a_new_regular_keeps_who_they_are() -> void:
	var customer := {"name": "Kim Ji-ho", "hangul": "김지호", "gender": "woman", "age": 34, "job": "office worker", "speech_style": "dry", "appearance": "A blazer.", "mood": "tired", "reason": "Work."}
	var look := {"hair": "bob", "clothes": "trench"}
	var regular := Regulars.new_regular(customer, look, ["soju", "tteokbokki"], 5, 4, 21 * 60, 0.5)
	assert_str(str(regular["hangul"])).is_equal("김지호")
	assert_float(float(regular["pull"])).is_equal(Regulars.NEW_PULL)
	assert_array(regular["favourite_days"]).contains([4])
	assert_bool(regular.has("mood")).is_false()  # tonight's mood isn't who they are
	assert_str(str(Regulars.dressed_for(look, "muggy")["clothes"])).is_equal("tshirt")
	assert_str(str(Regulars.dressed_for(look, "")["hair"])).is_equal("bob")


func test_the_bar_settles_instead_of_filling_up_with_regulars() -> void:
	# The runaway guard: a hundred nights, twenty times over, with made-up verdicts.
	var founding_kept := 0
	for seed_value in range(1, 21):
		var run := Regulars.simulate(seed_value)
		var counts: Array = run["counts"].slice(50)
		var shares: Array = run["shares"].slice(50)
		var regulars := 0.0
		var share := 0.0
		for i in counts.size():
			regulars += float(counts[i])
			share += float(shares[i])
		regulars /= counts.size()
		share /= shares.size()
		assert_float(regulars).override_failure_message("seed %d: %.1f regulars on average" % [seed_value, regulars]).is_between(3.0, 20.0)
		assert_float(share).override_failure_message("seed %d: regulars %.0f%% of the night" % [seed_value, share * 100]).is_between(0.05, 0.35)
		founding_kept += int(run["founding_left"])
	assert_int(founding_kept).is_greater(20)  # founding regulars usually last (out of 40)


func test_memories_blur_after_a_few_visits_and_facts_stick() -> void:
	var regular := {}
	for night in range(1, 6):
		Regulars.remember(regular, night, {"owner_remembers": "Night %d: talked about the exam. Laughed a lot." % night, "they_remember": "Kind owner.", "job": "student" if night == 1 else "", "home": "Busan" if night == 4 else ""})
	var memories: Array = regular["memories"]
	assert_int(memories.size()).is_equal(Regulars.RECENT_MEMORIES)
	assert_int(int(memories[0]["night"])).is_equal(3)  # the newest three, oldest first
	assert_str(str(regular["impression"])).contains("Night 1: talked about the exam.")
	assert_str(str(regular["impression"])).not_contains("Laughed")  # just the gist
	assert_str(str(regular["facts"]["job"])).is_equal("student")  # stuck, even though not said again
	assert_str(str(regular["facts"]["home"])).is_equal("Busan")
