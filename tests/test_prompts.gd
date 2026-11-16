extends GdUnitTestSuite
## Tests for scripts/ai/prompts.gd: the facts the game puts into prompts must actually be there.
## These don't call the AI; they only check the text the game would send.

const Prompts = preload("res://scripts/ai/prompts.gd")
const Menu = preload("res://scripts/rules/menu.gd")
const Captions = preload("res://scripts/rules/captions.gd")
const Talk = preload("res://scripts/rules/talk.gd")
const Story = preload("res://scripts/rules/story.gd")


func _owner_data() -> Dictionary:
	return {
		"name": "Park Mi-sook", "age": 61, "gender": "woman", "title": "Ajumma",
		"archetype": "gruff-but-soft ajumma", "appearance": "Apron and rubber gloves.",
		"personality": "blunt, caring", "speech_style": "short and scolding",
		"secret": "She once sang backing vocals for a trot singer.",
	}


func _customer_data() -> Dictionary:
	return {
		"name": "Kim Ji-ho", "age": 34, "job": "office worker", "mood": "worn out",
		"reason": "Her team lead took credit for her work.", "speech_style": "dry, tired",
		"appearance": "A crumpled blazer.",
	}


func _moment() -> Dictionary:
	return {"day": "Thursday", "time": "1:40am", "weather": "light drizzle"}


## The text of the request (the last message) in a list of messages.
func _request(messages: Array) -> String:
	return str(messages[messages.size() - 1]["content"])


func test_owner_prompt_uses_the_game_chosen_title() -> void:
	assert_str(_request(Prompts.owner_messages("woman"))).contains("Ajumma")
	assert_str(_request(Prompts.owner_messages("man"))).contains("Ajusshi")


func test_owner_prompt_doesnt_ask_the_ai_for_a_title() -> void:
	# Regression, LLM-TUNING.md "Owner titles": the title is a game fact now.
	assert_str(_request(Prompts.owner_messages("woman"))).not_contains("\"title\"")


func test_customer_prompt_includes_the_moment() -> void:
	var text := _request(Prompts.customer_messages("Thursday", "1:40am", "light drizzle"))
	assert_str(text).contains("Thursday")
	assert_str(text).contains("1:40am")
	assert_str(text).contains("light drizzle")


func test_customer_prompt_in_a_visit_has_no_opening_line() -> void:
	# Regression, LLM-TUNING.md "Double opening": in a visit, first words come with the order.
	assert_str(_request(Prompts.customer_messages("Thursday", "1:40am", "fog", false))).not_contains("opening_line")
	assert_str(_request(Prompts.customer_messages("Thursday", "1:40am", "fog", true))).contains("opening_line")


func test_order_prompt_lists_the_menu() -> void:
	var text := _request(Prompts.order_messages(_owner_data(), _customer_data(), _moment(), Menu.prompt_list(), []))
	for item in Menu.ITEMS:
		assert_str(text).contains(str(item["id"]))



func test_people_order_by_the_korean_names() -> void:
	var text := _request(Prompts.order_messages(_owner_data(), _customer_data(), _moment(), Menu.prompt_list(), []))
	assert_str(text).contains("by their Korean names").contains("the rest of the line is plain English").contains("ask for everything in \"items\"")
	assert_str(text).contains("rice is a side to go with a dish")

func test_regression_order_and_dialogue_prompts_say_its_a_first_visit() -> void:
	# LLM-TUNING.md "Strangers acting like regulars" (interim fix).
	var order := _request(Prompts.order_messages(_owner_data(), _customer_data(), _moment(), Menu.prompt_list(), []))
	var line := _request(Prompts.dialogue_messages(_owner_data(), _customer_data(), _moment(), "Soju", [], true, ""))
	for text in [order, line]:
		assert_str(text).contains("first visit")
		assert_str(text).contains("the usual")


func test_dialogue_prompt_rules_out_relationship_terms() -> void:
	# LLM-TUNING.md "Owner titles": customers never call the owner oppa, hyung, nuna or eonni.
	var text := _request(Prompts.dialogue_messages(_owner_data(), _customer_data(), _moment(), "Soju", [], false, ""))
	assert_str(text).contains("never oppa")


func test_dialogue_prompt_names_the_right_speaker() -> void:
	var owner_turn := _request(Prompts.dialogue_messages(_owner_data(), _customer_data(), _moment(), "Soju", [], true, ""))
	var customer_turn := _request(Prompts.dialogue_messages(_owner_data(), _customer_data(), _moment(), "Soju", [], false, ""))
	assert_str(owner_turn).contains("spoken by Park Mi-sook (the owner)")
	assert_str(customer_turn).contains("spoken by Kim Ji-ho (the customer)")


func test_transcript_is_included_in_dialogue_prompt() -> void:
	var transcript := [{"speaker": "Kim Ji-ho", "text": "Ajumma, one soju please."}]
	var text := _request(Prompts.dialogue_messages(_owner_data(), _customer_data(), _moment(), "Soju", transcript, true, ""))
	assert_str(text).contains("Ajumma, one soju please.")


# --- Regression, LLM-TUNING.md "Not listening to each other" ----------------------------

func _served_transcript() -> Array:
	return [
		{"speaker": "Kim Ji-ho", "text": "Ajumma, a cold beer and some tteokbokki, please."},
		{"action": "Park Mi-sook serves: Beer, Tteokbokki."},
	]


func test_serving_appears_in_transcript_as_stage_direction() -> void:
	assert_str(Prompts.transcript_text(_served_transcript())).contains("(Park Mi-sook serves: Beer, Tteokbokki.)")


func test_dialogue_prompt_repeats_what_just_happened_after_the_transcript() -> void:
	var text := _request(Prompts.dialogue_messages(_owner_data(), _customer_data(), _moment(), "Beer, Tteokbokki", _served_transcript(), true, ""))
	var recap := "WHAT JUST HAPPENED: Kim Ji-ho just said: \"Ajumma, a cold beer and some tteokbokki, please.\" Then: (Park Mi-sook serves: Beer, Tteokbokki.)"
	assert_str(text).contains(recap)
	assert_int(text.find(recap)).is_greater(text.find("The conversation so far:"))


func test_what_just_happened_with_no_conversation_yet() -> void:
	assert_str(Prompts.what_just_happened([])).contains("first line")


func test_regression_style_guide_names_no_menu_items() -> void:
	# LLM-TUNING.md "Talking about food that isn't on the table": the setting said "steam rising
	# off the tteokbokki", and the AI talked about tteokbokki nobody had ordered.
	var guide := (Prompts.STYLE_GUIDE + " " + Prompts.DIALOGUE_RULES).to_lower()
	for item in Menu.ITEMS:
		assert_str(guide).override_failure_message("the style guide mentions %s" % item["name"]).not_contains(str(item["name"]).to_lower())



func test_order_prompt_explains_how_people_order() -> void:
	var text := _request(Prompts.order_messages(_owner_data(), _customer_data(), _moment(), Menu.prompt_list(), []))
	assert_str(text).contains("at least one drink and at least one food")
	assert_str(text).contains("at most one main dish")


func test_order_prompt_can_set_the_scene_for_how_they_order() -> void:
	var situation := str(Talk.ORDER_MOMENTS[1]["text"])
	var text := _request(Prompts.order_messages(_owner_data(), _customer_data(), _moment(), Menu.prompt_list(), [], false, false, situation))
	assert_str(text).contains("why they're here tonight. " + situation + " Order between 2 and 4")
	var plain := _request(Prompts.order_messages(_owner_data(), _customer_data(), _moment(), Menu.prompt_list(), []))
	assert_str(plain).contains("why they're here tonight. Order between 2 and 4")


func test_order_prompt_lets_hungry_customers_order_two_mains() -> void:
	var text := _request(Prompts.order_messages(_owner_data(), _customer_data(), _moment(), Menu.prompt_list(), [], true))
	assert_str(text).contains("up to two main dishes")



func test_order_prompt_asks_for_one_drink() -> void:
	var text := _request(Prompts.order_messages(_owner_data(), _customer_data(), _moment(), Menu.prompt_list(), []))
	assert_str(text).contains("ONE drink")
	assert_str(text).contains("They'll order just one drink.")
	assert_str(text).not_contains("a drink or two")


func test_order_prompt_allows_two_drinks_on_a_rough_night() -> void:
	var text := _request(Prompts.order_messages(_owner_data(), _customer_data(), _moment(), Menu.prompt_list(), [], false, true))
	assert_str(text).contains("may order two drinks")



func test_extra_order_prompt_sets_the_limits_and_shows_the_table() -> void:
	var text := _request(Prompts.extra_order_messages(_owner_data(), _customer_data(), _moment(), Menu.prompt_list(), _served_transcript(), "Beer, Tteokbokki"))
	assert_str(text).contains("On the table: Beer, Tteokbokki")
	assert_str(text).contains("at most one drink, and no main dishes")
	assert_str(text).contains("WHAT JUST HAPPENED")



func test_extra_order_prompt_says_its_not_a_first_order() -> void:
	var text := _request(Prompts.extra_order_messages(_owner_data(), _customer_data(), _moment(), Menu.prompt_list(), _served_transcript(), "Beer, Tteokbokki"))
	assert_str(text).contains("NOT their first order")



func test_bar_name_prompt_asks_for_romanised_korean_and_knows_the_owner() -> void:
	var text := _request(Prompts.bar_name_messages(_owner_data()))
	assert_str(text).contains("Park Mi-sook")
	assert_str(text).contains("romanised")
	assert_str(text).contains("not English words")


# --- Customers talking to each other -----------------------------------------------------

func _second_customer() -> Dictionary:
	return {
		"name": "Lee Min-jun", "age": 27, "job": "line cook", "mood": "restless",
		"reason": "His restaurant closed tonight for good.", "speech_style": "quick, joking",
		"appearance": "Kitchen clogs.", "company": "chatty",
	}


func _chat(owner_in: bool, transcript: Array = []) -> String:
	return _request(Prompts.counter_chat_messages(_owner_data(), owner_in, [_customer_data(), _second_customer()],
		["Beer, plus free banchan", "Soju, plus free banchan"], _moment(), transcript, "Kim Ji-ho", "Lee Min-jun", ""))


func test_counter_chat_prompt_describes_everyone_and_their_tables() -> void:
	var text := _chat(false)
	assert_str(text).contains("Kim Ji-ho, 34, office worker")
	assert_str(text).contains("Lee Min-jun, 27, line cook")
	assert_str(text).contains("Their table: Beer, plus free banchan")
	assert_str(text).contains("Their table: Soju, plus free banchan")
	assert_str(text).contains("1:40am")


func test_counter_chat_prompt_says_who_speaks_to_whom() -> void:
	assert_str(_chat(false)).contains("spoken by Kim Ji-ho to Lee Min-jun")


func test_counter_chat_prompt_says_they_are_strangers_who_talk_politely() -> void:
	var text := _chat(false)
	assert_str(text).contains("strangers who've only just met")
	assert_str(text).contains("don't know each other's names")
	assert_str(text).contains("no oppa, hyung, nuna or eonni")


func test_counter_chat_prompt_leaves_the_owner_out_unless_they_join() -> void:
	assert_str(_chat(false)).contains("isn't part of this conversation")
	assert_str(_chat(false)).not_contains("THE OWNER:")  # just who they are, not their whole profile and secret
	assert_str(_chat(false)).contains("Park Mi-sook (customers call her")
	assert_str(_chat(true)).contains("THE OWNER: Park Mi-sook")
	assert_str(_chat(true)).contains("The owner has joined in")


func test_counter_chat_prompt_includes_the_chat_and_what_just_happened() -> void:
	var text := _chat(false, [{"speaker": "Lee Min-jun", "text": "Rough night?"}])
	assert_str(text).contains("Lee Min-jun: \"Rough night?\"")
	assert_str(text).contains("WHAT JUST HAPPENED: Lee Min-jun just said: \"Rough night?\"")


func test_customer_description_includes_their_mood_for_company() -> void:
	var text := Prompts.describe_person(_second_customer())
	assert_str(text).contains("With other customers: happy to chat with anyone at the counter")
	assert_str(Prompts.describe_person(_customer_data())).not_contains("With other customers")


func test_name_prompt_avoids_names_at_the_counter_and_from_tonight() -> void:
	var text := _request(Prompts.customer_name_messages("Friday", "9:00pm", "fog", ["Kim Ji-ho", "Lee Min-jun"], ["Park Seo-jun"]))
	assert_str(text).contains("must have a different name: Kim Ji-ho, Lee Min-jun")
	assert_str(text).contains("avoid them too: Park Seo-jun")
	assert_str(text).contains("\"gender\"")
	assert_str(text).not_contains("\"job\"")


func test_details_prompt_is_for_the_named_customer() -> void:
	var text := _request(Prompts.customer_messages("Friday", "9:00pm", "fog", false, "Moon Tae-il", "man"))
	assert_str(text).contains("Moon Tae-il (a man)")
	assert_str(text).contains("\"job\"")
	assert_str(text).not_contains("\"name\"")


func test_customer_description_includes_gender_when_known() -> void:
	var data := _customer_data()
	data["gender"] = "woman"
	assert_str(Prompts.describe_person(data)).starts_with("Kim Ji-ho (a woman), 34, office worker")


func test_non_binary_customers_are_they_them() -> void:
	var named := _request(Prompts.customer_name_messages("Friday", "9:00pm", "fog", [], [], "non-binary"))
	assert_str(named).contains("They're non-binary, they/them")
	assert_str(named).not_contains("\"gender\"")  # the game decided it: only the name is asked for
	var details := _request(Prompts.customer_messages("Friday", "9:00pm", "fog", false, "Han Seol", "non-binary"))
	assert_str(details).contains("Han Seol (non-binary, they/them)")
	var data := _customer_data()
	data["gender"] = "non-binary"
	assert_str(Prompts.describe_person(data)).starts_with("Kim Ji-ho (non-binary, they/them), 34")


# --- The cat ----------------------------------------------------------------------------------

func _cat() -> Dictionary:
	return {"name": "Nabi", "coat": "ginger", "personality": "lazy"}


func test_dialogue_prompts_say_where_the_cat_is() -> void:
	var cat := Prompts.describe_cat(_cat(), "Nabi is curled up asleep by the stove.")
	assert_str(cat).contains("Nabi, the tent's ginger cat, lazy: sleeps most of the night")
	assert_str(cat).contains("nobody strokes it")
	var line := _request(Prompts.dialogue_messages(_owner_data(), _customer_data(), _moment(), "Soju", [], true, "", cat))
	assert_str(line).contains("Right now: Nabi is curled up asleep by the stove.")
	var chat := _request(Prompts.counter_chat_messages(_owner_data(), false, [_customer_data()], ["Soju"], _moment(), [], "Kim Ji-ho", "Lee Min-jun", "", cat))
	assert_str(chat).contains("THE CAT: Nabi")


func test_cat_name_prompt_knows_the_cat() -> void:
	var text := _request(Prompts.cat_name_messages(_owner_data(), "Golmok Pocha", "calico", "greedy"))
	assert_str(text).contains("a calico female cat, greedy")
	assert_str(text).contains("Korean pet name")


# --- Speaking English, and knowing only what you've been told --------------------------------

func test_dialogue_is_english_with_the_odd_korean_word() -> void:
	var text := str(Prompts.dialogue_messages(_owner_data(), _customer_data(), _moment(), "Soju", [], true, "")[0]["content"])
	assert_str(text).contains("Write in English")
	assert_str(text).contains("Western fans of K-dramas")
	assert_str(text).contains("Never whole sentences in Korean")


func test_nobody_knows_what_they_havent_been_told() -> void:
	assert_str(Prompts.describe_owner(_owner_data())).contains("Customers don't know the owner's past or secret")
	var person := Prompts.describe_person(_customer_data())
	assert_str(person).contains("Nobody else knows their name, age, job or why they're here unless they've said it")
	assert_str(person).contains("What anyone can see: A crumpled blazer.")


func test_details_prompt_asks_for_someone_different_from_tonights_others() -> void:
	var text := _request(Prompts.customer_messages("Friday", "9:00pm", "fog", false, "Moon Tae-il", "man", ["nurse", "office worker"], ["Dark circles and a messy bun."]))
	assert_str(text).contains("Jobs they've had: nurse, office worker. Pick a different job.")
	assert_str(text).contains("Dark circles and a messy bun.")
	var first := _request(Prompts.customer_messages("Friday", "9:00pm", "fog", false, "Moon Tae-il", "man"))
	assert_str(first).not_contains("Pick a different job")  # the first customer of the night has nobody to differ from


func test_the_cat_is_a_she_or_a_he() -> void:
	var cat := {"name": "Nabi", "coat": "ginger", "personality": "lazy", "sex": "he"}
	assert_str(Prompts.describe_cat(cat, "Nabi is asleep.")).contains("(a male: call the cat \"he\")")
	assert_str(_request(Prompts.cat_name_messages(_owner_data(), "Golmok Pocha", "black", "curious", "he", ["Ssal"]))).contains("Other tents' cats are called Ssal")


func test_everyone_speaks_fluently() -> void:
	var text := str(Prompts.dialogue_messages(_owner_data(), _customer_data(), _moment(), "Soju", [], true, "")[0]["content"])
	assert_str(text).contains("fluent, natural English in their own voice")
	assert_str(text).contains("never broken English")


func test_bar_look_prompt_offers_the_games_options() -> void:
	var text := _request(Prompts.bar_look_messages(_owner_data(), "Byeolbit Pocha", "Starlight Tent"))
	assert_str(text).contains("Byeolbit Pocha (Starlight Tent)")
	assert_str(text).contains("Hangul")
	for option in ["striped", "neon", "string_lights", "lucky_cat", "peaked (a peaked roof", "blue_stripes"]:
		assert_str(text).contains(option)


func test_bar_look_prompt_offers_only_the_games_shortlist() -> void:
	var offer := {"tarp": ["teal", "maroon"], "shape": ["awning"]}
	var text := _request(Prompts.bar_look_messages(_owner_data(), "Byeolbit Pocha", "Starlight Tent", offer))
	assert_str(text).contains("teal, maroon")
	assert_str(text).contains("awning (a flat awning")
	assert_str(text).not_contains("blue_stripes")
	assert_str(text).not_contains("peaked (")


func test_the_game_decided_look_goes_into_the_prompts() -> void:
	var look := {"age_range": "30s", "hair": "bob", "hair_colour": "black", "clothes": "trench", "colour": "beige", "glasses": false, "bag": ""}
	var details := _request(Prompts.customer_messages("Friday", "9:00pm", "fog", false, "Han Seol", "woman", [], [], look))
	assert_str(details).contains("black hair in a bob")
	assert_str(details).contains("beige trench coat")
	assert_str(details).contains("from 30 to 39")
	var owner_look := {"age_range": "60s", "hair": "perm", "hair_colour": "grey", "clothes": "cardigan", "colour": "camel", "apron": true}
	var the_owner := _request(Prompts.owner_messages("woman", owner_look))
	assert_str(the_owner).contains("greying perm")
	assert_str(the_owner).contains("from 60 to 69")


func test_regression_chats_know_everyones_sat_down_and_new_here() -> void:
	var person := {"name": "Han Seol", "gender": "woman", "age": 30, "job": "teacher", "mood": "tired", "reason": "A long day.", "speech_style": "soft"}
	var text := _request(Prompts.counter_chat_messages(_owner_data(), false, [person, person], ["soju", "beer"], {"day": "Friday", "time": "9:00pm", "weather": "fog"}, [], "Han Seol", "Han Seol", ""))
	assert_str(text).contains("already sitting")
	assert_str(text).contains("first time at this tent")
	assert_str(text).contains("busy elsewhere")
	assert_str(text).contains(str(_owner_data()["name"]))


func test_regression_new_customers_dont_copy_earlier_appearances() -> void:
	var look := {"age_range": "30s", "hair": "bob", "hair_colour": "black", "clothes": "trench", "colour": "beige"}
	var text := _request(Prompts.customer_messages("Friday", "9:00pm", "fog", false, "Han Seol", "woman", [], ["a dog-eared copy of The Stranger"], look))
	assert_str(text).not_contains("The Stranger")
	assert_str(text).contains("not an object")


func test_names_are_asked_for_in_hangul_too() -> void:
	assert_str(_request(Prompts.customer_name_messages("Friday", "9:00pm", "fog"))).contains("\"hangul\"")
	assert_str(_request(Prompts.customer_name_messages("Friday", "9:00pm", "fog", [], [], "non-binary"))).contains("\"hangul\"")
	assert_str(_request(Prompts.owner_messages("woman"))).contains("\"hangul\"")


func test_a_first_timer_is_a_stranger_and_a_regular_is_known() -> void:
	var stranger := {"name": "Han Seol", "gender": "woman"}
	assert_str(Prompts.describe_relationship(_owner_data(), stranger)).contains("first visit")
	var regular := {"name": "Han Seol", "gender": "woman", "regular": {"visits": 3, "nights_ago": 9, "usual": [], "owner_knows_name": false, "knows_owner_name": false}}
	var text := Prompts.describe_relationship(_owner_data(), regular)
	assert_str(text).contains("4th visit")
	assert_str(text).contains("a week ago")
	assert_str(text).contains("not their name")
	assert_str(text).contains("don't have a usual yet")
	assert_str(text).not_contains("first visit")
	regular["regular"].merge({"usual": ["soju", "tteokbokki"], "owner_knows_name": true}, true)
	text = Prompts.describe_relationship(_owner_data(), regular)
	assert_str(text).contains("the usual")
	assert_str(text).contains("Tteokbokki")
	assert_str(text).contains("knows their name, Han Seol")


func test_founding_regular_prompt_has_the_games_facts() -> void:
	var look := {"age_range": "40s", "hair": "short", "hair_colour": "black", "clothes": "work_jacket", "colour": "navy"}
	var text := _request(Prompts.founding_regular_messages(_owner_data(), "Golmok Pocha", "man", look, "fixture", "for 9 years", "most nights", ["soju", "sundae"], ["Park Mi-sook"]))
	assert_str(text).contains("for 9 years, most nights")
	assert_str(text).contains("end stool")
	assert_str(text).contains("Soju")
	assert_str(text).contains("Park Mi-sook")
	assert_str(text).contains("from 40 to 49")
	assert_str(text).contains("never the owner's secret")


func test_the_diary_prompt_has_the_nights_facts() -> void:
	var facts := {"episode": 12, "day": "Friday", "weather": "the first snow of winter", "owner": "Park Mi-sook", "customers": 14,
		"takings": "₩412,000", "takings_vs_usual": "better than usual", "busiest": "10:40pm, with 5 at the counter",
		"people": [{"name": "Kim Ji-ho", "job": "nurse", "regular": "a regular", "ordered": "Soju"}], "missing": ["Hwang Tae-oh"],
		"moments": [{"who": "Kim Ji-ho", "mood": "shock", "caption": "SHE QUIT HER JOB?!", "said": "I quit today."}],
		"friendlier": ["Kim Ji-ho and Lee Da-eun are on \"eonni\" terms now"], "new_regulars": ["Kim Ji-ho"], "cat": "Mandu",
		"cat_laps": ["Kim Ji-ho"], "walked_on": 2, "line": {"speaker": "Kim Ji-ho", "text": "I quit today."}}
	var text := _request(Prompts.diary_messages(_owner_data(), facts))
	for bit in ["episode 12", "Friday, the first snow of winter", "Kim Ji-ho (nurse, a regular, had Soju)", "SHE QUIT HER JOB?!", "I quit today.",
			"Hwang Tae-oh, a regular, didn't come in", "\"eonni\" terms", "looks like becoming a regular", "Mandu, the cat, sat on Kim Ji-ho's lap",
			"2 people had to walk on", "₩412,000, better than usual", "first person", "\"entry\"", "no numbers but the ones above"]:
		assert_str(text).contains(bit)


func test_the_recap_prompt_tells_last_time() -> void:
	var facts := {"episode": 13, "bar": "Donghwa Pocha", "owner_data": _owner_data(), "last_entry": "Ji-ho quit. Tae-oh didn't come.",
		"last": {"day": "Friday", "weather": "snow", "customers": 9, "takings": "₩300,000", "people": [], "missing": ["Hwang Tae-oh"]},
		"memories": ["Lee Da-eun, a regular: nervous about her exam."]}
	var text := _request(Prompts.recap_messages(facts))
	for bit in ["Donghwa Pocha", "Episode 13", "Previously on", "Ji-ho quit. Tae-oh didn't come.", "Hwang Tae-oh, a regular, didn't come in",
			"nervous about her exam", "present tense", "teaser", "\"beats\"", "no numbers but the ones above"]:
		assert_str(text).contains(bit)
	# One example teaser, picked by the game (given just one, the AI copied it).
	assert_str(text).contains("in the spirit of \"%s\", but your own" % Story.RECAP_TEASER_EXAMPLES[0])
	facts["teaser_example"] = Story.RECAP_TEASER_EXAMPLES[3]
	assert_str(_request(Prompts.recap_messages(facts))).contains(Story.RECAP_TEASER_EXAMPLES[3])
	assert_str(text).not_contains("Will they come back")


func test_the_owners_life_is_in_every_prompt() -> void:
	var the_owner := _owner_data()
	the_owner["family"] = "widowed young; a grown daughter in Daejeon"
	the_owner["before"] = "a fish stall at Jagalchi market"
	var text := Prompts.describe_owner(the_owner)
	assert_str(text).contains("widowed young; a grown daughter in Daejeon")
	assert_str(text).contains("a fish stall at Jagalchi market")
	assert_str(text).contains("never changes")
	assert_str(Prompts.describe_owner(_owner_data())).not_contains("never changes")  # an older owner, before it's filled in
	var asked := _request(Prompts.owner_messages("woman"))
	assert_str(asked).contains("\"family\"")
	assert_str(asked).contains("\"before\"")


func test_the_tv_reaction_prompt() -> void:
	var text := _request(Prompts.reaction_messages([{"speaker": "Kim Ji-ho", "text": "I quit my job today."}], ["Kim Ji-ho", "Park Mi-sook"]))
	assert_str(text).contains("I quit my job today.")
	assert_str(text).contains("Kim Ji-ho, Park Mi-sook")
	assert_str(text).contains("\"none\"")
	assert_str(text).contains("Most lines are this")
	for mood in Captions.REACTIONS:
		assert_str(text).contains("\"%s\"" % mood)
	assert_str(text).contains("at most five words")
	assert_str(text).contains("\"size\"")
	assert_str(text).contains("Only a %d or more gets a caption" % Captions.REACTION_MIN_SIZE)
	assert_str(text).contains("\"none\" if it's %d or less" % (Captions.REACTION_MIN_SIZE - 1))


func test_the_memory_prompt_and_a_regulars_memories() -> void:
	var customer := {"name": "Han Seol", "gender": "woman", "age": 30, "job": "teacher", "mood": "tired", "reason": "A long day.", "speech_style": "soft"}
	var text := _request(Prompts.memory_messages(_owner_data(), customer, [{"speaker": "Han Seol", "text": "My exam's on Friday."}], []))
	assert_str(text).contains("My exam's on Friday.")
	assert_str(text).contains("\"owner_remembers\"")
	assert_str(text).contains("\"night\"")
	assert_str(text).contains("didn't enjoy it")
	assert_str(text).contains("nothing invented")
	customer["regular"] = {"visits": 2, "usual": [], "memories": [{"night": 1, "owner": "Nervous about her exam on Friday.", "them": "The owner told her to sleep."}],
		"impression": "A quiet one.", "facts": {"job": "teacher", "home": "Daegu"}}
	var known := Prompts.describe_relationship(_owner_data(), customer)
	assert_str(known).contains("Nervous about her exam on Friday.")
	assert_str(known).contains("The owner told her to sleep.")
	assert_str(known).contains("A quiet one.")
	assert_str(known).contains("from: Daegu")


func test_regression_regulars_arent_strangers_in_customer_chats() -> void:
	var newcomer := {"name": "Moon Ji-yeon", "gender": "woman", "age": 30, "job": "teacher", "mood": "tired", "reason": "A long day.", "speech_style": "soft"}
	var fixture := {"name": "Kang Tae-il", "gender": "man", "age": 64, "job": "retired customs officer", "mood": "calm", "reason": "Wednesdays.", "speech_style": "dry",
		"regular": {"founding": true, "since": "for 12 years", "visits": 600, "knows_owner_name": true}}
	var family := fixture.duplicate(true)
	family["name"] = "Yoon Ji-hyun"
	var moment := {"day": "Friday", "time": "9:00pm", "weather": "fog"}
	var text := _request(Prompts.counter_chat_messages(_owner_data(), false, [newcomer, fixture], ["soju", "beer"], moment, [], "Kang Tae-il", "Moon Ji-yeon", ""))
	assert_str(text).contains("It's their first time at this tent")  # the newcomer
	assert_str(text).contains("long-time regular (coming for 12 years), and know the owner well")
	assert_str(text).contains("by name, Park Mi-sook")
	assert_str(text).not_contains("know each other: long-time")
	text = _request(Prompts.counter_chat_messages(_owner_data(), false, [fixture, family], ["soju", "beer"], moment, [], "Kang Tae-il", "Yoon Ji-hyun", ""))
	assert_str(text).contains("Kang Tae-il and Yoon Ji-hyun know each other")


func test_the_memory_prompt_says_what_each_verdict_means() -> void:
	var customer := {"name": "Han Seol", "gender": "woman", "age": 30, "job": "teacher", "mood": "tired", "reason": "A long day.", "speech_style": "soft"}
	var text := _request(Prompts.memory_messages(_owner_data(), customer, [], []))
	assert_str(text).contains("an ordinary good night")
	assert_str(text).contains("rare")
