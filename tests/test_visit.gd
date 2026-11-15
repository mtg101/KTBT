extends GdUnitTestSuite
## Click-through tests for the visit scene: load the real scene, click the real button with
## simulated mouse input, and check what happens. The AI is offline mode (the canned AI),
## sometimes with scripted replies, so these run without Ollama, quickly and repeatably.

const Visit = preload("res://scripts/visit.gd")
const Ai = preload("res://scripts/ai.gd")
const AiSettings = preload("res://scripts/ai_settings.gd")
const CannedAi = preload("res://scripts/canned_ai.gd")
const Rules = preload("res://scripts/rules.gd")
const Regulars = preload("res://scripts/regulars.gd")
const Prompts = preload("res://scripts/prompts.gd")
const Menu = preload("res://scripts/menu.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const NightStats = preload("res://scripts/night_stats.gd")

const SCENE := "res://scenes/visit.tscn"
const TEST_SAVES := "user://test_saves_visit/"
const TIMEOUT_MS := 15000

## A reply that's valid for either gender of owner (the archetype names no gendered term).
const ANY_OWNER := {"name": "Han Jeong-hee", "age": 47, "archetype": "former chef who walked out of a hotel kitchen", "appearance": "Sleeves rolled up.", "personality": "proud, funny", "speech_style": "quick and teasing", "secret": "She still gets job offers from the hotel."}
const A_BAR_NAME := {"name": "Golmok Pocha", "meaning": "Back Alley Tent"}
const A_CAT_NAME := {"name": "Dubu"}
const A_LOOK := {"hangul": "골목 포차", "tarp": "blue", "sign": "neon", "shape": "peaked", "touches": ["radio", "lanterns"]}
## A customer comes in two steps: their name and gender, then the rest.
const A_NAME := {"name": "Kim Ji-ho", "gender": "woman"}
const A_CUSTOMER := {"name": "Kim Ji-ho", "age": 34, "job": "office worker", "mood": "worn out", "reason": "Her team lead took credit for her work again.", "speech_style": "dry, tired", "appearance": "A crumpled blazer."}


var _real_saves := "user://saves/"  # (never "", which would save into the project folder)
var _real_stats := "user://stats/"
const TEST_TRANSCRIPTS := "user://test_transcripts_visit/"
const TEST_STATS := "user://test_stats_visit/"


func before_test() -> void:
	_real_saves = SaveStore.folder
	SaveStore.folder = TEST_SAVES
	_real_stats = NightStats.folder
	NightStats.folder = TEST_STATS  # night logs go here, not among real ones
	_clear_folder(TEST_STATS)
	Visit.transcript_folder = TEST_TRANSCRIPTS  # and transcripts, not into the project
	_clear_folder(TEST_TRANSCRIPTS)
	_clear_saves()
	Game.bar = {}  # a new bar each test
	AiSettings.override = {"backend": "canned"}
	CannedAi.scripted = []
	Visit.pause_scale_override = 0.01
	Visit.random_seed = 1234
	Visit.run_clock = false  # no automatic customers: these tests click Next customer themselves


func after_test() -> void:
	_clear_saves()
	SaveStore.folder = _real_saves
	_clear_folder(TEST_STATS)
	NightStats.folder = _real_stats
	_clear_folder(TEST_TRANSCRIPTS)
	Visit.transcript_folder = ""
	Game.bar = {}
	Ai.simulate_unreachable = false
	AiSettings.override = {}
	CannedAi.scripted = []
	Visit.pause_scale_override = -1.0
	Visit.random_seed = 0
	Visit.run_clock = true
	Visit.stay_minutes_override = -1
	Visit.company_override = ""
	Visit.chat_chance_override = -1.0
	Visit.gender_override = ""
	Visit.cat_wanders = true
	Visit.strollers = true
	Visit.offer_every_look = true
	Visit.bubbles = false  # lines as fast as the AI writes them (one test turns them on)
	Visit.founding_regulars = false  # (they would use up scripted replies; their own tests turn them on)
	Visit.regular_roll_override = 1.0  # nobody becomes a regular unless a test says so
	Visit.memories = false  # (an extra AI call per visit; memory tests turn it on)
	Visit.reactions = false  # (an extra AI call after a spell of talk; reaction tests turn it on)
	Visit.captions = true
	Visit.caption_pacing = false  # every caption shows, so tests can look for them (pacing has its own rule tests)
	Ambience.make_sound = false  # quiet tests (and quick ones)
	Ambience.settings_path = "user://test_settings.cfg"
	Ai.canned_think_seconds = 0.0


# --- Helpers ---------------------------------------------------------------------------

func _clear_folder(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name in dir.get_files():
		dir.remove(file_name)


func _clear_saves() -> void:
	var dir := DirAccess.open(TEST_SAVES)
	if dir == null:
		return
	for file_name in dir.get_files():
		dir.remove(file_name)


## Waits (a frame at a time) until condition() is true. Returns false on timeout.
func _wait_until(condition: Callable, timeout_ms := TIMEOUT_MS) -> bool:
	var start := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - start > timeout_ms:
			return false
		await get_tree().process_frame
	return true


## Clicks a button the way a player would: move the mouse over it and press.
func _click(runner: GdUnitSceneRunner, button: Button) -> void:
	# Let layouts settle first: a button that's only just appeared (like Try again) may not
	# be in its place yet.
	for i in 3:
		await get_tree().process_frame
	runner.simulate_mouse_move(button.get_global_rect().get_center())
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()


## Loads the scene and waits until the owner is in and the button is ready.
func _open_bar() -> GdUnitSceneRunner:
	var runner := scene_runner(SCENE)
	var scene = runner.scene()
	var bar_open: bool = await _wait_until(func(): return not scene.busy and not scene._owner.is_empty())
	assert_bool(bar_open).override_failure_message("the owner never arrived").is_true()
	return runner


## Someone turns up, and this waits for their whole visit to finish.
func _run_one_visit(runner: GdUnitSceneRunner) -> void:
	var scene = runner.scene()
	_crowd(scene, 1)
	assert_bool(scene.busy).override_failure_message("nobody turned up").is_true()
	var done: bool = await _wait_until(func(): return not scene.busy)
	assert_bool(done).override_failure_message("the visit never finished").is_true()
	await get_tree().process_frame  # let freed dishes disappear


func _transcript(runner: GdUnitSceneRunner) -> String:
	return (runner.find_child("Transcript") as RichTextLabel).get_parsed_text()


# --- Tests -------------------------------------------------------------------------------

func test_owner_arrives_and_the_bar_is_ready() -> void:
	var runner := await _open_bar()
	assert_bool((runner.find_child("TryAgainButton") as Button).visible).is_false()
	assert_bool((runner.find_child("Owner") as Control).visible).is_true()
	assert_str(_transcript(runner)).contains("opens up for the night")


func test_offline_mode_is_clearly_marked() -> void:
	var runner := await _open_bar()
	var badge := runner.find_child("ModeLabel") as Label
	assert_bool(badge.visible).is_true()
	assert_str(badge.text).is_equal("OFFLINE MODE")


func test_clicking_next_customer_plays_a_whole_visit() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	await _run_one_visit(runner)
	var text := _transcript(runner)
	assert_str(text).contains("Served:")
	assert_str(text).contains("with the free banchan")
	assert_str(text).contains("heads back out into the night")
	# The bill is the game's: exactly the menu prices of everything they ordered.
	assert_int(scene._takings).is_equal(Rules.bill(scene._order))
	assert_int(scene._takings).is_greater(0)
	assert_str((runner.find_child("TakingsLabel") as Label).text).is_equal("Takings: %s" % Menu.format_won(scene._takings))
	# They've gone, and the counter's clear.
	assert_array(scene._guests).is_empty()
	assert_int(scene._table_item_count()).is_equal(0)


# --- Several at once ---------------------------------------------------------------------

## As if this many people turned up at the same moment.
func _crowd(scene, count: int) -> void:
	for i in count:
		scene._arrive(scene._clock)


func test_several_customers_sit_at_once() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 3)
	var together: bool = await _wait_until(func(): return scene._guests.size() >= 2)
	assert_bool(together).override_failure_message("never more than one customer at a time").is_true()
	assert_bool(await _wait_until(func(): return not scene.busy)).override_failure_message("the customers never all left").is_true()
	# Everyone paid, and the takings are exactly their bills added up.
	var saved := SaveStore.load_bar(str(Game.bar["id"]))
	assert_int(int(saved["visits"])).is_equal(3)
	var bills := 0
	for visit in saved["history"]:
		bills += int(visit["bill"])
	assert_int(scene._takings).is_equal(bills)
	assert_int(scene._table_item_count()).is_equal(0)


func test_there_are_only_five_stools() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 7)
	var full: bool = await _wait_until(func(): return scene._guests.size() == 5)
	assert_bool(full).override_failure_message("the tent never filled up").is_true()
	assert_int(scene._waiting.size()).is_equal(2)  # the other two wait for a stool
	var most := [0]
	var seats_ok := [true]
	var watch := func() -> bool:
		most[0] = maxi(most[0], scene._guests.size())
		var seats := {}
		for guest in scene._guests:
			if seats.has(guest.seat):
				seats_ok[0] = false
			seats[guest.seat] = true
		return not scene.busy
	var done: bool = await _wait_until(watch, 30000)
	assert_bool(done).is_true()
	assert_int(most[0]).is_equal(5)
	assert_bool(seats_ok[0]).override_failure_message("two customers shared a stool").is_true()
	assert_int(int(Game.bar["visits"])).is_equal(7)


## Ends everyone's stay, so they say goodbye and go (for tests that kept them seated).
func _time_up(scene) -> void:
	for guest in scene._guests:
		guest.stay_left = 0.0


func test_someone_who_waits_too_long_walks_past() -> void:
	Visit.stay_minutes_override = 600  # nobody leaves, so the tent stays full
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 6)
	assert_bool(await _wait_until(func(): return scene._guests.size() == 5)).is_true()
	scene._clock += Rules.GIVE_UP_MINUTES + 1  # the one left waiting has waited long enough
	assert_bool(await _wait_until(func(): return scene._passers_by == 1)).override_failure_message("nobody gave up").is_true()
	assert_array(scene._waiting).is_empty()
	assert_str(_transcript(runner)).contains("sees every stool taken, and walks on")
	# They really walk past: on screen now, gone once they've walked on.
	var passer := runner.find_child("PasserBy1", true, false) as Control
	assert_object(passer).is_not_null()
	assert_bool(await _wait_until(func(): return not is_instance_valid(passer))).override_failure_message("the passer-by never left").is_true()
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy, 30000)).is_true()
	assert_int(int(Game.bar["visits"])).is_equal(5)


func test_cooked_food_waits_at_the_stove() -> void:
	var order := {"items": ["beer", "tteokbokki"], "line": "A cold beer and the tteokbokki, please."}
	CannedAi.scripted = [ANY_OWNER, A_BAR_NAME, A_CAT_NAME, A_LOOK, A_NAME, A_CUSTOMER, order]
	var runner := await _open_bar()
	await _run_one_visit(runner)
	var text := _transcript(runner)
	# The beer comes straight away; the tteokbokki goes on the stove and is carried over later.
	assert_str(text).contains("Served: Beer, with the free banchan")
	assert_str(text).contains("On the stove: Tteokbokki")
	assert_str(text).contains("brings the Tteokbokki over to Kim Ji-ho")
	assert_int(text.find("On the stove: Tteokbokki")).is_less(text.find("brings the Tteokbokki over"))


func test_the_ai_hears_what_is_still_cooking() -> void:
	var order := {"items": ["beer", "dakgalbi"], "line": "A beer and the dakgalbi, please."}
	CannedAi.scripted = [ANY_OWNER, A_BAR_NAME, A_CAT_NAME, A_LOOK, A_NAME, A_CUSTOMER, order]
	Visit.pause_scale_override = 1.0  # slow the stove, so the dakgalbi is still cooking for the first line
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 1)
	var seated: bool = await _wait_until(func(): return not scene._guests.is_empty() and scene._guests[0].line > 0)
	assert_bool(seated).is_true()
	var guest = scene._guests[0]
	assert_str(scene._table_text(guest)).contains("Still cooking")
	assert_str(scene._table_text(guest)).contains("Dakgalbi")
	var told := false
	for entry in guest.transcript:
		if entry.has("action") and str(entry["action"]).contains("puts Dakgalbi on the stove; it isn't ready yet"):
			told = true
	assert_bool(told).is_true()


func test_the_owner_moves_between_customers() -> void:
	Visit.stay_minutes_override = 600
	Visit.chat_chance_override = 0.0  # just the owner talking
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 2)
	assert_bool(await _wait_until(func(): return _transcript(runner).contains("turns back to"))).is_true()
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()
	var text := _transcript(runner)
	assert_str(text).contains("turns back to")
	# With two in, the owner's lines say who they're talking to.
	assert_str(text).contains(") to ")


func test_takings_add_up_over_several_visits() -> void:
	# Covers later orders too: whatever they add partway through goes on the bill.
	var runner := await _open_bar()
	var scene = runner.scene()
	var expected := 0
	for visit in 4:
		await _run_one_visit(runner)
		expected += Rules.bill(scene._order)
		assert_int(scene._takings).is_equal(expected)


func test_a_bad_owner_reply_is_retried() -> void:
	CannedAi.scripted = [{"name": "Nobody", "age": 12}]  # missing fields and far too young
	var runner := await _open_bar()
	var scene = runner.scene()
	# The bad reply really was handed to the game...
	assert_array(CannedAi.scripted).override_failure_message("the scripted bad reply was never used").is_empty()
	# ...rejected, and replaced by a valid owner on the retry.
	assert_bool((runner.find_child("Owner") as Control).visible).is_true()
	assert_str(str(scene._owner["name"])).is_not_equal("Nobody")
	assert_int(int(scene._owner["age"])).is_greater_equal(Rules.MIN_OWNER_AGE)


func test_owner_that_cant_be_invented_offers_try_again() -> void:
	CannedAi.scripted = [{"bad": 1}, {"bad": 2}, {"bad": 3}]
	var runner := scene_runner(SCENE)
	var scene = runner.scene()
	var button := runner.find_child("TryAgainButton") as Button
	var gave_up: bool = await _wait_until(func(): return button.visible)
	assert_bool(gave_up).is_true()
	assert_bool((runner.find_child("Owner") as Control).visible).is_false()
	# Trying again (the queue's empty now) brings the owner in.
	await _click(runner, button)
	var arrived: bool = await _wait_until(func(): return not scene.busy and not scene._owner.is_empty())
	assert_bool(arrived).is_true()
	assert_bool(button.visible).is_false()


func test_order_falls_back_to_soju_and_odeng_when_the_ai_keeps_failing() -> void:
	CannedAi.scripted = [ANY_OWNER, A_BAR_NAME, A_CAT_NAME, A_LOOK, A_NAME, A_CUSTOMER, {"items": ["pizza"], "line": "Pizza!"}, {"items": []}, {"nope": true}]
	var runner := await _open_bar()
	var scene = runner.scene()
	await _run_one_visit(runner)
	assert_str(_transcript(runner)).contains("so the game served soju and odeng")
	assert_array(scene._order.slice(0, 2)).contains_exactly(["soju", "odeng"])


func test_unreachable_ollama_switches_to_offline_mode() -> void:
	# Auto mode with Ollama "unreachable" (a test hook, so this doesn't depend on how long
	# Windows takes to refuse a connection): the game should go offline and carry on.
	AiSettings.override = {"backend": "auto"}
	Ai.simulate_unreachable = true
	var runner := scene_runner(SCENE)
	var scene = runner.scene()
	var bar_open: bool = await _wait_until(func(): return not scene.busy and not scene._owner.is_empty())
	assert_bool(bar_open).is_true()
	assert_bool((runner.find_child("ModeLabel") as Label).visible).is_true()
	assert_str(_transcript(runner)).contains("switched to offline mode")
	await _run_one_visit(runner)
	assert_int(scene._takings).is_greater(0)


func test_ollama_backend_never_falls_back() -> void:
	# "ollama" means real AI or nothing: no offline mode, and the owner can't be invented.
	AiSettings.override = {"backend": "ollama"}
	Ai.simulate_unreachable = true
	var runner := scene_runner(SCENE)
	var button := runner.find_child("TryAgainButton") as Button
	var gave_up: bool = await _wait_until(func(): return button.visible)
	assert_bool(gave_up).is_true()
	assert_bool((runner.find_child("ModeLabel") as Label).visible).is_false()
	assert_str(_transcript(runner)).contains("Couldn't invent the owner")


# --- How long people stay, and customers talking to each other -------------------------

func test_customers_say_goodbye_and_leave_when_their_time_is_up() -> void:
	Visit.stay_minutes_override = 600
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 1)
	assert_bool(await _wait_until(func(): return not scene._guests.is_empty() and scene._guests[0].line >= 4)).is_true()
	var guest = scene._guests[0]
	# Mid-conversation, their time's up: they say goodbye and pay, without finishing it.
	guest.stay_left = 0.0
	assert_bool(await _wait_until(func(): return not scene.busy)).override_failure_message("they never left").is_true()
	assert_int(int(Game.bar["visits"])).is_equal(1)
	var last := ""
	for entry in guest.transcript:
		if entry.has("text"):
			last = str(entry["text"])
	var goodbyes: Array = CannedAi.CUSTOMER_LAST_LINES.map(func(l): return l % scene._owner["title"] if l.contains("%s") else l)
	assert_bool(goodbyes.has(last)).override_failure_message("their last line wasn't a goodbye: %s" % last).is_true()


func test_customers_chat_to_each_other() -> void:
	Visit.stay_minutes_override = 600
	Visit.company_override = "chatty"
	Visit.chat_chance_override = 1.0
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 2)
	var chatted := func() -> bool:
		if scene._guests.size() < 2 or not _transcript(runner).contains("gets talking to"):
			return false
		for entry in scene._guests[0].transcript:
			if entry.has("action") and str(entry["action"]).contains("has been chatting with"):
				return true
		return false
	var chatting: bool = await _wait_until(chatted)
	assert_bool(chatting).override_failure_message("the customers never chatted").is_true()
	var a: String = scene._name_label(scene._guests[0].customer)
	var b: String = scene._name_label(scene._guests[1].customer)
	# The chat starts before its first line is written, so wait for a line too.
	var spoke := func() -> bool:
		var text := _transcript(runner)
		return text.contains("%s to %s:" % [a, b]) or text.contains("%s to %s:" % [b, a])
	assert_bool(await _wait_until(spoke)).override_failure_message("no line from one customer to the other").is_true()
	assert_int(scene._chats.size()).is_equal(1)
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()
	assert_array(scene._chats).is_empty()
	assert_int(int(Game.bar["visits"])).is_equal(2)


func test_quiet_customers_keep_to_themselves() -> void:
	Visit.stay_minutes_override = 600
	Visit.company_override = "quiet"
	Visit.chat_chance_override = 1.0
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 2)
	var talked: bool = await _wait_until(func(): return scene._guests.size() == 2 and scene._guests[0].line >= 6 and scene._guests[1].line >= 6)
	assert_bool(talked).is_true()
	assert_str(_transcript(runner)).not_contains("gets talking to")
	assert_array(scene._chats).is_empty()
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


func test_no_two_customers_at_the_counter_share_a_name() -> void:
	Visit.stay_minutes_override = 600
	# Two arrive together. The AI names the second customer the same as the first:
	# rejected, and asked again. (The reply in between is the first one's order: with
	# someone else waiting, the owner greets them quickly, with no chat yet.)
	CannedAi.scripted = [ANY_OWNER, A_BAR_NAME, A_CAT_NAME, A_LOOK, A_NAME, A_CUSTOMER,
		{"items": ["beer", "odeng"], "line": "A beer and some odeng, please."},
		A_NAME]
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 2)
	assert_bool(await _wait_until(func(): return scene._guests.size() == 2)).is_true()
	assert_array(CannedAi.scripted).override_failure_message("the same-name customer was never offered").is_empty()
	assert_str(str(scene._guests[0].customer["name"])).is_equal("Kim Ji-ho")
	assert_str(str(scene._guests[1].customer["name"])).is_not_equal("Kim Ji-ho")
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


func test_greetings_are_quick_when_its_busy() -> void:
	Visit.stay_minutes_override = 600
	Visit.chat_chance_override = 0.0
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 3)
	assert_bool(await _wait_until(func(): return scene._guests.size() == 3 and scene._guests[2].line >= 2)).is_true()
	# The first two came with others waiting: order taken and served, chat later.
	assert_bool(scene._guests[0].quick_greeting).is_true()
	assert_bool(scene._guests[1].quick_greeting).is_true()
	assert_array(scene._guests[0].served).is_not_empty()
	# The last had nobody behind them and only two at the counter: a proper hello.
	assert_bool(scene._guests[2].quick_greeting).is_false()
	# Everyone gets their chat with the owner in the end.
	assert_bool(await _wait_until(func(): return scene._guests[0].line >= 2 and scene._guests[1].line >= 2)).is_true()
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


func test_food_is_carried_over_while_the_ai_is_thinking() -> void:
	Visit.stay_minutes_override = 600
	Visit.chat_chance_override = 0.0
	var order := {"items": ["beer", "tteokbokki"], "line": "A beer and the tteokbokki, please."}
	CannedAi.scripted = [ANY_OWNER, A_BAR_NAME, A_CAT_NAME, A_LOOK, A_NAME, A_CUSTOMER, order]
	var runner := await _open_bar()
	var scene = runner.scene()
	Ai.canned_think_seconds = 0.3  # a slow AI: the tteokbokki is ready long before the next line
	_crowd(scene, 1)
	var while_thinking := [false]
	var served := func() -> bool:
		if scene._guests.is_empty() or not scene._guests[0].served.has("tteokbokki"):
			return false
		while_thinking[0] = scene._owner_working
		return true
	assert_bool(await _wait_until(served)).override_failure_message("the tteokbokki never came").is_true()
	assert_bool(while_thinking[0]).override_failure_message("the owner waited for the AI before carrying it over").is_true()
	Ai.canned_think_seconds = 0.0
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


# --- Debug stats --------------------------------------------------------------------------

func test_stats_are_shown_by_default_and_can_be_hidden() -> void:
	var runner := await _open_bar()
	var panel := runner.find_child("StatsPanel") as Control
	var transcript_panel := (runner.find_child("Transcript") as Control).get_parent().get_parent() as Control
	assert_bool(panel.visible).is_true()
	var narrow := transcript_panel.size.x
	var options := runner.find_child("OptionsButton") as Button  # the settings are in the Options panel
	options.button_pressed = true
	assert_bool((runner.find_child("OptionsPanel") as Control).visible).is_true()
	await _click(runner, runner.find_child("StatsToggle"))
	assert_bool(await _wait_until(func(): return not panel.visible)).is_true()
	options.button_pressed = false
	assert_bool((runner.find_child("OptionsPanel") as Control).visible).is_false()
	assert_float(transcript_panel.size.x).is_greater(narrow)  # the transcript gets the room back


func test_stats_count_a_visit() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	await _run_one_visit(runner)
	var stats = scene._stats
	assert_int(stats.arrived).is_equal(1)
	assert_int(stats.served).is_equal(1)
	assert_int(stats.peak_seated).is_equal(1)
	assert_int(stats.proper_greetings).is_equal(1)
	assert_int(stats.owner_lines).is_greater(0)
	assert_int(stats.ai_calls).is_greater(3)  # their name, details, order and lines
	assert_int(stats.owner_lines_each.size()).is_equal(1)
	# The panel refreshes twice a second, so give it a moment to catch up.
	var panel := runner.find_child("StatsText") as RichTextLabel
	assert_bool(await _wait_until(func(): return panel.get_parsed_text().contains("Arrived 1"), 3000)).override_failure_message(panel.get_parsed_text()).is_true()


func test_stats_count_customer_chats() -> void:
	Visit.stay_minutes_override = 600
	Visit.company_override = "chatty"
	Visit.chat_chance_override = 1.0
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 2)
	assert_bool(await _wait_until(func(): return scene._stats.chat_lines >= 2)).is_true()
	assert_int(scene._stats.chats_started).is_equal(1)
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


# --- Gender symbols ------------------------------------------------------------------------

func test_names_on_screen_show_gender_symbols() -> void:
	Visit.stay_minutes_override = 600
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 1)
	assert_bool(await _wait_until(func(): return not scene._guests.is_empty() and scene._guests[0].line >= 2)).is_true()
	var guest = scene._guests[0]
	var symbol: String = Visit.gender_symbol(guest.customer["gender"])
	assert_str(symbol).is_not_empty()
	var label: String = scene._name_label(guest.customer)
	assert_str(label).contains("%s %s" % [guest.customer["name"], symbol])
	assert_str(label).starts_with(str(guest.customer["hangul"]))  # the Hangul first, like the sign
	assert_str((guest.node.get_node("Tag") as Label).text).is_equal(label)
	assert_str(_transcript(runner)).contains(label + ":")
	assert_str((runner.find_child("Info") as RichTextLabel).get_parsed_text()).contains(label)
	var owner_symbol: String = Visit.gender_symbol(scene._owner["gender"])
	assert_str((runner.find_child("Owner").get_node("Tag") as Label).text).contains(owner_symbol)
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


func test_gender_symbols() -> void:
	assert_str(Visit.gender_symbol("woman")).is_equal("♀")
	assert_str(Visit.gender_symbol("man")).is_equal("♂")
	assert_str(Visit.gender_symbol("non-binary")).is_equal("⚲")
	assert_str(Visit.gender_symbol("")).is_empty()


func test_a_non_binary_customer_comes_in() -> void:
	Visit.gender_override = "non-binary"
	var runner := await _open_bar()
	var scene = runner.scene()
	await _run_one_visit(runner)
	assert_str(str(scene._customer["gender"])).is_equal("non-binary")
	assert_str(_transcript(runner)).contains("%s ⚲:" % scene._with_hangul(scene._customer))


func test_time_speeds_up_when_the_tent_is_empty_and_slows_when_busy() -> void:
	Visit.run_clock = true
	Visit.pause_scale_override = 1.0  # real speed, so the night doesn't race past before we look
	Visit.stay_minutes_override = 600
	var runner := await _open_bar()
	var scene = runner.scene()
	assert_bool(await _wait_until(func(): return scene._time_speed > 5.0)).is_true()
	assert_str((runner.find_child("MomentLabel") as Label).text).contains("▶▶")
	_crowd(scene, 2)
	assert_bool(await _wait_until(func(): return scene._guests.size() >= 2 and scene._time_speed <= 1.0)).override_failure_message("time didn't slow down for two customers").is_true()
	Visit.run_clock = false  # no more arrivals, so the tent can empty
	Visit.pause_scale_override = 0.01
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


# --- The cat ----------------------------------------------------------------------------------

func test_a_new_bar_gets_a_cat() -> void:
	var runner := await _open_bar()
	var cat: Dictionary = Game.bar["cat"]
	assert_str(str(cat["name"])).is_not_empty()
	assert_bool(Rules.CAT_COATS.has(cat["coat"])).is_true()
	assert_bool(Rules.CAT_PERSONALITIES.has(cat["personality"])).is_true()
	assert_bool(SaveStore.load_bar(str(Game.bar["id"]))["cat"].has("name")).is_true()  # saved
	assert_bool((runner.find_child("Cat") as Control).visible).is_true()
	assert_str((runner.find_child("Info") as RichTextLabel).get_parsed_text()).contains("THE CAT")
	assert_str(_transcript(runner)).contains("%s, the tent's %s cat" % [cat["name"], cat["coat"]])


func test_the_ai_names_the_cat() -> void:
	CannedAi.scripted = [ANY_OWNER, A_BAR_NAME, A_CAT_NAME]
	await _open_bar()
	assert_str(str(Game.bar["cat"]["name"])).is_equal("Dubu")


func test_the_cat_on_a_lap_is_in_the_conversation() -> void:
	Visit.stay_minutes_override = 600
	Visit.cat_wanders = false
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 1)
	assert_bool(await _wait_until(func(): return not scene._guests.is_empty() and scene._guests[0].line >= 2)).is_true()
	var guest = scene._guests[0]
	scene._move_cat("lap")
	var cat_name := str(Game.bar["cat"]["name"])
	assert_str(_transcript(runner)).contains("%s jumps up onto %s's lap" % [cat_name, guest.customer["name"]])
	assert_int(int(scene._stats.captions.get("cat_lap", 0))).is_equal(1)  # a TV caption
	assert_bool(guest.transcript.any(func(e): return e.has("action") and str(e["action"]).contains("lap"))).is_true()
	assert_str(scene._cat_prompt()).contains("on %s's lap" % guest.customer["name"])
	# When they leave, the cat jumps down.
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()
	assert_str(scene._cat_spot).is_not_equal("lap")
	assert_object(scene._cat_with).is_null()


func test_the_cat_wanders_by_itself() -> void:
	Visit.run_clock = true
	var runner := await _open_bar()
	var scene = runner.scene()
	var moved: bool = await _wait_until(func(): return scene._cat_spot != "stove")
	assert_bool(moved).override_failure_message("the cat never moved").is_true()


func test_the_cat_faces_the_way_its_going() -> void:
	Visit.cat_wanders = false
	var runner := await _open_bar()
	var scene = runner.scene()
	var cat := runner.find_child("Cat") as Control
	scene._move_cat("counter")  # from the stove (left) to the far end of the counter (right)
	assert_float(cat.scale.x).is_equal(1.0)
	await get_tree().create_timer(0.1).timeout  # let it get there
	scene._move_cat("stove")  # and back to the left
	assert_float(cat.scale.x).is_equal(-1.0)


# --- How conversations flow -----------------------------------------------------------------

func test_the_owners_chat_turns_to_a_topic() -> void:
	Visit.stay_minutes_override = 600
	Visit.chat_chance_override = 0.0
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 1)
	assert_bool(await _wait_until(func(): return not scene._guests.is_empty() and scene._guests[0].topic != "")).is_true()
	assert_bool(Rules.OWNER_TOPICS.has(scene._guests[0].topic)).is_true()
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


func test_a_line_written_before_a_dish_arrived_is_asked_for_again() -> void:
	Visit.stay_minutes_override = 600
	Visit.chat_chance_override = 0.0
	var order := {"items": ["beer", "tteokbokki"], "line": "A beer and the tteokbokki, please."}
	CannedAi.scripted = [ANY_OWNER, A_BAR_NAME, A_CAT_NAME, A_LOOK, A_NAME, A_CUSTOMER, order]
	var runner := await _open_bar()
	var scene = runner.scene()
	Ai.canned_think_seconds = 0.3  # the tteokbokki's ready while the owner's first line is being written
	_crowd(scene, 1)
	assert_bool(await _wait_until(func(): return scene._stats.stale_redone >= 1)).override_failure_message("no out-of-date line was redone").is_true()
	Ai.canned_think_seconds = 0.0
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


func test_nobody_speaks_twice_running_as_they_leave() -> void:
	Visit.stay_minutes_override = 600
	Visit.chat_chance_override = 0.0
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 1)
	# A proper hello ends with the customer's reply: they've had the last word.
	assert_bool(await _wait_until(func(): return not scene._guests.is_empty() and scene._guests[0].line >= 2)).is_true()
	var guest = scene._guests[0]
	guest.stay_left = 0.0
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()
	var speakers: Array = guest.transcript.filter(func(e): return e.has("text")).map(func(e): return str(e["speaker"]))
	for i in range(1, speakers.size()):
		assert_bool(speakers[i] == speakers[i - 1] and speakers[i] == str(guest.customer["name"])).override_failure_message("the customer spoke twice running: %s" % str(speakers)).is_false()


func test_nobody_starts_a_chat_just_before_leaving() -> void:
	Visit.stay_minutes_override = 600
	Visit.company_override = "chatty"
	Visit.chat_chance_override = 0.0  # no chat while they settle in
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 2)
	assert_bool(await _wait_until(func(): return scene._guests.size() == 2 and scene._guests.all(func(g): return not g.order.is_empty()))).is_true()
	assert_bool(scene._chat_possible()).is_true()  # two chatty, settled-in customers could chat...
	for guest in scene._guests:
		guest.stay_left = Visit.CHAT_MIN_STAY_LEFT - 1.0
	assert_bool(scene._chat_possible()).is_false()  # ...but not with minutes to go
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


func test_someone_leaving_a_chat_says_goodbye_to_their_partner() -> void:
	Visit.stay_minutes_override = 600
	Visit.company_override = "chatty"
	Visit.chat_chance_override = 1.0
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 2)
	assert_bool(await _wait_until(func(): return scene._stats.chat_lines >= 2 and not scene._chats.is_empty())).is_true()
	var leaving = scene._guests[0]
	var staying = scene._guests[1]
	leaving.stay_left = 0.0
	var told: bool = await _wait_until(func(): return staying.transcript.any(func(e): return e.has("action") and str(e["action"]).contains("who they were chatting with, says goodbye")))  # by name only if it was said
	assert_bool(told).override_failure_message("their chat partner never heard them go").is_true()
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


func test_a_chat_gets_a_few_lines_before_anything_cuts_in() -> void:
	Visit.stay_minutes_override = 600
	Visit.company_override = "chatty"
	Visit.chat_chance_override = 1.0
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 2)
	assert_bool(await _wait_until(func(): return scene._stats.chats_started >= 1)).is_true()
	_crowd(scene, 1)  # someone new turns up mid-chat: greeting them is urgent...
	assert_bool(await _wait_until(func(): return scene._guests.size() == 3)).is_true()
	assert_int(scene._stats.chat_lines).is_greater_equal(Visit.CHAT_LINES_BEFORE_INTERRUPTING)  # ...but the chat had its say first
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


func test_time_doesnt_race_while_the_first_customer_is_being_greeted() -> void:
	Visit.stay_minutes_override = 600
	Ai.canned_think_seconds = 0.2  # inventing them takes a while
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 1)
	# While they're being invented they're off the queue but not yet on a stool: still someone in.
	assert_bool(await _wait_until(func(): return scene._greeting)).is_true()
	assert_int(scene._people_in()).is_equal(1)
	Ai.canned_think_seconds = 0.0
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()
	assert_bool(scene._greeting).is_false()


func test_waiting_for_the_owner_and_for_drinks_are_counted_separately() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	await _run_one_visit(runner)
	assert_int(scene._stats.greet_waits.size()).is_equal(1)
	assert_int(scene._stats.serve_waits.size()).is_equal(1)
	assert_float(float(scene._stats.serve_waits[0])).is_greater_equal(float(scene._stats.greet_waits[0]))
	var panel := runner.find_child("StatsText") as RichTextLabel
	assert_bool(await _wait_until(func(): return panel.get_parsed_text().contains("Wait for first drinks"), 3000)).is_true()


func test_a_new_bars_cat_is_a_she_or_a_he_with_its_own_name() -> void:
	# Another bar (not called Golmok Pocha, like the new one, or they'd share an id).
	var other := SaveStore.new_bar("Sarang Pocha", "Love Tent", ANY_OWNER)
	other["cat"] = {"name": "Dubu", "coat": "black", "personality": "lazy", "sex": "she"}
	SaveStore.save_bar(other)
	CannedAi.scripted = [ANY_OWNER, A_BAR_NAME, A_CAT_NAME]  # the AI suggests Dubu: taken
	await _open_bar()
	var cat: Dictionary = Game.bar["cat"]
	assert_bool(cat["sex"] in Rules.CAT_SEXES).is_true()
	assert_str(str(cat["name"])).is_not_equal("Dubu")


func test_customers_are_women_and_men_about_equally() -> void:
	var genders := {}
	for i in 200:
		var g: String = Rules.game_gender(randf())
		genders[g] = int(genders.get(g, 0)) + 1
	assert_int(int(genders.get("woman", 0))).is_between(70, 130)
	assert_int(int(genders.get("man", 0))).is_between(70, 130)


func test_tonights_jobs_and_looks_are_remembered() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	await _run_one_visit(runner)
	assert_int(scene._jobs_tonight.size()).is_equal(1)
	assert_int(scene._looks_tonight.size()).is_equal(1)


# --- How the tent and the night look --------------------------------------------------------

func test_a_new_bar_gets_its_own_look() -> void:
	CannedAi.scripted = [ANY_OWNER, A_BAR_NAME, A_CAT_NAME, A_LOOK]
	var runner := await _open_bar()
	var look: Dictionary = SaveStore.load_bar(str(Game.bar["id"]))["look"]  # saved with the bar
	assert_str(str(look["tarp"])).is_equal("blue")
	assert_str((runner.find_child("SignHangul") as Label).text).is_equal("골목 포차")
	assert_str((runner.find_child("SignEnglish") as Label).text).is_equal("GOLMOK POCHA")
	assert_bool((runner.find_child("Sign") as Control).visible).is_true()
	assert_bool((runner.find_child("Tarp") as Polygon2D).color.is_equal_approx(Color(Rules.BAR_TARPS["blue"][0]))).is_true()
	assert_int(runner.find_child("DecorCounter").get_child_count()).is_greater(0)  # the radio
	assert_int(runner.find_child("DecorRoof").get_child_count()).is_greater(0)  # the lanterns


func test_rain_falls_when_its_raining() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	scene._show_weather("rain")
	assert_object(runner.find_child("Rain", true, false)).is_not_null()
	assert_object(runner.find_child("Drips", true, false)).is_not_null()  # heavy rain drips off the tarp
	scene._show_weather("snow")
	await get_tree().process_frame
	assert_object(runner.find_child("Snow", true, false)).is_not_null()
	assert_bool(is_instance_valid(runner.find_child("Rain", true, false))).is_false()  # the rain's stopped
	scene._show_weather("fog")
	await get_tree().process_frame
	assert_object(runner.find_child("Fog0", true, false)).is_not_null()


func test_the_sky_darkens_as_the_night_goes_on() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	var sky := runner.find_child("Sky") as ColorRect
	scene._clock = 18 * 60.0
	await get_tree().process_frame
	var dusk := sky.color.get_luminance()
	scene._clock = 24 * 60.0
	await get_tree().process_frame
	assert_float(sky.color.get_luminance()).is_less(dusk)


func test_the_tent_cover_has_the_chosen_shape() -> void:
	CannedAi.scripted = [ANY_OWNER, A_BAR_NAME, A_CAT_NAME, A_LOOK]  # peaked
	var runner := await _open_bar()
	var scene = runner.scene()
	var tarp := runner.find_child("Tarp") as Polygon2D
	assert_int(tarp.polygon.size()).is_equal(5)  # a peak, not the classic four corners
	var top := 999.0
	for point in tarp.polygon:
		top = minf(top, point.y)
	assert_float(top).is_less(40.0)  # higher in the middle than the classic tarp
	for shape in Rules.TENT_SHAPES:
		assert_int(scene._tent_shape(shape).size()).is_greater_equal(4)


func test_stripes_are_cut_to_the_shape() -> void:
	var look := A_LOOK.duplicate()
	look["tarp"] = "red_stripes"
	look["shape"] = "rounded"
	CannedAi.scripted = [ANY_OWNER, A_BAR_NAME, A_CAT_NAME, look]
	var runner := await _open_bar()
	assert_int(runner.find_child("TarpStripes").get_child_count()).is_greater(0)


func test_people_walk_past_without_coming_in() -> void:
	Visit.run_clock = true
	var runner := await _open_bar()
	var scene = runner.scene()
	assert_bool(await _wait_until(func(): return scene._strollers >= 3)).override_failure_message("nobody walked past").is_true()
	var walker := runner.find_child("Stroller1", true, false) as Control
	if walker != null:
		assert_float(walker.position.y).is_greater(Visit.CUSTOMER_Y)  # on the pavement, nearer than the stools
	assert_int(scene._stats.arrived).is_less(scene._strollers)  # most just walk on by


func test_no_template_tent_while_the_ai_thinks() -> void:
	Ai.canned_think_seconds = 0.3
	var runner := scene_runner(SCENE)
	var tarp := runner.find_child("Tarp") as Polygon2D
	assert_bool(tarp.visible).is_false()
	assert_bool(await _wait_until(func(): return tarp.visible)).override_failure_message("the tent never went up").is_true()


func test_a_new_bar_chooses_from_a_few_colours_and_shapes() -> void:
	Visit.offer_every_look = false
	var runner := await _open_bar()
	var scene = runner.scene()
	var offer: Dictionary = scene._look_offer
	assert_int(offer["tarp"].size()).is_equal(Rules.OFFERED_TARPS)
	assert_array(offer["tarp"]).contains([Game.bar["look"]["tarp"]])
	assert_array(offer["shape"]).contains([Game.bar["look"]["shape"]])


func test_a_loading_screen_covers_a_new_bar_being_set_up() -> void:
	Ai.canned_think_seconds = 0.3
	var runner := scene_runner(SCENE)
	var loading := runner.find_child("Loading") as Control
	assert_bool(loading.visible).is_true()
	assert_bool(await _wait_until(func(): return not loading.visible)).override_failure_message("the loading screen never went").is_true()
	assert_bool((runner.find_child("Tarp") as Polygon2D).visible).is_true()


func test_passers_by_carry_umbrellas_in_the_rain() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	scene._weather_kind = "rain"
	scene._stroll()
	var walker := runner.find_child("Stroller%d" % scene._strollers, true, false) as Control
	assert_object(walker.find_child("Umbrella", true, false)).is_not_null()


func test_sound_is_on_by_default_can_be_turned_off_and_has_a_volume() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ambience.settings_path))
	var runner := await _open_bar()
	var toggle := runner.find_child("SoundToggle") as CheckBox
	assert_bool(toggle.button_pressed).is_true()
	(runner.find_child("OptionsButton") as Button).button_pressed = true  # it's in the Options panel
	await _click(runner, toggle)
	assert_bool(toggle.button_pressed).is_false()
	assert_bool(Ambience.load_enabled()).is_false()  # remembered for next time
	var slider := runner.find_child("SoundVolume") as HSlider
	assert_float(slider.value).is_equal(0.8)  # the default
	slider.value = 0.3
	assert_float(Ambience.load_volume()).is_equal_approx(0.3, 0.001)
	var music := runner.find_child("MusicVolume") as HSlider
	assert_float(music.value).is_equal(0.5)
	music.value = 0.0  # all the way down: no music
	assert_float(Music.load_volume()).is_equal(0.0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Ambience.settings_path))


func test_people_are_drawn_in_their_look() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	assert_bool(scene._owner.has("look")).is_true()
	assert_bool(scene._owner["look"]["apron"]).is_true()
	assert_bool(Game.bar["owner"].has("look")).is_true()  # saved with the bar
	assert_object(runner.find_child("Owner").find_child("Look", false, false)).is_not_null()
	_crowd(scene, 1)
	assert_bool(await _wait_until(func(): return scene._guests.size() == 1)).is_true()
	var guest = scene._guests[0]
	assert_bool(guest.customer.has("look")).is_true()
	assert_object(guest.node.find_child("Look", false, false)).is_not_null()
	assert_object(guest.node.find_child("Tag", false, false)).is_not_null()
	# Facing us as they come in; once they're sat down, facing the counter (their back to us).
	var front := guest.node.get_node("Look/Front") as Control
	var back := guest.node.get_node("Look/Back") as Control
	assert_bool(await _wait_until(func(): return back.visible)).override_failure_message("they never turned to the counter").is_true()
	assert_bool(front.visible).is_false()
	assert_bool((runner.find_child("Owner").get_node("Look/Front") as Control).visible).is_true()  # the owner faces us


func test_the_cat_has_a_name_tag() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	var tag := runner.find_child("Cat").get_node("Tag") as Label
	assert_str(tag.text).contains(str(scene._cat["name"]))
	assert_str(tag.text).starts_with(str(Rules.CAT_HANGUL[scene._cat["name"]]))  # Hangul first, like everyone's
	assert_str(tag.text).ends_with("♀" if scene._cat["sex"] == "she" else "♂")


func test_lines_show_in_speech_bubbles_with_who_they_are_to() -> void:
	Visit.bubbles = true
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 1)
	assert_bool(await _wait_until(func(): return runner.find_child("Bubble", true, false) != null)).override_failure_message("no speech bubble").is_true()
	var bubble = runner.find_child("Bubble", true, false)
	var header := bubble.find_child("Header", true, false) as Label
	assert_str(header.text).starts_with("→ ")
	assert_object(bubble.listener).is_not_null()
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


# --- Regulars ---------------------------------------------------------------------------------

func _a_regular(founding: bool = false) -> Dictionary:
	var customer := {"name": "Choi Hye-rin", "hangul": "최혜린", "gender": "woman", "age": 31, "job": "pharmacist",
		"speech_style": "precise", "appearance": "A camel coat, buttoned to the top."}
	var regular := Regulars.new_regular(customer, Rules.pick_look("woman", "30s", ""), ["soju", "tteokbokki"], 1, 0, 21 * 60, 0.5)
	regular["visits"] = 4
	if founding:
		regular.merge({"founding": true, "role": "looks_out", "since": "for six years", "habit": "most Fridays", "usual": ["beer", "pajeon"],
			"owner_knows_name": true, "knows_owner_name": true, "pull": Regulars.FOUNDING_PULL}, true)
	return regular


func test_a_new_bar_opens_with_two_founding_regulars() -> void:
	Visit.founding_regulars = true
	var runner := await _open_bar()
	var regulars: Array = Game.bar.get("regulars", [])
	assert_int(regulars.size()).is_equal(2)
	var names := {}
	for regular in regulars:
		assert_bool(regular["founding"]).is_true()
		assert_bool(Regulars.ROLES.has(regular["role"])).is_true()
		assert_float(float(regular["pull"])).is_equal(Regulars.FOUNDING_PULL)
		assert_int(Regulars.usual_of(regular).size()).is_equal(2)
		assert_str(str(regular["name"])).is_not_equal(str(runner.scene()._owner["name"]))
		names[regular["name"]] = true
	assert_int(names.size()).is_equal(2)  # two different people
	assert_str(regulars[0]["role"]).is_not_equal(regulars[1]["role"])


func test_a_regular_comes_back_as_themselves() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	var regular := _a_regular()
	Game.bar["regulars"] = [regular]
	var asked: Array = []
	scene._ai.answered.connect(func(purpose, _s, _p, _ok): asked.append(purpose))
	scene._arrive(scene._clock, regular["id"])
	assert_bool(await _wait_until(func(): return scene._guests.size() == 1)).override_failure_message("the regular never sat down").is_true()
	var guest = scene._guests[0]
	assert_str(str(guest.customer["name"])).is_equal("Choi Hye-rin")
	assert_array(asked).not_contains(["customer_name", "customer"])  # not reinvented
	assert_array(asked).contains(["regular_tonight"])
	assert_str(str(guest.customer["look"]["hair"])).is_equal(str(regular["look"]["hair"]))
	assert_str((guest.node.get_node("Tag") as Label).text).ends_with("★")  # their 5th visit: a regular
	assert_str(_transcript(runner)).contains("Choi Hye-rin is back, for her 5th visit")
	assert_int(int(scene._stats.captions.get("regular_back", 0))).is_equal(1)  # a TV caption
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()
	assert_int(int(regular["visits"])).is_equal(5)
	assert_int(int(regular["last_night"])).is_equal(scene._night_number)


func test_a_founding_regulars_prompt_knows_their_history() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	var regular := _a_regular(true)
	Game.bar["regulars"] = [regular]
	scene._arrive(scene._clock, regular["id"])
	assert_bool(await _wait_until(func(): return scene._guests.size() == 1)).is_true()
	var guest = scene._guests[0]
	var text := Prompts.describe_relationship(scene._owner, guest.customer)
	assert_str(text).contains("been coming for six years, most Fridays")
	assert_str(text).contains("Beer")  # their usual
	assert_str(text).contains("knows their name")
	assert_str(text).contains("looks out for people")
	assert_str((guest.node.get_node("Tag") as Label).text).ends_with("★★")
	assert_str(_transcript(runner)).contains("takes her usual stool")
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


func test_someone_who_enjoyed_their_visit_can_become_a_regular() -> void:
	Visit.regular_roll_override = 0.0  # if it's possible at all, it happens
	var runner := await _open_bar()
	var scene = runner.scene()
	Game.bar["regulars"] = []
	await _run_one_visit(runner)
	var regulars: Array = Game.bar["regulars"]
	assert_int(regulars.size()).is_equal(1)
	assert_str(str(regulars[0]["name"])).is_equal(str(scene._customer["name"]))
	assert_str(_transcript(runner)).contains("be back")
	assert_bool(SaveStore.load_bar(Game.bar["id"])["regulars"].size() == 1).is_true()  # saved


func test_nobody_becomes_a_regular_when_the_dice_say_no() -> void:
	Visit.regular_roll_override = 1.0
	var runner := await _open_bar()
	Game.bar["regulars"] = []
	await _run_one_visit(runner)
	assert_array(Game.bar["regulars"]).is_empty()


func test_regulars_who_stay_away_fade() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	var staying := _a_regular()
	staying["pull"] = 0.5
	staying["last_night"] = 0  # not in tonight
	var going := _a_regular()
	going["id"] = "going"
	going["name"] = "Bae Joon-young"
	going["pull"] = 0.105
	going["last_night"] = 0
	Game.bar["regulars"] = [staying, going]
	scene._fade_regulars()
	assert_float(float(staying["pull"])).is_less(0.5)
	assert_array(Game.bar["regulars"]).has_size(1)
	assert_str(_transcript(runner)).contains("Bae Joon-young hasn't been in for a long while")
	assert_str(scene._stats.panel_text(0, 0)).contains("REGULARS")
	assert_str(scene._stats.panel_text(0, 0)).contains("faded away 1")


func test_founding_regulars_always_come_in_the_first_night_and_are_introduced() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	var regular := _a_regular(true)
	regular["introduced"] = false
	regular["pull"] = 0.0  # even someone who'd never come otherwise
	regular["history"] = "She found the tent the night her pharmacy opened"
	Game.bar["regulars"] = [regular]
	scene._plan_regulars_tonight()
	assert_int(scene._regulars_due.size()).is_equal(1)
	scene._regulars_due.clear()
	scene._arrive(scene._clock, regular["id"])
	assert_bool(await _wait_until(func(): return scene._guests.size() == 1)).is_true()
	var text := _transcript(runner)
	assert_str(text).contains("She's the one who looks out for people")
	assert_str(text).contains("She found the tent the night her pharmacy opened.")
	assert_bool(regular["introduced"]).is_true()
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


func _a_departing_guest(scene) -> Visit.Guest:
	var guest := Visit.Guest.new()
	guest.customer = {"name": "Yoon Na-rae", "hangul": "윤나래", "gender": "woman", "age": 28, "job": "nurse", "mood": "tired",
		"reason": "A double shift.", "speech_style": "brisk", "appearance": "Scrubs under a coat.", "look": Rules.pick_look("woman", "20s", "")}
	guest.first_order = ["soju", "odeng"]
	guest.arrived_minutes = int(scene._clock)
	guest.transcript = [{"speaker": "Yoon Na-rae", "text": "Double shift at the hospital again. My mum keeps telling me to quit."},
		{"speaker": scene._owner["name"], "text": "Eat something first."}]
	return guest


func test_a_loved_visit_is_remembered_and_makes_a_regular() -> void:
	Visit.memories = true
	Visit.regular_roll_override = 0.05  # under "loved it"'s 1 in 10, over "fine"'s 1 in 200
	var runner := await _open_bar()
	var scene = runner.scene()
	Game.bar["regulars"] = []
	CannedAi.scripted = [{"owner_remembers": "The nurse on a double shift; her mum wants her to quit.", "they_remember": "The owner made her eat first.",
		"job": "nurse at the hospital", "family": "her mum wants her to quit", "home": "Jeju", "other": "", "night": "loved it", "towards_owner": "warmer"}]
	await scene._after_visit(_a_departing_guest(scene))
	var regulars: Array = Game.bar["regulars"]
	assert_int(regulars.size()).is_equal(1)
	var regular: Dictionary = regulars[0]
	assert_str(str(regular["memories"][0]["owner"])).contains("double shift")
	assert_str(str(regular["facts"]["job"])).is_equal("nurse at the hospital")
	assert_str(str(regular["facts"]["family"])).contains("mum")
	assert_bool(regular["facts"].has("home")).is_false()  # Jeju was never said
	assert_int(int(scene._stats.verdicts.get("loved", 0))).is_equal(1)
	# Next time, the owner's prompt remembers.
	var facts: Dictionary = scene._regular_facts(regular)
	var text := Prompts.describe_relationship(scene._owner, {"name": "Yoon Na-rae", "regular": facts})
	assert_str(text).contains("her mum wants her to quit")


func test_a_visit_they_didnt_enjoy_makes_no_regular() -> void:
	Visit.memories = true
	Visit.regular_roll_override = 0.0
	var runner := await _open_bar()
	var scene = runner.scene()
	Game.bar["regulars"] = []
	CannedAi.scripted = [{"owner_remembers": "Barely said a word.", "they_remember": "Slow food.", "night": "didn't enjoy it", "towards_owner": "cooler"}]
	await scene._after_visit(_a_departing_guest(scene))
	assert_array(Game.bar["regulars"]).is_empty()
	assert_int(int(scene._stats.verdicts.get("didnt", 0))).is_equal(1)


func test_two_regulars_get_to_know_each_other_and_then_ask() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	var younger := _a_regular()
	younger["age"] = 26
	var older := _a_regular()
	older.merge({"id": "older", "name": "Kang Da-eun", "hangul": "강다은", "age": 33}, true)
	Game.bar["regulars"] = [younger, older]
	Visit.stay_minutes_override = 600
	scene._arrive(scene._clock, younger["id"])
	scene._arrive(scene._clock, older["id"])
	assert_bool(await _wait_until(func(): return scene._guests.size() == 2)).override_failure_message("they never both sat down").is_true()
	var a = scene._guest_named("Choi Hye-rin")
	var b = scene._guest_named("Kang Da-eun")
	assert_object(a).is_not_null()
	assert_object(b).is_not_null()
	if a == null or b == null:
		return
	var chat := Visit.Chat.new()
	chat.people = [a, b]
	chat.transcript = [{"speaker": "Kang Da-eun", "text": "I'm Da-eun, by the way."}]
	scene._remember_chat(chat, "I'm Da-eun, by the way.")
	var friend: Dictionary = younger["friends"]["older"]
	assert_int(int(friend["meetings"])).is_equal(1)
	assert_bool(friend["names"]).is_true()
	assert_str((a.node.get_node("Tag") as Label).text).ends_with("∞")  # a friend's here too
	scene._remember_chat(chat, "Same night again.")
	assert_int(int(younger["friends"]["older"]["meetings"])).is_equal(1)  # once a night
	assert_str(scene._friendly_moment(a, b)).is_empty()  # not yet
	friend["meetings"] = Visit.FRIENDLY_AFTER
	assert_str(scene._friendly_moment(a, b)).is_equal("eonni")
	assert_str(scene._friendly_moment(b, a)).is_empty()  # the older one doesn't ask
	scene._make_close(a, b, "eonni")
	assert_bool(scene._close(a, b)).is_true()
	assert_bool(older["friends"]["choi-hye-rin-1"]["close"]).is_true()
	assert_str(_transcript(runner)).contains("are on \"eonni\" terms now")
	assert_int(int(scene._stats.captions.get("friendlier", 0))).is_equal(1)  # a TV caption
	assert_str(scene._to_label("Eonni, look!", a, b, "label")).starts_with("언니 Eonni")
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


func test_the_owner_uses_a_well_known_regulars_given_name() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	var regular := _a_regular(true)
	Game.bar["regulars"] = [regular]
	scene._arrive(scene._clock, regular["id"])
	assert_bool(await _wait_until(func(): return scene._guests.size() == 1)).is_true()
	var note: String = scene._address_note(scene._guests[0])
	assert_str(note).contains("given name, Hye-rin")
	assert_str(note).contains("may call")
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


func test_noteworthy_moments_get_tv_captions() -> void:
	Visit.stay_minutes_override = 600  # nobody leaves, so the tent stays full
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 6)
	assert_bool(await _wait_until(func(): return scene._guests.size() == 5)).is_true()
	assert_int(int(scene._stats.captions.get("rush", 0))).is_equal(1)  # the counter filling up
	assert_str(_transcript(runner)).contains("[TV] ")
	scene._clock += Rules.GIVE_UP_MINUTES + 1
	assert_bool(await _wait_until(func(): return scene._passers_by == 1)).is_true()
	assert_str(_transcript(runner)).contains("[TV] ")
	assert_int(int(scene._stats.captions["full_house"])).is_equal(1)
	assert_int(scene._red_flashes).override_failure_message("no red light for an emergency").is_equal(1)
	# Drawn: Hangul over the English, by the tent (at normal speed, so it's still up to look at).
	Visit.pause_scale_override = 1.0
	scene._caption("stove")
	Visit.pause_scale_override = 0.01
	var caption: Control = scene._caption_shown
	assert_object(caption).is_not_null()
	if caption != null:
		assert_str(caption.name).is_equal("Caption")
		var hangul: Array = Rules.CAPTIONS["stove"]["words"].map(func(w): return w[0])
		assert_array(hangul).contains([(caption.find_child("Hangul", true, false) as Label).text])
		assert_str((caption.find_child("English", true, false) as Label).text).is_not_empty().not_contains("{")
	# The Captions toggle turns them off.
	(runner.find_child("CaptionsToggle", true, false) as CheckBox).button_pressed = false
	scene._call_last_orders()
	assert_int(int(scene._stats.captions.get("last_orders", 0))).is_equal(0)
	assert_bool(await _wait_until(func(): return not scene.busy, 30000)).is_true()


func test_the_last_customer_leaving_late_is_all_quiet() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	scene._clock = float(Rules.QUIET_AFTER + 10)
	_crowd(scene, 1)
	assert_bool(await _wait_until(func(): return scene._guests.size() == 1)).is_true()
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()
	assert_int(int(scene._stats.captions.get("quiet", 0))).is_equal(1)


func test_a_big_moment_gets_a_tv_reaction() -> void:
	Visit.reactions = true
	var runner := await _open_bar()
	var scene = runner.scene()
	var owner_name := str(Game.bar["owner"]["name"])
	var names := ["Kim Ji-ho", owner_name]
	var lines := [{"speaker": "Kim Ji-ho", "text": "I quit my job today."}, {"speaker": owner_name, "text": "You did what?"}]
	CannedAi.scripted = [{"size": 5, "mood": "shock", "who": "Ji-ho", "caption": "she quit her job?!"}]
	await scene._react(lines, names, [])
	assert_str(_transcript(runner)).contains("SHE QUIT HER JOB?!")
	assert_int(int(scene._stats.reactions_shown.get("shock", 0))).is_equal(1)
	assert_array(Rules.REACTIONS["shock"]["hangul"]).contains([(scene._caption_shown.find_child("Hangul", true, false) as Label).text])
	# Nothing special: no caption. A bad answer: dropped, not asked again.
	CannedAi.scripted = [{"mood": "none"}]
	await scene._react(lines, names, [])
	assert_int(scene._stats.reactions_none).is_equal(1)
	CannedAi.scripted = [{"size": 4, "mood": "angry", "who": "Kim Ji-ho", "caption": "GRR"}, {"size": 4, "mood": "funny", "who": "Kim Ji-ho", "caption": "NOT ASKED"}]
	await scene._react(lines, names, [])
	assert_int(scene._stats.reactions_dropped).is_equal(1)
	assert_int(CannedAi.scripted.size()).is_equal(1)  # only one try
	assert_str(_transcript(runner)).not_contains("NOT ASKED")
	assert_int(scene._stats.reactions_asked).is_equal(3)
	CannedAi.scripted = []
