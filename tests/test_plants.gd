extends GdUnitTestSuite
## Tests for scripts/rules/plants.gd: the PD's plant cards, as data and rules.

const Plants = preload("res://scripts/rules/plants.gd")
const Talk = preload("res://scripts/rules/talk.gd")


func test_a_hand_is_dealt_from_the_cards() -> void:
	var dice := RandomNumberGenerator.new()
	dice.seed = 7
	var hand := Plants.deal(dice)
	assert_int(hand.size()).is_equal(mini(Plants.HAND, Plants.CARDS.size()))
	for card in hand:
		assert_bool(Plants.CARDS.has(card)).is_true()
		assert_int(hand.count(card)).is_equal(1)  # (all different)
	dice.seed = 7
	assert_array(Plants.deal(dice)).is_equal(hand)  # (the same dice, the same hand)


func test_every_card_is_complete() -> void:
	for card in Plants.CARDS:
		var data: Dictionary = Plants.CARDS[card]
		assert_str(str(data.get("title", ""))).is_not_empty()
		assert_str(str(data.get("about", ""))).is_not_empty()
		assert_str(str(data.get("moment", ""))).is_not_empty()
		assert_bool(Talk.HINT_TELLS.has("plant_" + str(card))).override_failure_message("no tells for %s" % card).is_true()


func test_when_a_card_can_be_played() -> void:
	var now := {"open": true, "seated": 2, "regulars_away": 1, "weather_kind": ""}
	for card in Plants.CARDS:
		assert_str(Plants.why_not(card, now)).is_empty()
		assert_str(Plants.why_not(card, {"open": false})).is_not_empty()  # (not before or after the night, or closing up)
	assert_str(Plants.why_not("regular_in", {"open": true, "regulars_away": 0})).contains("No regulars")
	assert_str(Plants.why_not("rain", {"open": true, "weather_kind": "drizzle"})).contains("already wet")
	assert_str(Plants.why_not("rain", {"open": true, "weather_kind": "snow"})).contains("already wet")
	assert_str(Plants.why_not("phone", {"open": true, "seated": 0})).contains("Nobody")


func test_a_cards_moment_is_about_whoever_it_happens_to() -> void:
	assert_str(Plants.moment("phone", "Kim Ji-ho")).starts_with("Ji-ho's phone")
	assert_str(Plants.moment("regular_in", "Park Mi-sook")).contains("Mi-sook").contains("PD")
	assert_str(Plants.moment("rain")).contains("pouring")
	# Taken up: talking about it, not just carrying on.
	assert_bool(Talk.hint_taken("plant_phone", "Sorry, I have to take this call.")).is_true()
	assert_bool(Talk.hint_taken("plant_rain", "Look at that rain!")).is_true()
	assert_bool(Talk.hint_taken("plant_regular_in", "The producer rang me, can you believe it?")).is_true()
	assert_bool(Talk.hint_taken("plant_phone", "Another soju, please.")).is_false()
