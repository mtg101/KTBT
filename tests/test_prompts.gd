extends GdUnitTestSuite
## Tests for scripts/prompts.gd: the facts the game puts into prompts must actually be there.
## These don't call the AI; they only check the text the game would send.

const Prompts = preload("res://scripts/prompts.gd")
const Menu = preload("res://scripts/menu.gd")


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
	assert_str(text).contains("never oppa, hyung, nuna or eonni")


func test_counter_chat_prompt_leaves_the_owner_out_unless_they_join() -> void:
	assert_str(_chat(false)).contains("isn't part of this conversation")
	assert_str(_chat(false)).not_contains("Park Mi-sook")
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
	assert_str(text).contains("never whole sentences in Korean")


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
