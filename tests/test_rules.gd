extends GdUnitTestSuite
## Tests for scripts/rules/: the checks that keep the AI's output consistent with the
## game's facts. Tests marked "Regression" guard fixes recorded in LLM-TUNING.md.

const Address = preload("res://scripts/rules/address.gd")
const BarLook = preload("res://scripts/rules/bar_look.gd")
const Captions = preload("res://scripts/rules/captions.gd")
const CatRules = preload("res://scripts/rules/cat_rules.gd")
const Looks = preload("res://scripts/rules/looks.gd")
const Memories = preload("res://scripts/rules/memories.gd")
const Names = preload("res://scripts/rules/names.gd")
const NightRules = preload("res://scripts/rules/night_rules.gd")
const Orders = preload("res://scripts/rules/orders.gd")
const People = preload("res://scripts/rules/people.gd")
const Prompts = preload("res://scripts/prompts.gd")
const Story = preload("res://scripts/rules/story.gd")
const Talk = preload("res://scripts/rules/talk.gd")
const Menu = preload("res://scripts/menu.gd")
const Glossary = preload("res://scripts/rules/glossary.gd")
const Text = preload("res://scripts/rules/text.gd")
const Seasons = preload("res://scripts/rules/seasons.gd")
const Skyline = preload("res://scripts/rules/skyline.gd")
const DishArt = preload("res://scripts/rules/dish_art.gd")


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
	assert_str(People.validate_customer(_customer())).is_empty()


func test_customer_under_drinking_age_is_rejected() -> void:
	assert_str(People.validate_customer(_customer({"age": 18}))).contains("18")


func test_customer_at_drinking_age_is_accepted() -> void:
	assert_str(People.validate_customer(_customer({"age": 19}))).is_empty()


func test_age_given_as_text_is_converted_to_a_number() -> void:
	var data := _customer({"age": "34"})
	assert_str(People.validate_customer(data)).is_empty()
	assert_int(typeof(data["age"])).is_equal(TYPE_INT)
	assert_int(data["age"]).is_equal(34)


func test_age_given_as_decimal_is_converted_to_a_whole_number() -> void:
	var data := _customer({"age": 34.0})
	assert_str(People.validate_customer(data)).is_empty()
	assert_int(typeof(data["age"])).is_equal(TYPE_INT)


func test_age_that_isnt_a_number_is_rejected() -> void:
	assert_str(People.validate_customer(_customer({"age": "thirty-ish"}))).contains("number")


func test_missing_field_is_rejected_and_named() -> void:
	var data := _customer()
	data.erase("mood")
	assert_str(People.validate_customer(data)).contains("mood")


func test_empty_field_is_rejected() -> void:
	assert_str(People.validate_customer(_customer({"job": "   "}))).contains("job")


func test_list_in_a_text_field_is_joined_up() -> void:
	var data := _customer({"mood": ["tired", "a bit tipsy"]})
	assert_str(People.validate_customer(data)).is_empty()
	assert_str(str(data["mood"])).is_equal("tired, a bit tipsy")


func test_reply_that_isnt_an_object_is_rejected() -> void:
	assert_str(People.validate_customer("just some text")).is_not_empty()
	assert_str(People.validate_customer(null)).is_not_empty()


# --- Owners ------------------------------------------------------------------------

func test_valid_owner_is_accepted() -> void:
	assert_str(People.validate_owner(_owner(), "woman")).is_empty()


func test_owner_under_40_is_rejected() -> void:
	assert_str(People.validate_owner(_owner({"age": 39}), "woman")).contains("39")


func test_regression_man_described_as_ajumma_is_rejected() -> void:
	# LLM-TUNING.md, "Owner titles": a man's title on a "gruff-but-soft ajumma".
	var problem := People.validate_owner(_owner({"archetype": "gruff-but-soft ajumma"}), "man")
	assert_str(problem).contains("ajumma")


func test_regression_woman_described_with_mens_term_is_rejected() -> void:
	var problem := People.validate_owner(_owner({"archetype": "the hyung everyone trusts"}), "woman")
	assert_str(problem).contains("hyung")


func test_gendered_terms_match_whole_words_only() -> void:
	# "funny" contains "unni" (a woman's term), but it's not that word.
	assert_str(People.validate_owner(_owner({"archetype": "funny ex-idol trainee"}), "man")).is_empty()


# --- Orders ------------------------------------------------------------------------

func test_valid_order_is_accepted() -> void:
	assert_str(Orders.validate_order(_order(["soju", "tteokbokki"], "Ajumma, soju and tteokbokki please."))).is_empty()


func test_order_names_are_turned_into_menu_ids() -> void:
	var data := _order(["Soju", "Gyeran-mari"], "Soju and gyeran-mari, please.")
	assert_str(Orders.validate_order(data)).is_empty()
	assert_array(data["items"]).contains_exactly(["soju", "gyeran_mari"])


func test_order_for_something_not_on_the_menu_is_rejected() -> void:
	assert_str(Orders.validate_order(_order(["pizza"], "A pizza, please."))).contains("pizza")


func test_empty_order_is_rejected() -> void:
	assert_str(Orders.validate_order(_order([], "Just sitting here."))).is_not_empty()


func test_order_with_too_many_items_is_rejected() -> void:
	var items := ["soju", "beer", "odeng", "ramyeon", "pajeon"]
	assert_str(Orders.validate_order(_order(items, "Lots, please."))).contains("5")


func test_order_without_a_line_is_rejected() -> void:
	assert_str(Orders.validate_order({"items": ["soju"]})).contains("line")


func test_regression_line_mentioning_unordered_item_is_rejected() -> void:
	# LLM-TUNING.md, "Double opening and mismatched orders": said soju, ordered beer.
	var problem := Orders.validate_order(_order(["beer", "odeng"], "One soju, please. Just one."))
	assert_str(problem).contains("Soju")


func test_somaek_order_may_mention_soju_and_beer() -> void:
	assert_str(Orders.validate_order(_order(["somaek", "odeng"], "A somaek: soju dropped in beer, the way I like it."))).is_empty()


func test_somaek_has_to_be_asked_for() -> void:
	# From real nights: "One more soju" and "One more bottle" were both served as somaek.
	assert_str(Orders.validate_extra_order(_order(["somaek"], "One more soju, and an omelette."), ["soju"])).contains("doesn't ask for it")
	assert_str(Orders.validate_extra_order(_order(["somaek"], "One more bottle, please."), ["soju"])).contains("doesn't ask for it")
	assert_str(Orders.validate_order(_order(["somaek", "odeng"], "Ajumma, a soju and the odeng."))).contains("doesn't ask for it")
	# Asking for it any of these ways is fine.
	assert_str(Orders.validate_extra_order(_order(["somaek"], "One more somaek, please."), ["soju"])).is_empty()
	assert_str(Orders.validate_extra_order(_order(["somaek"], "Can I get another soju dropped into this beer?"), ["beer"])).is_empty()
	assert_str(Orders.validate_order(_order(["somaek", "odeng"], "Ajumma, the usual, and odeng."))).is_empty()
	assert_str(Orders.validate_order(_order(["somaek", "odeng"], "Just a somaeck and odeng, please."))).is_empty()  # (a common misspelling)
	assert_str(Menu.resolve("somac")).is_equal("somaek")


func test_quotes_around_order_line_are_removed() -> void:
	var data := _order(["soju", "odeng"], "\"Soju and odeng, please.\"")
	assert_str(Orders.validate_order(data)).is_empty()
	assert_str(str(data["line"])).is_equal("Soju and odeng, please.")


# --- Dialogue lines ------------------------------------------------------------------

func test_valid_line_is_accepted() -> void:
	assert_str(Talk.validate_line({"line": "Eat something first."}, "Park Mi-sook", "Ajumma")).is_empty()


func test_speaker_name_prefix_is_removed() -> void:
	var data := {"line": "Park Mi-sook: Eat something first."}
	assert_str(Talk.validate_line(data, "Park Mi-sook", "Ajumma")).is_empty()
	assert_str(str(data["line"])).is_equal("Eat something first.")


func test_title_prefix_is_removed() -> void:
	var data := {"line": "Ajumma: Eat something first."}
	assert_str(Talk.validate_line(data, "Park Mi-sook", "Ajumma")).is_empty()
	assert_str(str(data["line"])).is_equal("Eat something first.")


func test_other_persons_reply_is_cut_off() -> void:
	var data := {"line": "Eat something first.\nKim Ji-ho: I'm not hungry."}
	assert_str(Talk.validate_line(data, "Park Mi-sook", "Ajumma")).is_empty()
	assert_str(str(data["line"])).is_equal("Eat something first.")


func test_quotes_around_line_are_removed() -> void:
	var data := {"line": "“Eat something first.”"}
	assert_str(Talk.validate_line(data, "Park Mi-sook", "Ajumma")).is_empty()
	assert_str(str(data["line"])).is_equal("Eat something first.")


func test_empty_line_is_rejected() -> void:
	assert_str(Talk.validate_line({"line": "  "}, "Park Mi-sook", "Ajumma")).is_not_empty()


func test_very_long_line_is_rejected() -> void:
	var data := {"line": "Aigoo. ".repeat(100)}
	assert_str(Talk.validate_line(data, "Park Mi-sook", "Ajumma")).contains("long")


func test_line_reply_without_line_key_is_rejected() -> void:
	assert_str(Talk.validate_line({"text": "Hello"}, "Park Mi-sook", "Ajumma")).contains("line")


# --- Bills and order text -------------------------------------------------------------

func test_bill_adds_up_menu_prices() -> void:
	assert_int(Orders.bill(["soju", "tteokbokki"])).is_equal(17000)


func test_bill_counts_repeated_items() -> void:
	assert_int(Orders.bill(["soju", "soju", "soju"])).is_equal(15000)


func test_bill_for_nothing_is_zero() -> void:
	assert_int(Orders.bill([])).is_equal(0)


func test_item_names_groups_repeats() -> void:
	assert_str(Orders.item_names(["soju", "soju", "tteokbokki"])).is_equal("2x Soju, Tteokbokki")


# --- Text helpers -------------------------------------------------------------------

func test_as_sentence_capitalises_and_adds_full_stop() -> void:
	assert_str(Text.as_sentence("a messy bob, dark circles under her eyes")).is_equal("A messy bob, dark circles under her eyes.")


func test_as_sentence_keeps_existing_punctuation() -> void:
	assert_str(Text.as_sentence("Soaked to the skin!")).is_equal("Soaked to the skin!")


func test_as_sentence_leaves_empty_text_alone() -> void:
	assert_str(Text.as_sentence("")).is_empty()


func test_words_splits_on_anything_that_isnt_a_letter() -> void:
	assert_array(Array(Text.words("Gruff-but-soft Ajumma!"))).contains_exactly(["gruff", "but", "soft", "ajumma"])


# --- Regression, LLM-TUNING.md "Talking about food that isn't on the table" ---------------

func test_regression_line_mentioning_food_not_on_the_table_is_rejected() -> void:
	# She ordered makgeolli and ramyeon; the owner talked about tteokbokki.
	var data := {"line": "I put in extra tteokbokki, like I said."}
	var problem := Talk.validate_line(data, "Kim Sung-ho", "Ajusshi", ["makgeolli", "ramyeon", "ramyeon"])
	assert_str(problem).contains("Tteokbokki")
	assert_str(problem).contains("2x Ramyeon")


func test_line_mentioning_food_on_the_table_is_accepted() -> void:
	var data := {"line": "Careful, the ramyeon's hot."}
	assert_str(Talk.validate_line(data, "Kim Sung-ho", "Ajusshi", ["makgeolli", "ramyeon"])).is_empty()


func test_line_check_skips_the_menu_when_no_table_is_given() -> void:
	assert_str(Talk.validate_line({"line": "Tteokbokki is my weakness."}, "Kim Sung-ho", "Ajusshi")).is_empty()


func test_somaek_on_the_table_lets_lines_mention_soju_and_beer() -> void:
	var data := {"line": "Soju in beer, the salaryman's medicine."}
	assert_str(Talk.validate_line(data, "Kim Sung-ho", "Ajusshi", ["somaek"])).is_empty()


# --- How people order: a drink, a food, usually one main ------------------------------

func test_order_with_no_drink_is_rejected() -> void:
	assert_str(Orders.validate_order(_order(["tteokbokki"], "Tteokbokki, please."))).contains("drink")


func test_order_with_no_food_is_rejected() -> void:
	assert_str(Orders.validate_order(_order(["soju", "soju"], "Two soju, please."))).contains("food")


func test_drink_main_and_side_is_accepted() -> void:
	assert_str(Orders.validate_order(_order(["beer", "pajeon", "odeng"], "Beer, pajeon and odeng, please."))).is_empty()


func test_regression_two_mains_rejected_for_a_normal_customer() -> void:
	# Customers kept ordering double ramyeon (plus tteokbokki). Only hungry ones may have two mains.
	var problem := Orders.validate_order(_order(["soju", "ramyeon", "ramyeon"], "Soju and two ramyeon, please."))
	assert_str(problem).contains("main")


func test_two_mains_accepted_for_a_hungry_customer() -> void:
	assert_str(Orders.validate_order(_order(["soju", "ramyeon", "ramyeon"], "Soju and two ramyeon, please."), 2)).is_empty()


func test_three_mains_rejected_even_for_a_hungry_customer() -> void:
	var items := ["soju", "ramyeon", "ramyeon", "tteokbokki"]
	assert_str(Orders.validate_order(_order(items, "Soju, two ramyeon and tteokbokki."), 2)).contains("3")


func test_regression_two_drinks_rejected_for_a_normal_customer() -> void:
	# Once "a drink or two" was in the prompt, everyone ordered two drinks.
	assert_str(Orders.validate_order(_order(["soju", "beer", "odeng"], "Soju, a beer and odeng."))).contains("drinks")


func test_two_of_the_same_drink_counts_as_two_drinks() -> void:
	assert_str(Orders.validate_order(_order(["soju", "soju", "odeng"], "Two soju and odeng."))).contains("drinks")


func test_two_drinks_accepted_on_a_rough_night() -> void:
	assert_str(Orders.validate_order(_order(["soju", "soju", "odeng"], "Two soju and odeng."), 1, 2)).is_empty()



# --- Later orders: one more bottle, a side, rice ---------------------------------------

func test_extra_order_of_one_more_bottle_is_accepted() -> void:
	var data := _order(["soju"], "Ajumma, one more bottle.")
	assert_str(Orders.validate_extra_order(data, ["soju", "tteokbokki"])).is_empty()


func test_extra_order_names_and_aliases_become_menu_ids() -> void:
	var data := _order(["rice"], "This sauce needs rice too.")
	assert_str(Orders.validate_extra_order(data, ["soju", "tteokbokki"])).is_empty()
	assert_array(data["items"]).contains_exactly(["gonggibap"])


func test_extra_order_line_may_mention_whats_already_on_the_table() -> void:
	var data := _order(["gonggibap"], "This tteokbokki needs a bowl of rice too.")
	assert_str(Orders.validate_extra_order(data, ["soju", "tteokbokki"])).is_empty()


func test_extra_order_line_mentioning_something_elsewhere_is_rejected() -> void:
	var data := _order(["soju"], "One more soju, and some pajeon.")
	assert_str(Orders.validate_extra_order(data, ["soju", "tteokbokki"])).contains("Pajeon")


func test_extra_order_with_a_main_dish_is_rejected() -> void:
	var data := _order(["ramyeon"], "Actually, ramyeon too.")
	assert_str(Orders.validate_extra_order(data, ["soju", "tteokbokki"])).contains("main")


func test_extra_order_with_two_drinks_is_rejected() -> void:
	var data := _order(["soju", "beer"], "Soju and a beer.")
	assert_str(Orders.validate_extra_order(data, ["soju", "odeng"])).contains("drinks")


func test_extra_order_with_three_items_is_rejected() -> void:
	var data := _order(["soju", "odeng", "gonggibap"], "Soju, odeng and rice.")
	assert_str(Orders.validate_extra_order(data, ["soju", "tteokbokki"])).contains("3")


func test_fried_rice_needs_a_main_on_the_table() -> void:
	var data := _order(["bokkeumbap"], "Fried rice in this sauce, please.")
	assert_str(Orders.validate_extra_order(data, ["soju", "odeng"])).contains("main")


func test_fried_rice_accepted_after_a_main() -> void:
	var data := _order(["bokkeumbap"], "Fried rice in this sauce too, please.")
	assert_str(Orders.validate_extra_order(data, ["soju", "dakgalbi"])).is_empty()


func test_fried_rice_cant_be_part_of_the_first_order() -> void:
	var data := _order(["soju", "dakgalbi", "bokkeumbap"], "Soju, dakgalbi and fried rice.")
	assert_str(Orders.validate_order(data)).contains("later")



# --- How often people order again -------------------------------------------------------

func test_extra_order_odds_add_up_to_one() -> void:
	var total := 0.0
	for odds in Orders.EXTRA_ORDER_ODDS:
		total += odds
	assert_float(total).is_equal_approx(1.0, 0.0001)


func test_extra_order_count_gives_a_mix() -> void:
	# Half never order again, most of the rest order once more, a few order a third time.
	assert_int(Orders.extra_order_count(0.0)).is_equal(0)
	assert_int(Orders.extra_order_count(0.49)).is_equal(0)
	assert_int(Orders.extra_order_count(0.5)).is_equal(1)
	assert_int(Orders.extra_order_count(0.89)).is_equal(1)
	assert_int(Orders.extra_order_count(0.9)).is_equal(2)
	assert_int(Orders.extra_order_count(0.999)).is_equal(2)


func test_extra_order_turns_are_customer_turns_but_never_first_or_last() -> void:
	for exchanges in range(4, 9):
		for attempt in 20:
			for turn in Orders.extra_order_turns(exchanges, 1):
				assert_int(turn % 2).is_equal(1)
				assert_int(turn).is_greater(1)
				assert_int(turn).is_less(exchanges * 2 - 1)


func test_regression_two_extra_orders_are_spaced_out() -> void:
	# Later orders kept coming straight after the food, and a third order straight after the second.
	for exchanges in range(5, 9):
		for attempt in 20:
			var turns := Orders.extra_order_turns(exchanges, 2)
			assert_int(turns.size()).is_equal(2)
			assert_int(turns[1] - turns[0]).is_greater_equal(4)
			assert_int(turns[0]).is_greater(1)
			assert_int(turns[1]).is_less(exchanges * 2 - 1)


func test_short_conversation_gets_at_most_one_extra_order() -> void:
	# 3 exchanges leave only one turn that isn't the first reply or the last line.
	assert_array(Orders.extra_order_turns(3, 2)).contains_exactly([3])


func test_no_extra_orders_means_no_turns() -> void:
	assert_array(Orders.extra_order_turns(4, 0)).is_empty()



func test_regression_extra_order_that_sounds_like_a_first_order_is_rejected() -> void:
	# Later orders sounded like "I'll take soju and skewers", as if they'd only just sat down.
	var data := _order(["soju", "odeng"], "I'll take soju and odeng.")
	assert_str(Orders.validate_extra_order(data, ["beer", "tteokbokki"])).contains("first order")


func test_extra_order_with_another_is_accepted() -> void:
	var data := _order(["odeng"], "Another plate of odeng, Ajumma.")
	assert_str(Orders.validate_extra_order(data, ["soju", "odeng"])).is_empty()



# --- Regression, LLM-TUNING.md "Later orders that ask for more than they get" -----------

func test_regression_later_order_asking_for_more_of_a_table_dish_is_rejected() -> void:
	# "Another tteokbokki" with only makgeolli in the order: tteokbokki never arrived.
	var data := _order(["makgeolli"], "One more makgeolli and another tteokbokki.")
	var problem := Orders.validate_extra_order(data, ["makgeolli", "tteokbokki"])
	assert_str(problem).contains("Tteokbokki")
	assert_str(problem).contains("this tteokbokki")


func test_later_order_asking_for_rice_gets_rice() -> void:
	# The line wins for a side the AI left out of "items" (it used to be rejected, and 9 orders
	# in a run of six nights fell back to the game's own soju and odeng because of it).
	var data := _order(["soju"], "One more soju and some rice too.")
	assert_str(Orders.validate_extra_order(data, ["soju", "tteokbokki"])).is_empty()
	assert_array(data["items"]).is_equal(["soju", "gonggibap"])


func test_first_order_asking_for_rice_gets_rice() -> void:
	var data := _order(["soju", "tteokbokki"], "Soju, tteokbokki and a bowl of rice.")
	assert_str(Orders.validate_order(data)).is_empty()
	assert_array(data["items"]).is_equal(["soju", "tteokbokki", "gonggibap"])
	assert_int(int(data["added_sides"])).is_equal(1)  # (counted in the stats)
	assert_str(Text.problem_kind("they ordered Somaek, but the line doesn't ask for it")).is_equal("line doesn't match the order")


func test_only_sides_are_added_and_only_if_they_fit() -> void:
	# A main or a drink the line names but "items" doesn't is a real mix-up: still rejected.
	assert_str(Orders.validate_order(_order(["soju", "odeng"], "Soju, odeng and the pajeon."))).contains("Pajeon")
	assert_str(Orders.validate_order(_order(["beer", "odeng"], "Soju and odeng."))).contains("Soju")
	# No room: a later order is at most two things.
	var full := _order(["soju", "odeng"], "One more soju, more odeng, and some rice too.")
	assert_str(Orders.validate_extra_order(full, ["soju", "odeng"])).contains("Gonggibap")
	# Fried rice with a first order: still only later.
	assert_str(Orders.validate_order(_order(["soju", "tteokbokki"], "Soju, tteokbokki and fried rice."))).contains("Bokkeumbap")
	# Talking about the rice already on the table isn't asking for more.
	var talk := _order(["soju"], "One more soju to go with this rice.")
	assert_str(Orders.validate_extra_order(talk, ["soju", "gonggibap"])).is_empty()
	assert_array(talk["items"]).is_equal(["soju"])


func test_fried_rice_is_not_also_read_as_rice() -> void:
	var found := Orders.mentions("Fried rice in this sauce, please.", true)
	assert_int(found.size()).is_equal(1)
	assert_str(str(found[0]["id"])).is_equal("bokkeumbap")


func test_conversation_can_mention_rice_without_ordering_it() -> void:
	# "Have you eaten rice?" is a greeting, not an order: aliases only count in order lines.
	assert_str(Talk.validate_line({"line": "Have you eaten rice today?"}, "Kim Sung-ho", "Ajusshi", ["soju", "odeng"])).is_empty()


func test_the_and_my_also_refer_to_whats_on_the_table() -> void:
	var data := _order(["gonggibap"], "The tteokbokki is so good, I need rice too.")
	assert_str(Orders.validate_extra_order(data, ["soju", "tteokbokki"])).is_empty()



# --- Bar names -------------------------------------------------------------------------

func test_valid_bar_name_is_accepted() -> void:
	assert_str(BarLook.validate_bar_name({"name": "Byeolbit Pocha", "meaning": "Starlight Tent"})).is_empty()


func test_bar_name_in_hangul_is_rejected() -> void:
	assert_str(BarLook.validate_bar_name({"name": "별빛 포차", "meaning": "Starlight Tent"})).contains("English letters")


func test_bar_name_thats_just_the_english_meaning_is_rejected() -> void:
	assert_str(BarLook.validate_bar_name({"name": "Starlight Tent", "meaning": "Starlight Tent"})).contains("Korean")


func test_very_long_bar_name_is_rejected() -> void:
	assert_str(BarLook.validate_bar_name({"name": "Pocha ".repeat(10), "meaning": "Tent"})).contains("too long")


func test_bar_name_without_a_meaning_is_rejected() -> void:
	assert_str(BarLook.validate_bar_name({"name": "Sarang Pocha"})).contains("meaning")


func test_quotes_around_bar_name_are_removed() -> void:
	var data := {"name": "\"Golmok Pocha\"", "meaning": "Back Alley Tent"}
	assert_str(BarLook.validate_bar_name(data)).is_empty()
	assert_str(str(data["name"])).is_equal("Golmok Pocha")



func test_fallback_bar_name_uses_the_owners_given_name() -> void:
	var named := BarLook.fallback_bar_name("Park Mi-sook")
	assert_str(str(named["name"])).is_equal("Mi-sook-ne Pocha")
	assert_str(BarLook.validate_bar_name(named)).is_empty()


func test_fallback_bar_name_copes_with_odd_names() -> void:
	assert_str(BarLook.validate_bar_name(BarLook.fallback_bar_name(""))).is_empty()
	assert_str(BarLook.validate_bar_name(BarLook.fallback_bar_name("Kim 지호"))).is_empty()


# --- The night's clock ------------------------------------------------------------------

func test_clock_text_reads_like_a_clock() -> void:
	assert_str(NightRules.clock_text(18 * 60)).is_equal("6:00pm")
	assert_str(NightRules.clock_text(23 * 60 + 59)).is_equal("11:59pm")
	assert_str(NightRules.clock_text(24 * 60 + 5)).is_equal("12:05am")
	assert_str(NightRules.clock_text(NightRules.CLOSE_MINUTES)).is_equal("3:00am")
	assert_str(NightRules.clock_text(12 * 60)).is_equal("12:00pm")


func test_late_evening_is_busier_than_opening_and_closing() -> void:
	var opening := NightRules.arrivals_per_hour(NightRules.OPEN_MINUTES)
	var late := NightRules.arrivals_per_hour(NightRules.CLOSE_MINUTES - 30)
	for hour in [21, 22, 23]:
		assert_float(NightRules.arrivals_per_hour(hour * 60)).is_greater(opening)
		assert_float(NightRules.arrivals_per_hour(hour * 60)).is_greater(late)


func test_arrivals_have_a_rate_even_outside_opening_hours() -> void:
	assert_float(NightRules.arrivals_per_hour(10 * 60)).is_greater(0.0)
	assert_float(NightRules.arrivals_per_hour(30 * 60)).is_greater(0.0)


func test_arrival_gaps_vary_around_the_average() -> void:
	var average := 60.0 / NightRules.arrivals_per_hour(22 * 60)
	assert_int(NightRules.next_arrival_gap(22 * 60, 0.0)).is_equal(maxi(5, roundi(average * 0.5)))
	assert_int(NightRules.next_arrival_gap(22 * 60, 1.0)).is_equal(roundi(average * 1.5))
	assert_int(NightRules.next_arrival_gap(22 * 60, 0.5)).is_equal(roundi(average))


func test_arrival_gaps_are_never_tiny() -> void:
	for minutes in range(NightRules.OPEN_MINUTES, NightRules.CLOSE_MINUTES, 30):
		assert_int(NightRules.next_arrival_gap(minutes, 0.0)).is_greater_equal(5)


func test_a_whole_night_fits_a_sensible_number_of_customers() -> void:
	# Average gaps across the night: about twenty customers, so there's time to talk.
	var minutes := NightRules.OPEN_MINUTES
	var arrivals := 0
	while minutes < NightRules.LAST_ARRIVAL_MINUTES:
		minutes += NightRules.next_arrival_gap(minutes, 0.5)
		arrivals += 1
	assert_int(arrivals).is_between(17, 23)


func test_nights_go_round_the_week() -> void:
	assert_str(NightRules.night_day(4, 1)).is_equal("Friday")
	assert_str(NightRules.night_day(4, 2)).is_equal("Saturday")
	assert_str(NightRules.night_day(4, 4)).is_equal("Monday")
	assert_str(NightRules.night_day(0, 8)).is_equal("Monday")
	assert_str(NightRules.night_day(6, 1)).is_equal("Sunday")


func test_memorable_line_is_the_longest() -> void:
	var lines := [
		{"speaker": "Kim Ji-ho", "text": "Soju, please."},
		{"speaker": "Lee Min-ji", "text": "My boss said the same thing three times today, louder each time."},
		{"speaker": "Kim Ji-ho", "text": "Another one."},
	]
	assert_str(str(NightRules.memorable_line(lines)["speaker"])).is_equal("Lee Min-ji")


func test_memorable_line_is_empty_when_nobody_spoke() -> void:
	assert_bool(NightRules.memorable_line([]).is_empty()).is_true()


# --- Seats and the kitchen ---------------------------------------------------------------

func test_the_tent_has_five_stools() -> void:
	assert_int(NightRules.SEATS).is_equal(5)


func test_drinks_come_straight_away_and_cooked_food_waits() -> void:
	var order := ["beer", "tteokbokki", "odeng", "pajeon"]
	assert_array(Orders.instant_items(order)).contains_exactly(["beer", "odeng"])
	assert_array(Orders.cooked_items(order)).contains_exactly(["tteokbokki", "pajeon"])


func test_table_text_says_what_is_still_cooking() -> void:
	var text := Orders.table_text(["beer"], ["tteokbokki"], "kimchi")
	assert_str(text).starts_with("Beer, plus free banchan (kimchi)")
	assert_str(text).contains("Still cooking")
	assert_str(text).contains("nobody can eat it: Tteokbokki")


func test_table_text_with_everything_served_mentions_no_cooking() -> void:
	assert_str(Orders.table_text(["beer", "tteokbokki"], [], "kimchi")).is_equal("Beer, Tteokbokki, plus free banchan (kimchi)")


func test_table_text_with_only_banchan() -> void:
	assert_str(Orders.table_text([], ["bokkeumbap"], "kimchi")).starts_with("free banchan (kimchi). Still cooking")


# --- How long people stay, and their mood for company -------------------------------------

func test_company_is_mostly_chatty() -> void:
	assert_str(People.company(0.0)).is_equal("owner")
	assert_str(People.company(People.HERE_TO_TALK_CHANCE + 0.01)).is_equal("quiet")
	assert_str(People.company(0.99)).is_equal("chatty")
	var chatty := 0
	for i in 100:
		if People.company(i / 100.0) == "chatty":
			chatty += 1
	assert_int(chatty).is_between(50, 60)


func test_most_people_stay_half_an_hour_to_an_hour() -> void:
	assert_int(People.stay_minutes("chatty", 0.0)).is_equal(30)
	assert_int(People.stay_minutes("quiet", 1.0)).is_equal(60)
	assert_int(People.stay_minutes("chatty", 0.5)).is_equal(45)


func test_people_here_to_talk_stay_longer() -> void:
	assert_int(People.stay_minutes("owner", 0.0)).is_equal(60)
	assert_int(People.stay_minutes("owner", 1.0)).is_equal(90)


func test_greetings_are_quick_when_its_busy() -> void:
	assert_bool(People.quick_greeting(1, 0)).is_true()  # someone else is waiting
	assert_bool(People.quick_greeting(0, People.BUSY_COUNTER)).is_true()  # a busy counter
	assert_bool(People.quick_greeting(0, People.BUSY_COUNTER - 1)).is_false()  # quiet: a proper hello


func test_only_quiet_customers_stay_out_of_chats() -> void:
	assert_bool(People.joins_chats("chatty")).is_true()
	assert_bool(People.joins_chats("owner")).is_true()
	assert_bool(People.joins_chats("quiet")).is_false()


func test_every_mood_for_company_is_described() -> void:
	for mood in ["chatty", "quiet", "owner"]:
		assert_bool(People.COMPANY_TEXT.has(mood)).is_true()


# --- How strangers talk ---------------------------------------------------------------------

func test_strangers_dont_say_oppa_or_eonni() -> void:
	for line in ["Oppa, pass the soju?", "Thanks, eonni.", "Hyung! Over here.", "Noona, are you okay?"]:
		var data := {"line": line}
		assert_str(Talk.validate_line(data, "Kim Ji-ho", "")).override_failure_message(line).contains("only just met")


func test_polite_lines_between_strangers_are_fine() -> void:
	var data := {"line": "Jeogiyo, sorry to bother you. Is this seat taken?"}
	assert_str(Talk.validate_line(data, "Kim Ji-ho", "", [], ["Lee Min-jun"])).is_empty()


func test_names_dont_count_as_close_terms() -> void:
	# Lee Hyung-jun's name has "hyung" in it; saying his name is fine.
	assert_str(Talk.close_term("Nice to meet you, Hyung-jun.", ["Lee Hyung-jun"])).is_empty()
	assert_str(Talk.close_term("Lee Hyung-jun, right?", ["Lee Hyung-jun"])).is_empty()
	assert_str(Talk.close_term("Hyung-jun, oppa!", ["Lee Hyung-jun"])).is_equal("oppa")


func test_close_terms_are_whole_words_only() -> void:
	assert_str(Talk.close_term("Unnecessary, honestly.")).is_empty()


# --- No same names ----------------------------------------------------------------------------

func test_a_customer_name_and_gender_is_fine() -> void:
	var data := {"name": " Moon Tae-il ", "gender": "Man"}
	assert_str(Names.validate_customer_name(data, ["Kim Ji-ho"])).is_empty()
	assert_str(str(data["name"])).is_equal("Moon Tae-il")
	assert_str(str(data["gender"])).is_equal("man")


func test_a_name_already_at_the_counter_is_rejected_straight_away() -> void:
	var problem := Names.validate_customer_name({"name": "Kim Ji-ho", "gender": "woman"}, ["kim ji-ho"])
	assert_str(problem).contains("already at the counter")


func test_bad_names_and_genders_are_rejected() -> void:
	assert_str(Names.validate_customer_name({"name": "Ji-ho", "gender": "woman"})).contains("family name")
	assert_str(Names.validate_customer_name({"name": "김지호 Kim", "gender": "woman"})).contains("English letters")
	assert_str(Names.validate_customer_name({"name": "Kim Ji-ho", "gender": "girl"})).contains("gender")
	assert_str(Names.validate_customer_name({"name": "Kim Ji-ho"})).is_not_empty()


func test_customer_details_need_everything_but_the_name() -> void:
	var details := _customer()
	details.erase("name")
	assert_str(People.validate_customer_details(details)).is_empty()
	details.erase("job")
	assert_str(People.validate_customer_details(details)).is_not_empty()


func test_a_customer_with_a_name_already_at_the_counter_is_rejected() -> void:
	var problem := People.validate_customer(_customer(), ["Lee Min-jun", "kim ji-ho"])
	assert_str(problem).contains("already at the counter")


func test_a_customer_with_a_new_name_is_fine() -> void:
	assert_str(People.validate_customer(_customer(), ["Lee Min-jun"])).is_empty()


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
		assert_str(Text.problem_kind(problem)).override_failure_message(problem).is_equal(cases[problem])


# --- Non-binary customers -------------------------------------------------------------------

func test_the_game_decides_every_gender() -> void:
	# About one in a hundred non-binary, the rest half women and half men.
	var counts := {"non-binary": 0, "woman": 0, "man": 0}
	for i in 1000:
		counts[People.game_gender(i / 1000.0)] += 1
	assert_int(counts["non-binary"]).is_equal(10)
	assert_int(counts["woman"]).is_between(490, 500)
	assert_int(counts["man"]).is_between(490, 500)


func test_a_gender_the_game_decided_needs_only_a_name() -> void:
	var data := {"name": "Han Seol"}
	assert_str(Names.validate_customer_name(data, [], "non-binary")).is_empty()
	assert_str(str(data["gender"])).is_equal("non-binary")
	# ...and it overrides whatever gender the AI added anyway.
	var other := {"name": "Han Seol", "gender": "woman"}
	assert_str(Names.validate_customer_name(other, [], "non-binary")).is_empty()
	assert_str(str(other["gender"])).is_equal("non-binary")


func test_the_ai_cant_choose_non_binary_itself() -> void:
	# So the game's 1% stays 1%.
	assert_str(Names.validate_customer_name({"name": "Han Seol", "gender": "non-binary"})).contains("gender")


# --- How fast time runs ---------------------------------------------------------------------

func test_time_runs_fast_when_the_tent_is_quiet() -> void:
	assert_float(NightRules.time_speed(0)).is_greater(NightRules.time_speed(1))  # empty: really fast
	assert_float(NightRules.time_speed(1)).is_greater(NightRules.time_speed(2))  # one: a bit fast
	assert_float(NightRules.time_speed(2)).is_equal(1.0)  # two or more: time to chat
	assert_float(NightRules.time_speed(5)).is_equal(1.0)


# --- The cat --------------------------------------------------------------------------------

func test_the_cat_always_moves_somewhere_new() -> void:
	for personality in CatRules.CAT_PERSONALITIES:
		for i in 20:
			var spot := CatRules.pick_cat_spot(personality, true, true, i / 20.0, "stove")
			assert_str(spot).is_not_equal("stove")
			assert_bool(spot in CatRules.CAT_SPOTS).is_true()


func test_the_cat_needs_someone_for_a_lap_and_food_for_begging() -> void:
	for i in 50:
		var spot := CatRules.pick_cat_spot("affectionate", false, false, i / 50.0)
		assert_bool(spot in ["lap", "feet", "food"]).override_failure_message(spot).is_false()
		var no_food := CatRules.pick_cat_spot("greedy", true, false, i / 50.0)
		assert_str(no_food).is_not_equal("food")


func test_personality_shapes_where_the_cat_goes() -> void:
	var laps := {"affectionate": 0, "grumpy": 0}
	for personality in laps:
		for i in 100:
			if CatRules.pick_cat_spot(personality, true, true, i / 100.0) == "lap":
				laps[personality] += 1
	assert_int(laps["affectionate"]).is_greater(laps["grumpy"] * 5)


func test_cat_text_says_where_it_is() -> void:
	assert_str(CatRules.cat_text("Nabi", "stove")).is_equal("Nabi is curled up asleep by the stove.")
	assert_str(CatRules.cat_text("Nabi", "lap", "Kim Ji-ho")).is_equal("Nabi is curled up on Kim Ji-ho's lap.")
	assert_str(CatRules.cat_move_text("Nabi", "street")).contains("slips out")


func test_nobody_strokes_a_cat_that_isnt_on_their_lap() -> void:
	var people := ["Park Mi-sook", "Kim Ji-ho"]
	# Asleep by the stove: no stroking, no lap.
	assert_str(CatRules.check_cat("Nabi purrs as I stroke her.", "Nabi", "stove", "", people)).contains("isn't what's happening")
	assert_str(CatRules.check_cat("Look, the cat's on my lap!", "Nabi", "street", "", people)).contains("out in the street")
	# On someone else's lap, not in this conversation: still no.
	assert_str(CatRules.check_cat("Can I pet the cat?", "Nabi", "lap", "Lee Min-jun", people)).is_not_empty()


func test_stroking_a_cat_on_a_lap_in_the_conversation_is_fine() -> void:
	var people := ["Park Mi-sook", "Kim Ji-ho"]
	assert_str(CatRules.check_cat("She likes it when you stroke Nabi there.", "Nabi", "lap", "Kim Ji-ho", people)).is_empty()


func test_mentioning_the_cat_without_touching_is_fine_anywhere() -> void:
	assert_str(CatRules.check_cat("Where's Nabi got to?", "Nabi", "street", "", [])).is_empty()
	assert_str(CatRules.check_cat("I'll pet-sit for my sister next week.", "Nabi", "stove", "", [])).is_empty()  # no cat mentioned


func test_cat_checks_are_part_of_line_checks() -> void:
	var cat := {"name": "Nabi", "spot": "stove", "with": ""}
	assert_str(Talk.validate_line({"line": "I'll just stroke Nabi a bit."}, "Kim Ji-ho", "", [], ["Park Mi-sook"], cat)).contains("the cat")
	assert_str(Text.problem_kind("the line has the cat being stroked or on a lap, but that isn't what's happening: ...")).is_equal("the cat")


func test_cat_names() -> void:
	var data := {"name": " Dubu "}
	assert_str(CatRules.validate_cat_name(data, "Park Mi-sook")).is_empty()
	assert_str(str(data["name"])).is_equal("Dubu")
	assert_str(CatRules.validate_cat_name({"name": "Mi-sook"}, "Park Mi-sook")).contains("owner's name")
	assert_str(CatRules.validate_cat_name({"name": "The Very Fluffy One"})).contains("one or two words")
	assert_str(CatRules.validate_cat_name({"name": "두부"})).contains("English letters")
	assert_bool(CatRules.fallback_cat_name(0.5) in CatRules.CAT_NAMES).is_true()
	assert_str(CatRules.fallback_cat_name(1.0)).is_equal(CatRules.CAT_NAMES.back())


# --- What conversations turn to -----------------------------------------------------------

func test_owner_topics_vary_and_never_repeat_straight_away() -> void:
	var seen := {}
	for i in 100:
		var topic := Talk.pick_owner_topic(i / 100.0, false, "tent", "their_day")
		assert_str(topic).is_not_equal("their_day")
		seen[topic] = true
	assert_int(seen.size()).is_greater_equal(6)  # plenty of variety, food among them
	assert_bool(seen.has("food")).is_true()


func test_food_comes_up_more_when_somethings_just_been_served() -> void:
	var counts := {true: 0, false: 0}
	for news in [true, false]:
		for i in 200:
			if Talk.pick_owner_topic(i / 200.0, news, "tent") == "food":
				counts[news] += 1
	assert_int(counts[true]).is_greater(counts[false] * 2)


func test_the_cat_comes_up_only_when_its_about() -> void:
	for i in 100:
		assert_str(Talk.pick_owner_topic(i / 100.0, false, "none")).is_not_equal("the_cat")
		assert_str(Talk.pick_chat_topic(i / 100.0, "none")).is_not_equal("the_cat")
	var with_them := 0
	var about := 0
	for i in 200:
		if Talk.pick_owner_topic(i / 200.0, false, "with_them") == "the_cat":
			with_them += 1
		if Talk.pick_owner_topic(i / 200.0, false, "tent") == "the_cat":
			about += 1
	assert_int(with_them).is_greater(about * 2)  # a cat on your lap is hard to ignore


func test_topic_hints_say_where_to_steer() -> void:
	assert_str(Talk.topic_hint("their_day")).contains("how their day has gone")
	assert_str(Talk.topic_hint("life", true)).contains("love, family")
	assert_str(Talk.topic_hint("nonsense")).is_empty()


func test_lines_with_brackets_are_rejected() -> void:
	var problem := Talk.validate_line({"line": "Ne, soju moksaess-eoyo? (Just got soju, right?)"}, "Kim Ji-ho", "")
	assert_str(problem).contains("brackets")
	assert_str(Text.problem_kind(problem)).is_equal("brackets (translations, asides)")
	assert_str(Talk.validate_line({"line": "Aigoo, what a night."}, "Kim Ji-ho", "")).is_empty()


func test_every_bars_cat_has_its_own_name() -> void:
	assert_str(CatRules.validate_cat_name({"name": "Ssal"}, "Park Mi-sook", ["ssal", "Dubu"])).contains("already called")
	assert_str(Text.problem_kind("another bar's cat is already called Ssal: pick a different name")).is_equal("same name")
	for i in 20:
		assert_str(CatRules.fallback_cat_name(i / 20.0, ["Nabi", "Dubu"])).is_not_equal("Nabi")


# --- How the tent and the night look --------------------------------------------------------

func _look(changes: Dictionary = {}) -> Dictionary:
	var data := {"hangul": "별빛 포차", "tarp": "Blue", "sign": "neon", "touches": ["string_lights", "plants"]}
	data.merge(changes, true)
	return data


func test_a_bar_look_from_the_options_is_fine() -> void:
	var data := _look()
	assert_str(BarLook.validate_bar_look(data)).is_empty()
	assert_str(str(data["tarp"])).is_equal("blue")


func test_the_sign_must_be_in_hangul() -> void:
	assert_str(BarLook.validate_bar_look(_look({"hangul": "Byeolbit Pocha"}))).contains("Hangul")
	assert_str(BarLook.validate_bar_look(_look({"hangul": "별"}))).contains("Hangul")  # one letter isn't a name
	assert_str(BarLook.validate_bar_look(_look({"hangul": "별빛 포차 별빛 포차 별빛"}))).contains("too long")


func test_a_bar_look_must_use_the_games_options() -> void:
	assert_str(BarLook.validate_bar_look(_look({"tarp": "purple"}))).contains("\"tarp\"")
	assert_str(BarLook.validate_bar_look(_look({"sign": "graffiti"}))).contains("\"sign\"")
	assert_str(BarLook.validate_bar_look(_look({"touches": ["disco ball"]}))).contains("isn't one of the touches")
	assert_str(BarLook.validate_bar_look(_look({"touches": []}))).contains("one or two")
	assert_str(BarLook.validate_bar_look(_look({"touches": ["radio", "plants", "photos"]}))).contains("one or two")
	assert_str(Text.problem_kind("\"tarp\" must be one of: orange, red")).is_equal("the bar's look")


func test_the_night_darkens_and_the_tent_glows() -> void:
	var dusk := NightRules.night_light(18 * 60)
	var midnight := NightRules.night_light(24 * 60)
	var late := NightRules.night_light(26 * 60 + 30)
	assert_float((dusk["sky"] as Color).get_luminance()).is_greater((midnight["sky"] as Color).get_luminance())
	assert_float(float(midnight["glow"])).is_greater(float(dusk["glow"]))
	assert_float(float(late["glow"])).is_less(float(midnight["glow"]))  # a little tired by the end
	var between := NightRules.night_light(18 * 60 + 45)  # changes gradually
	assert_float(float(between["glow"])).is_between(float(dusk["glow"]), float(NightRules.night_light(19 * 60 + 30)["glow"]))


func test_weather_kinds() -> void:
	assert_str(NightRules.weather_kind("heavy rain drumming on the tarp")).is_equal("rain")
	assert_str(NightRules.weather_kind("light drizzle")).is_equal("drizzle")
	assert_str(NightRules.weather_kind("the first snow of winter")).is_equal("snow")
	assert_str(NightRules.weather_kind("thick fog")).is_equal("fog")
	assert_str(NightRules.weather_kind("clear, bitterly cold air")).is_equal("cold")
	assert_str(NightRules.weather_kind("a muggy summer heat")).is_equal("muggy")
	assert_str(NightRules.weather_kind("a warm spring breeze")).is_equal("breeze")


func test_the_calendar_runs_through_the_seasons() -> void:
	assert_str(str(Seasons.date(0)["text"])).is_equal("1 January")
	assert_str(str(Seasons.date(318)["text"])).is_equal("15 November")
	assert_str(str(Seasons.date(364)["text"])).is_equal("31 December")
	assert_str(str(Seasons.date(59)["text"])).is_equal("1 March")
	assert_int(Seasons.day_of_year(318, 1)).is_equal(318)
	assert_int(Seasons.day_of_year(318, 48)).is_equal(0)  # (night 48 is new year's day)
	assert_str(Seasons.season(318)).is_equal("autumn")
	assert_str(Seasons.season(10)).is_equal("winter")
	assert_str(Seasons.season(100)).is_equal("spring")
	assert_str(Seasons.season(180)).is_equal("monsoon")  # (late June to late July)
	assert_str(Seasons.season(220)).is_equal("summer")
	assert_str(Seasons.season(340)).is_equal("winter")
	assert_str(Seasons.season_words(318)).is_equal("late autumn")
	assert_str(Seasons.season_words(340)).is_equal("early winter")
	assert_str(Seasons.season_words(10)).is_equal("midwinter")
	assert_str(Seasons.season_words(180)).contains("monsoon")
	# A winter runs from December into the new year.
	assert_int(Seasons.winter_number(318, 1)).is_equal(0)
	assert_int(Seasons.winter_number(318, 17)).is_equal(1)  # 1 December
	assert_int(Seasons.winter_number(318, 60)).is_equal(1)  # mid-January: the same winter
	assert_int(Seasons.today()).is_between(0, 364)


func test_the_weather_follows_on_through_the_seasons() -> void:
	# Every kind of weather reads as what it is.
	var kinds := {"monsoon downpour: heavy rain hammering the tarp": "rain", "a typhoon's edge: heavy rain and wind": "rain",
		"yellow dust hazing the streetlights": "fog", "freezing fog": "fog", "a raw, cold wind off the river": "cold",
		"snow falling steadily on the tarp": "snow", "cherry blossom petals on the breeze": "breeze", "a sticky, muggy night with thunder far off": "muggy",
		"crisp, clear autumn air": "", "a mild, clear evening": "", "a warm, clear night": "", "a cool breeze": "breeze"}
	for text in kinds:
		assert_str(NightRules.weather_kind(text)).override_failure_message(text).is_equal(kinds[text])
	# Only the season's, within their dates.
	var spring_texts: Array = Seasons.options(95).map(func(option): return option["text"])
	assert_array(spring_texts).contains(["cherry blossom petals on the breeze"])
	assert_array(Seasons.options(140).map(func(option): return option["text"])).not_contains(["cherry blossom petals on the breeze"])
	for roll in [0.0, 0.2, 0.5, 0.7, 0.99]:
		assert_bool(Seasons.options(318).map(func(option): return option["text"]).has(Seasons.next_weather(318, "", roll))).is_true()
	# The same again now and then, if it can be this season.
	assert_str(Seasons.next_weather(318, "thick fog", 0.1)).is_equal("thick fog")
	assert_str(Seasons.next_weather(318, "a muggy summer heat", 0.1)).is_not_equal("a muggy summer heat")
	# The first snow of each winter.
	var first_snows := 0
	var snows := 0
	for k in 100:
		var roll := k / 100.0
		if Seasons.next_weather(10, "", roll, false) == Seasons.FIRST_SNOW:
			first_snows += 1
		if Seasons.next_weather(10, "", roll, true).contains("snow"):
			snows += 1
			assert_str(Seasons.next_weather(10, "", roll, true)).is_not_equal(Seasons.FIRST_SNOW)
	assert_int(first_snows).is_greater(0).is_equal(snows)
	assert_str(Seasons.next_weather(10, Seasons.FIRST_SNOW, 0.1)).is_equal("snow falling steadily on the tarp")  # (only the once)
	assert_str(str(Captions.for_event("first_snow", {})["kind"])).is_equal("first_snow")
	# The season in the prompts.
	assert_str(Prompts.describe_moment({"day": "Wednesday", "time": "9:40pm", "weather": "thick fog", "date": "15 November, late autumn"})).starts_with("TONIGHT: Wednesday 15 November, late autumn, 9:40pm, with thick fog")
	assert_str(Prompts.describe_moment({"day": "Wednesday", "time": "9:40pm", "weather": "thick fog"})).starts_with("TONIGHT: Wednesday, 9:40pm")


func test_the_skyline_behind_the_tent() -> void:
	var city := Skyline.plan(1872.0, 42)
	assert_str(str(city)).is_equal(str(Skyline.plan(1872.0, 42)))  # each bar's own, the same every night
	assert_str(str(city)).is_not_equal(str(Skyline.plan(1872.0, 43)))
	var last: Dictionary = city[-1]
	assert_float(float(last["x"]) + float(last["width"])).is_greater_equal(1872.0)  # right across
	var kinds: Array = city.map(func(building): return building["kind"])
	assert_array(kinds).contains(["apt"])
	assert_int(kinds.count("tower")).is_less_equal(2)
	var numbers: Array = city.filter(func(building): return building["kind"] == "apt").map(func(building): return int(building["number"]))
	for k in range(1, numbers.size()):
		assert_int(numbers[k]).is_equal(numbers[k - 1] + 1)  # 101동, 102동, 103동...
	for building in city:
		for window in building["windows"]:
			assert_float(float(window["x"]) + Skyline.WINDOW.x).is_less_equal(float(building["width"]))
			assert_float(float(window["y"]) + Skyline.WINDOW.y).is_less_equal(float(building["height"]))
	# Windows go dark through the night.
	assert_float(Skyline.lit_share(18 * 60)).is_equal_approx(0.45, 0.001)
	assert_float(Skyline.lit_share(21 * 60)).is_greater(Skyline.lit_share(26 * 60))
	assert_float(Skyline.lit_share(26 * 60 + 30)).is_between(Skyline.lit_share(27 * 60), Skyline.lit_share(26 * 60))
	var at_nine := 0
	var at_two := 0
	for building in city:
		for window in building["windows"]:
			at_nine += 1 if Skyline.lit(window, 21 * 60) else 0
			at_two += 1 if Skyline.lit(window, 26 * 60) else 0
	assert_int(at_nine).is_greater(at_two * 3)
	assert_str(Skyline.block_label(103)).is_equal("103동")


func test_dishes_are_drawn_from_what_they_come_in() -> void:
	for item in Menu.ITEMS:
		var id := str(item["id"])
		var art: Dictionary = item.get("art", {})
		assert_bool(DishArt.VESSELS.has(str(art.get("vessel", "")))).override_failure_message("%s: no vessel" % id).is_true()
		if art.has("bits"):
			assert_array(DishArt.BITS).contains([art["bits"]])
		if art.has("garnish"):
			assert_array(DishArt.GARNISHES).contains([art["garnish"]])
		var box := DishArt.size(art)
		var drawn := DishArt.shapes(art, Color(str(item["color"])), id)
		assert_array(drawn).is_not_empty()
		for shape in drawn:
			var at: Vector2 = shape["pos"]
			var end: Vector2 = at + shape["size"]
			assert_bool(at.x >= 0 and at.y >= 0 and end.x <= box.x + 0.01 and end.y <= box.y + 0.01).override_failure_message("%s: %s is outside its %s box" % [id, str(shape), str(box)]).is_true()
		assert_str(str(drawn)).is_equal(str(DishArt.shapes(art, Color(str(item["color"])), id)))  # the same every time
	assert_str(str(DishArt.size({"vessel": "a wok"}))).is_equal(str(DishArt.VESSELS["bowl"]["size"]))  # (an unknown vessel's a bowl)
	assert_array(DishArt.shapes({"vessel": "a wok", "fill": "d8452f"}, Color.RED, "x")).is_not_empty()


func test_tent_shapes_and_colours_come_from_the_games_lists() -> void:
	var data := _look({"shape": "Scalloped", "tarp": "blue_stripes"})
	assert_str(BarLook.validate_bar_look(data)).is_empty()
	assert_str(str(data["shape"])).is_equal("scalloped")
	assert_str(BarLook.validate_bar_look(_look({"shape": "geodesic dome"}))).contains("\"shape\"")
	var old := _look()
	old.erase("shape")  # looks from before shapes are classic
	assert_str(BarLook.validate_bar_look(old)).is_empty()
	assert_str(str(old["shape"])).is_equal("classic")


func test_more_people_walk_past_in_the_evening_than_the_small_hours() -> void:
	assert_float(NightRules.stroll_gap(22 * 60, 0.5)).is_less(NightRules.stroll_gap(26 * 60, 0.5))
	assert_float(NightRules.stroll_gap(22 * 60, 0.5)).is_less(60.0 / NightRules.arrivals_per_hour(22 * 60))  # several for each customer
	assert_float(NightRules.stroll_gap(22 * 60, 0.0)).is_greater_equal(1.0)


func test_a_new_bar_is_offered_a_few_looks_and_must_pick_from_them() -> void:
	var offer := BarLook.look_offer()
	assert_int(offer["tarp"].size()).is_equal(BarLook.OFFERED_TARPS)
	assert_int(offer["shape"].size()).is_equal(BarLook.OFFERED_SHAPES)
	var limited := {"tarp": ["teal", "maroon"], "shape": ["awning"]}
	assert_str(BarLook.validate_bar_look(_look({"tarp": "teal", "shape": "awning"}), limited)).is_empty()
	assert_str(BarLook.validate_bar_look(_look({"tarp": "orange", "shape": "awning"}), limited)).contains("teal, maroon")
	assert_str(BarLook.validate_bar_look(_look({"tarp": "teal", "shape": "peaked"}), limited)).contains("\"shape\"")


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
		var look := Looks.pick_look(["woman", "man", "non-binary"][i % 3], Looks.pick_age_range(randf()), "")
		assert_bool(Looks.AGE_RANGES.has(look["age_range"])).is_true()
		assert_bool(Looks.HAIR_STYLES.has(look["hair"])).is_true()
		assert_bool(Looks.HAIR_COLOURS.has(look["hair_colour"])).is_true()
		assert_bool(Looks.CLOTHES.has(look["clothes"])).is_true()
		assert_bool(Looks.CLOTHES_COLOURS.has(look["colour"])).is_true()
		if look["clothes"] == "suit":
			assert_array(Looks.SUIT_COLOURS).contains([look["colour"]])
		if look["colour"] in ["beige", "black", "navy", "charcoal", "white", "cream", "camel"]:
			neutral += 1
	assert_int(neutral).is_greater(200)  # mostly beige and black (it's Seoul)


func test_looks_suit_the_weather_and_the_owner() -> void:
	for i in 200:
		assert_str(str(Looks.pick_look("man", "30s", "muggy")["clothes"])).is_not_equal("padded")
		assert_str(str(Looks.pick_look("woman", "30s", "snow")["clothes"])).is_not_equal("tshirt")
		var the_owner := Looks.pick_look("woman", Looks.pick_age_range(randf(), true), "", true)
		assert_array(["suit", "blazer", "trench", "scrubs"]).not_contains([the_owner["clothes"]])
		assert_bool(the_owner["apron"]).is_true()
		assert_array(["20s", "30s"]).not_contains([the_owner["age_range"]])
		assert_str(str(Looks.pick_look("man", "20s", "")["hair"])).is_not_equal("balding")
		assert_array(["grey", "white"]).not_contains([Looks.pick_look("woman", "20s", "")["hair_colour"]])


func test_ages_keep_to_the_games_range() -> void:
	var customer := {"age": 45, "job": "nurse", "mood": "tired", "reason": "A long shift.", "speech_style": "quiet", "appearance": "Scrubs."}
	var fits := customer.duplicate()
	assert_str(People.validate_customer_details(fits, "40s")).is_empty()
	assert_int(int(fits["age"])).is_equal(45)
	var too_old := customer.duplicate()
	assert_str(People.validate_customer_details(too_old, "20s")).is_empty()
	assert_int(int(too_old["age"])).is_equal(29)  # moved into the game's range, not rejected
	assert_str(People.validate_customer_details(customer.duplicate())).is_empty()  # any adult age
	var the_owner := _owner({"age": 52})
	assert_str(People.validate_owner(the_owner, "woman", "60s")).is_empty()
	assert_int(int(the_owner["age"])).is_equal(60)
	assert_str(People.validate_customer_details(_ages(15), "20s")).contains("15")  # under age is still rejected
	assert_str(Looks.age_range_of(58)).is_equal("50s")
	assert_str(Looks.age_range_of(80)).is_equal("70s")


func test_a_look_in_words() -> void:
	var look := {"age_range": "30s", "hair": "bob", "hair_colour": "black", "clothes": "trench", "colour": "beige", "glasses": true, "bag": "tote"}
	assert_str(Looks.look_text(look)).is_equal("in their thirties, with black hair in a bob and glasses, wearing a beige trench coat and carrying a tote bag")
	look.merge({"clothes": "suit", "colour": "navy", "glasses": false, "bag": "", "hair": "side_part"}, true)
	assert_str(Looks.look_text(look)).is_equal("in their thirties, with neatly side-parted black hair, wearing a navy suit and tie")
	var the_owner := {"age_range": "60s", "hair": "perm", "hair_colour": "grey", "clothes": "cardigan", "colour": "camel", "apron": true}
	assert_str(Looks.look_text(the_owner)).is_equal("in their sixties, with a short, tight greying perm, wearing a camel cardigan under an apron")


func _ages(age: int) -> Dictionary:
	return {"age": age, "job": "student", "mood": "giddy", "reason": "Exams are over.", "speech_style": "loud", "appearance": "A hoodie."}


func test_regression_spicy_rice_cakes_are_tteokbokki_not_rice() -> void:
	var ids: Array = Orders.mentions("I'll have a soju and the spicy rice cakes, please.", true).map(func(m): return m["id"])
	assert_array(ids).contains(["tteokbokki"])
	assert_array(ids).not_contains(["gonggibap"])
	var both: Array = Orders.mentions("The spicy rice cakes and a bowl of rice.", true).map(func(m): return m["id"])
	assert_array(both).contains(["tteokbokki", "gonggibap"])


func test_strangers_are_known_by_how_they_look() -> void:
	var look := {"clothes": "trench", "colour": "beige"}
	assert_str(Looks.seen_as({"gender": "woman", "look": look})).is_equal("the woman in the beige trench coat")
	assert_str(Looks.seen_as({"gender": "man"})).is_equal("the man next to them")


func test_names_in_hangul_are_checked_against_the_romanised_name() -> void:
	assert_str(Names.fit_hangul("Kim Ji-ho", "김지호")).is_equal("김지호")
	assert_str(Names.fit_hangul("Seo Yeon-woo", " 서연우 ")).is_equal("서연우")
	assert_str(Names.fit_hangul("Lee Min-ji", "이민지")).is_equal("이민지")
	assert_str(Names.fit_hangul("Jang Ji-Hyun", "장지현")).is_equal("장지현")
	assert_str(Names.fit_hangul("Kim Ji-ho", "박지호")).is_empty()  # the wrong family name
	assert_str(Names.fit_hangul("Kim Ji-ho", "김미호")).is_empty()  # "Ji" doesn't start with ㅁ
	assert_str(Names.fit_hangul("Kim Ji-ho", "Kim Ji-ho")).is_empty()  # not Hangul
	assert_str(Names.fit_hangul("Kim Ji-ho", "")).is_empty()
	assert_str(Names.fit_hangul("Nabi", "나비")).is_equal("나비")
	assert_str(Names.fit_hangul("Nabi", "고비")).is_empty()


func test_a_customer_name_keeps_its_hangul_only_if_it_fits() -> void:
	var good := {"name": "Kim Ji-ho", "hangul": "김지호", "gender": "woman"}
	assert_str(Names.validate_customer_name(good)).is_empty()
	assert_str(str(good["hangul"])).is_equal("김지호")
	var wrong := {"name": "Kim Ji-ho", "hangul": "박지호", "gender": "woman"}
	assert_str(Names.validate_customer_name(wrong)).is_empty()  # the name's still fine...
	assert_str(str(wrong["hangul"])).is_empty()  # ...but the wrong Hangul isn't shown


func test_long_lines_are_paged_for_speech_bubbles() -> void:
	assert_array(Array(Talk.bubble_pages("Evening, Ajumma."))).is_equal(["Evening, Ajumma."])
	var one := "I should warn you, the owner's recipes are a closely guarded secret, but I can tell you that her sundae is a game-changer."
	assert_int(Talk.bubble_pages(one).size()).is_equal(1)  # most lines fit in one bubble
	var long := one + " It's the one thing that keeps me coming back, even on the nights I swore I'd go straight home, and I've told nobody that, not even my sister."
	var pages := Talk.bubble_pages(long)
	assert_int(pages.size()).is_greater(1)
	for i in pages.size():
		assert_int(pages[i].length()).is_less_equal(Talk.BUBBLE_PAGE + 41)  # a short leftover may join the page before
		if i < pages.size() - 1:
			assert_str(pages[i]).ends_with("…")
	assert_str(" ".join(pages).replace("…", "")).contains("game-changer")
	assert_float(Talk.page_seconds("Hi.")).is_equal(1.8)


func test_regression_made_up_korean_is_rejected() -> void:
	var line := {"line": "Eotteoke haeyo, yukhae? Chamcha-eun naneun joa?"}
	assert_str(Talk.validate_line(line, "Kim Hye-ok", "Ajumma")).contains("made-up Korean")
	assert_str(Text.problem_kind("the line has made-up Korean words in it (x)")).is_equal("made-up Korean")
	# The odd known word, names, food and everyday English are all fine.
	assert_str(Talk.validate_line({"line": "Jeogiyo, is this seat taken? Geonbae, everyone!"}, "Kim Ji-ho", "")).is_empty()
	assert_str(Talk.validate_line({"line": "Seo Yeon-woo and Jeong Eun-ji said the tteokbokki here is the best in Seoul."}, "Kim Ji-ho", "", [], ["Seo Yeon-woo", "Jeong Eun-ji"])).is_empty()
	assert_str(Talk.validate_line({"line": "Some people just need someone to listen, and everyone needs a theory about love."}, "Kim Ji-ho", "")).is_empty()


func test_muggy_nights_have_few_cardigans() -> void:
	var cardigans := 0
	for i in 400:
		if Looks.pick_look("woman", "30s", "muggy")["clothes"] == "cardigan":
			cardigans += 1
	assert_int(cardigans).is_less(25)


func _memory(changes: Dictionary = {}) -> Dictionary:
	var data := {"owner_remembers": "Tired pharmacist; laughed at last.", "they_remember": "The owner fussed over her.",
		"job": "pharmacist", "family": "two kids", "home": "", "other": "", "night": "Enjoyed it", "towards_owner": "warmer"}
	data.merge(changes, true)
	return data


func test_a_memory_keeps_only_what_was_said() -> void:
	var data := _memory()
	assert_str(Memories.validate_memory(data, "i run the pharmacy on the corner, and my boss never stops")).is_empty()
	assert_str(str(data["night"])).is_equal("enjoyed")
	assert_str(str(data["towards_owner"])).is_equal("warmer")
	assert_str(str(data["job"])).is_equal("pharmacist")  # backed by "pharmacy"
	assert_str(str(data["family"])).is_empty()  # nobody said anything about kids: it doesn't stick
	assert_str(Memories.validate_memory(_memory({"night": "it was amazing"}), "")).contains("\"night\"")
	assert_str(Memories.validate_memory(_memory({"towards_owner": "in love"}), "")).contains("\"towards_owner\"")
	var long := "".lpad(Memories.MAX_MEMORY + 1, "a")
	assert_str(Memories.validate_memory(_memory({"owner_remembers": long}), "")).contains("too long")
	var none := _memory({"night": "didn't enjoy it", "towards_owner": "about the same", "job": "none"})
	assert_str(Memories.validate_memory(none, "pharmacy")).is_empty()
	assert_str(str(none["night"])).is_equal("didnt")
	assert_str(str(none["job"])).is_empty()


func test_last_time_comes_up_only_with_something_to_remember() -> void:
	for i in 50:
		assert_str(Talk.pick_owner_topic(randf(), false, "none")).is_not_equal("last_time")
	var asked := 0
	for i in 200:
		if Talk.pick_owner_topic(randf(), false, "none", "", true) == "last_time":
			asked += 1
	assert_int(asked).is_greater(20)


func _p(gender: String, age: int, the_owner: bool = false) -> Dictionary:
	return {"gender": gender, "age": age, "owner": the_owner}


func test_who_may_call_whom_what() -> void:
	var her25 := _p("woman", 25)
	var her30 := _p("woman", 30)
	var him32 := _p("man", 32)
	var him22 := _p("man", 22)
	var owner_her := _p("woman", 58, true)
	var owner_him := _p("man", 58, true)
	# Big brother and sister words: younger to older, the right genders, and only when close.
	assert_array(Address.allowed_terms(her25, him32, true)).contains(["oppa"])
	assert_array(Address.allowed_terms(her25, him32, false)).not_contains(["oppa"])  # not close yet
	assert_array(Address.allowed_terms(her30, him22, true)).not_contains(["oppa", "nuna"])  # he's younger
	assert_array(Address.allowed_terms(him22, him32, true)).contains(["hyung"])
	assert_array(Address.allowed_terms(him22, her25, true)).contains(["nuna"])
	assert_array(Address.allowed_terms(her25, her30, true)).contains(["eonni"])
	assert_array(Address.allowed_terms(him22, her25, true)).not_contains(["eonni", "oppa", "hyung"])
	assert_array(Address.allowed_terms(_p("non-binary", 22), him32, true)).not_contains(["oppa", "hyung"])
	# The owner.
	assert_array(Address.allowed_terms(her25, owner_her, false)).contains(["imo", "ajumma", "sajangnim"])
	assert_array(Address.allowed_terms(her25, owner_him, false)).contains(["samchon", "ajusshi"])
	assert_array(Address.allowed_terms(her25, owner_him, false)).not_contains(["imo", "ajumma"])
	assert_array(Address.allowed_terms(_p("man", 70), owner_her, false)).not_contains(["imo"])  # older than her
	assert_array(Address.allowed_terms(_p("man", 70), owner_her, false)).contains(["sajangnim"])
	assert_array(Address.allowed_terms(her25, owner_her, true)).not_contains(["eonni"])  # never to the owner
	# Strangers, and the owner to customers.
	assert_array(Address.allowed_terms(her25, her30, false)).not_contains(["ajumma"])  # an insult at thirty
	assert_array(Address.allowed_terms(her25, _p("woman", 48), false)).contains(["ajumma"])
	assert_array(Address.allowed_terms(owner_her, him22, false)).contains(["haksaeng"])
	assert_array(Address.allowed_terms(owner_her, him32, false)).not_contains(["haksaeng", "sajangnim"])
	assert_array(Address.allowed_terms(owner_her, _p("man", 75), false)).contains(["seonsaengnim"])


func test_the_must_never_rules_over_the_whole_grid() -> void:
	for speaker_gender in ["woman", "man", "non-binary"]:
		for listener_gender in ["woman", "man", "non-binary"]:
			for ages in [[22, 35], [35, 22], [30, 30], [45, 60]]:
				for close in [true, false]:
					for to_owner in [true, false]:
						var speaker := _p(speaker_gender, ages[0])
						var listener := _p(listener_gender, ages[1], to_owner)
						var allowed := Address.allowed_terms(speaker, listener, close)
						var context := "%s %d to %s %d, close %s, owner %s: %s" % [speaker_gender, ages[0], listener_gender, ages[1], close, to_owner, allowed]
						for sibling in ["oppa", "hyung", "eonni", "nuna"]:
							if allowed.has(sibling):
								assert_bool(close and not to_owner and ages[1] > ages[0]).override_failure_message(context).is_true()
						if allowed.has("ajumma"):
							assert_bool(listener_gender == "woman" and ages[1] >= Address.MIDDLE_AGED).override_failure_message(context).is_true()
						if allowed.has("imo") or allowed.has("samchon"):
							assert_bool(to_owner and ages[1] > ages[0]).override_failure_message(context).is_true()
						if allowed.has("oppa") or allowed.has("hyung"):
							assert_str(listener_gender).override_failure_message(context).is_equal("man")
						if allowed.has("eonni") or allowed.has("nuna"):
							assert_str(listener_gender).override_failure_message(context).is_equal("woman")


func test_lines_that_break_the_address_rules_are_rejected() -> void:
	var not_close := {"speaker": _p("woman", 25), "listener": _p("woman", 30), "close": false, "listener_name": "Han Seol"}
	assert_str(Talk.validate_line({"line": "Eonni, try the tteokbokki."}, "Kim Ji-ho", "", [], [], {}, not_close)).contains("the line calls Han Seol \"eonni\"")
	assert_str(Text.problem_kind("the line calls Han Seol \"eonni\", but...")).is_equal("address rules")
	var close := not_close.duplicate()
	close["close"] = true
	assert_str(Talk.validate_line({"line": "Unni, try the tteokbokki."}, "Kim Ji-ho", "", [], [], {}, close)).is_empty()
	var to_owner := {"speaker": _p("woman", 25), "listener": _p("man", 58, true), "close": false, "listener_name": "Kim Sung-ho"}
	assert_str(Talk.validate_line({"line": "Ajumma, one more soju."}, "Kim Ji-ho", "", [], [], {}, to_owner)).contains("ajumma")
	assert_str(Talk.validate_line({"line": "Samchon, one more soju."}, "Kim Ji-ho", "", [], [], {}, to_owner)).is_empty()
	# A name isn't a term.
	var to_him := {"speaker": _p("woman", 25), "listener": _p("man", 22), "close": false, "listener_name": "Lee Hyung-jun"}
	assert_str(Talk.validate_line({"line": "Nice to meet you, Hyung-jun."}, "Kim Ji-ho", "", [], ["Lee Hyung-jun"], {}, to_him)).is_empty()


func test_sibling_terms_and_colours() -> void:
	assert_str(Address.sibling_term(_p("woman", 25), _p("woman", 30))).is_equal("eonni")
	assert_str(Address.sibling_term(_p("man", 25), _p("woman", 30))).is_equal("nuna")
	assert_str(Address.sibling_term(_p("woman", 30), _p("woman", 30))).is_empty()  # the same age
	assert_str(Address.sibling_term(_p("woman", 30), _p("woman", 25))).is_empty()  # she's the older one
	var coloured := Glossary.explain("Imo, one more! Thanks, Hyung-jun.", ["Lee Hyung-jun"])
	assert_str(coloured).contains("[color=#%s]Imo[/color]" % Address.WARMTH_COLOURS["family"])
	assert_str(coloured).contains("auntie")
	assert_str(coloured).contains("Hyung-jun.")  # a name, left alone
	assert_str(coloured).not_contains("[color=#%s]Hyung" % Address.WARMTH_COLOURS["close"])
	assert_str(Address.address_text("Kim Ji-ho", _p("woman", 25), "Park Mi-sook", _p("woman", 58, true), false)).contains("Imo")


func test_served_moments_are_situations_for_real_menu_items() -> void:
	for id in Talk.SERVED_MOMENTS:
		assert_dict(Menu.find(id)).is_not_empty()  # only things on the menu
		for moment in Talk.SERVED_MOMENTS[id]:
			assert_str(str(moment)).not_contains("\"")  # never a phrase for the AI to repeat
	assert_str(Talk.served_moment(["somaek"], 0.9, 0.0)).is_empty()  # now and then, not every time
	assert_str(Talk.served_moment(["somaek"], 0.0, 0.0)).contains("soju dropped into the beer")
	assert_str(Talk.served_moment(["dakgalbi"], 0.0, 0.0)).contains("ssam")
	assert_bool(Talk.FOOD_MOMENTS.has(Talk.served_moment(["dakgalbi"], 0.0, 0.9))).is_true()  # sometimes a general food one
	assert_bool(Talk.SERVED_MOMENTS["soju"].has(Talk.served_moment(["soju"], 0.0, 0.9))).is_true()  # drinks: never a food one
	assert_str(Talk.served_moment(["gyeran_mari"], 0.0, 0.0)).is_not_empty()  # no special one: a general food moment
	assert_str(Talk.served_moment(["gonggibap", "beer"], 0.0, 0.0)).is_not_empty()


func test_sharing_moments_only_say_what_is_true() -> void:
	assert_str(Talk.sharing_moment("Kim Ji-ho", "Lee Min-jun", true, true, true, 0.9, 0.0)).is_empty()
	assert_str(Talk.sharing_moment("Kim Ji-ho", "Lee Min-jun", false, false, false, 0.0, 0.0)).is_empty()  # nothing true to offer
	assert_str(Talk.sharing_moment("Kim Ji-ho", "Lee Min-jun", false, true, false, 0.0, 0.5)).is_equal(
		"Kim Ji-ho has more food on the table than Lee Min-jun has.")
	assert_str(Talk.sharing_moment("Kim Ji-ho", "Lee Min-jun", false, false, true, 0.0, 0.5)).contains("top up Lee Min-jun's")
	assert_str(Talk.sharing_moment("Kim Ji-ho", "Lee Min-jun", true, false, false, 0.0, 0.5)).contains("feed each other a bite")
	for which in [0.0, 0.4, 0.8]:  # strangers never get the close one
		assert_str(Talk.sharing_moment("Kim Ji-ho", "Lee Min-jun", false, true, true, 0.0, which)).not_contains("feed each other")


func test_korean_words_are_explained_once() -> void:
	var line := Glossary.explain("Jjan! Somaek and tteokbokki, Imo. Aigoo, ramen with banchan, Mr Jeong? Beer too.", ["Jeong Min-ho"])
	for word in ["Jjan", "Somaek", "tteokbokki", "Imo", "Aigoo", "ramen", "banchan"]:
		assert_str(line).contains("]%s[/color][/hint]" % word)
	assert_str(line).contains("떡볶이 Tteokbokki: spicy rice cakes")  # the menu's own Hangul and description
	assert_str(line).contains("[color=#%s]Imo" % Address.WARMTH_COLOURS["family"])  # terms keep their warmth colours
	assert_str(line).contains("Mr Jeong?")  # a person, not a word
	assert_str(line).contains(" Beer too.")  # not a Korean word
	# Somaek's tip mentions soju: hinted once, never a hint inside a hint.
	assert_int(line.count("[hint=")).is_equal(7)
	var label: RichTextLabel = auto_free(RichTextLabel.new())
	label.bbcode_enabled = true
	label.text = line
	assert_str(label.get_parsed_text()).is_equal("Jjan! Somaek and tteokbokki, Imo. Aigoo, ramen with banchan, Mr Jeong? Beer too.")
	assert_str(Glossary.explain("They were fighting about the sundae.")).contains("]sundae[/color]")
	assert_str(Glossary.explain("They were fighting about it.")).is_equal("They were fighting about it.")  # English stays English
	for item in Menu.ITEMS:
		assert_str(str(item.get("hangul", ""))).is_not_empty()


func test_rain_gear_varies_and_some_people_run_for_it() -> void:
	assert_dict(Looks.rain_gear("clear", 0.0, 0.0, 0.0)).is_empty()
	assert_bool(bool(Looks.rain_gear("rain", 0.0, 0.5, 0.5)["umbrella"])).is_false()  # no umbrella: rare
	assert_bool(bool(Looks.rain_gear("rain", 0.5, 0.5, 0.5)["umbrella"])).is_true()
	assert_float(float(Looks.NO_UMBRELLA_CHANCE["rain"])).is_less(0.15)
	var shapes := {}
	for i in 20:
		var gear := Looks.rain_gear("snow", 0.9, i / 20.0, i / 20.0)
		shapes[gear["shape"]] = true
		assert_float(float(gear["size"])).is_between(0.7, 1.15)  # nothing major
		assert_float(absf(float(gear["tilt"]))).is_less_equal(0.12)
	assert_int(shapes.size()).is_equal(Looks.UMBRELLA_SHAPES.size())  # every shape turns up
	var total := 0.0
	for shape in Looks.UMBRELLA_SHAPES:
		total += float(Looks.UMBRELLA_SHAPES[shape])
	assert_float(total).is_equal_approx(1.0, 0.001)


func test_text_helpers_tidy_what_the_ai_sends() -> void:
	assert_str(Text.tidy_text(["  kimchi", "radish  "])).is_equal("kimchi, radish")  # a list where text was wanted
	assert_str(Text.tidy_text("  plain  ")).is_equal("plain")
	assert_str(Text.tidy_text(42)).is_equal("42")
	for quoted in ["\"Hello\"", "“Hello”", "'Hello'", "\" Hello \""]:
		assert_str(Text.unquote(quoted)).is_equal("Hello")
	assert_str(Text.unquote("\"Hello")).is_equal("\"Hello")  # only a matching pair comes off
	assert_str(Text.unquote("\"")).is_equal("\"")
	assert_str(Text.sentence_case("light drizzle")).is_equal("Light drizzle")
	assert_str(Text.sentence_case("")).is_empty()
	assert_str(Text.as_sentence(" a messy bob ")).is_equal("A messy bob.")
	assert_str(Text.as_sentence("Really?")).is_equal("Really?")
	assert_array(Array(Text.words("Gruff-but-soft Ajumma!"))).is_equal(["gruff", "but", "soft", "ajumma"])
	assert_array(Text.numbers_in("₩412,000 for 3 bottles, at 2am")).is_equal(["412000", "3", "2"])
	assert_array(Text.numbers_in("no numbers here")).is_empty()


func test_wrap_breaks_long_text_at_spaces() -> void:
	assert_str(Text.wrap("Mood: anxious about tomorrow's big presentation at work", 20)).is_equal("Mood: anxious about\ntomorrow's big\npresentation at work")
	assert_str(Text.wrap("short", 20)).is_equal("short")
	assert_str(Text.wrap("averyveryverylongword here", 10)).is_equal("averyveryverylongword\nhere")  # (a long word gets its own line)
	assert_str(Text.shorten("Worried about her sister's operation, and about the bills", 30)).is_equal("Worried about her sister's…")
	assert_str(Text.shorten("From: Busan", 30)).is_equal("From: Busan")


func test_check_fields_wants_every_field_with_something_in_it() -> void:
	assert_str(Text.check_fields("not a dict", ["name"])).is_equal("it wasn't a JSON object")
	assert_str(Text.check_fields({"name": "Kim"}, ["name", "job"])).is_equal("it left out \"job\"")
	assert_str(Text.check_fields({"name": "   "}, ["name"])).is_equal("\"name\" was empty")
	var data := {"name": "  Kim Ji-ho ", "likes": ["soju", "rain"], "age": 0}
	assert_str(Text.check_fields(data, ["name", "likes", "age"])).is_empty()  # (age: a number, not checked as text)
	assert_str(str(data["name"])).is_equal("Kim Ji-ho")  # tidied in place
	assert_str(str(data["likes"])).is_equal("soju, rain")


func test_pick_weighted_follows_the_weights_and_skips() -> void:
	var weights := {"a": 1.0, "b": 3.0, "c": 0.0}
	assert_str(Text.pick_weighted(weights, 0.0, "")).is_equal("a")
	assert_str(Text.pick_weighted(weights, 0.2, "")).is_equal("a")
	assert_str(Text.pick_weighted(weights, 0.3, "")).is_equal("b")
	assert_str(Text.pick_weighted(weights, 1.0, "")).is_equal("b")  # (a roll of 1 still lands)
	assert_str(Text.pick_weighted(weights, 0.0, "a")).is_equal("b")  # skipped: never picked
	for roll in [0.0, 0.5, 0.99]:
		assert_str(Text.pick_weighted(weights, roll, "")).is_not_equal("c")  # no weight, never picked


func test_street_company_and_phones() -> void:
	assert_int(Looks.street_company(0.0)).is_equal(1)
	assert_int(Looks.street_company(0.7)).is_equal(2)
	assert_int(Looks.street_company(0.95)).is_equal(3)
	assert_int(Looks.street_company(1.0)).is_equal(1)
	assert_bool(Looks.on_phone(true, false, 0.3)).is_true()  # plenty on their own are
	assert_bool(Looks.on_phone(false, false, 0.3)).is_false()  # fewer with friends
	assert_bool(Looks.on_phone(true, true, 0.0)).is_false()  # nobody running for it
	assert_float(float(Looks.PHONE_CHANCE["together"])).is_less(float(Looks.PHONE_CHANCE["alone"]))


func test_order_and_opener_situations_only_say_what_is_true() -> void:
	for moment in Talk.ORDER_MOMENTS + Talk.OPENER_MOMENTS:
		assert_str(str(moment["text"])).not_contains("\"")  # never a phrase for the AI to repeat
		assert_bool(["any", "usual", "first", "late", "regular", "rain"].has(str(moment["when"]))).is_true()
	assert_str(Talk.order_moment(false, false, false, 0.9, 0.0)).is_empty()  # now and then, not always
	for i in 20:
		var plain := Talk.order_moment(false, false, false, 0.0, i / 20.0)
		assert_str(plain).is_not_empty()
		assert_str(plain).not_contains("usual")  # no usual: never "reaching for it"
		assert_str(plain).not_contains("first time")
		assert_str(plain).not_contains("late")
		var opener := Talk.opener_moment(false, false, false, false, 0.0, i / 20.0)
		assert_str(opener).not_contains("wet")
		assert_str(opener).not_contains("remember")
	assert_str(Talk.order_moment(true, false, false, 0.0, 0.99)).contains("usual")  # (the last that fits)
	assert_str(Talk.order_moment(false, true, true, 0.0, 0.99)).contains("late")
	assert_str(Talk.opener_moment(true, false, false, false, 0.0, 0.99)).contains("remember")
	assert_float(Talk.ORDER_MOMENT_CHANCE).is_less_equal(0.5)  # the AI's own way stays in the mix


func test_specials_follow_the_weather() -> void:
	assert_array(Orders.pick_specials("rain", 0.5, 0.9)).is_equal(["pajeon", "makgeolli"])  # rain: always
	assert_array(Orders.pick_specials("drizzle", 0.0, 0.0)).is_equal(["pajeon", "makgeolli"])
	for weather in Orders.SPECIAL_DISHES:
		for roll in [0.0, 0.5, 0.99]:
			var specials := Orders.pick_specials(weather, roll, roll)
			assert_int(specials.size()).is_between(1, 2)
			assert_str(str(Menu.find(str(specials[0])).get("kind", ""))).is_equal("food")
			if specials.size() == 2:
				assert_str(str(Menu.find(str(specials[1])).get("kind", ""))).is_equal("drink")
			for id in specials:
				assert_bool(bool(Menu.find(str(id)).get("extra_only", false))).is_false()  # orderable from the start
	assert_int(Orders.pick_specials("snow", 0.0, 0.9).size()).is_equal(1)  # a drink only now and then


func test_cravings_only_say_what_is_true() -> void:
	assert_str(Talk.craving("", false, false, 0.9, 0.0)).is_empty()  # now and then
	for i in 20:
		var plain := Talk.craving("", false, false, 0.0, i / 20.0)
		assert_str(plain).is_not_empty()
		for not_true in ["chilled", "Rain", "too warm", "share", "day they've had", "comfort"]:
			assert_str(plain).not_contains(not_true)
	assert_str(Talk.craving("rain", false, false, 0.0, 0.99)).contains("pajeon and makgeolli")
	assert_str(Talk.craving("snow", false, false, 0.0, 0.99)).contains("chilled")
	assert_str(Talk.craving("", false, true, 0.0, 0.99)).contains("share")
	assert_str(Talk.craving("", true, false, 0.0, 0.99)).contains("comfort")
	for each in Talk.CRAVINGS:
		assert_str(str(each["text"])).not_contains("\"")


func test_the_diary_may_mention_tonights_specials() -> void:
	var facts := {"people": [], "ordered": ["soju"], "specials": ["pajeon", "makgeolli"], "customers": 0, "takings": "₩0", "owner": "Park Mi-sook"}
	var problem := Story.validate_diary({"entry": "Rain all night, and I had the pajeon ready for anyone who wanted it. Nobody did. Still, the soju went, and the tarp held up fine until close."}, facts)
	assert_str(problem).not_contains("nobody ordered")
	assert_str(Prompts.diary_facts_text(facts)).contains("Tonight's specials: Pajeon and Makgeolli.")


func test_people_get_moments_to_talk_to_the_cat() -> void:
	assert_str(CatRules.cat_moment("Garae", "lap", 0.9)).is_empty()  # now and then
	assert_str(CatRules.cat_moment("Garae", "street", 0.0)).is_empty()  # it's not here
	for spot in CatRules.CAT_MOMENTS:
		var moment := CatRules.cat_moment("Garae", spot, 0.0)
		assert_str(moment).starts_with("Garae ")
		assert_str(moment).not_contains("\"")  # a situation, never a line
	assert_bool(CatRules.owner_spot("counter")).is_true()  # the owner's to deal with
	assert_bool(CatRules.owner_spot("lap")).is_false()  # the customer it's with
	assert_bool(Talk.hint_taken("cat", "Get down from there, you!")).is_true()
	assert_bool(Talk.hint_taken("cat", "Hello, Garae.", ["garae"])).is_true()  # its name counts
	assert_bool(Talk.hint_taken("cat", "Another soju, please.", ["garae"])).is_false()


func test_short_made_up_korean_is_caught_and_real_korean_isnt() -> void:
	# From a real night: a verb ending no English word has, on a made-up word.
	assert_array(Talk.romanised_korean("Banchan na, makgeolli haetjuseyo? Not eating?")).contains(["haetjuseyo"])
	# Real Korean the glossary knows is fine, however it ends.
	for line in ["Annyeonghaseyo, Imo!", "Gomawoyo, really.", "Gwaenchana? You look tired.", "Mianhaeyo, I'm late.", "Kamsahamnida!"]:
		assert_array(Talk.romanised_korean(line)).override_failure_message(line).is_empty()
	# English that ends in "yo" or has "eo" in it is fine too.
	assert_array(Talk.romanised_korean("I flew in from Tokyo, so extra mayo on everything.")).is_empty()
	assert_array(Talk.romanised_korean("Someone at the rodeo, of all people.")).is_empty()
	# (Still missed: a lone made-up word with no telltale ending, "Mandeulso, go na?".)


func test_dishes_not_on_the_menu_cant_be_served_here() -> void:
	assert_str(Talk.off_menu_here("My friend ordered the bibimbap, said it's a game-changer.")).is_equal("bibimbap")
	assert_str(Talk.off_menu_here("Is the bulgogi good tonight?")).is_equal("bulgogi")
	assert_str(Talk.off_menu_here("Your japchae smells amazing, Imo.")).is_equal("japchae")
	# Somewhere else's, or someone's cooking at home: fine.
	assert_str(Talk.off_menu_here("My mum's kimchi jjigae is the best thing in the world.")).is_empty()
	assert_str(Talk.off_menu_here("I had bibimbap at my desk for lunch.")).is_empty()
	assert_str(Talk.off_menu_here("Mandu's asleep by the stove again.")).is_empty()  # (a cat's name)
	assert_str(Talk.validate_line({"line": "Can I get the bibimbap?"}, "Kim Ji-ho", "")).contains("isn't on the menu")
	assert_str(Text.problem_kind("the line talks about bibimbap as if it's served here, but it isn't on the menu")).is_equal("not on the menu")


func test_real_brands_are_never_named() -> void:
	# Mix coffee is fine; the brand isn't (see CONCEPT.md, "Real people, brands and shows").
	assert_str(Talk.real_brand("This tteokbokki's as sweet as Maxim coffee!")).is_equal("maxim")
	assert_str(Talk.real_brand("Grab me a Choco Pie from the convenience store.")).is_equal("choco pie")
	assert_str(Talk.real_brand("I'll message you on KakaoTalk.")).is_equal("kakaotalk")
	assert_str(Talk.real_brand("Sweet as vending-machine mix coffee, this.")).is_empty()
	assert_str(Talk.real_brand("The green bottle, and banana milk for the walk home.")).is_empty()
	assert_str(Talk.real_brand("Back at eleven, Imo. Look, you can see Orion tonight.")).is_empty()  # (not brands)
	assert_str(Talk.validate_line({"line": "Sweet as Maxim coffee, Imo!"}, "Kim Ji-ho", "")).contains("real brand")
	assert_str(Text.problem_kind("the line names a real brand (maxim)")).is_equal("real brands")
	assert_str(Captions.validate_reaction({"size": 4, "mood": "funny", "who": "Kim Ji-ho", "caption": "SWEETER THAN MAXIM"}, ["Kim Ji-ho"])).contains("real brand")
	assert_str(Prompts.STYLE_GUIDE).contains("Never use a real person, brand")


func test_the_moment_says_its_tonights_only_weather() -> void:
	assert_str(Prompts.describe_moment({"day": "Friday", "time": "9:12pm", "weather": "light drizzle"})).contains("light drizzle (tonight's only weather")


func test_a_greedy_cat_steals_fish_cakes() -> void:
	assert_bool(CatRules.steals("greedy", true, 0.2)).is_true()
	assert_bool(CatRules.steals("greedy", false, 0.0)).is_false()  # nothing to steal
	assert_bool(CatRules.steals("lazy", true, 0.0)).is_false()  # can't be bothered
	assert_bool(CatRules.steals("curious", true, 0.5)).is_false()  # only once in a while
	var caption := Captions.for_event("cat_stole", {"cat": "Garae", "name": "Kim Ji-ho"})
	assert_str(str(caption["kind"])).is_equal("cat_thief")
	assert_bool(bool(Captions.CAPTIONS["cat_thief"]["emergency"])).is_true()  # the red light, for a fish cake
	var facts := Story.diary_facts([{"kind": "cat_stole", "at": 1300, "cat": "Garae", "name": "Kim Ji-ho"}], {"cat": "Garae"})
	assert_array(facts["cat_thefts"]).is_equal(["Kim Ji-ho"])
	assert_str(Prompts.diary_facts_text(facts)).contains("Garae, the cat, stole an odeng skewer off Kim Ji-ho's plate")


func test_closing_early_goes_in_the_diary() -> void:
	var facts := Story.diary_facts([], {"day": "Friday", "weather": "rain", "owner": "Park Mi-sook", "customers": 0, "takings": 0, "closed_early": "11:42pm"})
	assert_str(str(facts["closed_early"])).is_equal("11:42pm")
	assert_str(Prompts.diary_facts_text(facts)).contains("The owner closed up early, at 11:42pm.")
	assert_str(Story.diary_stamp(facts)).is_equal("early")
	var stitched := Story.stitched_diary(facts)
	assert_str(stitched).contains("I closed up early, at 11:42pm.")
	assert_str(Story.validate_diary({"entry": stitched}, facts)).is_empty()  # (the time's in the facts, so its numbers are allowed)
	var asked := str(Prompts.diary_messages({"name": "Park Mi-sook", "hangul": "박미숙", "age": 61, "gender": "woman", "title": "Ajumma", "archetype": "gruff-but-soft ajumma", "appearance": "An apron.", "personality": "blunt", "speech_style": "blunt", "secret": "Once sang trot."}, facts)[1]["content"])
	assert_str(asked).contains("It's 11:42pm and the tarp's down.")
	assert_str(asked).contains("Say why, in a sentence, in their own words")
	var usual := str(Prompts.diary_messages({"name": "Park Mi-sook", "hangul": "박미숙", "age": 61, "gender": "woman", "title": "Ajumma", "archetype": "gruff-but-soft ajumma", "appearance": "An apron.", "personality": "blunt", "speech_style": "blunt", "secret": "Once sang trot."}, Story.diary_facts([], {"owner": "Park Mi-sook"}))[1]["content"])
	assert_str(usual).contains("It's 3am")
	assert_str(usual).not_contains("closed up early")
	assert_str(str(Captions.for_event("closed_early", {})["kind"])).is_equal("closing_early")


func test_the_owner_says_why_they_are_closing_early() -> void:
	var the_owner := {"name": "Park Mi-sook", "hangul": "박미숙", "age": 61, "gender": "woman", "title": "Ajumma", "archetype": "gruff-but-soft ajumma", "appearance": "An apron.", "personality": "blunt", "speech_style": "blunt", "secret": "Once sang trot."}
	# The prompt: who's there to tell, and a reason of their own.
	var asked := str(Prompts.closing_messages(the_owner, {"time": "11:42pm", "weather": "Heavy rain", "seated": ["Kim Ji-ho"], "customers": 3})[1]["content"])
	assert_str(asked).contains("It's 11:42pm, Heavy rain, and 3 customers").contains("(Kim Ji-ho)").contains("\"caption\"")
	assert_str(str(Prompts.closing_messages(the_owner, {"time": "9:10pm"})[1]["content"])).contains("the empty stools")
	# Checked like any line of theirs, with a short caption.
	var names := ["Park Mi-sook", "Kim Ji-ho"]
	var good := {"line": "My knees have had it. Take your time, Ji-ho, but nobody else tonight.", "caption": "the knees have spoken"}
	assert_str(Story.validate_closing(good, "Park Mi-sook", "Ajumma", names)).is_empty()
	assert_str(str(good["caption"])).is_equal("THE KNEES HAVE SPOKEN")  # (in capitals, for the TV)
	assert_str(Story.validate_closing({"line": "My knees have had it."}, "Park Mi-sook", "Ajumma", names)).contains("caption")
	assert_str(Story.validate_closing({"line": "My knees have had it.", "caption": "KNEES"}, "Park Mi-sook", "Ajumma", names)).contains("too short")
	assert_str(Story.validate_closing({"line": "My knees have had it.", "caption": "THE KNEES HAVE SPOKEN AND THEY ARE VERY TIRED"}, "Park Mi-sook", "Ajumma", names)).contains("too long")
	assert_str(Story.validate_closing({"line": "My knees have had it.", "caption": "JI-HO STAYS LATE"}, "Park Mi-sook", "Ajumma", names)).contains("names")
	assert_str(Story.validate_closing({"line": "My knees have had it.", "caption": "MI-SOOK CALLS IT"}, "Park Mi-sook", "Ajumma", names)).is_empty()
	assert_str(Story.validate_closing({"line": "", "caption": "THE KNEES HAVE SPOKEN"}, "Park Mi-sook", "Ajumma", names)).is_not_empty()
	# The game's own reasons pass the same checks, and fit the weather (about half the time).
	for kind in Story.CLOSING_REASONS:
		for reason in Story.CLOSING_REASONS[kind]:
			var copy: Dictionary = reason.duplicate()
			assert_str(Story.validate_closing(copy, "Park Mi-sook", "Ajumma", names)).override_failure_message(str(reason)).is_empty()
	assert_bool(Story.CLOSING_REASONS["rain"].has(Story.closing_reason("drizzle", 0.1))).is_true()
	assert_bool(Story.CLOSING_REASONS["any"].has(Story.closing_reason("drizzle", 0.9))).is_true()
	assert_bool(Story.CLOSING_REASONS["any"].has(Story.closing_reason("fog", 0.1))).is_true()
	# On TV, with the reason as the caption, never held back.
	var caption := Captions.for_event("closed_early", {"reason": "THE KNEES HAVE SPOKEN"})
	assert_str(str(caption["kind"])).is_equal("closing_reason")
	assert_str(Captions.caption_words("closing_reason", caption["fill"], 0.0)["english"]).is_equal("THE KNEES HAVE SPOKEN")
	assert_bool(Captions.CAPTIONS["closing_reason"]["always"]).is_true()
	for k in 10:  # (the reason whenever there is one; the plain words only without)
		assert_str(Captions.caption_words("closing_reason", caption["fill"], k / 10.0)["english"]).is_equal("THE KNEES HAVE SPOKEN")
	assert_str(Captions.caption_words("closing_reason", {}, 0.0)["english"]).is_equal("CLOSING EARLY!")
	# And the diary gives the same reason.
	var facts := Story.diary_facts([], {"owner": "Park Mi-sook", "closed_early": "11:42pm", "closed_said": "My knees have had it."})
	assert_str(Prompts.diary_facts_text(facts)).contains("The owner closed up early, at 11:42pm, saying: \"My knees have had it.\"")
	assert_str(str(Prompts.diary_messages(the_owner, facts)[1]["content"])).contains("told the counter why: \"My knees have had it.\"").contains("(the same reason)")


func test_hover_tips_never_break_their_tag() -> void:
	# "ma'am" in ajumma's tip showed the whole tag as raw text in the transcript.
	var coloured := Glossary.explain("Thanks, Ajumma. Seonsaengnim, you too.")
	var tip_parts := coloured.split("[hint=")
	for part in tip_parts.slice(1):
		var tip := part.split("]")[0]
		assert_str(tip).not_contains("'")
		assert_str(tip).not_contains("\"")
	var label: RichTextLabel = auto_free(RichTextLabel.new())
	label.bbcode_enabled = true
	label.text = coloured
	assert_str(label.get_parsed_text()).is_equal("Thanks, Ajumma. Seonsaengnim, you too.")
	label.text = Text.hint("She's a nurse [night 2]\nsays \"hi\"", "[b]Kim Ji-ho[/b]")
	assert_str(label.get_parsed_text()).is_equal("Kim Ji-ho")
	# A long tip's wrapped, like every hover, and still a hint.
	var long_tip := "Grew up in Busan, moved up for work, and still goes home every Chuseok to help her mum at the market stall."
	label.text = Text.hint(long_tip, "Kim Ji-ho")
	assert_str(label.get_parsed_text()).is_equal("Kim Ji-ho")
	assert_str(Text.hint(long_tip, "x")).contains("\n")


func test_orders_get_what_was_asked_for() -> void:
	# Food the line never asks for is taken off (the line wins), if the order still keeps the rules.
	var quiet := {"items": ["soju", "gonggibap", "gyeran_mari"], "line": "Ajumma, just a quiet soju and some rice, please."}
	assert_str(Orders.validate_order(quiet)).is_empty()
	assert_array(quiet["items"]).contains_exactly(["soju", "gonggibap"])
	assert_int(int(quiet["dropped_unsaid"])).is_equal(1)
	var thirsty := {"items": ["beer", "soju", "tteokbokki"], "line": "Ajumma, one beer and the tteokbokki, please."}
	assert_str(Orders.validate_order(thirsty, 1, 2)).is_empty()
	assert_array(thirsty["items"]).contains_exactly(["beer", "tteokbokki"])
	# Not when it can't go (an order needs a food), or when the choosing's left to the owner.
	var lonely := {"items": ["soju", "odeng"], "line": "Ajumma, a soju, please."}
	assert_str(Orders.validate_order(lonely)).is_empty()
	assert_array(lonely["items"]).contains_exactly(["soju", "odeng"])
	var good := {"items": ["soju", "pajeon"], "line": "Ajumma, what's good tonight?"}
	assert_str(Orders.validate_order(good)).is_empty()
	assert_array(good["items"]).contains_exactly(["soju", "pajeon"])
	var bottle := {"items": ["soju", "tteokbokki"], "line": "A bottle and the tteokbokki, Imo."}
	assert_str(Orders.validate_order(bottle)).is_empty()
	assert_array(bottle["items"]).contains_exactly(["soju", "tteokbokki"])  # (a bottle is a drink)
	# The menu's descriptions are its other names: the chicken asked for isn't sundae.
	var swapped := {"items": ["somaek", "sundae", "tteokbokki"], "line": "I'm starving: the spicy stir-fried chicken and the spicy rice cakes, and a shot of soju in my beer."}
	assert_str(Orders.validate_order(swapped, 2)).contains("Dakgalbi")
	assert_str(Menu.resolve("rolled omelette")).is_equal("gyeran_mari")
	assert_str(Menu.resolve("milky rice wine")).is_equal("makgeolli")
	assert_str(Menu.resolve("fish cakes")).is_equal("odeng")
	assert_str(str(Orders.mentions("the spring onion pancake, please", true)[0]["id"])).is_equal("pajeon")
	assert_str(str(Orders.mentions("some rice wine", true)[0]["id"])).is_equal("makgeolli")  # (not rice)


func test_lines_never_too_dark_or_giving_things_away() -> void:
	var dark := {"line": "You'll find a job that doesn't make you want to jump off a bridge."}
	assert_str(Talk.validate_line(dark, "Park Mi-sook", "Ajumma")).contains("too dark")
	assert_str(Text.problem_kind(Talk.validate_line(dark, "Park Mi-sook", "Ajumma"))).is_equal("dark turns of phrase")
	var free := {"line": "The soju's on the house for first-timers."}
	assert_str(Talk.validate_line(free, "Kim Ji-ho", "")).contains("gives something away")
	assert_str(Text.problem_kind(Talk.validate_line(free, "Kim Ji-ho", ""))).is_equal("giving things away")
	assert_str(Talk.validate_line({"line": "I saw it on Instagram."}, "Kim Ji-ho", "")).contains("real brand")
	assert_str(Talk.validate_line({"line": "My feed's all food photos."}, "Kim Ji-ho", "")).is_empty()
	assert_str(Talk.validate_line({"line": "The banchan's free, help yourself."}, "Park Mi-sook", "Ajumma")).is_empty()  # (it is)
	assert_str(Talk.validate_line({"line": "My feet are killing me."}, "Park Mi-sook", "Ajumma")).is_empty()


func test_korean_exclamations_and_the_double_take() -> void:
	assert_str(Prompts.DIALOGUE_RULES).contains("mwo?!").contains("hwaiting").contains("not in every line")
	assert_array(Glossary.words_in("Mwo?! Mworago? Heol.")).contains_exactly(["Mwo", "Mworago", "Heol"])
	assert_array(Talk.romanised_korean("Mwo?! Mworago? You quit?")).is_empty()  # (real Korean)
	var stunned := Talk.stunned_moment("Kim Ji-ho")
	assert_str(stunned).contains("Ji-ho").contains("hardly believe")
	assert_bool(Talk.hint_taken("stunned", "Mwo?! You quit your job?")).is_true()
	# The first snow, as an occasion; the diary knows who Imo is.
	assert_str(Prompts.describe_moment({"day": "Friday", "time": "9pm", "weather": Seasons.FIRST_SNOW})).contains("make a wish")
	assert_str(Prompts.describe_moment({"day": "Friday", "time": "9pm", "weather": "thick fog"})).not_contains("wish")
	var the_owner := {"name": "Park Mi-sook", "hangul": "박미숙", "age": 61, "gender": "woman", "title": "Ajumma", "archetype": "x", "appearance": "x", "personality": "x", "speech_style": "blunt", "secret": "x"}
	assert_str(str(Prompts.diary_messages(the_owner, Story.diary_facts([], {"owner": "Park Mi-sook"}))[1]["content"])).contains("they mean the owner")


func test_the_door_and_the_chorus() -> void:
	# Polite for a stranger, casual for an old friend.
	assert_str(Talk.door_welcome("")).is_equal("Eoseo oseyo!")
	assert_str(Talk.door_welcome("☆")).is_equal("Tto osyeonneyo!")
	assert_str(Talk.door_welcome("★★")).is_equal("Wasseo?")
	assert_str(Talk.door_goodbye("")).is_equal("Annyeonghi gaseyo!")
	assert_str(Talk.door_goodbye("★★")).is_equal("Josimhi ga!")
	# Romanised, like any Korean said, and every one explains itself on hover.
	for said in [Talk.DOOR_THANKS, Talk.CHORUS] + Talk.DOOR_WELCOME.values() + Talk.DOOR_GOODBYE.values():
		assert_array(Glossary.words_in(str(said))).override_failure_message(str(said)).is_not_empty()
	# Hwaiting, said, gets the counter joining in.
	assert_bool(Talk.says_hwaiting("Hwaiting, Ji-ho! You've got this.")).is_true()
	assert_bool(Talk.says_hwaiting("That's the fighting spirit.")).is_false()
	assert_str(str(Captions.for_event("cheered_on", {})["kind"])).is_equal("hwaiting")


func test_table_games_only_when_the_night_is_right() -> void:
	assert_str(Talk.table_game(1, 3, false, true, 0.0, 0.0)).is_empty()  # (a game needs company)
	assert_str(Talk.table_game(2, 0, false, true, 0.0, 0.0)).is_empty()  # (everyone drinking)
	assert_str(Talk.table_game(2, 3, false, false, 0.0, 0.0)).is_empty()  # (later on)
	assert_str(Talk.table_game(2, 3, false, true, 0.9, 0.0)).is_empty()  # (now and then)
	var seen := {}
	for k in 20:
		var game := Talk.table_game(2, 3, false, true, 0.0, k / 20.0)
		assert_bool(Talk.TABLE_GAMES.has(game)).is_true()
		seen[game] = true
	assert_bool(seen.has("love_shot")).is_false()  # (only between two who've got close)
	assert_str(Talk.table_game(2, 3, true, true, 0.0, 0.99)).is_equal("love_shot")
	for id in Talk.TABLE_GAMES:
		assert_bool(Talk.HINT_TELLS.has("game_" + str(id))).override_failure_message(str(id)).is_true()
		assert_str(str(Captions.for_event("table_game", {"game": id})["kind"])).is_equal("game_" + str(id))
		assert_bool(Captions.CAPTIONS.has("game_" + str(id))).is_true()
	assert_bool(Talk.hint_taken("game_spoon_mic", "Give me that spoon, I'm singing!")).is_true()
	assert_bool(Talk.hint_taken("game_titanic", "Whoever sinks it drinks it!")).is_true()
	assert_bool(Talk.hint_taken("game_nunchi", "I used to teach music in the countryside.")).is_false()  # (whole words: a real night's false start)
	assert_bool(Talk.hint_taken("game_love_shot", "My arms ache from the deliveries.")).is_false()
	assert_array(Glossary.words_in("Kya~! A love shot, then.")).contains(["Kya", "Love Shot"])


func test_the_cliffhanger_comes_true() -> void:
	var names := ["Park Mi-sook", "Kim Jin-seok", "Lee Ha-na"]
	# The recap says what its teaser asks; anything the game can't follow is "other".
	assert_dict(Story.tidy_cliffhanger({"kind": "comes_back", "who": ["kim jin-seok"]}, names)).is_equal({"kind": "comes_back", "who": ["Kim Jin-seok"]})
	assert_str(str(Story.tidy_cliffhanger({"kind": "comes_back", "who": ["Someone New"]}, names)["kind"])).is_equal("other")
	assert_str(str(Story.tidy_cliffhanger({"kind": "a wedding", "who": []}, names)["kind"])).is_equal("other")
	assert_str(str(Story.tidy_cliffhanger({"kind": "closer", "who": ["Kim Jin-seok"]}, names)["kind"])).is_equal("other")  # (closer takes two)
	assert_str(str(Story.tidy_cliffhanger("nonsense", names)["kind"])).is_equal("other")
	# Answered by the night's events.
	var back := {"kind": "comes_back", "who": ["Kim Jin-seok"]}
	assert_bool(Story.cliffhanger_answered(back, "sat_down", {"name": "Kim Jin-seok"})).is_true()
	assert_bool(Story.cliffhanger_answered(back, "sat_down", {"name": "Lee Ha-na"})).is_false()
	var pair := {"kind": "closer", "who": ["Kim Jin-seok", "Lee Ha-na"]}
	assert_bool(Story.cliffhanger_answered(pair, "friendlier", {"a": "Lee Ha-na", "b": "Kim Jin-seok"})).is_true()
	assert_bool(Story.cliffhanger_answered({"kind": "meet_again", "who": ["Kim Jin-seok", "Lee Ha-na"]}, "chat_started", {"name": "Kim Jin-seok", "friend": "Lee Ha-na"})).is_true()
	assert_bool(Story.cliffhanger_answered({"kind": "becomes_regular", "who": ["Lee Ha-na"]}, "became_regular", {"name": "Lee Ha-na"})).is_true()
	assert_bool(Story.cliffhanger_answered({"kind": "cat_chooses", "who": []}, "cat_moved", {"new_lap": true})).is_true()
	assert_bool(Story.cliffhanger_answered({"kind": "cat_chooses", "who": []}, "cat_moved", {"new_lap": false})).is_false()
	assert_bool(Story.cliffhanger_answered({"kind": "cat_strikes", "who": []}, "cat_stole", {})).is_true()
	assert_bool(Story.cliffhanger_answered({"kind": "tears", "who": []}, "big_moment", {"mood": "sad"})).is_true()
	assert_bool(Story.cliffhanger_answered({"kind": "shock", "who": []}, "big_moment", {"mood": "sad"})).is_false()
	assert_bool(Story.cliffhanger_answered({"kind": "full_house", "who": []}, "sat_down", {"seated": 5})).is_true()
	# The recap's checked with it, the game's own recap has one, and the prompt lists them.
	var recap := {"beats": ["Kim Jin-seok walks out into the rain.", "Lee Ha-na watches him go."], "teaser": "Will Jin-seok come back", "cliffhanger": {"kind": "comes_back", "who": ["Kim Jin-seok"]}}
	assert_str(Story.validate_recap(recap, {"names": names})).is_empty()
	assert_str(str(recap["cliffhanger"]["kind"])).is_equal("comes_back")
	var stitched := Story.stitched_recap({"episode": 4, "owner": "Park Mi-sook", "last": {"new_regulars": ["Lee Ha-na"]}})
	assert_dict(stitched["cliffhanger"]).is_equal({"kind": "comes_back", "who": ["Lee Ha-na"]})
	assert_str(Story.cliffhanger_kinds_text()).contains("comes_back").contains("about 2 people")
	# On TV (the red light), and in the diary.
	assert_str(str(Captions.for_event("cliffhanger_answered", {"name": "Kim Jin-seok"})["kind"])).is_equal("cliffhanger")
	assert_bool(Captions.CAPTIONS["cliffhanger"]["emergency"]).is_true()
	var facts := Story.diary_facts([], {"owner": "Park Mi-sook", "cliffhanger": {"teaser": "Will Jin-seok come back?", "kind": "comes_back", "answered": true}})
	assert_str(Prompts.diary_facts_text(facts)).contains("Last time's cliffhanger, \"Will Jin-seok come back?\", came true tonight.")


func test_any_hangul_explains_itself() -> void:
	# Everything the game writes in Hangul has a meaning to show: captions, reactions, stamps, days, titles, seasons.
	var hangul: Array = []
	for kind in Captions.CAPTIONS:
		for wording in Captions.CAPTIONS[kind]["words"]:
			hangul.append(str(wording[0]).replace("{term_hangul}", "언니"))  # (filled in with the term)
	for mood in Captions.REACTIONS:
		hangul.append_array(Captions.REACTIONS[mood]["hangul"])
	for key in Story.DIARY_STAMPS:
		hangul.append(str(Story.DIARY_STAMPS[key]["hangul"]))
	hangul.append_array(Story.DAY_HANGUL.values())
	for style in Story.RECAP_STYLES:
		hangul.append(str(Story.RECAP_STYLES[style]["title"]).get_slice(" · ", 0))
	for season in Seasons.SEASONS:
		hangul.append(str(Seasons.SEASONS[season]["hangul"]))
	for each in hangul:
		assert_str(Glossary.hangul_tip(str(each))).override_failure_message("no meaning for %s" % each).is_not_empty()
	# And every bit of Hangul in the game's code, wherever it's shown: a new caption or sign
	# can't reach the screen unexplained. (Not names, which are told to the Glossary as they're
	# known, the AI's prompts, which aren't shown, or the places the meanings come from.)
	var not_shown := ["canned_ai.gd", "names.gd", "prompts.gd", "pipeline_test.gd", "hangul.gd", "glossary.gd", "address.gd", "menu.gd"]
	var literal := RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")
	var run := RegEx.create_from_string("[\\x{AC00}-\\x{D7A3}\\x{3131}-\\x{318E}]+(?:[ 0-9]*[\\x{AC00}-\\x{D7A3}\\x{3131}-\\x{318E}]+)*")
	for path in _scripts("res://scripts"):
		if not_shown.has(path.get_file()):
			continue
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			for found in literal.search_all(line.get_slice("  #", 0)):
				var text := found.get_string(1).replace("\\n", "").replace("%d", "1")
				for piece in run.search_all(text):
					assert_str(Glossary.hangul_tip(piece.get_string())).override_failure_message("%s: no meaning for %s" % [path.get_file(), piece.get_string()]).is_not_empty()
	# In a line: a hint round the Hangul, and the line reads the same.
	var label: RichTextLabel = auto_free(RichTextLabel.new())
	label.bbcode_enabled = true
	var caption := Glossary.explain_hangul("[color=#ffd23f][b][TV] 짠! JJAN! BOTTOMS UP![/b][/color]")
	assert_str(caption).contains("[hint=짠! jjan!: cheers!")
	label.text = caption
	assert_str(label.get_parsed_text()).is_equal("[TV] 짠! JJAN! BOTTOMS UP!")
	assert_int(Glossary.explain_hangul("새벽 2시: 2AM").count("[hint=")).is_equal(1)  # (one run, digits and all)
	# Names, once they're known; the menu and terms of address by their Hangul; anything else is still marked Korean.
	Glossary.remember("박서준", "박서준: Park Seo-jun's name, in Hangul")
	assert_str(Glossary.explain_hangul("[b]박서준 Park Seo-jun:[/b] Hi.")).contains("Park Seo-jun’s name, in Hangul")
	assert_str(Glossary.hangul_tip("떡볶이")).contains("Tteokbokki")
	assert_str(Glossary.hangul_tip("이모")).contains("Imo")
	assert_str(Glossary.hangul_tip("잘 먹겠습니다")).contains("Jal Meokgesseumnida")
	assert_str(Glossary.hangul_tip("잘")).is_empty()  # (not filed under its first word)
	assert_str(Glossary.hangul_tip("안녕하세요")).contains("hello")
	assert_str(Glossary.explain_hangul("뷁")).contains("Korean, in Hangul")
	# Never inside another hint: a word's tip (with its Hangul) isn't hinted again.
	var word := Glossary.explain("Thanks, Imo.")
	assert_int(Glossary.explain_hangul(word).count("[hint=")).is_equal(1)
	label.text = Glossary.explain_hangul(word)
	assert_str(label.get_parsed_text()).is_equal("Thanks, Imo.")


## Every script under a folder, its subfolders too.
func _scripts(folder: String) -> Array:
	var found: Array = []
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			found.append(folder.path_join(file))
	for sub in DirAccess.get_directories_at(folder):
		found.append_array(_scripts(folder.path_join(sub)))
	return found


func test_every_hover_is_a_sensible_width() -> void:
	var wrapped := Text.tip("Closes up early: nobody new comes in, whoever's here finishes at their own pace, and the owner writes up the night.\nThen you can open the next night.")
	for line in wrapped.split("\n"):
		assert_int(line.length()).is_less_equal(Text.TIP_WIDTH)
	assert_str(wrapped).ends_with("\nThen you can open the next night.")  # (its own line breaks kept)
	assert_str(Text.tip("Short and sweet.")).is_equal("Short and sweet.")
	# Every hover set in the game's code goes through it.
	for path in ["res://scripts/visit.gd", "res://scripts/title.gd"]:
		var code := FileAccess.get_file_as_string(path)
		for line in code.split("\n"):
			var at := line.find(".tooltip_text = ")
			if at == -1:
				continue
			var said := line.substr(at + ".tooltip_text = ".length())
			var short := said.begins_with("str(item[") or said.begins_with("_hover_text(")  # (a dish's name; the customer's own wrapping)
			assert_bool(short or said.begins_with("Text.tip(")).override_failure_message("%s: %s" % [path, line.strip_edges()]).is_true()


func _every_fill() -> Dictionary:
	return {"gender": "woman", "name": "Kim Ji-ho", "friend": "Kang Da-eun", "term": "eonni", "cat": "Mandu",
		"owner": "Park Mi-sook", "amount": "₩26,000", "dish": "Tteokbokki", "drink": "Soju", "job": "office worker",
		"weather": "rain", "visit": 7, "drinks": 3, "dishes": 3, "seated": 4, "years": "for nine years",
		"reason": "THE KNEES HAVE SPOKEN"}


func test_tv_captions_fill_in_the_games_facts() -> void:
	for kind in Captions.CAPTIONS:
		assert_dict(Captions.caption_words(kind)).override_failure_message("%s has no wording without blanks" % kind).is_not_empty()
	var seen := {}
	for k in 20:
		var said := Captions.caption_words("order_up", {"dish": "Tteokbokki"}, k / 20.0)
		seen[said["english"]] = true
	assert_bool(seen.keys().any(func(e): return str(e).begins_with("TTEOKBOKKI, "))).is_true()
	for k in 20:
		assert_str(Captions.caption_words("order_up", {}, k / 20.0)["english"]).not_contains("{")  # no dish: none that need one
	assert_str(Captions.caption_words("jjin_chin", {"name": "Kim Ji-ho", "friend": "Kang Da-eun"}, 0.3)["english"]).is_equal("JI-HO & DA-EUN ∞")
	assert_str(Captions.caption_words("regular_back", {"visit": 7}, 0.7)["english"]).is_equal("VISIT NUMBER 7 ★")
	assert_str(Captions.caption_words("solo", {"weather": "rain"}, 0.99)["hangul"]).is_equal("비 오는 날 혼술…")
	assert_str(Names.given_name("Kim Ji-ho")).is_equal("Ji-ho")
	assert_str(Names.given_name("Mandu")).is_equal("Mandu")


func test_every_tv_caption_is_complete() -> void:
	for kind in Captions.CAPTIONS:
		var data: Dictionary = Captions.CAPTIONS[kind]
		for field in ["words", "icon", "colour", "sound", "emergency"]:
			assert_bool(data.has(field)).override_failure_message("%s has no %s" % [kind, field]).is_true()
		assert_array(Captions.CAPTION_STINGS).contains([data["sound"]])
		assert_bool(Ambience.STINGS.has(str(data["sound"]))).override_failure_message("no sting for %s" % kind).is_true()
		var wordings: Array = data["words"]
		if bool(data.get("fill_first", false)):  # (with everything filled in, only its wordings with blanks come up)
			wordings = wordings.filter(func(wording): return "{" in str(wording[0]) + str(wording[1]))
		var count: int = wordings.size()
		for k in count:
			var said := Captions.caption_words(kind, _every_fill(), (k + 0.5) / count)
			assert_str(said["hangul"]).is_equal(str(wordings[k][0]).replace("{term_hangul}", "언니"))  # each of its words can come up
			assert_str(said["hangul"] + said["english"]).not_contains("{")  # every blank filled
			assert_str(said["english"]).not_contains("<").not_contains("|")  # every piece picked
	assert_str(Captions.caption_text("full_house")).starts_with("[TV] 만석! FULL HOUSE")
	assert_str(Captions.caption_text("cheers", {}, 0.0)).starts_with("[TV] 짠! JJAN! ")
	assert_str(Captions.caption_text("cheers", {}, 0.99)).starts_with("[TV] 원샷! ONE SHOT")
	assert_str(Captions.caption_text("cheers", {}, 0.3)).is_equal(Captions.caption_text("cheers", {}, 0.3))  # the same roll, the same words
	var rng := RandomNumberGenerator.new()
	var seen := {}
	for i in 40:
		seen[Captions.pick_pieces("<SOLO|LONE> <DINER|WOLF>", rng)] = true
	assert_array(seen.keys()).contains_exactly_in_any_order(["SOLO DINER", "SOLO WOLF", "LONE DINER", "LONE WOLF"])
	assert_str(Captions.pick_pieces("NO PIECES HERE", rng)).is_equal("NO PIECES HERE")
	assert_str(Captions.caption_words("regular_back", {"gender": "man"})["english"]).starts_with("HE'S BACK")
	assert_str(Captions.caption_words("regular_back", {"gender": "non-binary"})["english"]).starts_with("THEY'RE BACK")
	assert_str(Captions.caption_text("friendlier", {"term": "eonni"})).starts_with("[TV] 언니! \"EONNI\" ")
	assert_str(Captions.caption_words("cat_lap", {"cat": "Mandu"})["english"]).starts_with("MANDU ")
	assert_bool(Captions.CAPTIONS["full_house"]["emergency"]).is_true()
	assert_bool(Captions.CAPTIONS["regular_back"]["emergency"]).is_false()
	assert_str(Captions.caption_text("bill", {"amount": "₩26,000"}, 0.5)).is_equal("[TV] 계산! ₩26,000")
	assert_str(Captions.caption_text("not a kind")).is_empty()


func test_tv_captions_are_paced() -> void:
	assert_bool(Captions.caption_allowed("rush", 100.0, -1.0, -1.0)).is_true()  # the first of the night
	assert_bool(Captions.caption_allowed("rush", 100.0, 98.0, -1.0)).is_false()  # too soon after another
	assert_bool(Captions.caption_allowed("rush", 100.0, 96.0, -1.0)).is_true()
	assert_bool(Captions.caption_allowed("regular_back", 100.0, 95.0, 92.0)).is_false()  # the same kind again so soon
	assert_bool(Captions.caption_allowed("regular_back", 200.0, 190.0, 85.0)).is_true()
	assert_bool(Captions.caption_allowed("full_house", 100.0, 99.0, -1.0)).is_true()  # an emergency doesn't wait...
	assert_bool(Captions.caption_allowed("full_house", 100.0, 99.0, 90.0)).is_false()  # ...but doesn't repeat on and on
	assert_bool(Captions.caption_allowed("not a kind", 100.0, -1.0, -1.0)).is_false()


func test_tv_reactions_are_checked() -> void:
	var names := ["Kim Ji-ho", "Park Mi-sook"]
	assert_str(Captions.validate_reaction({"mood": "none"}, names)).is_empty()
	var nothing := {"mood": "Nothing"}
	assert_str(Captions.validate_reaction(nothing, names)).is_empty()
	assert_str(str(nothing["mood"])).is_equal("none")
	var small := {"size": Captions.REACTION_MIN_SIZE - 1, "mood": "sad", "who": "Kim Ji-ho", "caption": "LONG DAY"}
	assert_str(Captions.validate_reaction(small, names)).is_empty()
	assert_str(str(small["mood"])).is_equal("none")  # too small for a caption
	var personal := {"size": Captions.REACTION_MIN_SIZE, "mood": "sad", "who": "Kim Ji-ho", "caption": "LONG DAY"}
	assert_str(Captions.validate_reaction(personal, names)).is_empty()
	assert_str(str(personal["mood"])).is_equal("sad")  # just big enough
	var unsized := {"mood": "sad", "who": "Kim Ji-ho", "caption": "LONG DAY"}
	assert_str(Captions.validate_reaction(unsized, names)).is_empty()
	assert_str(str(unsized["mood"])).is_equal("none")
	var good := {"size": 5, "mood": "Shock", "who": "Ji-ho", "caption": "\"she quit her job?!\""}
	assert_str(Captions.validate_reaction(good, names, ["soju"])).is_empty()
	assert_str(str(good["mood"])).is_equal("shock")
	assert_str(str(good["who"])).is_equal("Kim Ji-ho")  # a given name will do
	assert_str(str(good["caption"])).is_equal("SHE QUIT HER JOB?!")
	assert_str(Captions.validate_reaction({"size": 4, "mood": "angry", "who": "Kim Ji-ho", "caption": "WOW"}, names)).contains("isn't one of")
	assert_str(Captions.validate_reaction({"size": 4, "mood": "sad", "who": "Lee Min-ho", "caption": "WOW"}, names)).contains("isn't one of the people talking")
	assert_str(Captions.validate_reaction({"size": 4, "mood": "sad", "who": "Kim Ji-ho", "caption": ""}, names)).contains("empty")
	assert_str(Captions.validate_reaction({"size": 4, "mood": "funny", "who": "Kim Ji-ho", "caption": "THIS IS A REALLY LONG CAPTION ABOUT NOTHING"}, names)).contains("longer than five words")
	assert_str(Captions.validate_reaction({"size": 4, "mood": "funny", "who": "Kim Ji-ho", "caption": "LOL (LAUGHS)"}, names)).contains("brackets")
	assert_str(Captions.validate_reaction({"size": 4, "mood": "warm", "who": "Kim Ji-ho", "caption": "FREE TTEOKBOKKI FOR HER"}, names, ["soju"])).contains("nobody ordered")
	assert_str(Text.problem_kind(Captions.validate_reaction({"size": 4, "mood": "warm", "who": "x", "caption": "HI"}, names))).is_equal("TV reactions")
	# The game's Korean, the AI's English.
	var words := Captions.reaction_words("shock", "she quit her job?!", 0.0)
	assert_str(words["hangul"]).is_equal("충격!")
	assert_str(words["english"]).is_equal("SHE QUIT HER JOB?!")
	for mood in Captions.REACTIONS:
		assert_array(Captions.REACTION_STINGS).contains([Captions.REACTIONS[mood]["sound"]])
		assert_bool(Ambience.STINGS.has(str(Captions.REACTIONS[mood]["sound"]))).override_failure_message("no sting for %s" % mood).is_true()


func test_the_owners_life_is_fixed() -> void:
	var the_owner := {"name": "Kim Sung-ho", "gender": "man", "family": "\"widowed; a son in Busan\""}
	assert_bool(People.fill_owner_life(the_owner, 0.0)).is_true()
	assert_str(str(the_owner["family"])).is_equal("widowed; a son in Busan")  # the AI's, tidied
	assert_str(str(the_owner["before"])).is_equal(People.OWNER_BEFORES[0])  # left out: the game's
	assert_bool(People.fill_owner_life(the_owner, 0.9)).is_false()  # already there: kept
	var her := {"name": "Park Mi-sook", "gender": "woman"}
	People.fill_owner_life(her, 0.0)
	assert_str(str(her["family"])).is_equal(People.OWNER_FAMILIES["woman"][0])
	var rambling := {"gender": "woman", "family": "x".repeat(People.MAX_OWNER_LIFE + 1), "before": "a bakery"}
	People.fill_owner_life(rambling, 0.0)
	assert_str(str(rambling["family"])).is_equal(People.OWNER_FAMILIES["woman"][0])  # too long: the game's instead


func test_names_in_western_order_are_turned_round() -> void:
	assert_str(Names.family_name_first("Min-jae Lee")).is_equal("Lee Min-jae")
	assert_str(Names.family_name_first("Lee Min-jae")).is_equal("Lee Min-jae")
	assert_str(Names.family_name_first("Kim Min")).is_equal("Kim Min")  # both could be family names: left alone
	var data := {"name": "Ji-ho Kim", "gender": "woman"}
	assert_str(Names.validate_customer_name(data)).is_empty()
	assert_str(str(data["name"])).is_equal("Kim Ji-ho")


func _diary_facts() -> Dictionary:
	return {"episode": 12, "day": "Friday", "weather": "the first snow of winter", "owner": "Park Mi-sook",
		"customers": 14, "takings": "₩412,000", "takings_vs_usual": "better than usual", "busiest": "10:40pm, with 5 at the counter",
		"people": [{"name": "Kim Ji-ho", "job": "nurse", "regular": "a regular", "ordered": "Soju, Tteokbokki", "order_ids": ["soju", "tteokbokki"]}],
		"missing": ["Hwang Tae-oh"], "not_here": ["Lee Da-eun"],
		"moments": [{"who": "Kim Ji-ho", "mood": "shock", "caption": "SHE QUIT HER JOB?!", "said": "I quit today."}],
		"friendlier": [], "new_regulars": [], "cat": "Mandu", "cat_laps": [], "walked_on": 0,
		"line": {"speaker": "Kim Ji-ho", "text": "I quit today."}, "ordered": ["soju", "tteokbokki"]}


func test_the_diary_keeps_to_the_nights_facts() -> void:
	var facts := _diary_facts()
	var good := {"entry": "\"First snow, and the stools full by 10:40pm. Ji-ho finally said it: she quit. I gave her extra tteokbokki and pretended not to see her face. Tae-oh didn't come, the old goat. ₩412,000, a good Friday.\""}
	assert_str(Story.validate_diary(good, facts)).is_empty()
	assert_bool(str(good["entry"]).begins_with("First snow")).is_true()  # quotes tidied off
	assert_str(Story.validate_diary({"entry": "Too short."}, facts)).contains("too short")
	assert_str(Story.validate_diary({"entry": "x".repeat(Story.MAX_DIARY + 1)}, facts)).contains("too long")
	var stranger := {"entry": "Da-eun came in again and sat with Ji-ho for hours, laughing about the snow and the soju and the cold, cold night outside."}
	assert_str(Story.validate_diary(stranger, facts)).contains("Lee Da-eun")
	var counted := {"entry": "We had 30 customers tonight, which is madness for a snowy Friday. Ji-ho quit her job and I gave her soju until she smiled again."}
	assert_str(Story.validate_diary(counted, facts)).contains("number (30)")
	var fed := {"entry": "Ji-ho quit her job, so I made her some odeng and sat with her a while. Snow on the tarp all night, and a good Friday at the tin."}
	assert_str(Story.validate_diary(fed, facts)).contains("nobody ordered")
	# The game's own entry passes its own checks.
	assert_str(Story.validate_diary({"entry": Story.stitched_diary(facts)}, facts)).is_empty()
	var quiet := facts.duplicate(true)
	quiet["people"] = []
	quiet["moments"] = []
	quiet["customers"] = 0
	quiet["takings"] = "₩0"
	assert_str(Story.validate_diary({"entry": Story.stitched_diary(quiet)}, quiet)).is_empty()


func test_the_diary_page_gets_a_stamp_and_the_takings_a_word() -> void:
	assert_str(Story.takings_word(100, [])).is_empty()  # the first night: nothing to compare
	assert_str(Story.takings_word(100, [100, 100, 100])).is_equal("about usual")
	assert_str(Story.takings_word(130, [100, 100])).is_equal("better than usual")
	assert_str(Story.takings_word(200, [100, 100, 120])).is_equal("the best night yet")
	assert_str(Story.takings_word(50, [100, 100])).is_equal("quieter than usual")
	var facts := _diary_facts()
	assert_str(Story.diary_stamp(facts)).is_equal("well_done")
	facts["takings_vs_usual"] = "about usual"
	assert_str(Story.diary_stamp(facts)).is_equal("snow")
	facts["cat_laps"] = ["Kim Ji-ho"]
	assert_str(Story.diary_stamp(facts)).is_equal("paw")
	facts["new_regulars"] = ["Kim Ji-ho"]
	assert_str(Story.diary_stamp(facts)).is_equal("star")
	facts["cat_thefts"] = ["Kim Ji-ho"]
	assert_str(Story.diary_stamp(facts)).is_equal("thief")  # nothing tops it
	var stormy := {"weather": "heavy rain drumming on the tarp"}
	assert_str(Story.diary_stamp(stormy)).is_equal("storm")
	assert_str(Story.diary_stamp({"weather": "light drizzle"})).is_equal("rain")
	assert_str(Story.diary_stamp({"weather": "thick fog", "moments": [{"mood": "funny"}]})).is_equal("laugh")
	for key in Story.DIARY_STAMPS:
		assert_str(str(Story.DIARY_STAMPS[key]["hangul"])).is_not_empty()
	assert_str(Story.DAY_HANGUL["Friday"]).is_equal("금요일")


func test_food_moments_are_situations_not_lines() -> void:
	assert_bool(Talk.FOOD_MOMENTS.size() >= 4).is_true()  # enough to rotate
	for moment in Talk.FOOD_MOMENTS:
		assert_str(str(moment)).not_contains("\"")  # never a phrase for the AI to repeat
	assert_float(Talk.FOOD_MOMENT_CHANCE).is_less(0.5)  # now and then, not every dish
	assert_str(Captions.caption_words("eating", {}, 0.0)["hangul"]).is_equal("맛있겠다~")


func test_a_diary_entry_starts_straight_in() -> void:
	var facts := _diary_facts()
	for opening in ["Wrote tonight's entry in the diary.", "Dear diary, what a night.", "Tonight's entry: snow."]:
		var entry := {"entry": opening + " Ji-ho quit her job, and I gave her extra tteokbokki and pretended not to see her face. A good Friday."}
		assert_str(Story.validate_diary(entry, facts)).contains("start straight in")


func test_names_are_cased_the_usual_way() -> void:
	assert_str(Names.name_case("Kim Jae-Ho")).is_equal("Kim Jae-ho")
	assert_str(Names.name_case("KIM JI-HO")).is_equal("Kim Ji-ho")
	assert_str(Names.name_case("park mi-sook")).is_equal("Park Mi-sook")
	var data := {"name": "Yoon Tae-Oh", "gender": "man"}
	assert_str(Names.validate_customer_name(data)).is_empty()
	assert_str(str(data["name"])).is_equal("Yoon Tae-oh")
	for kind in Captions.CAPTIONS:
		var chance := float(Captions.CAPTIONS[kind].get("chance", 1.0))
		assert_bool(chance > 0.0 and chance <= 1.0).is_true()
	assert_float(float(Captions.CAPTIONS["late_guest"]["chance"])).is_less(1.0)  # not every late arrival


func _recap_facts() -> Dictionary:
	return {"episode": 13, "bar": "Donghwa Pocha", "owner": "Park Mi-sook", "archetype": "gruff-but-soft ajumma", "cat": "Mandu",
		"regulars": ["Hwang Tae-oh", "Lee Da-eun"], "names": ["Park Mi-sook", "Hwang Tae-oh", "Lee Da-eun", "Kim Ji-ho"],
		"last": _diary_facts(), "last_entry": "Ji-ho quit. Tae-oh didn't come.", "memories": []}


func test_the_recap_keeps_to_the_story() -> void:
	var facts := _recap_facts()
	var good := {"beats": ["\"Ji-ho finally says it: she quits.\"", "Tae-oh's stool stays empty."], "teaser": "Will Tae-oh come back."}
	assert_str(Story.validate_recap(good, facts)).is_empty()
	assert_str(str(good["beats"][0])).is_equal("Ji-ho finally says it: she quits.")
	assert_str(str(good["teaser"])).is_equal("Will Tae-oh come back?")  # made a question
	assert_str(Story.validate_recap({"beats": ["Just one."], "teaser": "Why?"}, facts)).contains("two or three")
	assert_str(Story.validate_recap({"beats": "Not a list", "teaser": "Why?"}, facts)).contains("a list")
	var stranger := {"beats": ["Ji-ho quits.", "Min-jun walks in with flowers."], "teaser": "Who is he?"}
	assert_str(Story.validate_recap(stranger, facts)).contains("Min-jun")
	var counted := {"beats": ["Ji-ho quits after 7 years.", "Tae-oh stays away."], "teaser": "What now?"}
	assert_str(Story.validate_recap(counted, facts)).contains("number (7)")
	assert_str(Story.unknown_name("A late-night Ji-ho, and Late-night rain.", ["Kim Ji-ho"])).is_empty()  # long words aren't names
	# The game's own recap, and a new bar's opener, pass the checks.
	assert_str(Story.validate_recap(Story.stitched_recap(facts), facts)).is_empty()
	var first := _recap_facts()
	first["episode"] = 1
	first["last"] = {}
	var opener := Story.stitched_recap(first)
	assert_str(str(opener["beats"][0])).contains("tarp goes up")
	assert_str(str(opener["beats"][2])).contains("Tae-oh and Da-eun")
	assert_str(Story.validate_recap(opener, first)).is_empty()
	assert_str(str(Story.stitched_recap(facts)["teaser"])).is_equal("Will Tae-oh be back tonight?")  # a founding regular who didn't come


func test_each_recap_gets_a_different_k_tv_style() -> void:
	var shock := {"moments": [{"who": "Kim Ji-ho", "mood": "shock"}], "customers": 14}
	assert_str(Story.pick_recap_style(shock, "", 0.0)).is_equal("makjang")  # a shock: a makjang cliffhanger
	assert_str(Story.pick_recap_style({"moments": [{"mood": "funny"}], "customers": 14}, "", 0.0)).is_equal("variety")
	assert_str(Story.pick_recap_style({"moments": [{"mood": "sad"}], "customers": 14}, "", 0.0)).is_equal("melodrama")
	assert_str(Story.pick_recap_style({"moments": [], "customers": 5}, "", 0.0)).is_equal("nostalgic")  # a quiet night
	assert_str(Story.pick_recap_style(shock, "makjang", 0.0)).is_not_equal("makjang")  # never the same twice running
	for roll in [0.0, 0.5, 0.99]:
		var picked := Story.pick_recap_style({"moments": [], "customers": 14}, "variety", roll)
		assert_bool(Story.RECAP_STYLES.has(picked)).is_true()
		assert_str(picked).is_not_equal("variety")
	# A stormy night gets the storm (whatever else happened), but never twice running, and
	# never otherwise.
	var stormy := {"moments": [{"mood": "funny"}], "customers": 14, "weather": "heavy rain drumming on the tarp"}
	assert_str(Story.pick_recap_style(stormy, "", 0.0)).is_equal("stormy")
	assert_str(Story.pick_recap_style(stormy, "stormy", 0.0)).is_equal("variety")
	for roll in [0.0, 0.3, 0.6, 0.99]:
		assert_str(Story.pick_recap_style({"moments": [], "customers": 14, "weather": "thick fog"}, "melodrama", roll)).is_not_equal("stormy")
	assert_str(str(Story.RECAP_STYLES["stormy"]["drift"])).is_equal("rain")
	for key in Story.RECAP_STYLES:
		for field in ["title", "sky", "rays", "pill", "tag", "teaser_colour", "ribbons", "drift", "beats", "last", "sting", "teaser", "overlay"]:
			assert_bool(Story.RECAP_STYLES[key].has(field)).override_failure_message("%s has no %s" % [key, field]).is_true()
		assert_bool(Ambience.STINGS.has(str(Story.RECAP_STYLES[key]["sting"]))).is_true()


func test_each_night_event_gets_its_caption() -> void:
	assert_dict(Captions.for_event("walked_on", {"first": true})).contains_keys(["kind"])
	assert_dict(Captions.for_event("walked_on", {"first": false})).is_empty()  # several at once: one caption
	var sat := {"name": "Kim Ji-ho", "seated": 2, "minutes": 1200, "job": "nurse", "regular": "", "friend": ""}
	assert_str(str(Captions.for_event("sat_down", sat)["kind"])).is_equal("new_face")
	sat["minutes"] = Captions.LATE_GUEST_AFTER + 5
	assert_str(str(Captions.for_event("sat_down", sat)["kind"])).is_equal("late_guest")
	sat["seated"] = 1
	assert_str(str(Captions.for_event("sat_down", sat)["kind"])).is_equal("solo")
	sat["seated"] = Captions.RUSH_SEATED
	sat["rush_open"] = true
	assert_str(str(Captions.for_event("sat_down", sat)["kind"])).is_equal("rush")
	sat["rush_open"] = false
	assert_str(str(Captions.for_event("sat_down", sat)["kind"])).is_equal("late_guest")  # the rush has had its caption
	sat["regular"] = "regular"
	assert_str(str(Captions.for_event("sat_down", sat)["kind"])).is_equal("regular_back")
	sat["regular"] = "founding"
	assert_str(str(Captions.for_event("sat_down", sat)["kind"])).is_equal("founding")
	sat["friend"] = "Lee Da-eun"
	var friends := Captions.for_event("sat_down", sat)
	assert_str(str(friends["kind"])).is_equal("jjin_chin")
	assert_str(str(friends["fill"]["friend"])).is_equal("Lee Da-eun")
	assert_str(str(Captions.for_event("greeted", {"quick": true})["kind"])).is_equal("multitask")
	assert_dict(Captions.for_event("greeted", {"quick": false})).is_empty()
	assert_str(str(Captions.for_event("drinks_poured", {"first": true, "drink": "Soju"})["kind"])).is_equal("cheers")
	assert_str(str(Captions.for_event("drinks_poured", {"first": false, "drinks": 3})["kind"])).is_equal("another_round")
	assert_str(str(Captions.for_event("dish_served", {"food_served": 2, "name": "Kim Ji-ho"})["kind"])).is_equal("eating")
	assert_str(str(Captions.for_event("dish_served", {"food_served": 1, "dish": "Tteokbokki"})["kind"])).is_equal("order_up")
	assert_str(str(Captions.for_event("paid", {"bill": Captions.BIG_SPENDER})["kind"])).is_equal("big_spender")
	assert_str(str(Captions.for_event("paid", {"bill": 12000})["kind"])).is_equal("bill")
	var left := {"seated": 0, "waiting": 0, "last_orders": false, "minutes": Captions.QUIET_AFTER + 1}
	assert_str(str(Captions.for_event("left", left)["kind"])).is_equal("quiet")
	left["last_orders"] = true
	assert_dict(Captions.for_event("left", left)).is_empty()  # last orders has its own
	assert_str(str(Captions.for_event("cat_moved", {"spot": "lap", "new_lap": true, "cat": "Mandu", "with": "Kim Ji-ho"})["kind"])).is_equal("cat_lap")
	assert_str(str(Captions.for_event("cat_moved", {"spot": "street", "was_out": false})["kind"])).is_equal("cat_out")
	assert_str(str(Captions.for_event("cat_moved", {"spot": "stove", "was_out": true})["kind"])).is_equal("cat_back")
	assert_dict(Captions.for_event("cat_moved", {"spot": "stove", "was_out": false})).is_empty()  # just pottering
	assert_dict(Captions.for_event("arrived", {})).is_empty()
	assert_dict(Captions.for_event("big_moment", {})).is_empty()  # (its own caption, from the AI's words)
	for kind in ["dawn", "last_orders", "stove_backed", "chat_started", "joined_chat", "owner_joined", "became_regular", "friendlier"]:
		var caption := Captions.for_event(kind, {})
		assert_bool(Captions.CAPTIONS.has(str(caption.get("kind", "")))).override_failure_message("no caption for %s" % kind).is_true()


func test_the_diary_facts_come_from_the_nights_events() -> void:
	var events := [
		{"kind": "sat_down", "at": 1300, "seated": 2},
		{"kind": "sat_down", "at": 1360, "seated": 5},
		{"kind": "walked_on", "at": 1365, "first": true},
		{"kind": "big_moment", "at": 1370, "who": "Kim Ji-ho", "mood": "shock", "caption": "SHE QUIT?!", "said": "I quit today."},
		{"kind": "cat_moved", "at": 1380, "spot": "lap", "new_lap": true, "with": "Kim Ji-ho"},
		{"kind": "cat_moved", "at": 1385, "spot": "lap", "new_lap": true, "with": "Kim Ji-ho"},  # (the same lap twice: once)
		{"kind": "friendlier", "at": 1390, "a": "Kim Ji-ho", "b": "Lee Da-eun", "term": "eonni"},
		{"kind": "became_regular", "at": 1400, "name": "Kim Ji-ho"},
		{"kind": "paid", "at": 1410, "name": "Kim Ji-ho", "hangul": "김지호", "job": "nurse", "regular": "", "ordered": "Soju, Tteokbokki", "order_ids": ["soju", "tteokbokki"]},
		{"kind": "paid", "at": 1420, "name": "Lee Da-eun", "hangul": "이다은", "job": "teacher", "regular": "a regular", "ordered": "Soju", "order_ids": ["soju"]},
	]
	var facts := Story.diary_facts(events, {"episode": 3, "day": "Friday", "weather": "rain", "owner": "Park Mi-sook", "customers": 2,
		"takings": 26000, "before": [10000, 10000, 10000], "cat": "Mandu", "line": {"speaker": "Kim Ji-ho", "text": "I quit today."},
		"regulars": [{"name": "Hwang Tae-oh", "founding": true}, {"name": "Lee Da-eun", "founding": false}, {"name": "Choi Min-ho", "founding": false}]})
	assert_str(str(facts["busiest"])).is_equal("10:40pm, with 5 at the counter")
	assert_int(int(facts["walked_on"])).is_equal(1)
	assert_str(str(facts["people"][0]["hangul"])).is_equal("김지호")
	assert_array(facts["ordered"]).contains_exactly(["soju", "tteokbokki"])
	assert_str(str(facts["moments"][0]["caption"])).is_equal("SHE QUIT?!")
	assert_array(facts["cat_laps"]).is_equal(["Kim Ji-ho"])
	assert_str(str(facts["friendlier"][0])).is_equal("Kim Ji-ho and Lee Da-eun are on \"eonni\" terms now")
	assert_array(facts["new_regulars"]).is_equal(["Kim Ji-ho"])
	assert_array(facts["missing"]).is_equal(["Hwang Tae-oh"])  # a founding regular who didn't come
	assert_array(facts["not_here"]).is_equal(["Choi Min-ho"])  # a regular who didn't come (not missed by name)
	assert_str(str(facts["takings"])).is_equal("₩26,000")
	assert_str(str(facts["takings_vs_usual"])).is_equal("the best night yet")
	assert_str(Story.validate_diary({"entry": Story.stitched_diary(facts)}, facts)).is_empty()  # and the game's own entry passes its checks


func test_the_diary_and_recap_know_everyones_pronouns() -> void:
	# (Without them, the diary had a woman regular as "he's been MIA".)
	var events := [
		{"kind": "paid", "at": 1410, "name": "Kim Ji-ho", "gender": "woman", "job": "nurse", "regular": "", "ordered": "Soju", "order_ids": ["soju"]},
		{"kind": "paid", "at": 1420, "name": "Lee Min-jun", "gender": "man", "job": "chef", "regular": "", "ordered": "Beer", "order_ids": ["beer"]},
		{"kind": "paid", "at": 1430, "name": "Han Ri-an", "gender": "non-binary", "job": "artist", "regular": "", "ordered": "Beer", "order_ids": ["beer"]},
	]
	var facts := Story.diary_facts(events, {"owner": "Park Mi-sook", "owner_gender": "woman", "customers": 3, "takings": 15000,
		"regulars": [{"name": "Kim Jin-sook", "founding": true, "gender": "woman"}]})
	assert_dict(facts["pronouns"]).is_equal({"Park Mi-sook": "she", "Kim Jin-sook": "she", "Kim Ji-ho": "she", "Lee Min-jun": "he", "Han Ri-an": "they"})
	var text := Prompts.diary_facts_text(facts)
	assert_str(text).contains("Kim Ji-ho (she, nurse")
	assert_str(text).contains("Lee Min-jun (he, chef")
	assert_str(text).contains("Kim Jin-sook (she), a regular, didn't come in tonight.")
	assert_str(text).contains("Use these pronouns:")
	assert_str(text).contains("Han Ri-an: they")
	# Facts saved before pronouns (older diaries, for "Previously on…") still read fine.
	var old := facts.duplicate(true)
	old.erase("pronouns")
	for person in old["people"]:
		person.erase("pronoun")
	assert_str(Prompts.diary_facts_text(old)).contains("Kim Jin-sook, a regular, didn't come in tonight.")
	assert_str(People.pronoun("")).is_equal("they")
