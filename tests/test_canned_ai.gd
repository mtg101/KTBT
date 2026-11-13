extends GdUnitTestSuite
## Tests for offline mode: the canned AI (scripts/canned_ai.gd) and the AI settings
## (scripts/ai_settings.gd). Every canned reply must pass the same rules as a real AI reply.

const CannedAi = preload("res://scripts/canned_ai.gd")
const AiSettings = preload("res://scripts/ai_settings.gd")
const Rules = preload("res://scripts/rules.gd")
const Menu = preload("res://scripts/menu.gd")

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
			assert_str(Rules.validate_owner(owner_data.duplicate(), gender)).override_failure_message("%s fails: %s" % [owner_data["name"], Rules.validate_owner(owner_data.duplicate(), gender)]).is_empty()


func test_canned_customers_pass_the_rules() -> void:
	for customer in CannedAi.CUSTOMERS:
		assert_str(Rules.validate_customer(customer.duplicate())).override_failure_message("%s fails" % customer["name"]).is_empty()


func test_canned_orders_pass_the_rules_for_every_kind_of_customer() -> void:
	for limits in [[1, 1], [2, 1], [1, 2], [2, 2]]:
		for attempt in TRIES:
			var reply: Dictionary = _canned.reply({"purpose": "order", "title": "Ajumma", "max_mains": limits[0], "max_drinks": limits[1]})
			var problem := Rules.validate_order(reply, limits[0], limits[1])
			assert_str(problem).override_failure_message("%s -> %s" % [JSON.stringify(reply), problem]).is_empty()


func test_canned_extra_orders_pass_the_rules() -> void:
	for table in TABLES:
		for attempt in TRIES:
			var reply: Dictionary = _canned.reply({"purpose": "extra_order", "title": "Ajusshi", "table": table})
			var problem := Rules.validate_extra_order(reply, table)
			assert_str(problem).override_failure_message("%s on %s -> %s" % [JSON.stringify(reply), str(table), problem]).is_empty()


func test_canned_lines_pass_the_rules_on_any_table() -> void:
	for table in TABLES:
		for flags in [[true, true, false], [true, false, false], [false, false, false], [false, false, true]]:
			for attempt in 20:
				var reply: Dictionary = _canned.reply({"purpose": "line", "title": "Ajumma", "owner_speaks": flags[0], "first": flags[1], "last": flags[2]})
				var problem := Rules.validate_line(reply, "Speaker", "Ajumma", table)
				assert_str(problem).override_failure_message("%s -> %s" % [JSON.stringify(reply), problem]).is_empty()


func test_no_canned_line_mentions_anything_on_the_menu() -> void:
	var lines := CannedAi.OWNER_FIRST_LINES + CannedAi.OWNER_LINES + CannedAi.CUSTOMER_LINES + CannedAi.CUSTOMER_LAST_LINES
	for line in lines:
		assert_str(Rules.unordered_mention(str(line), [])).override_failure_message("\"%s\" mentions a menu item" % line).is_empty()


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
