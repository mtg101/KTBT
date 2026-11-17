extends GdUnitTestSuite
## Tests for scripts/bar/night_stats.gd: the debug stats and the night log.

const NightStats = preload("res://scripts/bar/night_stats.gd")
const Menu = preload("res://scripts/rules/menu.gd")
const Talk = preload("res://scripts/rules/talk.gd")
const Text = preload("res://scripts/rules/text.gd")

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
	for part in ["PEOPLE", "TALK", "FOOD", "AI", "Arrived 7", "At the counter 3", "Wait for the owner", "Wait for first drinks", "on the stove now 1", "2 started (0 drawing in someone quiet), 10 lines (25% of all lines)"]:
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
	const NightEvents = preload("res://scripts/bar/night_events.gd")
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
	const NightEvents = preload("res://scripts/bar/night_events.gd")
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
	# Who came in: genders, ages and moods for company, from their sitting down.
	events.emit_event("sat_down", 1200.0, {"seated": 1, "gender": "woman", "age_range": "20s", "company": "chatty"})
	events.emit_event("sat_down", 1210.0, {"seated": 2, "gender": "woman", "age_range": "50s", "company": "quiet"})
	events.emit_event("sat_down", 1220.0, {"seated": 3, "gender": "non-binary", "age_range": "20s", "company": "chatty"})
	stats.tipsy = 1
	assert_int(int(stats.who["woman"])).is_equal(2)
	assert_str(stats.panel_text(0, 0)).contains("Who: woman 2 · non-binary 1 · ages 20s 2 · 50s 1")
	assert_str(stats.panel_text(0, 0)).contains("Company: chatty 2 · quiet 1 · tipsy 1")
	# How the night opened and its diary.
	stats.story = {"loading_seconds": 12.4, "recap_style": "stormy", "recap_by": "ai", "diary_stamp": "early", "diary_by": "game"}
	assert_str(stats.panel_text(0, 0)).contains("Opening: loading 12s · recap stormy (ai)")
	assert_str(stats.panel_text(0, 0)).contains("Diary: stamp early (game)")
	assert_int(int(stats.summary({})["who"]["genders"]["non-binary"])).is_equal(1)
	assert_str(str(stats.summary({})["story"]["recap_style"])).is_equal("stormy")
	# The street, and the sides added to orders.
	stats.record_street("in twos")
	stats.record_street("umbrella: bubble")
	stats.record_street("umbrella: bubble")
	stats.sides_added = 2
	assert_str(stats.panel_text(0, 0)).contains("Street: umbrella: bubble 2 · in twos 1")
	assert_str(stats.panel_text(0, 0)).contains("sides added 2")
	var logged := stats.summary({})
	assert_int(int(logged["street"]["umbrella: bubble"])).is_equal(2)
	assert_int(int(logged["food"]["sides_added"])).is_equal(2)
	assert_int(int(logged["talk"]["openings"]["order"]["ajumma i'll"])).is_equal(2)
	assert_int(int(logged["food"]["ordered"]["dakgalbi"])).is_equal(1)
	assert_int(int(logged["talk"]["korean_words"]["Aigoo"])).is_equal(1)
	assert_int(int(logged["talk"]["hints_given"]["pour"])).is_equal(1)


func test_what_talk_turned_to_is_counted() -> void:
	var stats := NightStats.new()
	stats.record_topic("food_fight", true)
	stats.record_topic("ribbing", true)
	stats.record_topic("on_their_mind", false)
	stats.record_topic("the_cat", false)  # (neither light nor deep)
	stats.record_topic("", true)  # (nothing)
	stats.record_ai(1.0, [Talk.validate_line({"line": "You've put on weight!"}, "Kim Ji-ho", "")], true, "chat")
	assert_array(stats.topic_mix()).is_equal([2, 1])
	var text := stats.panel_text(0, 0)
	assert_str(text).contains("Talk turned to: light 2 · deep 1").contains("chat: food_fight").contains("Teasing that crossed the line (dropped): 1")
	var logged := stats.summary({})
	assert_dict(logged["talk"]["topics"]).is_equal({"chat: food_fight": 1, "chat: ribbing": 1, "owner: on_their_mind": 1, "owner: the_cat": 1})
	assert_int(logged["talk"]["crossed_the_line"]).is_equal(1)


func test_quiet_ones_drawn_into_chats_are_counted() -> void:
	var stats := NightStats.new()
	stats.record_event("chat_started", {"name": "Kim Ji-ho", "friend": "Oh Seong-jun", "drawn_in": true})
	stats.record_event("chat_started", {"name": "Kim Ji-ho", "friend": "Lee Min-jun"})
	assert_str(stats.panel_text(0, 0)).contains("Customer chats: 2 started (1 drawing in someone quiet)")
	assert_int(int(stats.summary({})["talk"]["chats_drawn_in"])).is_equal(1)


func test_big_moments_are_counted_by_the_talk_they_came_from() -> void:
	var stats := NightStats.new()
	assert_str(stats.panel_text(0, 0)).contains("Big moments from: (none yet)")
	stats.record_event("big_moment", {"mood": "funny", "ai_mood": "funny", "topic": "food_fight"})
	stats.record_event("big_moment", {"mood": "roast", "ai_mood": "sad", "topic": "on_their_mind"})  # (the AI's mood counts: the PD's spin is the edit's)
	stats.record_event("big_moment", {"mood": "sad", "ai_mood": "sad", "topic": ""})
	assert_str(stats.panel_text(0, 0)).contains("Big moments from: light talk (funny 1) · deep talk (sad 1) · other talk (sad 1)")
	assert_dict(stats.summary({})["captions"]["reactions"]["from"]).is_equal({"light": {"funny": 1}, "deep": {"sad": 1}, "other": {"sad": 1}})


func test_phrases_said_too_often_are_counted() -> void:
	var stats := NightStats.new()
	stats.record_line("Can't talk right now, I'm trying to drown my sorrows.")
	stats.record_line("You're trying to drown your sorrows?", ["Kang Yoon-ah"])
	assert_array(stats.worn_out()).is_empty()  # (twice isn't worn out)
	stats.record_line("I'm still drowning my sorrows after today's meetings.")
	assert_array(stats.worn_out()).contains(["drown my sorrow"])
	assert_str(stats.panel_text(0, 0)).contains("Said too often").contains("\"drown my sorrow\" 3")
	# Worn out: a line saying it again is sent back (however it's said), one that doesn't isn't.
	assert_str(stats.worn_out_in("Drowning your sorrows again, Imo?")).is_equal("drown my sorrow")
	assert_str(stats.worn_out_in("Another long day, then.")).is_empty()
	assert_str(Text.problem_kind("the line says «drown my sorrow», and that's been said a lot tonight already: say it another way")).is_equal("said too often")
	assert_array(stats.summary({})["talk"]["worn_out"]).contains([["drown my sorrow", 3]])


func test_the_pds_camera_is_counted() -> void:
	var stats := NightStats.new()
	assert_str(stats.panel_text(0, 0)).contains("THE PD").contains("Camera: not used tonight")
	stats.events = [{"kind": "camera_on", "name": "Kim Ji-ho", "at": 1300}, {"kind": "camera_on", "name": "Lee Min-jun", "at": 1330, "from": "Kim Ji-ho"},
		{"kind": "camera_off", "name": "Lee Min-jun", "why": "left", "at": 1345}, {"kind": "camera_on", "name": "Kim Ji-ho", "at": 1400}]
	assert_array(stats.camera_follows()).is_equal([{"name": "Kim Ji-ho", "minutes": 30}, {"name": "Lee Min-jun", "minutes": 15}, {"name": "Kim Ji-ho", "minutes": -1}])
	stats.record_camera_line(true)
	stats.record_camera_line(false)
	stats.record_hint("camera", "Is that a camera?")
	var text := stats.panel_text(0, 0)
	for part in ["Camera: followed 3 · Kim Ji-ho 30 min · Lee Min-jun 15 min · Kim Ji-ho (still on)", "Lines on camera 1 of 2 (50%)", "noticed the camera 1/1"]:
		assert_str(text).contains(part)
	assert_str(stats.hints_text()).not_contains("camera")  # (in its own section)
	assert_array(stats.highlights()).contains(["9:40pm  the camera follows Kim Ji-ho"])
	var logged := stats.summary({})
	assert_array(logged["pd"]["lines_on_camera"]).is_equal([1, 2])
	assert_array(logged["pd"]["noticed_camera"]).is_equal([1, 1])
	assert_int(logged["pd"]["camera"].size()).is_equal(3)
	# The plant cards: played, and whether the lines given them took them up.
	assert_str(stats.panel_text(0, 0)).contains("Plants: none played tonight")
	stats.events.append({"kind": "plant_played", "card": "phone", "name": "Kim Ji-ho", "at": 1410})
	stats.record_hint("plant_phone", "Sorry, I have to take this call.")
	stats.record_hint("plant_phone", "Anyway.")
	assert_str(stats.panel_text(0, 0)).contains("Plants: played 1 · phone taken up 1/2")
	assert_array(stats.highlights()).contains(["11:30pm  plant: phone (Kim Ji-ho)"])
	assert_array(stats.summary({})["pd"]["plants"]["phone"]).is_equal([1, 2, 1, 0])
	# ... and whether it came up at all, in anyone's lines (the owner's too), soon after.
	stats.record_event("plant_played", {"card": "rain", "name": ""})
	stats.events.append({"kind": "plant_played", "card": "rain", "name": "", "at": 1420})
	stats.record_line("Be careful, it's pouring out there.")
	stats.record_line("Another soju, please.")
	for _k in NightStats.PLANT_WATCH_LINES:
		stats.record_line("Look at all that rain!")  # (past the watch: not counted)
	assert_array(stats.plants()["rain"]).is_equal([1, 0, 0, NightStats.PLANT_WATCH_LINES - 1])
	assert_str(stats.panel_text(0, 0)).contains("rain taken up 0/0, came up in %d lines after" % [NightStats.PLANT_WATCH_LINES - 1])
	# A card for someone is watched for as long as they're here (night 25: the sponsor's keyring came up 25 lines on).
	stats.record_event("plant_played", {"card": "ppl", "name": "Kim Min-seok"})
	for _k in NightStats.PLANT_WATCH_LINES * 2:
		stats.record_line("Snow's still coming down.")
	stats.record_line("Take the Dalbit Taxi keyring with you, it's on the table.")
	stats.record_event("left", {"name": "Kim Min-seok"})
	stats.record_line("A taxi home, then?")  # (gone: not counted)
	assert_int(int(stats.plant_mentions.get("ppl", 0))).is_equal(1)
	assert_bool(stats.plant_watch.has("ppl")).is_false()
	assert_str(stats.hints_text()).not_contains("plant_")
	# What the PD wrote: the words, who for, and the replies (for the log), and taken up by its own words.
	stats.record_written("cue_card", "her first love", "Kim Ji-ho", "", ["first", "love"])
	stats.record_written_line("Kim Ji-ho", ["Kim Ji-ho", "Lee Min-jun"], "My first love? Don't ask.")
	stats.record_written_line("Park Mi-sook", ["Kang Da-eun"], "Somewhere else entirely.")
	stats.record_hint("plant_cue_card", "My first love? Don't ask.")
	assert_int(int(stats.hints_taken.get("plant_cue_card", 0))).is_equal(1)
	assert_array(stats.written[0]["lines"]).is_equal(["Kim Ji-ho: My first love? Don't ask."])
	assert_str(stats.panel_text(0, 0)).contains("Written (cue_card, for Kim Ji-ho): «her first love»")
	assert_str(str(stats.summary({})["pd"]["written"][0]["text"])).is_equal("her first love")


func test_the_pocha_life_has_a_section_of_its_own() -> void:
	var stats := NightStats.new()
	stats.story = {"date": "15 November", "season": "late autumn", "weather": "thick fog"}
	stats.record_hint("game_spoon_mic", "Pass me that spoon, I'm singing!")
	stats.record_hint("game_titanic", "What a night.")
	stats.events = [{"kind": "table_game_offered", "game": "spoon_mic"}, {"kind": "table_game", "game": "spoon_mic"}, {"kind": "table_game_offered", "game": "titanic"}]
	stats.record_hint("stunned", "Mwo?! You quit?")
	stats.record_hint("soju", "Another glass, then.")
	stats.rituals = {"kya": 3, "tornado": 2}
	stats.record_event("cheered_on", {})
	var text := stats.panel_text(0, 0)
	for part in ["TONIGHT", "15 November, late autumn · thick fog", "POCHA LIFE", "Rituals: kya 3 · tornado 2", "Table games: offered 2, taken up 1",
			"spoon_mic 1/1", "titanic 0/1", "Double-takes: offered 1, taken up 1 · hwaiting chorus 1", "FOOD AND THE MENU"]:
		assert_str(text).contains(part)
	assert_str(stats.hints_text()).contains("soju").not_contains("game_").not_contains("stunned")  # (the pocha's own in their own section)
	var logged := stats.summary({})
	assert_array(logged["pocha_life"]["table_games"]["spoon_mic"]).is_equal([1, 1])
	assert_int(int(logged["pocha_life"]["hwaiting_chorus"])).is_equal(1)
	assert_str(str(logged["tonight"]["season"])).is_equal("late autumn")
	assert_int(int(logged["menu"]["board_opened"])).is_equal(0)
	# The bar's signature dishes, and how often they're ordered.
	Menu.use(Menu.ITEMS + [{"id": "own_halmeoni_kalguksu", "name": "Halmeoni Kalguksu", "hangul": "할머니 칼국수", "kind": "food", "price": 9000, "signature": true}])
	stats.ordered["own_halmeoni_kalguksu"] = 2
	stats.story["signatures_by"] = "ai"
	assert_str(stats.panel_text(0, 0)).contains("Signature dishes: Halmeoni Kalguksu 2 ordered (new tonight, by the ai)")
	assert_int(int(stats.summary({})["menu"]["signatures"]["Halmeoni Kalguksu"])).is_equal(2)
	Menu.use([])



func test_the_highlights_list_tonights_special_moments_in_order() -> void:
	var stats := NightStats.new()
	assert_str(stats.panel_text(0, 0)).contains("HIGHLIGHTS").contains("(nothing special yet)")
	stats.events = [
		{"kind": "sat_down", "at": 21 * 60, "seated": 2},
		{"kind": "table_game_offered", "at": 21 * 60 + 12, "game": "spoon_mic"},
		{"kind": "cheered_on", "at": 21 * 60 + 58},
		{"kind": "sat_down", "at": 22 * 60, "seated": 5},
		{"kind": "sat_down", "at": 22 * 60 + 5, "seated": 5},
		{"kind": "cat_stole", "at": 23 * 60 + 20, "name": "Min-jun"},
		{"kind": "cliffhanger_answered", "at": 24 * 60 + 5, "cliffhanger": "stays_away", "name": "Jin-seok"},
		{"kind": "table_game_offered", "at": 24 * 60 + 10, "game": "nunchi"},
		{"kind": "table_game", "at": 24 * 60 + 16, "game": "nunchi"},
		{"kind": "table_game_offered", "at": 24 * 60 + 40, "game": "nunchi"},
		{"kind": "ordered", "at": 24 * 60 + 41}]
	assert_array(stats.highlights()).is_equal([
		"9:12pm  table game offered: spoon_mic (not taken up)",
		"9:58pm  hwaiting chorus",
		"10:00pm  full house",
		"11:20pm  the cat stole a fish cake (from Min-jun)",
		"12:05am  CLIFFHANGER CAME TRUE (stays_away, Jin-seok)",
		"12:10am  table game offered: nunchi (taken up!)",
		"12:16am  TABLE GAME: nunchi",
		"12:40am  table game offered: nunchi (not taken up)"])  # (the second offer isn't the first one's game)
	var text := stats.panel_text(0, 0)
	assert_int(text.find("HIGHLIGHTS")).is_less(text.find("PEOPLE"))  # (first thing on the panel)
	assert_array(stats.summary({})["highlights"]).has_size(8)
	var sections := stats.sections(0, 0)
	assert_str(str(sections[0]["tab"])).is_equal("Highlights 8")  # (the panel's tabs: one section each)
	assert_str(str(sections[0]["text"])).starts_with("9:12pm").not_contains("PEOPLE")
	assert_array(sections.map(func(s): return s["tab"])).contains(["People", "Talk", "Pocha life", "Menu", "AI", "Everything"])
