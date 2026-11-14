extends GdUnitTestSuite
## Tests for scripts/rules.gd: the checks that keep the AI's output consistent with the
## game's facts. Tests marked "Regression" guard fixes recorded in LLM-TUNING.md.

const Rules = preload("res://scripts/rules.gd")


# --- Sample replies, as the AI might send them --------------------------------------

func _customer(changes: Dictionary = {}) -> Dictionary:
	var data := {
		"name": "Kim Ji-ho", "age": 34, "job": "office worker", "mood": "worn out",
		"reason": "Her team lead took credit for her work again.", "speech_style": "dry, tired",
		"appearance": "A crumpled blazer and a lanyard she forgot to take off.",
	}
	data.merge(changes, true)
	return data


func _owner(changes: Dictionary = {}) -> Dictionary:
	var data := {
		"name": "Park Mi-sook", "age": 61, "archetype": "gruff-but-soft ajumma",
		"appearance": "Apron, rubber gloves, reading glasses on a chain.",
		"personality": "blunt, caring, nosy", "speech_style": "short and scolding",
		"secret": "She once sang backing vocals for a famous trot singer.",
	}
	data.merge(changes, true)
	return data


func _order(items: Array, line: String) -> Dictionary:
	return {"items": items, "line": line}


# --- Customers ---------------------------------------------------------------------

func test_valid_customer_is_accepted() -> void:
	assert_str(Rules.validate_customer(_customer())).is_empty()


func test_customer_under_drinking_age_is_rejected() -> void:
	assert_str(Rules.validate_customer(_customer({"age": 18}))).contains("18")


func test_customer_at_drinking_age_is_accepted() -> void:
	assert_str(Rules.validate_customer(_customer({"age": 19}))).is_empty()


func test_age_given_as_text_is_converted_to_a_number() -> void:
	var data := _customer({"age": "34"})
	assert_str(Rules.validate_customer(data)).is_empty()
	assert_int(typeof(data["age"])).is_equal(TYPE_INT)
	assert_int(data["age"]).is_equal(34)


func test_age_given_as_decimal_is_converted_to_a_whole_number() -> void:
	var data := _customer({"age": 34.0})
	assert_str(Rules.validate_customer(data)).is_empty()
	assert_int(typeof(data["age"])).is_equal(TYPE_INT)


func test_age_that_isnt_a_number_is_rejected() -> void:
	assert_str(Rules.validate_customer(_customer({"age": "thirty-ish"}))).contains("number")


func test_missing_field_is_rejected_and_named() -> void:
	var data := _customer()
	data.erase("mood")
	assert_str(Rules.validate_customer(data)).contains("mood")


func test_empty_field_is_rejected() -> void:
	assert_str(Rules.validate_customer(_customer({"job": "   "}))).contains("job")


func test_list_in_a_text_field_is_joined_up() -> void:
	var data := _customer({"mood": ["tired", "a bit tipsy"]})
	assert_str(Rules.validate_customer(data)).is_empty()
	assert_str(str(data["mood"])).is_equal("tired, a bit tipsy")


func test_reply_that_isnt_an_object_is_rejected() -> void:
	assert_str(Rules.validate_customer("just some text")).is_not_empty()
	assert_str(Rules.validate_customer(null)).is_not_empty()


# --- Owners ------------------------------------------------------------------------

func test_valid_owner_is_accepted() -> void:
	assert_str(Rules.validate_owner(_owner(), "woman")).is_empty()


func test_owner_under_40_is_rejected() -> void:
	assert_str(Rules.validate_owner(_owner({"age": 39}), "woman")).contains("39")


func test_regression_man_described_as_ajumma_is_rejected() -> void:
	# LLM-TUNING.md, "Owner titles": a man's title on a "gruff-but-soft ajumma".
	var problem := Rules.validate_owner(_owner({"archetype": "gruff-but-soft ajumma"}), "man")
	assert_str(problem).contains("ajumma")


func test_regression_woman_described_with_mens_term_is_rejected() -> void:
	var problem := Rules.validate_owner(_owner({"archetype": "the hyung everyone trusts"}), "woman")
	assert_str(problem).contains("hyung")


func test_gendered_terms_match_whole_words_only() -> void:
	# "funny" contains "unni" (a woman's term), but it's not that word.
	assert_str(Rules.validate_owner(_owner({"archetype": "funny ex-idol trainee"}), "man")).is_empty()


# --- Orders ------------------------------------------------------------------------

func test_valid_order_is_accepted() -> void:
	assert_str(Rules.validate_order(_order(["soju", "tteokbokki"], "Ajumma, soju and tteokbokki please."))).is_empty()


func test_order_names_are_turned_into_menu_ids() -> void:
	var data := _order(["Soju", "Gyeran-mari"], "Soju and gyeran-mari, please.")
	assert_str(Rules.validate_order(data)).is_empty()
	assert_array(data["items"]).contains_exactly(["soju", "gyeran_mari"])


func test_order_for_something_not_on_the_menu_is_rejected() -> void:
	assert_str(Rules.validate_order(_order(["pizza"], "A pizza, please."))).contains("pizza")


func test_empty_order_is_rejected() -> void:
	assert_str(Rules.validate_order(_order([], "Just sitting here."))).is_not_empty()


func test_order_with_too_many_items_is_rejected() -> void:
	var items := ["soju", "beer", "odeng", "ramyeon", "pajeon"]
	assert_str(Rules.validate_order(_order(items, "Lots, please."))).contains("5")


func test_order_without_a_line_is_rejected() -> void:
	assert_str(Rules.validate_order({"items": ["soju"]})).contains("line")


func test_regression_line_mentioning_unordered_item_is_rejected() -> void:
	# LLM-TUNING.md, "Double opening and mismatched orders": said soju, ordered beer.
	var problem := Rules.validate_order(_order(["beer", "odeng"], "One soju, please. Just one."))
	assert_str(problem).contains("Soju")


func test_somaek_order_may_mention_soju_and_beer() -> void:
	assert_str(Rules.validate_order(_order(["somaek", "odeng"], "A somaek: soju dropped in beer, the way I like it."))).is_empty()


func test_quotes_around_order_line_are_removed() -> void:
	var data := _order(["soju", "odeng"], "\"Soju and odeng, please.\"")
	assert_str(Rules.validate_order(data)).is_empty()
	assert_str(str(data["line"])).is_equal("Soju and odeng, please.")


# --- Dialogue lines ------------------------------------------------------------------

func test_valid_line_is_accepted() -> void:
	assert_str(Rules.validate_line({"line": "Eat something first."}, "Park Mi-sook", "Ajumma")).is_empty()


func test_speaker_name_prefix_is_removed() -> void:
	var data := {"line": "Park Mi-sook: Eat something first."}
	assert_str(Rules.validate_line(data, "Park Mi-sook", "Ajumma")).is_empty()
	assert_str(str(data["line"])).is_equal("Eat something first.")


func test_title_prefix_is_removed() -> void:
	var data := {"line": "Ajumma: Eat something first."}
	assert_str(Rules.validate_line(data, "Park Mi-sook", "Ajumma")).is_empty()
	assert_str(str(data["line"])).is_equal("Eat something first.")


func test_other_persons_reply_is_cut_off() -> void:
	var data := {"line": "Eat something first.\nKim Ji-ho: I'm not hungry."}
	assert_str(Rules.validate_line(data, "Park Mi-sook", "Ajumma")).is_empty()
	assert_str(str(data["line"])).is_equal("Eat something first.")


func test_quotes_around_line_are_removed() -> void:
	var data := {"line": "“Eat something first.”"}
	assert_str(Rules.validate_line(data, "Park Mi-sook", "Ajumma")).is_empty()
	assert_str(str(data["line"])).is_equal("Eat something first.")


func test_empty_line_is_rejected() -> void:
	assert_str(Rules.validate_line({"line": "  "}, "Park Mi-sook", "Ajumma")).is_not_empty()


func test_very_long_line_is_rejected() -> void:
	var data := {"line": "Aigoo. ".repeat(100)}
	assert_str(Rules.validate_line(data, "Park Mi-sook", "Ajumma")).contains("long")


func test_line_reply_without_line_key_is_rejected() -> void:
	assert_str(Rules.validate_line({"text": "Hello"}, "Park Mi-sook", "Ajumma")).contains("line")


# --- Bills and order text -------------------------------------------------------------

func test_bill_adds_up_menu_prices() -> void:
	assert_int(Rules.bill(["soju", "tteokbokki"])).is_equal(17000)


func test_bill_counts_repeated_items() -> void:
	assert_int(Rules.bill(["soju", "soju", "soju"])).is_equal(15000)


func test_bill_for_nothing_is_zero() -> void:
	assert_int(Rules.bill([])).is_equal(0)


func test_item_names_groups_repeats() -> void:
	assert_str(Rules.item_names(["soju", "soju", "tteokbokki"])).is_equal("2x Soju, Tteokbokki")


# --- Text helpers -------------------------------------------------------------------

func test_as_sentence_capitalises_and_adds_full_stop() -> void:
	assert_str(Rules.as_sentence("a messy bob, dark circles under her eyes")).is_equal("A messy bob, dark circles under her eyes.")


func test_as_sentence_keeps_existing_punctuation() -> void:
	assert_str(Rules.as_sentence("Soaked to the skin!")).is_equal("Soaked to the skin!")


func test_as_sentence_leaves_empty_text_alone() -> void:
	assert_str(Rules.as_sentence("")).is_empty()


func test_words_splits_on_anything_that_isnt_a_letter() -> void:
	assert_array(Array(Rules.words("Gruff-but-soft Ajumma!"))).contains_exactly(["gruff", "but", "soft", "ajumma"])


# --- Regression, LLM-TUNING.md "Talking about food that isn't on the table" ---------------

func test_regression_line_mentioning_food_not_on_the_table_is_rejected() -> void:
	# She ordered makgeolli and ramyeon; the owner talked about tteokbokki.
	var data := {"line": "I put in extra tteokbokki, like I said."}
	var problem := Rules.validate_line(data, "Kim Sung-ho", "Ajusshi", ["makgeolli", "ramyeon", "ramyeon"])
	assert_str(problem).contains("Tteokbokki")
	assert_str(problem).contains("2x Ramyeon")


func test_line_mentioning_food_on_the_table_is_accepted() -> void:
	var data := {"line": "Careful, the ramyeon's hot."}
	assert_str(Rules.validate_line(data, "Kim Sung-ho", "Ajusshi", ["makgeolli", "ramyeon"])).is_empty()


func test_line_check_skips_the_menu_when_no_table_is_given() -> void:
	assert_str(Rules.validate_line({"line": "Tteokbokki is my weakness."}, "Kim Sung-ho", "Ajusshi")).is_empty()


func test_somaek_on_the_table_lets_lines_mention_soju_and_beer() -> void:
	var data := {"line": "Soju in beer, the salaryman's medicine."}
	assert_str(Rules.validate_line(data, "Kim Sung-ho", "Ajusshi", ["somaek"])).is_empty()


# --- How people order: a drink, a food, usually one main ------------------------------

func test_order_with_no_drink_is_rejected() -> void:
	assert_str(Rules.validate_order(_order(["tteokbokki"], "Tteokbokki, please."))).contains("drink")


func test_order_with_no_food_is_rejected() -> void:
	assert_str(Rules.validate_order(_order(["soju", "soju"], "Two soju, please."))).contains("food")


func test_drink_main_and_side_is_accepted() -> void:
	assert_str(Rules.validate_order(_order(["beer", "pajeon", "odeng"], "Beer, pajeon and odeng, please."))).is_empty()


func test_regression_two_mains_rejected_for_a_normal_customer() -> void:
	# Customers kept ordering double ramyeon (plus tteokbokki). Only hungry ones may have two mains.
	var problem := Rules.validate_order(_order(["soju", "ramyeon", "ramyeon"], "Soju and two ramyeon, please."))
	assert_str(problem).contains("main")


func test_two_mains_accepted_for_a_hungry_customer() -> void:
	assert_str(Rules.validate_order(_order(["soju", "ramyeon", "ramyeon"], "Soju and two ramyeon, please."), 2)).is_empty()


func test_three_mains_rejected_even_for_a_hungry_customer() -> void:
	var items := ["soju", "ramyeon", "ramyeon", "tteokbokki"]
	assert_str(Rules.validate_order(_order(items, "Soju, two ramyeon and tteokbokki."), 2)).contains("3")


func test_regression_two_drinks_rejected_for_a_normal_customer() -> void:
	# Once "a drink or two" was in the prompt, everyone ordered two drinks.
	assert_str(Rules.validate_order(_order(["soju", "beer", "odeng"], "Soju, a beer and odeng."))).contains("drinks")


func test_two_of_the_same_drink_counts_as_two_drinks() -> void:
	assert_str(Rules.validate_order(_order(["soju", "soju", "odeng"], "Two soju and odeng."))).contains("drinks")


func test_two_drinks_accepted_on_a_rough_night() -> void:
	assert_str(Rules.validate_order(_order(["soju", "soju", "odeng"], "Two soju and odeng."), 1, 2)).is_empty()



# --- Later orders: one more bottle, a side, rice ---------------------------------------

func test_extra_order_of_one_more_bottle_is_accepted() -> void:
	var data := _order(["soju"], "Ajumma, one more bottle.")
	assert_str(Rules.validate_extra_order(data, ["soju", "tteokbokki"])).is_empty()


func test_extra_order_names_and_aliases_become_menu_ids() -> void:
	var data := _order(["rice"], "This sauce needs rice too.")
	assert_str(Rules.validate_extra_order(data, ["soju", "tteokbokki"])).is_empty()
	assert_array(data["items"]).contains_exactly(["gonggibap"])


func test_extra_order_line_may_mention_whats_already_on_the_table() -> void:
	var data := _order(["gonggibap"], "This tteokbokki needs a bowl of rice too.")
	assert_str(Rules.validate_extra_order(data, ["soju", "tteokbokki"])).is_empty()


func test_extra_order_line_mentioning_something_elsewhere_is_rejected() -> void:
	var data := _order(["soju"], "One more soju, and some pajeon.")
	assert_str(Rules.validate_extra_order(data, ["soju", "tteokbokki"])).contains("Pajeon")


func test_extra_order_with_a_main_dish_is_rejected() -> void:
	var data := _order(["ramyeon"], "Actually, ramyeon too.")
	assert_str(Rules.validate_extra_order(data, ["soju", "tteokbokki"])).contains("main")


func test_extra_order_with_two_drinks_is_rejected() -> void:
	var data := _order(["soju", "beer"], "Soju and a beer.")
	assert_str(Rules.validate_extra_order(data, ["soju", "odeng"])).contains("drinks")


func test_extra_order_with_three_items_is_rejected() -> void:
	var data := _order(["soju", "odeng", "gonggibap"], "Soju, odeng and rice.")
	assert_str(Rules.validate_extra_order(data, ["soju", "tteokbokki"])).contains("3")


func test_fried_rice_needs_a_main_on_the_table() -> void:
	var data := _order(["bokkeumbap"], "Fried rice in this sauce, please.")
	assert_str(Rules.validate_extra_order(data, ["soju", "odeng"])).contains("main")


func test_fried_rice_accepted_after_a_main() -> void:
	var data := _order(["bokkeumbap"], "Fried rice in this sauce too, please.")
	assert_str(Rules.validate_extra_order(data, ["soju", "dakgalbi"])).is_empty()


func test_fried_rice_cant_be_part_of_the_first_order() -> void:
	var data := _order(["soju", "dakgalbi", "bokkeumbap"], "Soju, dakgalbi and fried rice.")
	assert_str(Rules.validate_order(data)).contains("later")



# --- How often people order again -------------------------------------------------------

func test_extra_order_odds_add_up_to_one() -> void:
	var total := 0.0
	for odds in Rules.EXTRA_ORDER_ODDS:
		total += odds
	assert_float(total).is_equal_approx(1.0, 0.0001)


func test_extra_order_count_gives_a_mix() -> void:
	# Half never order again, most of the rest order once more, a few order a third time.
	assert_int(Rules.extra_order_count(0.0)).is_equal(0)
	assert_int(Rules.extra_order_count(0.49)).is_equal(0)
	assert_int(Rules.extra_order_count(0.5)).is_equal(1)
	assert_int(Rules.extra_order_count(0.89)).is_equal(1)
	assert_int(Rules.extra_order_count(0.9)).is_equal(2)
	assert_int(Rules.extra_order_count(0.999)).is_equal(2)


func test_extra_order_turns_are_customer_turns_but_never_first_or_last() -> void:
	for exchanges in range(4, 9):
		for attempt in 20:
			for turn in Rules.extra_order_turns(exchanges, 1):
				assert_int(turn % 2).is_equal(1)
				assert_int(turn).is_greater(1)
				assert_int(turn).is_less(exchanges * 2 - 1)


func test_regression_two_extra_orders_are_spaced_out() -> void:
	# Later orders kept coming straight after the food, and a third order straight after the second.
	for exchanges in range(5, 9):
		for attempt in 20:
			var turns := Rules.extra_order_turns(exchanges, 2)
			assert_int(turns.size()).is_equal(2)
			assert_int(turns[1] - turns[0]).is_greater_equal(4)
			assert_int(turns[0]).is_greater(1)
			assert_int(turns[1]).is_less(exchanges * 2 - 1)


func test_short_conversation_gets_at_most_one_extra_order() -> void:
	# 3 exchanges leave only one turn that isn't the first reply or the last line.
	assert_array(Rules.extra_order_turns(3, 2)).contains_exactly([3])


func test_no_extra_orders_means_no_turns() -> void:
	assert_array(Rules.extra_order_turns(4, 0)).is_empty()



func test_regression_extra_order_that_sounds_like_a_first_order_is_rejected() -> void:
	# Later orders sounded like "I'll take soju and skewers", as if they'd only just sat down.
	var data := _order(["soju", "odeng"], "I'll take soju and odeng.")
	assert_str(Rules.validate_extra_order(data, ["beer", "tteokbokki"])).contains("first order")


func test_extra_order_with_another_is_accepted() -> void:
	var data := _order(["odeng"], "Another plate of odeng, Ajumma.")
	assert_str(Rules.validate_extra_order(data, ["soju", "odeng"])).is_empty()



# --- Regression, LLM-TUNING.md "Later orders that ask for more than they get" -----------

func test_regression_later_order_asking_for_more_of_a_table_dish_is_rejected() -> void:
	# "Another tteokbokki" with only makgeolli in the order: tteokbokki never arrived.
	var data := _order(["makgeolli"], "One more makgeolli and another tteokbokki.")
	var problem := Rules.validate_extra_order(data, ["makgeolli", "tteokbokki"])
	assert_str(problem).contains("Tteokbokki")
	assert_str(problem).contains("this tteokbokki")


func test_regression_later_order_asking_for_rice_by_alias_is_rejected() -> void:
	var data := _order(["soju"], "One more soju and some rice too.")
	assert_str(Rules.validate_extra_order(data, ["soju", "tteokbokki"])).contains("Gonggibap")


func test_first_order_asking_for_rice_by_alias_is_rejected() -> void:
	var data := _order(["soju", "tteokbokki"], "Soju, tteokbokki and a bowl of rice.")
	assert_str(Rules.validate_order(data)).contains("Gonggibap")


func test_fried_rice_is_not_also_read_as_rice() -> void:
	var found := Rules.mentions("Fried rice in this sauce, please.", true)
	assert_int(found.size()).is_equal(1)
	assert_str(str(found[0]["id"])).is_equal("bokkeumbap")


func test_conversation_can_mention_rice_without_ordering_it() -> void:
	# "Have you eaten rice?" is a greeting, not an order: aliases only count in order lines.
	assert_str(Rules.validate_line({"line": "Have you eaten rice today?"}, "Kim Sung-ho", "Ajusshi", ["soju", "odeng"])).is_empty()


func test_the_and_my_also_refer_to_whats_on_the_table() -> void:
	var data := _order(["gonggibap"], "The tteokbokki is so good, I need rice too.")
	assert_str(Rules.validate_extra_order(data, ["soju", "tteokbokki"])).is_empty()



# --- Bar names -------------------------------------------------------------------------

func test_valid_bar_name_is_accepted() -> void:
	assert_str(Rules.validate_bar_name({"name": "Byeolbit Pocha", "meaning": "Starlight Tent"})).is_empty()


func test_bar_name_in_hangul_is_rejected() -> void:
	assert_str(Rules.validate_bar_name({"name": "별빛 포차", "meaning": "Starlight Tent"})).contains("English letters")


func test_bar_name_thats_just_the_english_meaning_is_rejected() -> void:
	assert_str(Rules.validate_bar_name({"name": "Starlight Tent", "meaning": "Starlight Tent"})).contains("Korean")


func test_very_long_bar_name_is_rejected() -> void:
	assert_str(Rules.validate_bar_name({"name": "Pocha ".repeat(10), "meaning": "Tent"})).contains("too long")


func test_bar_name_without_a_meaning_is_rejected() -> void:
	assert_str(Rules.validate_bar_name({"name": "Sarang Pocha"})).contains("meaning")


func test_quotes_around_bar_name_are_removed() -> void:
	var data := {"name": "\"Golmok Pocha\"", "meaning": "Back Alley Tent"}
	assert_str(Rules.validate_bar_name(data)).is_empty()
	assert_str(str(data["name"])).is_equal("Golmok Pocha")



func test_fallback_bar_name_uses_the_owners_given_name() -> void:
	var named := Rules.fallback_bar_name("Park Mi-sook")
	assert_str(str(named["name"])).is_equal("Mi-sook-ne Pocha")
	assert_str(Rules.validate_bar_name(named)).is_empty()


func test_fallback_bar_name_copes_with_odd_names() -> void:
	assert_str(Rules.validate_bar_name(Rules.fallback_bar_name(""))).is_empty()
	assert_str(Rules.validate_bar_name(Rules.fallback_bar_name("Kim 지호"))).is_empty()


# --- The night's clock ------------------------------------------------------------------

func test_clock_text_reads_like_a_clock() -> void:
	assert_str(Rules.clock_text(18 * 60)).is_equal("6:00pm")
	assert_str(Rules.clock_text(23 * 60 + 59)).is_equal("11:59pm")
	assert_str(Rules.clock_text(24 * 60 + 5)).is_equal("12:05am")
	assert_str(Rules.clock_text(Rules.CLOSE_MINUTES)).is_equal("3:00am")
	assert_str(Rules.clock_text(12 * 60)).is_equal("12:00pm")


func test_late_evening_is_busier_than_opening_and_closing() -> void:
	var opening := Rules.arrivals_per_hour(Rules.OPEN_MINUTES)
	var late := Rules.arrivals_per_hour(Rules.CLOSE_MINUTES - 30)
	for hour in [21, 22, 23]:
		assert_float(Rules.arrivals_per_hour(hour * 60)).is_greater(opening)
		assert_float(Rules.arrivals_per_hour(hour * 60)).is_greater(late)


func test_arrivals_have_a_rate_even_outside_opening_hours() -> void:
	assert_float(Rules.arrivals_per_hour(10 * 60)).is_greater(0.0)
	assert_float(Rules.arrivals_per_hour(30 * 60)).is_greater(0.0)


func test_arrival_gaps_vary_around_the_average() -> void:
	var average := 60.0 / Rules.arrivals_per_hour(22 * 60)
	assert_int(Rules.next_arrival_gap(22 * 60, 0.0)).is_equal(maxi(5, roundi(average * 0.5)))
	assert_int(Rules.next_arrival_gap(22 * 60, 1.0)).is_equal(roundi(average * 1.5))
	assert_int(Rules.next_arrival_gap(22 * 60, 0.5)).is_equal(roundi(average))


func test_arrival_gaps_are_never_tiny() -> void:
	for minutes in range(Rules.OPEN_MINUTES, Rules.CLOSE_MINUTES, 30):
		assert_int(Rules.next_arrival_gap(minutes, 0.0)).is_greater_equal(5)


func test_a_whole_night_fits_a_sensible_number_of_customers() -> void:
	# Average gaps across the night: about twenty customers, so there's time to talk.
	var minutes := Rules.OPEN_MINUTES
	var arrivals := 0
	while minutes < Rules.LAST_ARRIVAL_MINUTES:
		minutes += Rules.next_arrival_gap(minutes, 0.5)
		arrivals += 1
	assert_int(arrivals).is_between(17, 23)


func test_nights_go_round_the_week() -> void:
	assert_str(Rules.night_day(4, 1)).is_equal("Friday")
	assert_str(Rules.night_day(4, 2)).is_equal("Saturday")
	assert_str(Rules.night_day(4, 4)).is_equal("Monday")
	assert_str(Rules.night_day(0, 8)).is_equal("Monday")
	assert_str(Rules.night_day(6, 1)).is_equal("Sunday")


func test_memorable_line_is_the_longest() -> void:
	var lines := [
		{"speaker": "Kim Ji-ho", "text": "Soju, please."},
		{"speaker": "Lee Min-ji", "text": "My boss said the same thing three times today, louder each time."},
		{"speaker": "Kim Ji-ho", "text": "Another one."},
	]
	assert_str(str(Rules.memorable_line(lines)["speaker"])).is_equal("Lee Min-ji")


func test_memorable_line_is_empty_when_nobody_spoke() -> void:
	assert_bool(Rules.memorable_line([]).is_empty()).is_true()


# --- Seats and the kitchen ---------------------------------------------------------------

func test_the_tent_has_five_stools() -> void:
	assert_int(Rules.SEATS).is_equal(5)


func test_drinks_come_straight_away_and_cooked_food_waits() -> void:
	var order := ["beer", "tteokbokki", "odeng", "pajeon"]
	assert_array(Rules.instant_items(order)).contains_exactly(["beer", "odeng"])
	assert_array(Rules.cooked_items(order)).contains_exactly(["tteokbokki", "pajeon"])


func test_table_text_says_what_is_still_cooking() -> void:
	var text := Rules.table_text(["beer"], ["tteokbokki"], "kimchi")
	assert_str(text).starts_with("Beer, plus free banchan (kimchi)")
	assert_str(text).contains("Still cooking")
	assert_str(text).contains("nobody can eat it: Tteokbokki")


func test_table_text_with_everything_served_mentions_no_cooking() -> void:
	assert_str(Rules.table_text(["beer", "tteokbokki"], [], "kimchi")).is_equal("Beer, Tteokbokki, plus free banchan (kimchi)")


func test_table_text_with_only_banchan() -> void:
	assert_str(Rules.table_text([], ["bokkeumbap"], "kimchi")).starts_with("free banchan (kimchi). Still cooking")


# --- How long people stay, and their mood for company -------------------------------------

func test_company_is_mostly_chatty() -> void:
	assert_str(Rules.company(0.0)).is_equal("owner")
	assert_str(Rules.company(Rules.HERE_TO_TALK_CHANCE + 0.01)).is_equal("quiet")
	assert_str(Rules.company(0.99)).is_equal("chatty")
	var chatty := 0
	for i in 100:
		if Rules.company(i / 100.0) == "chatty":
			chatty += 1
	assert_int(chatty).is_between(50, 60)


func test_most_people_stay_half_an_hour_to_an_hour() -> void:
	assert_int(Rules.stay_minutes("chatty", 0.0)).is_equal(30)
	assert_int(Rules.stay_minutes("quiet", 1.0)).is_equal(60)
	assert_int(Rules.stay_minutes("chatty", 0.5)).is_equal(45)


func test_people_here_to_talk_stay_longer() -> void:
	assert_int(Rules.stay_minutes("owner", 0.0)).is_equal(60)
	assert_int(Rules.stay_minutes("owner", 1.0)).is_equal(90)


func test_greetings_are_quick_when_its_busy() -> void:
	assert_bool(Rules.quick_greeting(1, 0)).is_true()  # someone else is waiting
	assert_bool(Rules.quick_greeting(0, Rules.BUSY_COUNTER)).is_true()  # a busy counter
	assert_bool(Rules.quick_greeting(0, Rules.BUSY_COUNTER - 1)).is_false()  # quiet: a proper hello


func test_only_quiet_customers_stay_out_of_chats() -> void:
	assert_bool(Rules.joins_chats("chatty")).is_true()
	assert_bool(Rules.joins_chats("owner")).is_true()
	assert_bool(Rules.joins_chats("quiet")).is_false()


func test_every_mood_for_company_is_described() -> void:
	for mood in ["chatty", "quiet", "owner"]:
		assert_bool(Rules.COMPANY_TEXT.has(mood)).is_true()


# --- How strangers talk ---------------------------------------------------------------------

func test_strangers_dont_say_oppa_or_eonni() -> void:
	for line in ["Oppa, pass the soju?", "Thanks, eonni.", "Hyung! Over here.", "Noona, are you okay?"]:
		var data := {"line": line}
		assert_str(Rules.validate_line(data, "Kim Ji-ho", "")).override_failure_message(line).contains("only just met")


func test_polite_lines_between_strangers_are_fine() -> void:
	var data := {"line": "Jeogiyo, sorry to bother you. Is this seat taken?"}
	assert_str(Rules.validate_line(data, "Kim Ji-ho", "", [], ["Lee Min-jun"])).is_empty()


func test_names_dont_count_as_close_terms() -> void:
	# Lee Hyung-jun's name has "hyung" in it; saying his name is fine.
	assert_str(Rules.close_term("Nice to meet you, Hyung-jun.", ["Lee Hyung-jun"])).is_empty()
	assert_str(Rules.close_term("Lee Hyung-jun, right?", ["Lee Hyung-jun"])).is_empty()
	assert_str(Rules.close_term("Hyung-jun, oppa!", ["Lee Hyung-jun"])).is_equal("oppa")


func test_close_terms_are_whole_words_only() -> void:
	assert_str(Rules.close_term("Unnecessary, honestly.")).is_empty()


# --- No same names ----------------------------------------------------------------------------

func test_a_customer_name_and_gender_is_fine() -> void:
	var data := {"name": " Moon Tae-il ", "gender": "Man"}
	assert_str(Rules.validate_customer_name(data, ["Kim Ji-ho"])).is_empty()
	assert_str(str(data["name"])).is_equal("Moon Tae-il")
	assert_str(str(data["gender"])).is_equal("man")


func test_a_name_already_at_the_counter_is_rejected_straight_away() -> void:
	var problem := Rules.validate_customer_name({"name": "Kim Ji-ho", "gender": "woman"}, ["kim ji-ho"])
	assert_str(problem).contains("already at the counter")


func test_bad_names_and_genders_are_rejected() -> void:
	assert_str(Rules.validate_customer_name({"name": "Ji-ho", "gender": "woman"})).contains("family name")
	assert_str(Rules.validate_customer_name({"name": "김지호 Kim", "gender": "woman"})).contains("English letters")
	assert_str(Rules.validate_customer_name({"name": "Kim Ji-ho", "gender": "girl"})).contains("gender")
	assert_str(Rules.validate_customer_name({"name": "Kim Ji-ho"})).is_not_empty()


func test_customer_details_need_everything_but_the_name() -> void:
	var details := _customer()
	details.erase("name")
	assert_str(Rules.validate_customer_details(details)).is_empty()
	details.erase("job")
	assert_str(Rules.validate_customer_details(details)).is_not_empty()


func test_a_customer_with_a_name_already_at_the_counter_is_rejected() -> void:
	var problem := Rules.validate_customer(_customer(), ["Lee Min-jun", "kim ji-ho"])
	assert_str(problem).contains("already at the counter")


func test_a_customer_with_a_new_name_is_fine() -> void:
	assert_str(Rules.validate_customer(_customer(), ["Lee Min-jun"])).is_empty()


# --- Kinds of problem, for the stats -----------------------------------------------------

func test_problems_are_grouped_by_kind() -> void:
	var cases := {
		"someone called Kim Ji-ho is already at the counter: pick a different name": "same name",
		"the line says \"oppa\", but these people have only just met: strangers don't use oppa, hyung, nuna or eonni": "oppa, hyung, nuna or eonni",
		"the line mentions Tteokbokki, but that isn't on the table (Beer)": "food that wasn't ordered",
		"\"pizza\" isn't on the menu": "not on the menu",
		"it wasn't a JSON object": "missing or broken JSON",
		"an age of 12 doesn't fit here (it must be 19 to 90)": "age",
		"\"gender\" must be \"woman\" or \"man\"": "name format",
		"there's no drink: everyone orders at least one drink": "order rules",
	}
	for problem in cases:
		assert_str(Rules.problem_kind(problem)).override_failure_message(problem).is_equal(cases[problem])


# --- Non-binary customers -------------------------------------------------------------------

func test_about_one_in_a_hundred_is_non_binary() -> void:
	assert_str(Rules.game_gender(0.0)).is_equal("non-binary")
	assert_str(Rules.game_gender(Rules.NON_BINARY_CHANCE + 0.001)).is_empty()  # the AI chooses
	var count := 0
	for i in 1000:
		if Rules.game_gender(i / 1000.0) == "non-binary":
			count += 1
	assert_int(count).is_equal(10)


func test_a_gender_the_game_decided_needs_only_a_name() -> void:
	var data := {"name": "Han Seol"}
	assert_str(Rules.validate_customer_name(data, [], "non-binary")).is_empty()
	assert_str(str(data["gender"])).is_equal("non-binary")
	# ...and it overrides whatever gender the AI added anyway.
	var other := {"name": "Han Seol", "gender": "woman"}
	assert_str(Rules.validate_customer_name(other, [], "non-binary")).is_empty()
	assert_str(str(other["gender"])).is_equal("non-binary")


func test_the_ai_cant_choose_non_binary_itself() -> void:
	# So the game's 1% stays 1%.
	assert_str(Rules.validate_customer_name({"name": "Han Seol", "gender": "non-binary"})).contains("gender")


# --- How fast time runs ---------------------------------------------------------------------

func test_time_runs_fast_when_the_tent_is_quiet() -> void:
	assert_float(Rules.time_speed(0)).is_greater(Rules.time_speed(1))  # empty: really fast
	assert_float(Rules.time_speed(1)).is_greater(Rules.time_speed(2))  # one: a bit fast
	assert_float(Rules.time_speed(2)).is_equal(1.0)  # two or more: time to chat
	assert_float(Rules.time_speed(5)).is_equal(1.0)


# --- The cat --------------------------------------------------------------------------------

func test_the_cat_always_moves_somewhere_new() -> void:
	for personality in Rules.CAT_PERSONALITIES:
		for i in 20:
			var spot := Rules.pick_cat_spot(personality, true, true, i / 20.0, "stove")
			assert_str(spot).is_not_equal("stove")
			assert_bool(spot in Rules.CAT_SPOTS).is_true()


func test_the_cat_needs_someone_for_a_lap_and_food_for_begging() -> void:
	for i in 50:
		var spot := Rules.pick_cat_spot("affectionate", false, false, i / 50.0)
		assert_bool(spot in ["lap", "feet", "food"]).override_failure_message(spot).is_false()
		var no_food := Rules.pick_cat_spot("greedy", true, false, i / 50.0)
		assert_str(no_food).is_not_equal("food")


func test_personality_shapes_where_the_cat_goes() -> void:
	var laps := {"affectionate": 0, "grumpy": 0}
	for personality in laps:
		for i in 100:
			if Rules.pick_cat_spot(personality, true, true, i / 100.0) == "lap":
				laps[personality] += 1
	assert_int(laps["affectionate"]).is_greater(laps["grumpy"] * 5)


func test_cat_text_says_where_it_is() -> void:
	assert_str(Rules.cat_text("Nabi", "stove")).is_equal("Nabi is curled up asleep by the stove.")
	assert_str(Rules.cat_text("Nabi", "lap", "Kim Ji-ho")).is_equal("Nabi is curled up on Kim Ji-ho's lap.")
	assert_str(Rules.cat_move_text("Nabi", "street")).contains("slips out")


func test_nobody_strokes_a_cat_that_isnt_on_their_lap() -> void:
	var people := ["Park Mi-sook", "Kim Ji-ho"]
	# Asleep by the stove: no stroking, no lap.
	assert_str(Rules.check_cat("Nabi purrs as I stroke her.", "Nabi", "stove", "", people)).contains("isn't what's happening")
	assert_str(Rules.check_cat("Look, the cat's on my lap!", "Nabi", "street", "", people)).contains("out in the street")
	# On someone else's lap, not in this conversation: still no.
	assert_str(Rules.check_cat("Can I pet the cat?", "Nabi", "lap", "Lee Min-jun", people)).is_not_empty()


func test_stroking_a_cat_on_a_lap_in_the_conversation_is_fine() -> void:
	var people := ["Park Mi-sook", "Kim Ji-ho"]
	assert_str(Rules.check_cat("She likes it when you stroke Nabi there.", "Nabi", "lap", "Kim Ji-ho", people)).is_empty()


func test_mentioning_the_cat_without_touching_is_fine_anywhere() -> void:
	assert_str(Rules.check_cat("Where's Nabi got to?", "Nabi", "street", "", [])).is_empty()
	assert_str(Rules.check_cat("I'll pet-sit for my sister next week.", "Nabi", "stove", "", [])).is_empty()  # no cat mentioned


func test_cat_checks_are_part_of_line_checks() -> void:
	var cat := {"name": "Nabi", "spot": "stove", "with": ""}
	assert_str(Rules.validate_line({"line": "I'll just stroke Nabi a bit."}, "Kim Ji-ho", "", [], ["Park Mi-sook"], cat)).contains("the cat")
	assert_str(Rules.problem_kind("the line has the cat being stroked or on a lap, but that isn't what's happening: ...")).is_equal("the cat")


func test_cat_names() -> void:
	var data := {"name": " Dubu "}
	assert_str(Rules.validate_cat_name(data, "Park Mi-sook")).is_empty()
	assert_str(str(data["name"])).is_equal("Dubu")
	assert_str(Rules.validate_cat_name({"name": "Mi-sook"}, "Park Mi-sook")).contains("owner's name")
	assert_str(Rules.validate_cat_name({"name": "The Very Fluffy One"})).contains("one or two words")
	assert_str(Rules.validate_cat_name({"name": "두부"})).contains("English letters")
	assert_bool(Rules.fallback_cat_name(0.5) in Rules.CAT_NAMES).is_true()
	assert_str(Rules.fallback_cat_name(1.0)).is_equal(Rules.CAT_NAMES.back())
