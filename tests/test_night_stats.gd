extends GdUnitTestSuite
## Tests for scripts/night_stats.gd: the debug stats and the night log.

const NightStats = preload("res://scripts/night_stats.gd")

const TEST_FOLDER := "user://test_stats/"

var _real_folder := ""


func before_test() -> void:
	_real_folder = NightStats.folder
	NightStats.folder = TEST_FOLDER
	_clear()


func after_test() -> void:
	_clear()
	NightStats.folder = _real_folder


func _clear() -> void:
	var dir := DirAccess.open(TEST_FOLDER)
	if dir == null:
		return
	for file_name in dir.get_files():
		dir.remove(file_name)


func test_ai_calls_are_counted_with_their_problems() -> void:
	var stats := NightStats.new()
	stats.record_ai(2.0, [], true)
	stats.record_ai(4.0, ["someone called Kim Ji-ho is already at the counter: pick a different name"], true)
	stats.record_ai(6.0, ["it wasn't a JSON object", "it wasn't a JSON object", "it left out \"line\""], false)
	assert_int(stats.ai_calls).is_equal(3)
	assert_float(NightStats.average(stats.ai_seconds)).is_equal(4.0)
	assert_int(stats.rejected).is_equal(4)
	assert_int(stats.gave_up).is_equal(1)
	assert_int(int(stats.rejections["missing or broken JSON"])).is_equal(3)
	# Most common first.
	assert_str(stats.rejection_text()).is_equal("missing or broken JSON 3, same name 1")


func test_averages_cope_with_nothing_yet() -> void:
	assert_float(NightStats.average([])).is_equal(0.0)
	assert_float(NightStats.longest([])).is_equal(0.0)
	assert_float(NightStats.shortest([])).is_equal(0.0)
	assert_int(NightStats.percent(1.0, 0.0)).is_equal(0)


func test_panel_shows_every_section() -> void:
	var stats := NightStats.new()
	stats.arrived = 7
	stats.chats_started = 2
	stats.chat_lines = 10
	stats.owner_lines = 30
	var text := stats.panel_text(3, 1)
	for part in ["PEOPLE", "TALK", "FOOD", "AI", "Arrived 7", "At the counter 3", "Wait for the owner", "Wait for first drinks", "on the stove now 1", "2 started, 10 lines (25% of all lines)"]:
		assert_str(text).contains(part)


func test_the_night_log_is_saved_as_json() -> void:
	var stats := NightStats.new()
	stats.served = 4
	stats.chats_started = 1
	var path := stats.save({"bar": "Golmok Pocha", "night": 3}, "golmok-pocha", 3)
	assert_str(path).ends_with("_golmok-pocha_night3.json")
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_int(int(data["people"]["served"])).is_equal(4)
	assert_int(int(data["talk"]["chats_started"])).is_equal(1)
	assert_str(str(data["context"]["bar"])).is_equal("Golmok Pocha")


func test_the_log_keeps_the_actual_reasons_with_what_was_asked() -> void:
	var stats := NightStats.new()
	var two_mains := "they ordered 2 main dishes, but most people order just one main (add a side instead)"
	stats.record_ai(1.0, [two_mains, two_mains], true, "order")
	stats.record_ai(1.0, ["there's no food: nobody drinks on an empty stomach, so order at least one food"], true, "order")
	var reasons: Dictionary = stats.summary({})["ai"]["rejection_reasons"]["order rules"]
	assert_int(int(reasons["order: " + two_mains])).is_equal(2)
	assert_int(reasons.size()).is_equal(2)


func test_how_full_the_tent_was() -> void:
	var stats := NightStats.new()
	stats.real_seconds = 100.0
	stats.seated_seconds = 150.0  # e.g. one person for half the night, two for the other half
	stats.together_seconds = 50.0
	assert_float(stats.average_seated()).is_equal(1.5)
	var text := stats.panel_text(2, 0)
	assert_str(text).contains("avg 1.5")
	assert_str(text).contains("Two or more in: 50% of the night")
	assert_float(float(stats.summary({})["people"]["average_seated"])).is_equal(1.5)


func test_chat_chances_are_counted() -> void:
	var stats := NightStats.new()
	stats.chat_chances = 10
	stats.chats_started = 2
	stats.chats_continued = 3
	assert_str(stats.panel_text(2, 0)).contains("Chat chances: 10 · taken 5 (2 new, 3 carried on)")
	assert_int(int(stats.summary({})["talk"]["chat_chances"])).is_equal(10)
	stats.free_turns = 30
	assert_str(stats.panel_text(2, 0)).contains("Owner free: 30 times (a chat possible in 10)")


func test_the_stats_count_the_nights_events() -> void:
	const NightEvents = preload("res://scripts/night_events.gd")
	var stats := NightStats.new()
	var events := NightEvents.new()
	events.happened.connect(stats.record_event)
	stats.events = events.timeline
	events.emit_event("arrived", 1100.0)
	events.emit_event("sat_down", 1100.0, {"seated": 3})
	events.emit_event("sat_down", 1110.0, {"seated": 2})
	events.emit_event("greeted", 1110.0, {"quick": true})
	events.emit_event("greeted", 1111.0, {"quick": false})
	events.emit_event("walked_on", 1120.0, {"first": true})
	events.emit_event("dish_served", 1130.0, {"wait": 8.0})
	events.emit_event("paid", 1140.0, {"bill": 26000})
	events.emit_event("chat_started", 1150.0)
	events.emit_event("joined_chat", 1151.0)
	events.emit_event("owner_joined", 1152.0)
	events.emit_event("became_regular", 1160.0)
	events.emit_event("friendlier", 1170.0)
	events.emit_event("big_moment", 1180.0, {"mood": "shock"})
	assert_int(stats.arrived).is_equal(1)
	assert_int(stats.peak_seated).is_equal(3)
	assert_int(stats.quick_greetings).is_equal(1)
	assert_int(stats.proper_greetings).is_equal(1)
	assert_int(stats.walked_past).is_equal(1)
	assert_int(stats.dishes_cooked).is_equal(1)
	assert_array(stats.food_waits).is_equal([8.0])
	assert_int(stats.served).is_equal(1)
	assert_int(stats.chats_started).is_equal(1)
	assert_int(stats.customer_joins).is_equal(1)
	assert_int(stats.owner_joins).is_equal(1)
	assert_int(stats.became_regulars).is_equal(1)
	assert_int(stats.friendlier_moments).is_equal(1)
	assert_int(int(stats.reactions_shown["shock"])).is_equal(1)
	# The timeline goes in the log, each event with its kind and time.
	var logged: Array = stats.summary({})["events"]
	assert_int(logged.size()).is_equal(14)
	assert_str(str(logged[0]["kind"])).is_equal("arrived")
	assert_int(int(logged[7]["bill"])).is_equal(26000)
	assert_int(int(logged[7]["at"])).is_equal(1140)
	# Every kind is counted, whether or not it has a stat of its own.
	assert_int(int(stats.event_counts["sat_down"])).is_equal(2)
	assert_int(int(stats.summary({})["event_counts"]["greeted"])).is_equal(2)


func test_everything_gets_counted() -> void:
	const NightEvents = preload("res://scripts/night_events.gd")
	const Talk = preload("res://scripts/rules/talk.gd")
	var stats := NightStats.new()
	var events := NightEvents.new()
	events.happened.connect(stats.record_event)
	events.emit_event("ordered", 1100.0, {"items": ["somaek", "dakgalbi"], "first": true})
	events.emit_event("ordered", 1130.0, {"items": ["somaek", "bokkeumbap"], "first": false})
	assert_int(int(stats.ordered["somaek"])).is_equal(2)
	assert_int(stats.first_orders).is_equal(1)
	assert_int(stats.extra_orders).is_equal(1)
	# Hints: given, and (roughly) taken up.
	stats.record_hint(Talk.moment_kind(Talk.SERVED_MOMENTS["dakgalbi"][0]), "Let me wrap you some ssam.")
	stats.record_hint(Talk.moment_kind(Talk.SERVED_MOMENTS["dakgalbi"][0]), "This is great.")
	stats.record_hint(Talk.moment_kind(Talk.sharing_moment("Kim Ji-ho", "Lee Min-jun", false, false, true, 0.0, 0.0)), "Here, let me top you up.")
	stats.record_hint("", "No hint, not counted.")
	assert_int(int(stats.hints_given["dakgalbi"])).is_equal(2)
	assert_int(int(stats.hints_taken["dakgalbi"])).is_equal(1)
	assert_int(int(stats.hints_taken["pour"])).is_equal(1)
	assert_str(stats.hints_text()).is_equal("dakgalbi 1/2 · pour 1/1")
	stats.record_hint("food", "Mm, this is good.")  # (no tell-tale words: just counted)
	assert_str(stats.hints_text()).is_equal("dakgalbi 1/2 · food ×1 · pour 1/1")
	# Korean words said, by word (two spellings of one word count together; names don't count).
	stats.record_line("Jjan! Ramen, ramyeon, aigoo, Imo.", ["Park Mi-sook"])
	stats.record_line("Jeong, more soju.", ["Jeong Min-ho"])
	assert_int(int(stats.korean_words["Ramyeon"])).is_equal(2)
	assert_int(int(stats.korean_words["Imo"])).is_equal(1)
	assert_int(int(stats.korean_words["Soju"])).is_equal(1)
	assert_str(NightStats.counts_text(stats.korean_words, 1)).is_equal("Ramyeon 2")
	var text := stats.panel_text(0, 0)
	for part in ["Orders 1 first, 1 more · somaek 2", "Hints taken up: dakgalbi 1/2", "Korean words said: Ramyeon 2", "EVERYTHING THAT HAPPENED", "ordered 2"]:
		assert_str(text).contains(part)
	# How samey lines are: their first two words, counted.
	stats.record_opening("order", "Ajumma, I'll have a soju.")
	stats.record_opening("order", "Ajumma, I'll take the odeng.")
	stats.record_opening("order", "Just a beer, please.")
	stats.record_opening("owner", "You look like you've had a day.")
	assert_str(stats.opening_text("order")).is_equal("\"ajumma i'll\" 2 of 3")
	assert_str(stats.opening_text("owner")).is_equal("\"you look\" 1 of 1")
	assert_str(stats.panel_text(0, 0)).contains("Commonest start: orders \"ajumma i'll\" 2 of 3")
	var logged := stats.summary({})
	assert_int(int(logged["talk"]["openings"]["order"]["ajumma i'll"])).is_equal(2)
	assert_int(int(logged["food"]["ordered"]["dakgalbi"])).is_equal(1)
	assert_int(int(logged["talk"]["korean_words"]["Aigoo"])).is_equal(1)
	assert_int(int(logged["talk"]["hints_given"]["pour"])).is_equal(1)
