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
