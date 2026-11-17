extends GdUnitTestSuite
## Tests for scripts/rules/plants.gd: the PD's plant cards, as data and rules.

const Plants = preload("res://scripts/rules/plants.gd")
const Talk = preload("res://scripts/rules/talk.gd")
const Captions = preload("res://scripts/rules/captions.gd")


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


func test_the_deal_follows_tonight() -> void:
	var dice := RandomNumberGenerator.new()
	var summer := {"winter": false, "snowed": false, "wet": false}
	var winter := {"winter": true, "snowed": false, "wet": false}
	for k in 30:
		dice.seed = k
		assert_array(Plants.deal(dice, summer)).not_contains(["first_snow"])  # (no first snow in summer)
		assert_array(Plants.deal(dice, {"winter": true, "snowed": true})).not_contains(["first_snow"])  # (only once a winter)
		assert_array(Plants.deal(dice, {"wet": true})).not_contains(["rain"])  # (it's raining already)
		var last := Plants.deal(dice, summer)
		assert_array(Plants.deal(dice, summer, last)).not_contains(last.filter(func(card): return card != Plants.ALWAYS))  # (not last night's again)
		assert_str(str(last[-1])).is_equal("ppl")  # (a word from our sponsor, every night)
	assert_bool(Plants.dealable("first_snow", winter)).is_true()


func test_every_card_is_complete() -> void:
	for card in Plants.CARDS:
		var data: Dictionary = Plants.CARDS[card]
		assert_str(str(data.get("title", ""))).is_not_empty()
		assert_str(str(data.get("about", ""))).is_not_empty()
		assert_str(str(data.get("moment", ""))).is_not_empty()
		assert_bool(Talk.HINT_TELLS.has("plant_" + str(card))).override_failure_message("no tells for %s" % card).is_true()
		assert_bool(["someone", "pair", "tent", "nobody"].has(str(data.get("for", "")))).override_failure_message("who's %s for?" % card).is_true()
		# Seen happening: a caption of its own (or, for the first snow, the one it already has).
		assert_bool(Captions.CAPTIONS.has("plant_" + str(card)) or card == "first_snow").override_failure_message("no caption for %s" % card).is_true()
		# Its moment and what happened name nobody but who it's for.
		assert_str(Plants.happened(card, "Kim Ji-ho", "Lee Min-jun", "went to the same school")).not_contains("{")
		assert_str(Plants.moment(card, "Kim Ji-ho", "Lee Min-jun", "went to the same school")).not_contains("{")


func test_when_a_card_can_be_played() -> void:
	var now := {"open": true, "seated": 2, "pairable": true, "regulars_away": 1, "weather_kind": ""}
	for card in Plants.CARDS:
		assert_str(Plants.why_not(card, now)).is_empty()
		assert_str(Plants.why_not(card, {"open": false})).is_not_empty()  # (not before or after the night, or closing up)
	assert_str(Plants.why_not("regular_in", {"open": true, "regulars_away": 0})).contains("No regulars")
	assert_str(Plants.why_not("rain", {"open": true, "weather_kind": "drizzle"})).contains("already wet")
	assert_str(Plants.why_not("rain", {"open": true, "weather_kind": "snow"})).contains("already wet")
	assert_str(Plants.why_not("phone", {"open": true, "seated": 0})).contains("Nobody")
	assert_str(Plants.why_not("round_on", {"open": true, "seated": 1})).contains("Nobody else")  # (a round needs someone to buy for)
	assert_str(Plants.why_not("small_world", {"open": true, "seated": 2, "pairable": false})).contains("chat")
	assert_str(Plants.why_not("first_snow", {"open": true, "weather_kind": "snow"})).contains("already snowing")


func test_a_cards_moment_is_about_whoever_it_happens_to() -> void:
	assert_str(Plants.moment("phone", "Kim Ji-ho")).starts_with("Ji-ho's phone")
	assert_str(Plants.moment("regular_in", "Park Mi-sook")).contains("Mi-sook is only here tonight because the show's PD rang them")
	# About one woman or man: "her ex", not "their ex" (and anyone else, "their").
	assert_str(Plants.happened("ex_walks_past", "Lee Ji-hyun", "", "carrying flowers", "woman")).is_equal("Someone walks past outside the tarp, and Lee Ji-hyun freezes: it's her ex, carrying flowers.")
	assert_str(Plants.happened("round_on", "Kim Min-seok", "", "it's their birthday", "man")).ends_with(": it's his birthday.")
	assert_str(Plants.gendered("They've quit their job, so tell them.", "woman")).is_equal("She's quit her job, so tell her.")
	assert_str(Plants.gendered("it's their ex", "non-binary")).is_equal("it's their ex")
	assert_str(Plants.gendered("the theory of themes", "man")).is_equal("the theory of themes")  # (whole words only)
	assert_str(Plants.moment("rain")).contains("pouring")
	assert_str(Plants.moment("small_world", "Kim Ji-ho", "Lee Min-jun", "went to the same school")).is_equal("Ji-ho and Min-jun have just worked out that they went to the same school.")
	# A card with variants isn't the same every time.
	var dice := RandomNumberGenerator.new()
	var seen := {}
	for k in 40:
		seen[Plants.variant("small_world", dice)] = true
	assert_int(seen.size()).is_greater(3)
	assert_str(Plants.variant("rain", dice)).is_empty()  # (the rain's just the rain)
	for card in ["phone", "text", "ex_walks_past", "round_on", "noraebang", "power_goes"]:
		assert_str(Plants.variant(card, dice)).is_not_empty()
	assert_str(Plants.others_moment("round_on", "Kim Ji-ho")).starts_with("Ji-ho has just bought")
	# Taken up: talking about it, not just carrying on.
	assert_bool(Talk.hint_taken("plant_phone", "Sorry, I have to take this call.")).is_true()
	assert_bool(Talk.hint_taken("plant_rain", "Look at that rain!")).is_true()
	assert_bool(Talk.hint_taken("plant_regular_in", "The producer rang me, can you believe it?")).is_true()
	assert_bool(Talk.hint_taken("plant_phone", "Another soju, please.")).is_false()


func test_every_hand_has_a_write_in() -> void:
	var dice := RandomNumberGenerator.new()
	for k in 30:
		dice.seed = k
		var hand := Plants.deal(dice)
		assert_int(hand.filter(func(card): return Plants.is_write(card)).size()).is_equal(1)  # (the PD's own words, every night)
		assert_int(hand.size()).is_equal(Plants.HAND)  # (three events, a write-in and the sponsor's)
		assert_int(hand.filter(func(card): return not Plants.is_write(card) and card != Plants.ALWAYS).size()).is_equal(Plants.EVENTS)
		assert_int(hand.count(Plants.ALWAYS)).is_equal(1)
		assert_array(hand.map(func(card): return Plants.kind_of(card))).contains_exactly(["event", "event", "event", "write", "sponsor"])
	for card in Plants.CARDS:
		if Plants.is_write(card):
			var write: Dictionary = Plants.CARDS[card]["write"]
			for field in ["label", "hint", "max", "steers"]:
				assert_bool(write.has(field)).override_failure_message("%s has no %s" % [card, field]).is_true()
			assert_str(Plants.why_not(card, {"open": true, "seated": 1, "online": false})).contains("Needs the AI")  # (offline: greyed out)


func test_what_the_pd_writes_is_checked() -> void:
	assert_dict(Plants.check_written("cue_card", "  «her first love»  ")).is_equal({"text": "her first love", "problem": ""})
	assert_str(str(Plants.check_written("cue_card", "\"the time she\nmissed the last bus\"")["text"])).is_equal("the time she missed the last bus")
	assert_str(str(Plants.check_written("cue_card", "hi")["problem"])).contains("a few words")
	assert_str(str(Plants.check_written("cue_card", "x".repeat(81))["problem"])).contains("80")
	assert_str(str(Plants.check_written("interview", "x".repeat(100))["problem"])).is_empty()  # (a question can be longer)
	assert_str(str(Plants.check_written("cue_card", "their first time having sex")["problem"])).contains("on air")
	assert_str(str(Plants.check_written("cue_card", "the time he nearly killed myself laughing")["problem"])).is_empty()  # (whole phrases only)
	assert_str(str(Plants.check_written("cue_card", "{who} says hi")["text"])).not_contains("{")
	# What counts as taken up: its longer words, not the commonest.
	assert_array(Plants.written_tells("Her first love, and the time they met")).is_equal(["first", "love", "time"])
	assert_array(Plants.written_tells("괜찮아요")).is_equal(["괜찮아요"])  # (Hangul's kept)


func test_a_text_and_the_sponsor() -> void:
	# A text's words are for its reader: the screen shows them, the others only see the phone buzz.
	assert_str(Plants.happened("text_from", "Kim Ji-ho", "", "their ex", "woman", "we need to talk")).is_equal("Kim Ji-ho's phone buzzes: a text from her ex.")
	assert_str(Plants.shown("text_from", "Kim Ji-ho", "their ex", "woman", "we need to talk")).ends_with("«we need to talk»")
	assert_str(Plants.moment("cue_card", "Kim Ji-ho", "", "", "woman", "her first love")).contains("«her first love»")  # (what was written isn't gendered)
	# The show's sponsors: our own, never a real brand, each explained.
	var dice := RandomNumberGenerator.new()
	var what := Plants.variant("ppl", dice)
	assert_dict(Plants.sponsor_of(what)).is_not_empty()
	for id in Plants.SPONSORS:
		var sponsor: Dictionary = Plants.SPONSORS[id]
		assert_str(Talk.real_brand(str(sponsor["name"]))).override_failure_message(str(sponsor["name"])).is_empty()
		for field in ["name", "hangul", "means", "what", "colour", "spellings"]:
			assert_bool(sponsor.has(field)).is_true()
		assert_str(Talk.made_up_korean("Have you tried %s? It's the best." % sponsor["name"])).is_empty()  # (known, not made-up Korean)
