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
