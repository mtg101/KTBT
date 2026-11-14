extends GdUnitTestSuite
## Click-through tests for the visit scene: load the real scene, click the real button with
## simulated mouse input, and check what happens. The AI is offline mode (the canned AI),
## sometimes with scripted replies, so these run without Ollama, quickly and repeatably.

const Visit = preload("res://scripts/visit.gd")
const Ai = preload("res://scripts/ai.gd")
const AiSettings = preload("res://scripts/ai_settings.gd")
const CannedAi = preload("res://scripts/canned_ai.gd")
const Rules = preload("res://scripts/rules.gd")
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
## A customer comes in two steps: their name and gender, then the rest.
const A_NAME := {"name": "Kim Ji-ho", "gender": "woman"}
const A_CUSTOMER := {"name": "Kim Ji-ho", "age": 34, "job": "office worker", "mood": "worn out", "reason": "Her team lead took credit for her work again.", "speech_style": "dry, tired", "appearance": "A crumpled blazer."}


var _real_saves := ""
var _real_stats := ""
const TEST_STATS := "user://test_stats_visit/"


func before_test() -> void:
	_real_saves = SaveStore.folder
	SaveStore.folder = TEST_SAVES
	_real_stats = NightStats.folder
	NightStats.folder = TEST_STATS  # night logs go here, not among real ones
	_clear_folder(TEST_STATS)
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
	CannedAi.scripted = [ANY_OWNER, A_BAR_NAME, A_CAT_NAME, A_NAME, A_CUSTOMER, order]
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
	CannedAi.scripted = [ANY_OWNER, A_BAR_NAME, A_CAT_NAME, A_NAME, A_CUSTOMER, order]
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
	CannedAi.scripted = [ANY_OWNER, A_BAR_NAME, A_CAT_NAME, A_NAME, A_CUSTOMER, {"items": ["pizza"], "line": "Pizza!"}, {"items": []}, {"nope": true}]
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
	var text := _transcript(runner)
	assert_bool(text.contains("%s to %s:" % [a, b]) or text.contains("%s to %s:" % [b, a])).override_failure_message("no line from one customer to the other").is_true()
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
	CannedAi.scripted = [ANY_OWNER, A_BAR_NAME, A_CAT_NAME, A_NAME, A_CUSTOMER,
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
	CannedAi.scripted = [ANY_OWNER, A_BAR_NAME, A_CAT_NAME, A_NAME, A_CUSTOMER, order]
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
	await _click(runner, runner.find_child("StatsToggle"))
	assert_bool(await _wait_until(func(): return not panel.visible)).is_true()
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
	var label := "%s %s" % [guest.customer["name"], symbol]
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
	assert_str(_transcript(runner)).contains("%s ⚲:" % scene._customer["name"])


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
