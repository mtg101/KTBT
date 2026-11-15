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

func test_the_game_decides_every_gender() -> void:
	# About one in a hundred non-binary, the rest half women and half men.
	var counts := {"non-binary": 0, "woman": 0, "man": 0}
	for i in 1000:
		counts[Rules.game_gender(i / 1000.0)] += 1
	assert_int(counts["non-binary"]).is_equal(10)
	assert_int(counts["woman"]).is_between(490, 500)
	assert_int(counts["man"]).is_between(490, 500)


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


# --- What conversations turn to -----------------------------------------------------------

func test_owner_topics_vary_and_never_repeat_straight_away() -> void:
	var seen := {}
	for i in 100:
		var topic := Rules.pick_owner_topic(i / 100.0, false, "tent", "their_day")
		assert_str(topic).is_not_equal("their_day")
		seen[topic] = true
	assert_int(seen.size()).is_greater_equal(6)  # plenty of variety, food among them
	assert_bool(seen.has("food")).is_true()


func test_food_comes_up_more_when_somethings_just_been_served() -> void:
	var counts := {true: 0, false: 0}
	for news in [true, false]:
		for i in 200:
			if Rules.pick_owner_topic(i / 200.0, news, "tent") == "food":
				counts[news] += 1
	assert_int(counts[true]).is_greater(counts[false] * 2)


func test_the_cat_comes_up_only_when_its_about() -> void:
	for i in 100:
		assert_str(Rules.pick_owner_topic(i / 100.0, false, "none")).is_not_equal("the_cat")
		assert_str(Rules.pick_chat_topic(i / 100.0, "none")).is_not_equal("the_cat")
	var with_them := 0
	var about := 0
	for i in 200:
		if Rules.pick_owner_topic(i / 200.0, false, "with_them") == "the_cat":
			with_them += 1
		if Rules.pick_owner_topic(i / 200.0, false, "tent") == "the_cat":
			about += 1
	assert_int(with_them).is_greater(about * 2)  # a cat on your lap is hard to ignore


func test_topic_hints_say_where_to_steer() -> void:
	assert_str(Rules.topic_hint("their_day")).contains("how their day has gone")
	assert_str(Rules.topic_hint("life", true)).contains("love, family")
	assert_str(Rules.topic_hint("nonsense")).is_empty()


func test_lines_with_brackets_are_rejected() -> void:
	var problem := Rules.validate_line({"line": "Ne, soju moksaess-eoyo? (Just got soju, right?)"}, "Kim Ji-ho", "")
	assert_str(problem).contains("brackets")
	assert_str(Rules.problem_kind(problem)).is_equal("brackets (translations, asides)")
	assert_str(Rules.validate_line({"line": "Aigoo, what a night."}, "Kim Ji-ho", "")).is_empty()


func test_every_bars_cat_has_its_own_name() -> void:
	assert_str(Rules.validate_cat_name({"name": "Ssal"}, "Park Mi-sook", ["ssal", "Dubu"])).contains("already called")
	assert_str(Rules.problem_kind("another bar's cat is already called Ssal: pick a different name")).is_equal("same name")
	for i in 20:
		assert_str(Rules.fallback_cat_name(i / 20.0, ["Nabi", "Dubu"])).is_not_equal("Nabi")


# --- How the tent and the night look --------------------------------------------------------

func _look(changes: Dictionary = {}) -> Dictionary:
	var data := {"hangul": "별빛 포차", "tarp": "Blue", "sign": "neon", "touches": ["string_lights", "plants"]}
	data.merge(changes, true)
	return data


func test_a_bar_look_from_the_options_is_fine() -> void:
	var data := _look()
	assert_str(Rules.validate_bar_look(data)).is_empty()
	assert_str(str(data["tarp"])).is_equal("blue")


func test_the_sign_must_be_in_hangul() -> void:
	assert_str(Rules.validate_bar_look(_look({"hangul": "Byeolbit Pocha"}))).contains("Hangul")
	assert_str(Rules.validate_bar_look(_look({"hangul": "별"}))).contains("Hangul")  # one letter isn't a name
	assert_str(Rules.validate_bar_look(_look({"hangul": "별빛 포차 별빛 포차 별빛"}))).contains("too long")


func test_a_bar_look_must_use_the_games_options() -> void:
	assert_str(Rules.validate_bar_look(_look({"tarp": "purple"}))).contains("\"tarp\"")
	assert_str(Rules.validate_bar_look(_look({"sign": "graffiti"}))).contains("\"sign\"")
	assert_str(Rules.validate_bar_look(_look({"touches": ["disco ball"]}))).contains("isn't one of the touches")
	assert_str(Rules.validate_bar_look(_look({"touches": []}))).contains("one or two")
	assert_str(Rules.validate_bar_look(_look({"touches": ["radio", "plants", "photos"]}))).contains("one or two")
	assert_str(Rules.problem_kind("\"tarp\" must be one of: orange, red")).is_equal("the bar's look")


func test_the_night_darkens_and_the_tent_glows() -> void:
	var dusk := Rules.night_light(18 * 60)
	var midnight := Rules.night_light(24 * 60)
	var late := Rules.night_light(26 * 60 + 30)
	assert_float((dusk["sky"] as Color).get_luminance()).is_greater((midnight["sky"] as Color).get_luminance())
	assert_float(float(midnight["glow"])).is_greater(float(dusk["glow"]))
	assert_float(float(late["glow"])).is_less(float(midnight["glow"]))  # a little tired by the end
	var between := Rules.night_light(18 * 60 + 45)  # changes gradually
	assert_float(float(between["glow"])).is_between(float(dusk["glow"]), float(Rules.night_light(19 * 60 + 30)["glow"]))


func test_weather_kinds() -> void:
	assert_str(Rules.weather_kind("heavy rain drumming on the tarp")).is_equal("rain")
	assert_str(Rules.weather_kind("light drizzle")).is_equal("drizzle")
	assert_str(Rules.weather_kind("the first snow of winter")).is_equal("snow")
	assert_str(Rules.weather_kind("thick fog")).is_equal("fog")
	assert_str(Rules.weather_kind("clear, bitterly cold air")).is_equal("cold")
	assert_str(Rules.weather_kind("a muggy summer heat")).is_equal("muggy")
	assert_str(Rules.weather_kind("a warm spring breeze")).is_equal("breeze")


func test_tent_shapes_and_colours_come_from_the_games_lists() -> void:
	var data := _look({"shape": "Scalloped", "tarp": "blue_stripes"})
	assert_str(Rules.validate_bar_look(data)).is_empty()
	assert_str(str(data["shape"])).is_equal("scalloped")
	assert_str(Rules.validate_bar_look(_look({"shape": "geodesic dome"}))).contains("\"shape\"")
	var old := _look()
	old.erase("shape")  # looks from before shapes are classic
	assert_str(Rules.validate_bar_look(old)).is_empty()
	assert_str(str(old["shape"])).is_equal("classic")


func test_more_people_walk_past_in_the_evening_than_the_small_hours() -> void:
	assert_float(Rules.stroll_gap(22 * 60, 0.5)).is_less(Rules.stroll_gap(26 * 60, 0.5))
	assert_float(Rules.stroll_gap(22 * 60, 0.5)).is_less(60.0 / Rules.arrivals_per_hour(22 * 60))  # several for each customer
	assert_float(Rules.stroll_gap(22 * 60, 0.0)).is_greater_equal(1.0)


func test_a_new_bar_is_offered_a_few_looks_and_must_pick_from_them() -> void:
	var offer := Rules.look_offer()
	assert_int(offer["tarp"].size()).is_equal(Rules.OFFERED_TARPS)
	assert_int(offer["shape"].size()).is_equal(Rules.OFFERED_SHAPES)
	var limited := {"tarp": ["teal", "maroon"], "shape": ["awning"]}
	assert_str(Rules.validate_bar_look(_look({"tarp": "teal", "shape": "awning"}), limited)).is_empty()
	assert_str(Rules.validate_bar_look(_look({"tarp": "orange", "shape": "awning"}), limited)).contains("teal, maroon")
	assert_str(Rules.validate_bar_look(_look({"tarp": "teal", "shape": "peaked"}), limited)).contains("\"shape\"")


func test_the_sound_follows_the_scene() -> void:
	var quiet := Ambience.mix({"weather": "", "people": 0, "open": true})
	assert_float(quiet["hum"]).is_equal(1.0)
	assert_float(quiet["simmer"]).is_equal(1.0)  # the odeng pot's always on
	assert_float(quiet["murmur"]).is_equal(0.0)
	assert_float(quiet["sizzle"]).is_equal(0.0)
	var busy := Ambience.mix({"weather": "rain", "people": 5, "cooking": true, "open": true})
	assert_float(busy["rain"]).is_equal(1.0)
	assert_float(busy["murmur"]).is_equal(1.0)
	assert_float(busy["sizzle"]).is_equal(1.0)
	assert_float(Ambience.mix({"weather": "muggy"})["cicadas"]).is_equal(1.0)
	assert_float(Ambience.mix({"weather": "breeze"})["wind"]).is_equal(1.0)
	assert_bool(Ambience.muffled("snow")).is_true()
	assert_bool(Ambience.muffled("rain")).is_false()
	assert_float(Ambience.traffic_gap(1.0, 0.5)).is_less(Ambience.traffic_gap(0.0, 0.5))


func test_every_sound_is_made() -> void:
	for sound in ["clink", "meow", "scrape"]:  # the quick ones; loops take longer to make
		var stream := Ambience.make(sound)
		assert_int(stream.data.size()).is_greater(1000)
		assert_int(stream.loop_mode).is_equal(AudioStreamWAV.LOOP_DISABLED)


func test_arirang_is_in_whole_bars_of_three() -> void:
	var beats := 0.0
	var bar := 0.0
	for note in Music.ARIRANG:
		assert_bool(Music.SEMITONES.has(note[0])).override_failure_message(str(note)).is_true()
		beats += float(note[1])
		bar += float(note[1])
		assert_float(bar).is_less_equal(3.0)  # no note runs over a bar line
		if is_equal_approx(bar, 3.0):
			bar = 0.0
	assert_float(beats).is_equal(48.0)  # sixteen bars


func test_the_game_picks_how_people_look() -> void:
	var neutral := 0
	for i in 300:
		var look := Rules.pick_look(["woman", "man", "non-binary"][i % 3], Rules.pick_age_range(randf()), "")
		assert_bool(Rules.AGE_RANGES.has(look["age_range"])).is_true()
		assert_bool(Rules.HAIR_STYLES.has(look["hair"])).is_true()
		assert_bool(Rules.HAIR_COLOURS.has(look["hair_colour"])).is_true()
		assert_bool(Rules.CLOTHES.has(look["clothes"])).is_true()
		assert_bool(Rules.CLOTHES_COLOURS.has(look["colour"])).is_true()
		if look["clothes"] == "suit":
			assert_array(Rules.SUIT_COLOURS).contains([look["colour"]])
		if look["colour"] in ["beige", "black", "navy", "charcoal", "white", "cream", "camel"]:
			neutral += 1
	assert_int(neutral).is_greater(200)  # mostly beige and black (it's Seoul)


func test_looks_suit_the_weather_and_the_owner() -> void:
	for i in 200:
		assert_str(str(Rules.pick_look("man", "30s", "muggy")["clothes"])).is_not_equal("padded")
		assert_str(str(Rules.pick_look("woman", "30s", "snow")["clothes"])).is_not_equal("tshirt")
		var owner := Rules.pick_look("woman", Rules.pick_age_range(randf(), true), "", true)
		assert_array(["suit", "blazer", "trench", "scrubs"]).not_contains([owner["clothes"]])
		assert_bool(owner["apron"]).is_true()
		assert_array(["20s", "30s"]).not_contains([owner["age_range"]])
		assert_str(str(Rules.pick_look("man", "20s", "")["hair"])).is_not_equal("balding")
		assert_array(["grey", "white"]).not_contains([Rules.pick_look("woman", "20s", "")["hair_colour"]])


func test_ages_keep_to_the_games_range() -> void:
	var customer := {"age": 45, "job": "nurse", "mood": "tired", "reason": "A long shift.", "speech_style": "quiet", "appearance": "Scrubs."}
	var fits := customer.duplicate()
	assert_str(Rules.validate_customer_details(fits, "40s")).is_empty()
	assert_int(int(fits["age"])).is_equal(45)
	var too_old := customer.duplicate()
	assert_str(Rules.validate_customer_details(too_old, "20s")).is_empty()
	assert_int(int(too_old["age"])).is_equal(29)  # moved into the game's range, not rejected
	assert_str(Rules.validate_customer_details(customer.duplicate())).is_empty()  # any adult age
	var owner := _owner({"age": 52})
	assert_str(Rules.validate_owner(owner, "woman", "60s")).is_empty()
	assert_int(int(owner["age"])).is_equal(60)
	assert_str(Rules.validate_customer_details(_ages(15), "20s")).contains("15")  # under age is still rejected
	assert_str(Rules.age_range_of(58)).is_equal("50s")
	assert_str(Rules.age_range_of(80)).is_equal("70s")


func test_a_look_in_words() -> void:
	var look := {"age_range": "30s", "hair": "bob", "hair_colour": "black", "clothes": "trench", "colour": "beige", "glasses": true, "bag": "tote"}
	assert_str(Rules.look_text(look)).is_equal("in their thirties, with black hair in a bob and glasses, wearing a beige trench coat and carrying a tote bag")
	look.merge({"clothes": "suit", "colour": "navy", "glasses": false, "bag": "", "hair": "side_part"}, true)
	assert_str(Rules.look_text(look)).is_equal("in their thirties, with neatly side-parted black hair, wearing a navy suit and tie")
	var owner := {"age_range": "60s", "hair": "perm", "hair_colour": "grey", "clothes": "cardigan", "colour": "camel", "apron": true}
	assert_str(Rules.look_text(owner)).is_equal("in their sixties, with a short, tight greying perm, wearing a camel cardigan under an apron")


func _ages(age: int) -> Dictionary:
	return {"age": age, "job": "student", "mood": "giddy", "reason": "Exams are over.", "speech_style": "loud", "appearance": "A hoodie."}


func test_regression_spicy_rice_cakes_are_tteokbokki_not_rice() -> void:
	var ids: Array = Rules.mentions("I'll have a soju and the spicy rice cakes, please.", true).map(func(m): return m["id"])
	assert_array(ids).contains(["tteokbokki"])
	assert_array(ids).not_contains(["gonggibap"])
	var both: Array = Rules.mentions("The spicy rice cakes and a bowl of rice.", true).map(func(m): return m["id"])
	assert_array(both).contains(["tteokbokki", "gonggibap"])


func test_strangers_are_known_by_how_they_look() -> void:
	var look := {"clothes": "trench", "colour": "beige"}
	assert_str(Rules.seen_as({"gender": "woman", "look": look})).is_equal("the woman in the beige trench coat")
	assert_str(Rules.seen_as({"gender": "man"})).is_equal("the man next to them")


func test_names_in_hangul_are_checked_against_the_romanised_name() -> void:
	assert_str(Rules.fit_hangul("Kim Ji-ho", "김지호")).is_equal("김지호")
	assert_str(Rules.fit_hangul("Seo Yeon-woo", " 서연우 ")).is_equal("서연우")
	assert_str(Rules.fit_hangul("Lee Min-ji", "이민지")).is_equal("이민지")
	assert_str(Rules.fit_hangul("Jang Ji-Hyun", "장지현")).is_equal("장지현")
	assert_str(Rules.fit_hangul("Kim Ji-ho", "박지호")).is_empty()  # the wrong family name
	assert_str(Rules.fit_hangul("Kim Ji-ho", "김미호")).is_empty()  # "Ji" doesn't start with ㅁ
	assert_str(Rules.fit_hangul("Kim Ji-ho", "Kim Ji-ho")).is_empty()  # not Hangul
	assert_str(Rules.fit_hangul("Kim Ji-ho", "")).is_empty()
	assert_str(Rules.fit_hangul("Nabi", "나비")).is_equal("나비")
	assert_str(Rules.fit_hangul("Nabi", "고비")).is_empty()


func test_a_customer_name_keeps_its_hangul_only_if_it_fits() -> void:
	var good := {"name": "Kim Ji-ho", "hangul": "김지호", "gender": "woman"}
	assert_str(Rules.validate_customer_name(good)).is_empty()
	assert_str(str(good["hangul"])).is_equal("김지호")
	var wrong := {"name": "Kim Ji-ho", "hangul": "박지호", "gender": "woman"}
	assert_str(Rules.validate_customer_name(wrong)).is_empty()  # the name's still fine...
	assert_str(str(wrong["hangul"])).is_empty()  # ...but the wrong Hangul isn't shown


func test_long_lines_are_paged_for_speech_bubbles() -> void:
	assert_array(Array(Rules.bubble_pages("Evening, Ajumma."))).is_equal(["Evening, Ajumma."])
	var one := "I should warn you, the owner's recipes are a closely guarded secret, but I can tell you that her sundae is a game-changer."
	assert_int(Rules.bubble_pages(one).size()).is_equal(1)  # most lines fit in one bubble
	var long := one + " It's the one thing that keeps me coming back, even on the nights I swore I'd go straight home, and I've told nobody that, not even my sister."
	var pages := Rules.bubble_pages(long)
	assert_int(pages.size()).is_greater(1)
	for i in pages.size():
		assert_int(pages[i].length()).is_less_equal(Rules.BUBBLE_PAGE + 41)  # a short leftover may join the page before
		if i < pages.size() - 1:
			assert_str(pages[i]).ends_with("…")
	assert_str(" ".join(pages).replace("…", "")).contains("game-changer")
	assert_float(Rules.page_seconds("Hi.")).is_equal(1.8)


func test_regression_made_up_korean_is_rejected() -> void:
	var line := {"line": "Eotteoke haeyo, yukhae? Chamcha-eun naneun joa?"}
	assert_str(Rules.validate_line(line, "Kim Hye-ok", "Ajumma")).contains("made-up Korean")
	assert_str(Rules.problem_kind("the line has made-up Korean words in it (x)")).is_equal("made-up Korean")
	# The odd known word, names, food and everyday English are all fine.
	assert_str(Rules.validate_line({"line": "Jeogiyo, is this seat taken? Geonbae, everyone!"}, "Kim Ji-ho", "")).is_empty()
	assert_str(Rules.validate_line({"line": "Seo Yeon-woo and Jeong Eun-ji said the tteokbokki here is the best in Seoul."}, "Kim Ji-ho", "", [], ["Seo Yeon-woo", "Jeong Eun-ji"])).is_empty()
	assert_str(Rules.validate_line({"line": "Some people just need someone to listen, and everyone needs a theory about love."}, "Kim Ji-ho", "")).is_empty()


func test_muggy_nights_have_few_cardigans() -> void:
	var cardigans := 0
	for i in 400:
		if Rules.pick_look("woman", "30s", "muggy")["clothes"] == "cardigan":
			cardigans += 1
	assert_int(cardigans).is_less(25)


func _memory(changes: Dictionary = {}) -> Dictionary:
	var data := {"owner_remembers": "Tired pharmacist; laughed at last.", "they_remember": "The owner fussed over her.",
		"job": "pharmacist", "family": "two kids", "home": "", "other": "", "night": "Enjoyed it", "towards_owner": "warmer"}
	data.merge(changes, true)
	return data


func test_a_memory_keeps_only_what_was_said() -> void:
	var data := _memory()
	assert_str(Rules.validate_memory(data, "i run the pharmacy on the corner, and my boss never stops")).is_empty()
	assert_str(str(data["night"])).is_equal("enjoyed")
	assert_str(str(data["towards_owner"])).is_equal("warmer")
	assert_str(str(data["job"])).is_equal("pharmacist")  # backed by "pharmacy"
	assert_str(str(data["family"])).is_empty()  # nobody said anything about kids: it doesn't stick
	assert_str(Rules.validate_memory(_memory({"night": "it was amazing"}), "")).contains("\"night\"")
	assert_str(Rules.validate_memory(_memory({"towards_owner": "in love"}), "")).contains("\"towards_owner\"")
	var long := "".lpad(Rules.MAX_MEMORY + 1, "a")
	assert_str(Rules.validate_memory(_memory({"owner_remembers": long}), "")).contains("too long")
	var none := _memory({"night": "didn't enjoy it", "towards_owner": "about the same", "job": "none"})
	assert_str(Rules.validate_memory(none, "pharmacy")).is_empty()
	assert_str(str(none["night"])).is_equal("didnt")
	assert_str(str(none["job"])).is_empty()


func test_last_time_comes_up_only_with_something_to_remember() -> void:
	for i in 50:
		assert_str(Rules.pick_owner_topic(randf(), false, "none")).is_not_equal("last_time")
	var asked := 0
	for i in 200:
		if Rules.pick_owner_topic(randf(), false, "none", "", true) == "last_time":
			asked += 1
	assert_int(asked).is_greater(20)


func _p(gender: String, age: int, owner: bool = false) -> Dictionary:
	return {"gender": gender, "age": age, "owner": owner}


func test_who_may_call_whom_what() -> void:
	var her25 := _p("woman", 25)
	var her30 := _p("woman", 30)
	var him32 := _p("man", 32)
	var him22 := _p("man", 22)
	var owner_her := _p("woman", 58, true)
	var owner_him := _p("man", 58, true)
	# Big brother and sister words: younger to older, the right genders, and only when close.
	assert_array(Rules.allowed_terms(her25, him32, true)).contains(["oppa"])
	assert_array(Rules.allowed_terms(her25, him32, false)).not_contains(["oppa"])  # not close yet
	assert_array(Rules.allowed_terms(her30, him22, true)).not_contains(["oppa", "nuna"])  # he's younger
	assert_array(Rules.allowed_terms(him22, him32, true)).contains(["hyung"])
	assert_array(Rules.allowed_terms(him22, her25, true)).contains(["nuna"])
	assert_array(Rules.allowed_terms(her25, her30, true)).contains(["eonni"])
	assert_array(Rules.allowed_terms(him22, her25, true)).not_contains(["eonni", "oppa", "hyung"])
	assert_array(Rules.allowed_terms(_p("non-binary", 22), him32, true)).not_contains(["oppa", "hyung"])
	# The owner.
	assert_array(Rules.allowed_terms(her25, owner_her, false)).contains(["imo", "ajumma", "sajangnim"])
	assert_array(Rules.allowed_terms(her25, owner_him, false)).contains(["samchon", "ajusshi"])
	assert_array(Rules.allowed_terms(her25, owner_him, false)).not_contains(["imo", "ajumma"])
	assert_array(Rules.allowed_terms(_p("man", 70), owner_her, false)).not_contains(["imo"])  # older than her
	assert_array(Rules.allowed_terms(_p("man", 70), owner_her, false)).contains(["sajangnim"])
	assert_array(Rules.allowed_terms(her25, owner_her, true)).not_contains(["eonni"])  # never to the owner
	# Strangers, and the owner to customers.
	assert_array(Rules.allowed_terms(her25, her30, false)).not_contains(["ajumma"])  # an insult at thirty
	assert_array(Rules.allowed_terms(her25, _p("woman", 48), false)).contains(["ajumma"])
	assert_array(Rules.allowed_terms(owner_her, him22, false)).contains(["haksaeng"])
	assert_array(Rules.allowed_terms(owner_her, him32, false)).not_contains(["haksaeng", "sajangnim"])
	assert_array(Rules.allowed_terms(owner_her, _p("man", 75), false)).contains(["seonsaengnim"])


func test_the_must_never_rules_over_the_whole_grid() -> void:
	for speaker_gender in ["woman", "man", "non-binary"]:
		for listener_gender in ["woman", "man", "non-binary"]:
			for ages in [[22, 35], [35, 22], [30, 30], [45, 60]]:
				for close in [true, false]:
					for to_owner in [true, false]:
						var speaker := _p(speaker_gender, ages[0])
						var listener := _p(listener_gender, ages[1], to_owner)
						var allowed := Rules.allowed_terms(speaker, listener, close)
						var context := "%s %d to %s %d, close %s, owner %s: %s" % [speaker_gender, ages[0], listener_gender, ages[1], close, to_owner, allowed]
						for sibling in ["oppa", "hyung", "eonni", "nuna"]:
							if allowed.has(sibling):
								assert_bool(close and not to_owner and ages[1] > ages[0]).override_failure_message(context).is_true()
						if allowed.has("ajumma"):
							assert_bool(listener_gender == "woman" and ages[1] >= Rules.MIDDLE_AGED).override_failure_message(context).is_true()
						if allowed.has("imo") or allowed.has("samchon"):
							assert_bool(to_owner and ages[1] > ages[0]).override_failure_message(context).is_true()
						if allowed.has("oppa") or allowed.has("hyung"):
							assert_str(listener_gender).override_failure_message(context).is_equal("man")
						if allowed.has("eonni") or allowed.has("nuna"):
							assert_str(listener_gender).override_failure_message(context).is_equal("woman")


func test_lines_that_break_the_address_rules_are_rejected() -> void:
	var not_close := {"speaker": _p("woman", 25), "listener": _p("woman", 30), "close": false, "listener_name": "Han Seol"}
	assert_str(Rules.validate_line({"line": "Eonni, try the tteokbokki."}, "Kim Ji-ho", "", [], [], {}, not_close)).contains("the line calls Han Seol \"eonni\"")
	assert_str(Rules.problem_kind("the line calls Han Seol \"eonni\", but...")).is_equal("address rules")
	var close := not_close.duplicate()
	close["close"] = true
	assert_str(Rules.validate_line({"line": "Unni, try the tteokbokki."}, "Kim Ji-ho", "", [], [], {}, close)).is_empty()
	var to_owner := {"speaker": _p("woman", 25), "listener": _p("man", 58, true), "close": false, "listener_name": "Kim Sung-ho"}
	assert_str(Rules.validate_line({"line": "Ajumma, one more soju."}, "Kim Ji-ho", "", [], [], {}, to_owner)).contains("ajumma")
	assert_str(Rules.validate_line({"line": "Samchon, one more soju."}, "Kim Ji-ho", "", [], [], {}, to_owner)).is_empty()
	# A name isn't a term.
	var to_him := {"speaker": _p("woman", 25), "listener": _p("man", 22), "close": false, "listener_name": "Lee Hyung-jun"}
	assert_str(Rules.validate_line({"line": "Nice to meet you, Hyung-jun."}, "Kim Ji-ho", "", [], ["Lee Hyung-jun"], {}, to_him)).is_empty()


func test_sibling_terms_and_colours() -> void:
	assert_str(Rules.sibling_term(_p("woman", 25), _p("woman", 30))).is_equal("eonni")
	assert_str(Rules.sibling_term(_p("man", 25), _p("woman", 30))).is_equal("nuna")
	assert_str(Rules.sibling_term(_p("woman", 30), _p("woman", 30))).is_empty()  # the same age
	assert_str(Rules.sibling_term(_p("woman", 30), _p("woman", 25))).is_empty()  # she's the older one
	var coloured := Rules.colour_terms("Imo, one more! Thanks, Hyung-jun.", ["Lee Hyung-jun"])
	assert_str(coloured).contains("[color=#%s]Imo[/color]" % Rules.WARMTH_COLOURS["family"])
	assert_str(coloured).contains("auntie")
	assert_str(coloured).contains("Hyung-jun.")  # a name, left alone
	assert_str(coloured).not_contains("[color=#%s]Hyung" % Rules.WARMTH_COLOURS["close"])
	assert_str(Rules.address_text("Kim Ji-ho", _p("woman", 25), "Park Mi-sook", _p("woman", 58, true), false)).contains("Imo")


func _every_fill() -> Dictionary:
	return {"gender": "woman", "name": "Kim Ji-ho", "friend": "Kang Da-eun", "term": "eonni", "cat": "Mandu",
		"owner": "Park Mi-sook", "amount": "₩26,000", "dish": "Tteokbokki", "drink": "Soju", "job": "office worker",
		"weather": "rain", "visit": 7, "drinks": 3, "dishes": 3, "seated": 4, "years": "for nine years"}


func test_tv_captions_fill_in_the_games_facts() -> void:
	for kind in Rules.CAPTIONS:
		assert_dict(Rules.caption_words(kind)).override_failure_message("%s has no wording without blanks" % kind).is_not_empty()
	var seen := {}
	for k in 20:
		var said := Rules.caption_words("order_up", {"dish": "Tteokbokki"}, k / 20.0)
		seen[said["english"]] = true
	assert_bool(seen.has("TTEOKBOKKI, INHALED!")).is_true()
	for k in 20:
		assert_str(Rules.caption_words("order_up", {}, k / 20.0)["english"]).not_contains("{")  # no dish: none that need one
	assert_str(Rules.caption_words("jjin_chin", {"name": "Kim Ji-ho", "friend": "Kang Da-eun"}, 0.5)["english"]).is_equal("JI-HO & DA-EUN ∞")
	assert_str(Rules.caption_words("regular_back", {"visit": 7}, 0.99)["english"]).is_equal("VISIT NUMBER 7 ★")
	assert_str(Rules.caption_words("solo", {"weather": "rain"}, 0.99)["hangul"]).is_equal("비 오는 날 혼술…")
	assert_str(Rules.given_name("Kim Ji-ho")).is_equal("Ji-ho")
	assert_str(Rules.given_name("Mandu")).is_equal("Mandu")


func test_every_tv_caption_is_complete() -> void:
	for kind in Rules.CAPTIONS:
		var data: Dictionary = Rules.CAPTIONS[kind]
		for field in ["words", "icon", "colour", "sound", "emergency"]:
			assert_bool(data.has(field)).override_failure_message("%s has no %s" % [kind, field]).is_true()
		assert_array(Rules.CAPTION_STINGS).contains([data["sound"]])
		assert_bool(Ambience.STINGS.has(str(data["sound"]))).override_failure_message("no sting for %s" % kind).is_true()
		var count: int = data["words"].size()
		for k in count:
			var said := Rules.caption_words(kind, _every_fill(), (k + 0.5) / count)
			assert_str(said["hangul"]).is_equal(str(data["words"][k][0]).replace("{term_hangul}", "언니"))  # each of its words can come up
			assert_str(said["hangul"] + said["english"]).not_contains("{")  # every blank filled
	assert_str(Rules.caption_text("full_house")).is_equal("[TV] 만석! FULL HOUSE!")
	assert_str(Rules.caption_text("cheers", {}, 0.0)).is_equal("[TV] 짠! JJAN! CHEERS!")
	assert_str(Rules.caption_text("cheers", {}, 0.99)).is_equal("[TV] 원샷! ONE SHOT!")
	assert_str(Rules.caption_words("regular_back", {"gender": "man"})["english"]).is_equal("HE'S BACK! ★")
	assert_str(Rules.caption_words("regular_back", {"gender": "non-binary"})["english"]).is_equal("THEY'RE BACK! ★")
	assert_str(Rules.caption_text("friendlier", {"term": "eonni"})).is_equal("[TV] 언니! \"EONNI\" NOW!")
	assert_str(Rules.caption_words("cat_lap", {"cat": "Mandu"})["english"]).is_equal("MANDU MAKES A FRIEND")
	assert_bool(Rules.CAPTIONS["full_house"]["emergency"]).is_true()
	assert_bool(Rules.CAPTIONS["regular_back"]["emergency"]).is_false()
	assert_str(Rules.caption_text("bill", {"amount": "₩26,000"})).is_equal("[TV] 계산! ₩26,000")
	assert_str(Rules.caption_text("not a kind")).is_empty()


func test_tv_captions_are_paced() -> void:
	assert_bool(Rules.caption_allowed("rush", 100.0, -1.0, -1.0)).is_true()  # the first of the night
	assert_bool(Rules.caption_allowed("rush", 100.0, 98.0, -1.0)).is_false()  # too soon after another
	assert_bool(Rules.caption_allowed("rush", 100.0, 96.0, -1.0)).is_true()
	assert_bool(Rules.caption_allowed("regular_back", 100.0, 95.0, 92.0)).is_false()  # the same kind again so soon
	assert_bool(Rules.caption_allowed("regular_back", 200.0, 190.0, 85.0)).is_true()
	assert_bool(Rules.caption_allowed("full_house", 100.0, 99.0, -1.0)).is_true()  # an emergency doesn't wait...
	assert_bool(Rules.caption_allowed("full_house", 100.0, 99.0, 90.0)).is_false()  # ...but doesn't repeat on and on
	assert_bool(Rules.caption_allowed("not a kind", 100.0, -1.0, -1.0)).is_false()
