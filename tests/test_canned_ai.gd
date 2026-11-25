extends GdUnitTestSuite
## Tests for offline mode: the canned AI (scripts/ai/canned_ai.gd) and the AI settings
## (scripts/ai/ai_settings.gd). Every canned reply must pass the same rules as a real AI reply.

const Channels = preload("res://scripts/rules/channels.gd")
const CannedAi = preload("res://scripts/ai/canned_ai.gd")
const AiSettings = preload("res://scripts/ai/ai_settings.gd")
const BarLook = preload("res://scripts/rules/bar_look.gd")
const Captions = preload("res://scripts/rules/captions.gd")
const CatRules = preload("res://scripts/rules/cat_rules.gd")
const Looks = preload("res://scripts/rules/looks.gd")
const Memories = preload("res://scripts/rules/memories.gd")
const Names = preload("res://scripts/rules/names.gd")
const Orders = preload("res://scripts/rules/orders.gd")
const People = preload("res://scripts/rules/people.gd")
const Story = preload("res://scripts/rules/story.gd")
const Talk = preload("res://scripts/rules/talk.gd")
const Menu = preload("res://scripts/rules/menu.gd")

const TRIES := 100
const TABLES := [
	["soju", "tteokbokki"],
	["beer", "ramyeon", "odeng"],
	["makgeolli", "pajeon", "pajeon"],
	["somaek", "gyeran_mari"],
	["soju", "dakgalbi", "bokkeumbap"],
]

var _canned: CannedAi


func before_test() -> void:
	_canned = CannedAi.new()
	CannedAi.scripted = []
	AiSettings.override = {}


func after_test() -> void:
	CannedAi.scripted = []
	AiSettings.override = {}


func test_canned_owners_pass_the_rules_for_their_gender() -> void:
	for gender in ["woman", "man"]:
		for owner_data in CannedAi.OWNERS[gender]:
			assert_str(People.validate_owner(owner_data.duplicate(), gender)).override_failure_message("%s fails: %s" % [owner_data["name"], People.validate_owner(owner_data.duplicate(), gender)]).is_empty()


func test_canned_customers_pass_the_rules() -> void:
	for customer in CannedAi.CUSTOMERS:
		assert_str(People.validate_customer(customer.duplicate())).override_failure_message("%s fails" % customer["name"]).is_empty()


func test_canned_orders_pass_the_rules_for_every_kind_of_customer() -> void:
	for limits in [[1, 1], [2, 1], [1, 2], [2, 2]]:
		for attempt in TRIES:
			var reply: Dictionary = _canned.reply({"purpose": "order", "title": "Ajumma", "max_mains": limits[0], "max_drinks": limits[1]})
			var problem := Orders.validate_order(reply, limits[0], limits[1])
			assert_str(problem).override_failure_message("%s -> %s" % [JSON.stringify(reply), problem]).is_empty()


func test_canned_extra_orders_pass_the_rules() -> void:
	for table in TABLES:
		for attempt in TRIES:
			var reply: Dictionary = _canned.reply({"purpose": "extra_order", "title": "Ajusshi", "table": table})
			var problem := Orders.validate_extra_order(reply, table)
			assert_str(problem).override_failure_message("%s on %s -> %s" % [JSON.stringify(reply), str(table), problem]).is_empty()


func test_canned_lines_pass_the_rules_on_any_table() -> void:
	for table in TABLES:
		for flags in [[true, true, false], [true, false, false], [false, false, false], [false, false, true]]:
			for attempt in 20:
				var reply: Dictionary = _canned.reply({"purpose": "line", "title": "Ajumma", "owner_speaks": flags[0], "first": flags[1], "last": flags[2]})
				var problem := Talk.validate_line(reply, "Speaker", "Ajumma", table)
				assert_str(problem).override_failure_message("%s -> %s" % [JSON.stringify(reply), problem]).is_empty()


func test_no_canned_line_mentions_anything_on_the_menu() -> void:
	var lines := CannedAi.OWNER_FIRST_LINES + CannedAi.OWNER_LINES + CannedAi.CUSTOMER_LINES + CannedAi.CUSTOMER_LAST_LINES
	for line in lines:
		assert_str(Orders.unordered_mention(str(line), [])).override_failure_message("\"%s\" mentions a menu item" % line).is_empty()


func test_canned_last_lines_say_goodbye() -> void:
	for attempt in 20:
		var reply: Dictionary = _canned.reply({"purpose": "line", "title": "Ajumma", "owner_speaks": false, "last": true})
		assert_bool(CannedAi.CUSTOMER_LAST_LINES.has(reply["line"]) or reply["line"].contains("Ajumma")).is_true()


func test_canned_replies_are_copies_not_the_originals() -> void:
	# Validators tidy replies in place; that must never change the canned library.
	var reply: Dictionary = _canned.reply({"purpose": "customer"})
	reply["name"] = "changed"
	for customer in CannedAi.CUSTOMERS:
		assert_str(str(customer["name"])).is_not_equal("changed")


func test_scripted_replies_are_used_first_and_in_order() -> void:
	# Raw JSON text and Dictionaries both work, including deliberately bad replies.
	CannedAi.scripted = ["{\"line\": \"first\"}", {"line": "second"}, {"wrong_key": "third"}]
	assert_str(str(_canned.reply({"purpose": "line"})["line"])).is_equal("first")
	assert_str(str(_canned.reply({"purpose": "line"})["line"])).is_equal("second")
	assert_bool(_canned.reply({"purpose": "line"}).has("wrong_key")).is_true()
	# Queue empty: back to normal canned replies.
	assert_bool(_canned.reply({"purpose": "line"}).has("line")).is_true()


func test_settings_override_picks_the_backend() -> void:
	AiSettings.override = {"backend": "canned"}
	assert_str(str(AiSettings.load_settings()["backend"])).is_equal("canned")


func test_unknown_backend_falls_back_to_auto() -> void:
	AiSettings.override = {"backend": "telepathy"}
	assert_str(str(AiSettings.load_settings()["backend"])).is_equal("auto")


func test_settings_always_include_server_and_model() -> void:
	var settings := AiSettings.load_settings()
	assert_str(str(settings["server"])).is_not_empty()
	assert_str(str(settings["model"])).is_not_empty()



func test_canned_bar_names_pass_the_rules() -> void:
	for bar_name in CannedAi.BAR_NAMES:
		assert_str(BarLook.validate_bar_name(bar_name.duplicate())).override_failure_message("%s fails" % bar_name["name"]).is_empty()
	for gender in ["woman", "man"]:
		for owner_data in CannedAi.OWNERS[gender]:
			for attempt in 10:
				var reply: Dictionary = _canned.reply({"purpose": "bar_name", "owner_name": owner_data["name"]})
				var problem := BarLook.validate_bar_name(reply)
				assert_str(problem).override_failure_message("%s -> %s" % [JSON.stringify(reply), problem]).is_empty()


func test_the_canned_niece_or_nephew_and_channels_pass_the_rules() -> void:
	for relation in ["niece", "nephew"]:
		for owner_data in CannedAi.OWNERS["woman"] + CannedAi.OWNERS["man"]:
			var reply: Dictionary = _canned.reply({"purpose": "relative", "relation": relation, "owner_name": owner_data["name"]})
			assert_str(Channels.validate_relative(reply)).override_failure_message(JSON.stringify(reply)).is_empty()
	for rung in ["video", "network"]:
		var taken: Array = []
		for k in 3:  # (each time a new one: never the same again)
			var channel: Dictionary = _canned.reply({"purpose": "channel", "rung": rung, "taken": taken})
			assert_str(Channels.validate_channel(channel, taken)).override_failure_message(JSON.stringify(channel)).is_empty()
			taken.append(str(channel["english"]))


func test_canned_customers_avoid_names_already_at_the_counter() -> void:
	var taken: Array = []
	for i in 5:
		var customer: Dictionary = _canned.reply({"purpose": "customer_name", "taken": taken})
		assert_str(Names.validate_customer_name(customer, taken)).override_failure_message("%s was already at the counter" % customer["name"]).is_empty()
		taken.append(customer["name"])


func test_canned_chat_lines_pass_the_rules() -> void:
	for flags in [[false, true], [false, false], [true, false]]:
		for attempt in 20:
			var reply: Dictionary = _canned.reply({"purpose": "chat_line", "owner_speaks": flags[0], "first": flags[1]})
			var problem := Talk.validate_line(reply, "Kim Ji-ho", "", ["beer", "tteokbokki"], ["Lee Min-jun"])
			assert_str(problem).override_failure_message("%s -> %s" % [JSON.stringify(reply), problem]).is_empty()


func test_no_canned_chat_line_mentions_food_or_close_terms() -> void:
	for line in CannedAi.CHAT_OPENERS + CannedAi.CHAT_LINES:
		assert_array(Orders.mentions(line, true)).override_failure_message(line).is_empty()
		assert_str(Talk.close_term(line)).override_failure_message(line).is_empty()


func test_canned_details_pass_the_rules_for_any_name() -> void:
	for named in [{"name": "Kim Ji-ho", "gender": "woman"}, {"name": "Moon Tae-il", "gender": "man"}]:
		var details: Dictionary = _canned.reply({"purpose": "customer", "name": named["name"], "gender": named["gender"]})
		assert_str(People.validate_customer_details(details)).is_empty()
		assert_str(str(details["gender"])).is_equal(named["gender"])


func test_canned_names_are_non_binary_only_when_the_game_says() -> void:
	for i in 50:
		var reply: Dictionary = _canned.reply({"purpose": "customer_name", "taken": []})
		assert_str(str(reply["gender"])).is_not_equal("non-binary")
	var nb: Dictionary = _canned.reply({"purpose": "customer_name", "taken": [], "gender": "non-binary"})
	assert_str(Names.validate_customer_name(nb, [], "non-binary")).is_empty()
	var details: Dictionary = _canned.reply({"purpose": "customer", "name": nb["name"], "gender": "non-binary"})
	assert_str(str(details["gender"])).is_equal("non-binary")
	assert_str(People.validate_customer_details(details)).is_empty()


func test_canned_cat_names_pass_the_rules() -> void:
	for i in 20:
		var reply: Dictionary = _canned.reply({"purpose": "cat_name"})
		assert_str(CatRules.validate_cat_name(reply, "Park Mi-sook")).is_empty()


func test_canned_bar_looks_pass_the_rules() -> void:
	for bar in CannedAi.BAR_NAMES + [{"name": "Mi-sook-ne Pocha"}]:
		var look: Dictionary = _canned.reply({"purpose": "bar_look", "bar_name": bar["name"]})
		assert_str(BarLook.validate_bar_look(look)).override_failure_message(JSON.stringify(look)).is_empty()


func test_canned_people_fit_the_games_look() -> void:
	var look := Looks.pick_look("man", "60s", "")
	var customer: Dictionary = _canned.reply({"purpose": "customer", "name": "Moon Tae-il", "gender": "man", "look": look})
	assert_str(People.validate_customer_details(customer, "60s")).is_empty()
	assert_str(str(customer["appearance"])).contains(str(Looks.CLOTHES[look["clothes"]]).trim_prefix("a ").split(" ")[0])
	var the_owner: Dictionary = _canned.reply({"purpose": "owner", "gender": "woman", "look": Looks.pick_look("woman", "70s", "", true)})
	assert_str(People.validate_owner(the_owner, "woman", "70s")).is_empty()


func test_every_canned_name_has_hangul_that_fits() -> void:
	for person in CannedAi.HANGUL:
		assert_str(Names.fit_hangul(person, CannedAi.HANGUL[person])).override_failure_message(person).is_equal(CannedAi.HANGUL[person])
	for cat in CatRules.CAT_NAMES:
		assert_str(Names.fit_hangul(cat, Names.CAT_HANGUL[cat])).override_failure_message(cat).is_equal(Names.CAT_HANGUL[cat])


func test_canned_founding_regulars_and_their_evenings_pass_the_rules() -> void:
	var look := Looks.pick_look("woman", "40s", "")
	var regular: Dictionary = _canned.reply({"purpose": "founding_regular", "taken": ["Park Mi-sook"], "gender": "woman", "look": look})
	assert_str(People.validate_founding_regular(regular, ["Park Mi-sook"], "woman", "40s")).is_empty()
	assert_str(People.validate_regular_tonight(_canned.reply({"purpose": "regular_tonight", "name": "Kim Ji-ho"}))).is_empty()


func test_the_canned_recap_passes_the_rules() -> void:
	var facts := {"episode": 2, "bar": "Donghwa Pocha", "owner": "Park Mi-sook", "names": ["Park Mi-sook", "Kim Ji-ho"], "regulars": [],
		"last": {"moments": [{"who": "Kim Ji-ho", "mood": "shock", "caption": "SHE QUIT?!", "said": "I quit today."}], "new_regulars": ["Kim Ji-ho"]}}
	var reply: Dictionary = _canned.reply({"purpose": "recap", "facts": facts})
	assert_str(Story.validate_recap(reply, facts)).is_empty()


func test_the_canned_diary_passes_the_rules() -> void:
	var facts := {"episode": 1, "day": "Friday", "weather": "a clear, cold night", "owner": "Park Mi-sook", "customers": 3,
		"people": [{"name": "Kim Ji-ho", "job": "nurse"}], "moments": [], "ordered": ["soju"], "cat": "Mandu", "cat_laps": ["Kim Ji-ho"]}
	var reply: Dictionary = _canned.reply({"purpose": "diary", "facts": facts})
	assert_str(Story.validate_diary(reply, facts)).is_empty()


func test_canned_tv_reactions_pass_the_rules() -> void:
	var names := ["Kim Ji-ho", "Park Mi-sook"]
	var shown := 0
	for i in TRIES:
		var reply: Dictionary = _canned.reply({"purpose": "reaction", "names": names})
		assert_str(Captions.validate_reaction(reply, names)).is_empty()
		if str(reply["mood"]) != "none":
			shown += 1
	@warning_ignore("integer_division")  # (whole numbers meant)
	assert_int(shown).is_between(1, TRIES / 2)  # mostly nothing


func test_canned_memories_pass_the_rules() -> void:
	for verdict in ["loved", "enjoyed", "fine", "didnt"]:
		var memory: Dictionary = _canned.reply({"purpose": "memory", "verdict": verdict})
		assert_str(Memories.validate_memory(memory, "")).is_empty()
		assert_str(str(memory["night"])).is_equal(verdict)
