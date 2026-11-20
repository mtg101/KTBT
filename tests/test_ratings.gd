extends GdUnitTestSuite
## Tests for scripts/rules/ratings.gd: the show's TV ratings (시청률) at 3am, what they're made
## of, the banners, and how they nudge how busy the bar is.

const Ratings = preload("res://scripts/rules/ratings.gd")
const NightRules = preload("res://scripts/rules/night_rules.gd")
const Hangul = preload("res://scripts/rules/hangul.gd")


func _moment(mood: String) -> Dictionary:
	return {"kind": "big_moment", "at": 1300, "who": "Kim Ji-ho", "mood": mood, "ai_mood": mood}


func _rating(events: Array, context: Dictionary = {}, roll: float = 0.5) -> float:
	return float(Ratings.score(events, context, roll)["rating"])


func test_a_night_with_nothing_happening_is_a_quiet_one() -> void:
	var result := Ratings.score([{"kind": "arrived", "at": 1100}, {"kind": "paid", "at": 1200, "name": "Lee Min-jun", "regular": ""}])
	assert_float(float(result["rating"])).is_equal_approx(Ratings.BASE, 0.001)
	assert_str(str(result["band"])).is_equal("a quiet night for the show")
	assert_array(result["parts"]).has_size(1)  # (only the luck, at nothing)
	assert_str(str(result["parts"][0][0])).starts_with("luck")


func test_big_moments_count_each_a_little_less_and_a_mix_of_moods_more() -> void:
	var one := _rating([_moment("funny")])
	var two := _rating([_moment("funny"), _moment("funny")])
	var three := _rating([_moment("funny"), _moment("funny"), _moment("funny")])
	assert_float(one).is_equal_approx(Ratings.BASE + Ratings.MOMENT, 0.001)
	assert_float(three - two).is_less(two - one)  # each worth a little less
	var mixed := _rating([_moment("funny"), _moment("sad"), _moment("sweet")])
	assert_float(mixed).is_equal_approx(three + 2 * Ratings.MOOD_MIX, 0.11)  # a laugh, a tear and something sweet beat three laughs
	# The mood as aired: the PD's spin is what the audience saw.
	var spun := {"kind": "big_moment", "at": 1300, "who": "Kim Ji-ho", "mood": "funny", "ai_mood": "sad"}
	assert_float(_rating([spun, _moment("sad")])).is_greater(_rating([_moment("sad"), _moment("sad")]))


func test_the_cliffhanger_regulars_and_happenings_add_to_it() -> void:
	var plain := _rating([])
	assert_float(_rating([{"kind": "cliffhanger_answered", "at": 1200}])).is_equal_approx(plain + Ratings.CLIFFHANGER, 0.01)
	# Regulars back (each once, however often they paid), up to a point.
	var regulars: Array = []
	for k in 8:
		regulars.append({"kind": "paid", "at": 1200 + k, "name": "Regular %d" % k, "regular": "r%d" % k})
	assert_float(_rating(regulars.slice(0, 2) + regulars.slice(0, 2))).is_equal_approx(plain + 2 * Ratings.REGULAR_IN, 0.01)
	assert_float(_rating(regulars)).is_equal_approx(plain + Ratings.REGULARS_MOST, 0.01)
	# A full house, a game and the first snow: once each a night.
	var happenings := [{"kind": "sat_down", "at": 1300, "seated": NightRules.SEATS}, {"kind": "sat_down", "at": 1310, "seated": NightRules.SEATS},
		{"kind": "table_game", "at": 1400, "game": "baskin"}, {"kind": "table_game", "at": 1420, "game": "baskin"}, {"kind": "first_snow", "at": 1500}]
	assert_float(_rating(happenings)).is_equal_approx(plain + Ratings.HAPPENINGS["full_house"] + Ratings.HAPPENINGS["table_game"] + Ratings.HAPPENINGS["first_snow"], 0.01)
	# The PD's cards taken up.
	assert_float(_rating([], {"cards_taken_up": 2})).is_equal_approx(plain + 2 * Ratings.CARD_TAKEN_UP, 0.01)
	# Where it came from, biggest first, then the luck.
	var parts: Array = Ratings.score([{"kind": "cliffhanger_answered", "at": 1200}, _moment("funny")])["parts"]
	assert_str(str(parts[0][0])).is_equal("last time's cliffhanger came true")
	assert_str(str(parts[1][0])).is_equal("1 big moment")
	# (one card reads right too: "1 of the PD's cards", 20 Nov)
	assert_str(str(Ratings.score([], {"cards_taken_up": 1})["parts"][0][0])).is_equal("1 of the PD's cards taken up")


func test_luck_moves_it_a_little_and_it_never_hits_nothing() -> void:
	var events := [_moment("funny"), _moment("warm")]
	assert_float(_rating(events, {}, 1.0) - _rating(events, {}, 0.0)).is_equal_approx(Ratings.LUCK, 0.11)
	assert_float(_rating([], {}, 0.0)).is_equal_approx(Ratings.LOWEST, 0.001)


func test_ordinary_good_and_great_nights_land_where_they_should() -> void:
	# An ordinary night: a couple of moments, a regular or two.
	var ordinary := [_moment("funny"), _moment("funny"), {"kind": "paid", "at": 1200, "name": "Park Seo-yeon", "regular": "r1"}]
	assert_float(_rating(ordinary)).is_between(2.0, 6.0)
	# A good one: four moments in three moods, three regulars, two getting friendlier, a full house.
	var good := [_moment("funny"), _moment("sad"), _moment("warm"), _moment("funny"), {"kind": "friendlier", "at": 1300}, {"kind": "friendlier", "at": 1400},
		{"kind": "sat_down", "at": 1300, "seated": NightRules.SEATS}]
	for k in 3:
		good.append({"kind": "paid", "at": 1200 + k, "name": "Regular %d" % k, "regular": "r%d" % k})
	assert_float(_rating(good)).is_between(6.0, 10.0)
	# A hit needs more: the cliffhanger paying off and the PD's cards landing too.
	var hit := good + [{"kind": "cliffhanger_answered", "at": 1250}, {"kind": "became_regular", "at": 1500}]
	assert_float(_rating(hit, {"cards_taken_up": 2})).is_greater_equal(Ratings.HIT)
	# 20% is the stuff of legend: everything at once, and luck too.
	var everything := hit + [_moment("sweet"), _moment("shock"), _moment("funny"), _moment("sad"), {"kind": "became_regular", "at": 1600},
		{"kind": "table_game", "at": 1400}, {"kind": "cat_stole", "at": 1450}, {"kind": "first_snow", "at": 1500}, {"kind": "cheered_on", "at": 1550}]
	for k in 5:
		everything.append({"kind": "paid", "at": 1300 + k, "name": "Regular %d" % (k + 3), "regular": "r%d" % (k + 3)})
	assert_float(_rating(everything, {"cards_taken_up": 3}, 1.0)).is_greater_equal(Ratings.LEGEND)
	assert_float(_rating(everything, {"cards_taken_up": 3}, 0.0)).is_less(Ratings.LEGEND)


func test_bands_and_banners() -> void:
	assert_str(Ratings.band(3.2)).is_equal("a quiet night for the show")
	assert_str(Ratings.band(6.4)).is_equal("a good episode")
	assert_str(Ratings.band(9.1)).is_equal("nearly double digits")
	assert_str(Ratings.band(12.0)).is_equal("double digits: a hit!")
	assert_str(Ratings.band(21.5)).is_equal(Ratings.LEGENDARY)
	assert_str(Ratings.percent_text(6.4)).is_equal("6.4%")
	# A new best only after a couple of rated nights, and it beats a hit.
	assert_str(Ratings.banner(7.0, [])).is_empty()
	assert_str(Ratings.banner(7.0, [5.0])).is_empty()
	assert_str(Ratings.banner(7.0, [5.0, 6.9])).is_equal(Ratings.RECORD_HANGUL)
	assert_str(Ratings.banner(7.0, [5.0, 7.0])).is_empty()  # (equalling it isn't a new best)
	assert_str(Ratings.banner(11.0, [12.0, 5.0])).is_equal(Ratings.HIT_HANGUL)
	assert_str(Ratings.banner(20.5, [21.0, 5.0])).is_equal(Ratings.LEGEND_HANGUL)
	assert_str(Ratings.banner(12.0, [5.0, 6.0])).is_equal(Ratings.RECORD_HANGUL)


func test_the_banners_and_word_explain_themselves() -> void:
	for hangul in [Ratings.WORD, Ratings.RECORD_HANGUL, Ratings.HIT_HANGUL, Ratings.LEGEND_HANGUL]:
		assert_bool(Hangul.MEANINGS.has(hangul)).override_failure_message("no meaning for %s" % hangul).is_true()
	var result := Ratings.score([_moment("funny"), {"kind": "cliffhanger_answered", "at": 1200}])
	var hover := Ratings.hover(result)
	assert_str(hover).contains("share of Korea's TV homes watching").contains("10% is a hit")
	assert_str(hover).contains("+2.5  last time's cliffhanger came true").contains("+1.2  1 big moment")
	assert_str(Ratings.log_text(result)).starts_with("%s (%s): +2.5 last time's cliffhanger came true, +1.2 1 big moment" % [Ratings.percent_text(float(result["rating"])), result["band"]])


func test_the_last_few_nights_ratings_nudge_how_busy_it_is() -> void:
	assert_float(Ratings.busier([])).is_equal_approx(1.0, 0.001)
	assert_float(Ratings.busier([6.0])).is_equal_approx(1.0, 0.001)  # an ordinary night changes nothing
	assert_float(Ratings.busier([10.0, 10.0, 10.0])).is_equal_approx(1.1, 0.001)
	assert_float(Ratings.busier([2.0, 2.0, 2.0])).is_equal_approx(0.9, 0.001)
	assert_float(Ratings.busier([30.0, 30.0, 30.0])).is_equal_approx(1.0 + Ratings.NUDGE_MOST, 0.001)  # never more than that
	assert_float(Ratings.busier([0.8, 0.8, 0.8])).is_equal_approx(1.0 - Ratings.NUDGE_MOST, 0.001)
	assert_float(Ratings.busier([2.0, 2.0, 6.0, 6.0, 6.0])).is_equal_approx(1.0, 0.001)  # only the last few
	# Only nights with ratings (older ones, from before the show had them, are left out).
	assert_array(Ratings.from_log([{"night": 1}, {"night": 2, "ratings": 5.5}, {"night": 3, "ratings": 7.0}])).contains_exactly([5.5, 7.0])
	# Busier means customers come along sooner, on average.
	assert_int(NightRules.next_arrival_gap(22 * 60, 0.5, 1.1)).is_less(NightRules.next_arrival_gap(22 * 60, 0.5))
	assert_int(NightRules.next_arrival_gap(22 * 60, 0.5, 0.9)).is_greater(NightRules.next_arrival_gap(22 * 60, 0.5))
