extends "res://tests/support/bar_test.gd"
## Click-through tests for the visit scene: load the real scene, click the real button with
## simulated mouse input, and check what happens. The AI is offline mode (the canned AI),
## sometimes with scripted replies, so these run without Ollama, quickly and repeatably.

const Seasons = preload("res://scripts/rules/seasons.gd")
const Visit = preload("res://scripts/visit.gd")
const PeopleView = preload("res://scripts/bar/people_view.gd")
const PdCamera = preload("res://scripts/bar/camera.gd")
const Plants = preload("res://scripts/rules/plants.gd")
const CounterChats = preload("res://scripts/bar/counter_chats.gd")
const Autopilot = preload("res://scripts/bar/autopilot.gd")
const Ai = preload("res://scripts/ai/ai.gd")
const AiSettings = preload("res://scripts/ai/ai_settings.gd")
const CannedAi = preload("res://scripts/ai/canned_ai.gd")
const BarLook = preload("res://scripts/rules/bar_look.gd")
const Captions = preload("res://scripts/rules/captions.gd")
const CatRules = preload("res://scripts/rules/cat_rules.gd")
const Looks = preload("res://scripts/rules/looks.gd")
const Names = preload("res://scripts/rules/names.gd")
const NightRules = preload("res://scripts/rules/night_rules.gd")
const Orders = preload("res://scripts/rules/orders.gd")
const People = preload("res://scripts/rules/people.gd")
const Story = preload("res://scripts/rules/story.gd")
const Talk = preload("res://scripts/rules/talk.gd")
const Skyline = preload("res://scripts/rules/skyline.gd")
const RecapScreen = preload("res://scripts/ui/recap_screen.gd")
const DiaryPage = preload("res://scripts/ui/diary_page.gd")
const Regulars = preload("res://scripts/rules/regulars.gd")
const Prompts = preload("res://scripts/ai/prompts.gd")
const Menu = preload("res://scripts/rules/menu.gd")
const MenuBoard = preload("res://scripts/ui/menu_board.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")
const NightStats = preload("res://scripts/bar/night_stats.gd")

const SCENE := "res://scenes/visit.tscn"
const TEST_SAVES := "user://test_saves_visit/"

## A reply that's valid for either gender of owner (the archetype names no gendered term).
const ANY_OWNER := {"name": "Han Jeong-hee", "age": 47, "archetype": "former chef who walked out of a hotel kitchen", "appearance": "Sleeves rolled up.", "personality": "proud, funny", "speech_style": "quick and teasing", "secret": "She still gets job offers from the hotel."}
const A_BAR_NAME := {"name": "Golmok Pocha", "meaning": "Back Alley Tent"}
const A_CAT_NAME := {"name": "Dubu"}
const A_LOOK := {"hangul": "골목 포차", "tarp": "blue", "sign": "neon", "shape": "peaked", "touches": ["radio", "lanterns"]}
## A customer comes in two steps: their name and gender, then the rest.
const A_NAME := {"name": "Kim Ji-ho", "gender": "woman"}
const A_CUSTOMER := {"name": "Kim Ji-ho", "age": 34, "job": "office worker", "mood": "worn out", "reason": "Her team lead took credit for her work again.", "speech_style": "dry, tired", "appearance": "A crumpled blazer."}


const TEST_TRANSCRIPTS := "user://test_transcripts_visit/"
const TEST_STATS := "user://test_stats_visit/"


func _setup() -> void:
	Hooks.random_seed = 1234
	Hooks.run_clock = false  # no automatic customers: these tests bring people in themselves


# --- Helpers ---------------------------------------------------------------------------

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
	assert_int(scene._takings).is_equal(Orders.bill(scene._order))
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
	Hooks.stay_minutes_override = 600  # nobody leaves, so the tent stays full
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 6)
	assert_bool(await _wait_until(func(): return scene._guests.size() == 5)).is_true()
	# Slower here, so the passer-by is still on screen to look at (at 0.01 they're gone in about
	# 50ms: a frame or two on a slow machine, like GitHub's).
	Hooks.pause_scale_override = 0.2
	scene._clock += NightRules.GIVE_UP_MINUTES + 1  # the one left waiting has waited long enough
	assert_bool(await _wait_until(func(): return scene._street.passers_by == 1)).override_failure_message("nobody gave up").is_true()
	assert_array(scene._waiting).is_empty()
	assert_str(_transcript(runner)).contains("sees every stool taken, and walks on")
	# They really walk past: on screen now, gone once they've walked on.
	var passer := runner.find_child("PasserBy1", true, false) as Control
	assert_object(passer).is_not_null()
	var passer_id := passer.get_instance_id() if passer != null else 0  # (watched by id: a wait holding the node itself complains once it's freed)
	assert_bool(await _wait_until(func(): return not is_instance_id_valid(passer_id))).override_failure_message("the passer-by never left").is_true()
	Hooks.pause_scale_override = 0.01
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy, 30000)).is_true()
	assert_int(int(Game.bar["visits"])).is_equal(5)


func test_cooked_food_waits_at_the_stove() -> void:
	var order := {"items": ["beer", "tteokbokki"], "line": "A cold beer and the tteokbokki, please."}
	CannedAi.scripted = [ANY_OWNER, A_BAR_NAME, A_CAT_NAME, A_LOOK, A_NAME, A_CUSTOMER, order]
	Hooks.stay_minutes_override = 600  # (they stay till it's carried over: on a slow machine their time could run out first)
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 1)
	assert_bool(await _wait_until(func(): return _transcript(runner).contains("brings the Tteokbokki over"), 10000)).override_failure_message(_transcript(runner)).is_true()
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()
	var text := _transcript(runner)
	# The beer comes straight away; the tteokbokki goes on the stove and is carried over later.
	assert_str(text).contains("Served: Beer, with the free banchan")
	assert_str(text).contains("On the stove: Tteokbokki")
	assert_str(text).contains("brings the Tteokbokki over to Kim Ji-ho")
	assert_int(text.find("On the stove: Tteokbokki")).is_less(text.find("brings the Tteokbokki over"))


func test_the_ai_hears_what_is_still_cooking() -> void:
	var order := {"items": ["beer", "dakgalbi"], "line": "A beer and the dakgalbi, please."}
	CannedAi.scripted = [ANY_OWNER, A_BAR_NAME, A_CAT_NAME, A_LOOK, A_NAME, A_CUSTOMER, order]
	Hooks.pause_scale_override = 1.0  # slow the stove, so the dakgalbi is still cooking for the first line
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


func test_the_next_customer_is_invented_ahead() -> void:
	Hooks.prepare_customers = true
	var runner := await _open_bar()
	var scene = runner.scene()
	# Nobody's in: the owner's free, so the next customer's invented before they arrive.
	assert_bool(await _wait_until(func(): return not scene._prepared.is_empty())).override_failure_message("nobody was invented ahead").is_true()
	var ahead := str(scene._prepared["customer"]["name"])
	assert_str(_transcript(runner)).not_contains(ahead)  # (nothing shown: they're not here yet)
	# When someone ducks under the tarp, it's them.
	scene._arrive(scene._clock)
	assert_bool(await _wait_until(func(): return not scene._guests.is_empty())).is_true()
	assert_str(str(scene._guests[0].customer["name"])).is_equal(ahead)
	assert_int(scene._stats.prepared_used).is_equal(1)
	# Too long waiting: from another hour, so thrown away and invented fresh.
	scene._owner_working = true  # (so the owner doesn't invent another meanwhile)
	scene._prepared = {"customer": {"name": "Old Name"}, "at": scene._clock - Visit.PREPARED_FRESH_MINUTES - 10.0}
	assert_dict(scene._take_prepared()).is_empty()
	assert_int(scene._stats.prepared_stale).is_equal(1)
	# Someone at the counter has their name by now: thrown away too.
	scene._prepared = {"customer": {"name": ahead}, "at": scene._clock}
	assert_dict(scene._take_prepared()).is_empty()
	assert_int(scene._stats.prepared_stale).is_equal(2)
	scene._owner_working = false


func test_the_owner_moves_between_customers() -> void:
	Hooks.stay_minutes_override = 600
	Hooks.chat_chance_override = 0.0  # just the owner talking
	# (Not someone who wants the owner to themselves: the owner favours them for a few turns,
	# which, on a slow machine, took longer than the wait. Which mood each customer got
	# depended on the dice, and every new roll elsewhere shifts them.)
	Hooks.company_override = "chatty"
	Hooks.cat_wanders = false  # (the cat coming and going makes lines be asked for again)
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
		expected += Orders.bill(scene._order)
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
	assert_int(int(scene._owner["age"])).is_greater_equal(People.MIN_OWNER_AGE)


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
	Hooks.stay_minutes_override = 600
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
	Hooks.stay_minutes_override = 600
	Hooks.company_override = "chatty"
	Hooks.chat_chance_override = 1.0
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
	var spoken: bool = await _wait_until(spoke)
	# (Failed once on GitHub's slower runner, never here: say what happened, if it does again.)
	assert_bool(spoken).override_failure_message("no line from one customer to the other (%s to %s). The AI's last error: %s. The transcript's end:\n%s" % [a, b,
		scene._ai.last_error, _transcript(runner).right(1500)]).is_true()
	assert_int(scene._chats.size()).is_equal(1)
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()
	assert_array(scene._chats).is_empty()
	assert_int(int(Game.bar["visits"])).is_equal(2)


func test_quiet_customers_keep_to_themselves() -> void:
	Hooks.stay_minutes_override = 600
	Hooks.company_override = "quiet"
	Hooks.chat_chance_override = 1.0
	Hooks.cat_wanders = false  # (the cat coming and going makes lines be asked for again)
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 2)
	# Plenty of chances to chat (chance 1.0 each time the owner's free), and none taken.
	# (A longer limit: on a slow machine, like GitHub's, the lines can take a while.)
	var talked: bool = await _wait_until(func(): return scene._guests.size() == 2 and scene._guests[0].line >= 4 and scene._guests[1].line >= 4, 45000)
	assert_bool(talked).is_true()
	assert_str(_transcript(runner)).not_contains("gets talking to")
	assert_array(scene._chats).is_empty()
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


func test_no_two_customers_at_the_counter_share_a_name() -> void:
	Hooks.stay_minutes_override = 600
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
	Hooks.stay_minutes_override = 600
	Hooks.chat_chance_override = 0.0
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
	Hooks.stay_minutes_override = 600
	Hooks.chat_chance_override = 0.0
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

func test_the_panels_under_the_tent() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	var side := runner.find_child("StatsPanel") as Control
	var desk := runner.find_child("PdDesk") as Control
	var transcript_panel := (runner.find_child("Transcript") as Control).get_parent().get_parent() as Control
	# Left to right: the transcript, the PD's desk, then who's here and the stats.
	assert_bool(side.visible and desk.visible).is_true()
	assert_float(transcript_panel.position.x + transcript_panel.size.x).is_less(desk.position.x)
	assert_float(desk.position.x + desk.size.x).is_less(side.position.x)
	assert_float(side.position.x + side.size.x).is_less_equal(Visit.SCREEN.x)
	assert_object(runner.find_child("StatsToggle")).is_null()  # (no hiding it: it's who's here too)
	# The side panel opens on who's here now; the desk on the camera.
	var side_text := runner.find_child("StatsText") as RichTextLabel
	assert_str(side_text.get_parsed_text()).contains("HERE NOW").contains("THE OWNER").contains(str(scene._owner["name"]))
	assert_str((runner.find_child("PdDeskText") as RichTextLabel).get_parsed_text()).contains("PD CONTROLS").contains("not on anyone")
	scene._on_cat_clicked(_left_press())
	assert_str((runner.find_child("PdDeskText") as RichTextLabel).get_parsed_text()).contains("● REC").contains(str(scene._cat["name"]))
	# Everything on the desk at once (the edit, long spins, three pins): it scrolls, and never
	# grows past the screen or over the side panel (it did, at 1920x1080: 17 Nov).
	for k in 3:
		scene._pd.pins.append({"id": 100 + k, "speaker": "Kim Ji-ho", "text": "A long line, said at the counter late at night, that goes on and on and on for a while."})
	scene._pd.offer_edit([{"mood": "sad", "caption": "SOMEONE GET HIM A TISSUE PLEASE NOW"}, {"mood": "funny", "caption": "NAP TIME, THEN? REALLY THOUGH, REALLY"},
		{"mood": "roast", "caption": "THE CONFIDENCE, THOUGH, HONESTLY NOW"}], {"who": "x"}, [], ["x"], 0.0)
	scene._update_desk()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(desk.position.y + desk.size.y).is_less_equal(Visit.SCREEN.y)
	assert_float(desk.position.x + desk.size.x).is_less(side.position.x)
	scene._pd.air_edit(0)


func _left_press() -> InputEventMouseButton:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	return press


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
	assert_str(panel.get_parsed_text()).contains("HERE NOW").not_contains("Arrived")  # (one section at a time: who's here first)
	await _click(runner, runner.find_child("StatsTab_PEOPLE", true, false))
	assert_bool(await _wait_until(func(): return panel.get_parsed_text().contains("Arrived 1"), 3000)).override_failure_message(panel.get_parsed_text()).is_true()
	assert_str(panel.get_parsed_text()).not_contains("HIGHLIGHTS")


func test_stats_count_customer_chats() -> void:
	Hooks.stay_minutes_override = 600
	Hooks.company_override = "chatty"
	Hooks.chat_chance_override = 1.0
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 2)
	assert_bool(await _wait_until(func(): return scene._stats.chat_lines >= 2)).is_true()
	assert_int(scene._stats.chats_started).is_equal(1)
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


# --- Gender symbols ------------------------------------------------------------------------

func test_names_on_screen_show_gender_symbols() -> void:
	Hooks.stay_minutes_override = 600
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
	assert_str((runner.find_child("StatsText") as RichTextLabel).get_parsed_text()).contains(label)  # (who's here now)
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
	Hooks.gender_override = "non-binary"
	var runner := await _open_bar()
	var scene = runner.scene()
	await _run_one_visit(runner)
	assert_str(str(scene._customer["gender"])).is_equal("non-binary")
	assert_str(_transcript(runner)).contains("%s ⚲:" % scene._with_hangul(scene._customer))


func test_time_speeds_up_when_the_tent_is_empty_and_slows_when_busy() -> void:
	Hooks.run_clock = true
	Hooks.pause_scale_override = 1.0  # real speed, so the night doesn't race past before we look
	Hooks.stay_minutes_override = 600
	var runner := await _open_bar()
	var scene = runner.scene()
	assert_bool(await _wait_until(func(): return scene._time_speed > 5.0)).is_true()
	assert_str((runner.find_child("MomentLabel") as Label).text).contains("▶▶")
	_crowd(scene, 2)
	assert_bool(await _wait_until(func(): return scene._guests.size() >= 2 and scene._time_speed <= 1.0)).override_failure_message("time didn't slow down for two customers").is_true()
	Hooks.run_clock = false  # no more arrivals, so the tent can empty
	Hooks.pause_scale_override = 0.01
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


# --- The cat ----------------------------------------------------------------------------------

func test_a_new_bar_gets_a_cat() -> void:
	Hooks.cat_wanders = false  # (asleep by the stove: one that's wandered out into the street isn't drawn)
	var runner := await _open_bar()
	var cat: Dictionary = Game.bar["cat"]
	assert_str(str(cat["name"])).is_not_empty()
	assert_bool(CatRules.CAT_COATS.has(cat["coat"])).is_true()
	assert_bool(CatRules.CAT_PERSONALITIES.has(cat["personality"])).is_true()
	assert_bool(SaveStore.load_bar(str(Game.bar["id"]))["cat"].has("name")).is_true()  # saved
	assert_bool((runner.find_child("Cat") as Control).visible).is_true()
	assert_str((runner.find_child("StatsText") as RichTextLabel).get_parsed_text()).contains("THE CAT")  # (who's here now)
	assert_str(_transcript(runner)).contains("%s, the tent's %s cat" % [cat["name"], cat["coat"]])


func test_the_ai_names_the_cat() -> void:
	CannedAi.scripted = [ANY_OWNER, A_BAR_NAME, A_CAT_NAME]
	await _open_bar()
	assert_str(str(Game.bar["cat"]["name"])).is_equal("Dubu")


func test_the_cat_on_a_lap_is_in_the_conversation() -> void:
	Hooks.stay_minutes_override = 600
	Hooks.cat_wanders = false
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
	assert_str(scene._tent_cat.prompt()).contains("on %s's lap" % guest.customer["name"])
	# When they leave, the cat jumps down.
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()
	assert_str(scene._cat_spot).is_not_equal("lap")
	assert_object(scene._cat_with).is_null()


func test_people_get_a_moment_to_talk_to_the_cat() -> void:
	Hooks.stay_minutes_override = 600
	Hooks.cat_wanders = false
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 1)
	assert_bool(await _wait_until(func(): return not scene._guests.is_empty() and scene._guests[0].line >= 2)).is_true()
	var guest = scene._guests[0]
	var cat_name := str(Game.bar["cat"]["name"])
	# On their lap: a moment for the customer (now and then, so it may take a few goes).
	for attempt in 30:
		scene._move_cat("lap")
		if guest.cat_moment != "":
			break
	assert_str(guest.cat_moment).contains(cat_name)
	assert_str(scene._owner_cat_moment).is_empty()
	# Up on the counter: the owner's to deal with, and the customer's moment has gone.
	for attempt in 30:
		scene._move_cat("counter")
		if scene._owner_cat_moment != "":
			break
	assert_str(scene._owner_cat_moment).contains("counter")
	assert_str(guest.cat_moment).is_empty()
	# With a moment, the owner's talk with them turns to the cat (as a situation alone, the AI
	# let it go by).
	scene._owner_cat_moment = ""
	guest.cat_moment = "%s is winding round their ankles." % cat_name
	scene._owner_working = true  # (so nothing else gets to them first)
	scene._talk(guest)
	assert_str(guest.topic).is_equal("the_cat")
	# Out in the street: nobody's.
	scene._move_cat("street")
	assert_str(scene._owner_cat_moment).is_empty()
	assert_str(guest.cat_moment).is_empty()


func test_the_loading_screen_suits_a_new_bar_or_a_reopened_one() -> void:
	var reopened: LoadingScreen = auto_free(LoadingScreen.new())
	reopened.reopening = true
	add_child(reopened)
	var reel = reopened.find_child("CaptionReel", true, false)
	assert_array(reel.lines).is_equal(LoadingScreen.REOPEN_LINES)
	for line in LoadingScreen.REOPEN_LINES:  # nothing that's only for a new bar
		for new_only in ["CAT AUDITIONS", "CASTING THE OWNER", "PAINTING THE SIGN", "TONIGHT'S POCHA IS"]:
			assert_str(str(line[1])).not_contains(new_only)
	var fresh: LoadingScreen = auto_free(LoadingScreen.new())
	add_child(fresh)
	assert_array(fresh.find_child("CaptionReel", true, false).lines).is_equal(LoadingScreen.LINES)


func test_the_loading_screens_tent_is_the_bars_own_with_a_stool_for_every_seat() -> void:
	# A new bar: a placeholder ("?" on the sign, nothing in Korean made up), with every seat.
	var fresh: LoadingScreen = auto_free(LoadingScreen.new())
	add_child(fresh)
	assert_bool(fresh.is_placeholder()).is_true()
	assert_str((fresh.find_child("SignHangul", true, false) as Label).text).is_equal("?")
	assert_int(fresh.find_child("Stools", true, false).get_child_count()).is_equal(NightRules.SEATS * 2)  # (a seat and legs each)
	assert_str((fresh.find_child("Sign", true, false) as Control).tooltip_text).is_empty()
	# Its look's chosen: the tent's redrawn as the bar's, in the same place.
	var at := fresh.get_node("Tent").get_index()
	var bar := {"name": "Dalbit Pocha", "name_meaning": "moonlight tent", "look": {"hangul": "달빛포차", "tarp": "blue_stripes", "sign": "neon", "shape": "peaked", "touches": ["lanterns"]}}
	fresh.show_bar(bar)
	await get_tree().process_frame
	assert_bool(fresh.is_placeholder()).is_false()
	assert_int(fresh.get_node("Tent").get_index()).is_equal(at)
	assert_str((fresh.find_child("SignHangul", true, false) as Label).text).is_equal("달빛포차")
	assert_str((fresh.find_child("SignEnglish", true, false) as Label).text).is_equal("DALBIT POCHA")
	assert_str((fresh.find_child("Sign", true, false) as Control).tooltip_text).contains("달빛포차").contains("moonlight tent")
	assert_that((fresh.find_child("Tarp", true, false) as Polygon2D).color).is_equal(Color(BarLook.BAR_TARPS["blue_stripes"][0]))
	assert_int(fresh.find_child("Stools", true, false).get_child_count()).is_equal(NightRules.SEATS * 2)
	# Reopening a bar: its own tent from the start; one from before looks gets the plain one.
	var reopened: LoadingScreen = auto_free(LoadingScreen.new())
	reopened.bar = bar
	add_child(reopened)
	assert_str((reopened.find_child("SignHangul", true, false) as Label).text).is_equal("달빛포차")
	var older: LoadingScreen = auto_free(LoadingScreen.new())
	older.bar = {"name": "Imo-ne Pocha"}
	add_child(older)
	assert_bool(older.is_placeholder()).is_false()
	assert_str((older.find_child("SignHangul", true, false) as Label).text).is_equal(BarLook.DEFAULT_HANGUL)
	# The title screen's backdrop: the plain tent, its sign explained on hover.
	var title: LoadingScreen = auto_free(LoadingScreen.new())
	title.backdrop = true
	add_child(title)
	assert_str((title.find_child("Sign", true, false) as Control).tooltip_text).contains("pojangmacha")


func test_the_street_behind_the_tent_is_pixel_art_and_reaches_above_it() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	var street = scene._street_art
	assert_bool(street.has_art()).is_true()  # (the game's own art folder has the street)
	assert_array(street.chosen).not_contains([""])  # (this bar's own street, a piece in every slot)
	assert_float(street.position.y + street.size.y).is_equal_approx(scene._stage.position.y + scene.STAGE_SIZE.y, 2.0)  # (behind the stage, and above it)
	assert_int(int(scene.STAGE_ROOM) % street.SCALE).is_equal(0)  # (the stage's top on a row of the grid: the tarp's pixels line up with the street's)
	assert_float(scene._stage.position.y - street.position.y).is_equal(scene.STAGE_ROOM)
	assert_bool(scene._tent_view.sky.visible).is_false()  # (the stage's own sky and city left out, so the street shows through)
	assert_bool(scene._skyline.visible).is_false()
	assert_that(street.sky.color).is_equal(scene._tent_view.sky.color)  # (the night by the hour)
	assert_float(scene._log_panel.position.y).is_greater(scene._stage.position.y + scene.STAGE_SIZE.y)  # (the panels below it all)


func test_a_slow_ai_on_the_loading_screen_shows_its_alive() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	scene._typing_label.text = ""
	scene._loading_note = "Writing \"Previously on…\""
	assert_str(scene._loading_status()).is_equal("Writing \"Previously on…\"")  # (it used to be wiped every frame)
	scene._loading_since -= 8.0
	assert_str(scene._loading_status()).contains("(8s)")
	scene._loading_since -= 12.0
	assert_str(scene._loading_status()).contains("may be waking up")
	scene._loading_note = ""


func test_hovering_over_a_customer_says_who_they_are() -> void:
	Hooks.stay_minutes_override = 600
	Hooks.cat_wanders = false
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 1)
	assert_bool(await _wait_until(func(): return not scene._guests.is_empty() and scene._guests[0].line >= 2)).is_true()
	var guest = scene._guests[0]
	await get_tree().create_timer(0.1).timeout  # (on their stool)
	scene._update_info()
	var hover := guest.node.find_child("Hover", true, false) as Control
	assert_object(hover).is_not_null()
	assert_int(hover.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	var tip := hover.tooltip_text
	assert_str(tip).contains(str(guest.customer["name"]))
	assert_str(tip).contains("first time here")
	assert_str(tip).contains("Company:")
	assert_str(tip).contains("On the table:")
	assert_str(tip).not_contains("Here because")  # (a quick summary, not their whole story)
	for line in tip.split("\n"):
		assert_int(line.length()).is_less_equal(Visit.HOVER_WIDTH + 12)  # wrapped (a long name or word can run over a little)
	# The dishes beside them keep their own tooltips: the hover area doesn't cover them.
	assert_bool(hover.get_global_rect().intersects(guest.food_row.get_global_rect())).is_false()
	assert_bool(hover.get_global_rect().intersects(guest.drinks_row.get_global_rect())).is_false()
	# Kept up to date: a cat on their lap shows.
	scene._move_cat("lap")
	scene._update_info()
	assert_str(hover.tooltip_text).contains("on their lap")


func test_the_cat_steals_a_fish_cake() -> void:
	Hooks.stay_minutes_override = 600
	Hooks.cat_wanders = false
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 1)
	assert_bool(await _wait_until(func(): return not scene._guests.is_empty() and scene._guests[0].line >= 2)).is_true()
	var guest = scene._guests[0]
	var cat_name := str(Game.bar["cat"]["name"])
	guest.served.append("odeng")
	scene._add_dish(guest, "odeng")
	var on_table: int = guest.food_row.get_child_count()
	var odeng_before: int = guest.served.count("odeng")  # (they may have ordered some themselves: the seed and the frames decide)
	var bill: int = Orders.bill(guest.order)
	scene._cat_steals(guest)
	assert_int(guest.served.count("odeng")).is_equal(odeng_before - 1)  # gone from the table...
	assert_int(guest.food_row.get_child_count()).is_equal(on_table - 1)
	assert_int(Orders.bill(guest.order)).is_equal(bill)  # ...but still on the bill
	assert_str(_transcript(runner)).contains("%s snatches an odeng skewer off %s's plate" % [cat_name, guest.customer["name"]])
	assert_str(scene._cat_spot).is_equal("street")  # off with it
	assert_str(scene._owner_cat_moment).contains("snatched an odeng skewer")
	assert_str(guest.cat_moment).contains("snatched one of their odeng skewers")
	assert_int(int(scene._stats.captions.get("cat_thief", 0))).is_equal(1)
	assert_int(int(scene._stats.event_counts.get("cat_stole", 0))).is_equal(1)


func test_the_night_has_neon_and_steam() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	assert_object(runner.find_child("Neon", true, false)).is_not_null()
	assert_str((runner.find_child("Neon", true, false) as Label).text).is_equal("노\n래\n방")
	assert_str((runner.find_child("Neon", true, false) as Label).tooltip_text).contains("karaoke")  # Korean on screen explains itself
	assert_int((runner.find_child("Neon", true, false) as Label).mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	# A hot dish steams; a drink doesn't.
	_crowd(scene, 1)
	assert_bool(await _wait_until(func(): return not scene._guests.is_empty())).is_true()
	var guest = scene._guests[0]
	scene._add_dish(guest, "tteokbokki")
	scene._add_dish(guest, "soju")
	assert_object(guest.food_row.get_child(guest.food_row.get_child_count() - 1).find_child("Steam", true, false)).is_not_null()
	assert_object(guest.drinks_row.get_child(guest.drinks_row.get_child_count() - 1).find_child("Steam", true, false)).is_null()
	# Each drawn from what it comes in.
	assert_array(guest.food_row.get_child(guest.food_row.get_child_count() - 1).shapes).is_not_empty()
	assert_str(guest.food_row.get_child(guest.food_row.get_child_count() - 1).tooltip_text).is_equal("Tteokbokki")


func test_the_door_the_chorus_and_the_double_take() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	Hooks.stay_minutes_override = 600
	_crowd(scene, 2)
	assert_bool(await _wait_until(func(): return scene._guests.size() == 2)).is_true()
	var first = scene._guests[0]
	var second = scene._guests[1]
	assert_bool(first.transcript.any(func(entry): return str(entry.get("action", "")).contains("Eoseo oseyo"))).is_true()  # strangers, welcomed politely
	# Someone says hwaiting: the counter joins in, with a caption.
	scene._cheer_along(first, "Hwaiting, you've got this!", [])
	assert_str(_transcript(runner)).contains("Everyone at the counter joins in")
	assert_int(int(scene._stats.event_counts.get("cheered_on", 0))).is_equal(1)
	assert_int(int(scene._stats.captions.get("hwaiting", 0))).is_equal(1)
	assert_bool(second.transcript.any(func(entry): return str(entry.get("action", "")).contains("Hwaiting"))).is_true()
	scene._cheer_along(first, "Have a good night.", [])
	assert_int(int(scene._stats.event_counts.get("cheered_on", 0))).is_equal(1)  # (only when it's said)
	# A shock: everyone else who heard it is stunned for their next line.
	var said_it := str(first.customer["name"])
	scene._stun_listeners(said_it, [said_it, str(second.customer["name"]), str(scene._owner["name"])])
	assert_str(second.stunned).contains("hardly believe")
	assert_str(scene._owner_stunned).contains("hardly believe")
	assert_str(first.stunned).is_empty()


func test_the_menu_board_opens_the_whole_menu() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	var board = runner.find_child("MenuBoard", true, false)
	assert_array(board.shown_ids).is_equal(Menu.board_order(scene._specials).map(func(item): return str(item["id"])))
	assert_array(MenuBoard.STYLE_ORDER).contains([board.style])
	assert_str(board.tooltip_text).contains("메뉴").contains("Click")  # Korean on screen explains itself
	assert_int(board.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)
	# Click it: the whole menu, over the tent.
	board.open()
	assert_bool(board.panel.visible).is_true()
	assert_int(scene._stats.menu_opened).is_equal(1)  # (counted)
	assert_str(scene._stats.panel_text(0, 0)).contains("Menu board opened: 1")
	var text: String = (board.panel.find_child("MenuText", true, false) as RichTextLabel).get_parsed_text()
	assert_str(text).contains("떡볶이").contains("Tteokbokki").contains("₩").contains("DRINKS")
	(board.panel.find_child("CloseMenu", true, false) as Button).pressed.emit()
	assert_bool(board.panel.visible).is_false()
	# Specials first, the favourite and sold out marked.
	var written := MenuBoard.menu_text(Menu.board_order(["pajeon"]), ["pajeon"], ["sundae"], "tteokbokki", "Byeolbit Pocha")
	assert_int(written.find("Pajeon")).is_less(written.find("Tteokbokki"))
	assert_str(written).contains("TONIGHT'S SPECIALS").contains("인기").contains("품절").contains("[s]").contains("Byeolbit Pocha")
	assert_str(written).not_contains("Somaek")  # (never on the menu: everyone knows to mix it)
	assert_str(MenuBoard.style_for("a bar")).is_equal(MenuBoard.style_for("a bar"))  # (the same every night)


func test_drinking_rituals_and_table_games() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	Hooks.stay_minutes_override = 600
	_crowd(scene, 2)
	assert_bool(await _wait_until(func(): return scene._guests.size() == 2 and scene._guests[0].drinks_row.get_child_count() > 0)).is_true()
	var first = scene._guests[0]
	assert_bool(first.kya_done).is_true()  # (the first drink's had its moment: Kya~!, now and then)
	# A new bottle of soju: the tornado.
	scene._add_dish(first, "soju")
	assert_int(int(scene._stats.rituals.get("tornado", 0))).is_greater_equal(1)
	# A table game, taken up: on TV, and for the spoon mic, the spoon in the bottle.
	var chat = Visit.Chat.new()
	chat.game = "spoon_mic"
	scene._table_game_taken(chat, first, "Pass me that spoon, I'm singing!")
	assert_int(int(scene._stats.event_counts.get("table_game", 0))).is_equal(1)
	assert_int(int(scene._stats.captions.get("game_spoon_mic", 0))).is_equal(1)
	assert_object(first.drinks_row.find_child("SpoonMic", true, false)).is_not_null()
	scene._table_game_taken(chat, first, "Pass me that spoon, I'm singing!")
	assert_int(int(scene._stats.event_counts.get("table_game", 0))).is_equal(1)  # (once a chat)
	# Turning away to drink, in front of someone much older: now and then, once a night.
	first.customer["age"] = 24
	scene._owner["age"] = 61
	for _k in 60:
		scene._mind_your_elders(first, null)
	assert_int(int(scene._stats.rituals.get("turned_away", 0))).is_equal(1)
	assert_str(_transcript(runner)).contains("turns away to drink")
	assert_str(scene._stats.panel_text(0, 0)).contains("Rituals:")


func _click_person(scene, guest) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	scene._on_guest_clicked(press, guest)


func test_the_pds_camera_follows_whoever_is_clicked() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	Hooks.stay_minutes_override = 600
	_crowd(scene, 2)
	assert_bool(await _wait_until(func(): return scene._guests.size() == 2 and scene._guests.all(func(g): return g.node.get_node_or_null("Hover") != null))).is_true()
	var followed = scene._guests[0]
	assert_str(str(followed.node.get_node("Hover").tooltip_text)).contains("Click to follow them with the camera")
	_click_person(scene, followed)
	assert_bool(scene._camera.is_on(followed)).is_true()
	assert_object(followed.node.get_node_or_null("CameraBadge")).is_not_null()
	assert_str(str(followed.node.get_node("Hover").tooltip_text)).contains("click to stop")
	assert_str(_transcript(runner)).contains("The camera follows %s." % followed.customer["name"])
	assert_str((runner.find_child("CameraRec") as Label).text).contains(str(followed.customer["name"]))
	assert_bool(followed.transcript.any(func(e): return str(e.get("action", "")) == Talk.camera_happened(followed.customer["name"]))).is_true()  # (noticed: in their conversation)
	assert_int(int(scene._stats.event_counts.get("camera_on", 0))).is_equal(1)
	# The owner gets to them sooner (as if they'd waited longer).
	assert_int(scene._neediness(followed)).is_equal(followed.attended - PdCamera.PULL - (3 if followed.company == "owner" else 0))
	# Clicked again: it stops.
	_click_person(scene, followed)
	assert_bool(scene._camera.is_on(followed)).is_false()
	assert_str(_transcript(runner)).contains("The camera stops following %s." % followed.customer["name"])
	await get_tree().process_frame
	assert_object(followed.node.get_node_or_null("CameraBadge")).is_null()
	# Followed again, and they go home: the camera stops with them.
	_click_person(scene, followed)
	followed.stay_left = 0.0
	assert_bool(await _wait_until(func(): return not scene._guests.has(followed))).is_true()
	assert_object(scene._camera.following).is_null()
	assert_array(scene._stats.events.filter(func(e): return str(e["kind"]) == "camera_off").map(func(e): return str(e["why"]))).is_equal(["pd", "left"])
	assert_str(scene._stats.panel_text(0, 0)).contains("THE PD")


func test_the_pds_camera_can_follow_the_cat() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	var rec := runner.find_child("CameraRec") as Label
	assert_bool(rec.visible).is_false()
	assert_str(scene._cat_node.tooltip_text).contains("Click to follow it with the camera")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	scene._on_cat_clicked(press)
	assert_bool(scene._camera.on_cat).is_true()
	assert_object(scene._cat_node.get_node_or_null("CameraBadge")).is_not_null()
	# The corner says so, over everything (never hidden behind a speech bubble).
	assert_bool(rec.visible).is_true()
	assert_str(rec.text).contains(str(scene._cat["name"]))
	assert_int(rec.z_index).is_greater(scene._bubble_layer.z_index)
	assert_str(_transcript(runner)).contains("The camera follows %s, the cat." % scene._cat["name"])
	# Clicked again, it stops.
	scene._on_cat_clicked(press)
	assert_bool(scene._camera.on_cat).is_false()
	assert_bool(rec.visible).is_false()
	assert_array(scene._stats.events.filter(func(e): return str(e["kind"]).begins_with("camera_")).map(func(e): return str(e["kind"]))).is_equal(["camera_on", "camera_off"])


func test_the_pds_plant_cards() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	Hooks.stay_minutes_override = 600
	# Tonight's hand, on the desk.
	var cards := runner.find_child("PlantCards") as Control
	assert_int(cards.get_child_count()).is_equal(Plants.HAND)
	assert_bool(scene._pd.hand.all(func(card): return Plants.CARDS.has(card))).is_true()
	assert_array(Game.bar["last_hand"]).is_equal(scene._pd.hand)  # (remembered: not the same tomorrow)
	scene._pd.hand = ["phone", "rain", "regular_in"]  # (these three, for this test)
	scene._update_desk()
	var phone := cards.get_node("Plant_phone") as Button
	assert_bool(phone.disabled).is_true()  # (nobody at the counter yet)
	_crowd(scene, 2)
	assert_bool(await _wait_until(func(): return scene._guests.size() == 2)).is_true()
	scene._update_desk()
	assert_bool(phone.disabled).is_false()
	# A phone rings: for whoever the camera's on.
	var followed = scene._guests[1]
	_click_person(scene, followed)
	followed.camera_moment = ""
	phone.pressed.emit()
	assert_str(followed.plant_card).is_equal("phone")
	assert_str(followed.plant_moment).contains("phone has just started ringing")
	assert_str(_transcript(runner)).contains("%s's phone starts ringing: it's " % followed.customer["name"])  # (who's calling, this time)
	assert_bool(followed.transcript.any(func(e): return str(e.get("action", "")) == followed.plant_happened)).is_true()
	assert_int(int(scene._stats.captions.get("plant_phone", 0))).is_equal(1)  # (so you can see it happen)
	# Whichever conversation they speak in next has it too (once).
	var elsewhere: Array = []
	scene._plant_in(elsewhere, followed)
	scene._plant_in(elsewhere, followed)
	assert_int(elsewhere.size()).is_equal(1)
	assert_bool(phone.disabled).is_true()  # (once a night)
	assert_str(phone.text).contains("(played)")
	# The rain: tonight's weather, now, for everyone.
	scene._weather_kind = ""
	scene._pd.press("rain")
	assert_str(scene._weather_kind).is_equal("rain")
	assert_str(str(scene._guests[0].moment["weather"])).is_equal(Plants.CARDS["rain"]["weather"])
	assert_str(scene._guests[0].plant_card).is_equal("rain")
	assert_str(_transcript(runner)).contains("the heavens open")
	# A regular rung: on their way, and they'll know why they're here.
	var away: Array = scene._regulars_away()
	if not away.is_empty():
		scene._pd.press("regular_in")
		assert_str(scene._planted_regular).is_not_empty()
		assert_bool(scene._regulars_due.any(func(d): return str(d["id"]) == scene._planted_regular)).is_true()
		assert_str(_transcript(runner)).contains("The PD rings")
	assert_int(int(scene._stats.event_counts.get("plant_played", 0))).is_equal(3 if not away.is_empty() else 2)
	assert_str(scene._stats.panel_text(0, 0)).contains("Plants: played")


func test_small_world_gets_two_strangers_talking() -> void:
	Hooks.stay_minutes_override = 600
	Hooks.company_override = "chatty"
	Hooks.chat_chance_override = 0.0  # (nobody chatting by themselves)
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 2)
	assert_bool(await _wait_until(func(): return scene._guests.size() == 2 and scene._guests.all(func(g): return scene._can_chat(g)))).is_true()
	assert_array(scene._chats).is_empty()
	scene._pd.hand = ["small_world", "phone", "rain"]
	scene._update_desk()
	assert_bool((runner.find_child("Plant_small_world") as Button).disabled).is_false()  # (two who could get talking)
	scene._pd.press("small_world")
	assert_int(scene._chats.size()).is_equal(1)
	assert_array(_names(scene._chats[0].people)).contains_exactly_in_any_order(_names(scene._guests))  # (by name: see _names)
	assert_str(_transcript(runner)).contains("gets talking to").contains("have just worked out that they")
	assert_bool(scene._stats.events.any(func(e): return str(e["kind"]) == "plant_played" and str(e.get("what", "")) != "")).is_true()
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


func test_the_pd_pins_lines_for_the_episode() -> void:
	Hooks.stay_minutes_override = 600
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 1)
	assert_bool(await _wait_until(func(): return scene._said.size() >= 2)).is_true()
	assert_str(_transcript(runner)).contains("📌")  # (each line said has one)
	scene._on_transcript_link("pin:1")
	assert_int(scene._pd.pins.size()).is_equal(1)
	assert_str(_transcript(runner)).contains("📌 Pinned for the episode: %s" % scene._said[1]["speaker"])
	assert_str(str(scene._night_quote()["text"])).is_equal(str(scene._said[1]["text"]))  # (the night's quote: the first pin, not the longest line)
	assert_int(scene._diary_facts()["pinned"].size()).is_equal(1)
	assert_str((runner.find_child("PdDeskText") as RichTextLabel).get_parsed_text()).contains("Pinned 1/3")
	assert_str((runner.find_child("Transcript") as RichTextLabel).get_parsed_text()).contains(str(scene._said[1]["text"]))  # (drawn again, the line's still there...)
	assert_bool(scene._chunks.any(func(c): return int(c["pin"]) == 1 and scene._render(c).contains("[bgcolor="))).is_true()  # (...and tinted: it's pinned)
	assert_bool(scene._chunks.any(func(c): return int(c["pin"]) == 0 and not scene._render(c).contains("[bgcolor="))).is_true()
	scene._pd.link.call("pin:1")  # (let go from the desk: the same as clicking its 📌 again)
	assert_int(scene._pd.pins.size()).is_equal(0)
	assert_str(_transcript(runner)).contains("📌 Unpinned")
	assert_bool(scene._chunks.all(func(c): return not scene._render(c).contains("[bgcolor="))).is_true()
	scene._on_transcript_link("pin:999")  # (no such line: nothing happens)
	scene._on_transcript_link("https://example.com")
	assert_int(scene._pd.pins.size()).is_equal(0)
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


func test_the_pd_writes_a_card() -> void:
	Hooks.stay_minutes_override = 600
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 1)
	assert_bool(await _wait_until(func(): return scene._guests.size() == 1 and scene._guests[0].line >= 2)).is_true()
	var guest = scene._guests[0]
	scene._pd.hand = ["ppl", "cue_card", "interview", "text_from"]
	scene._update_desk()
	# A text from…: who it's from is said before you type it, and it's who it's from when played.
	Hooks.write_ins_offline = true
	scene._update_desk()
	(runner.find_child("Plant_text_from") as Button).pressed.emit()
	var sender: String = Plants.gendered(str(scene._pd.card_what["text_from"]), str(guest.customer["gender"]))
	assert_str((runner.find_child("PlantWritingLabel") as Label).text).contains("a text from " + sender)
	(runner.find_child("PlantWritingText") as LineEdit).text_submitted.emit("come back to the office")
	assert_str(_transcript(runner)).contains("a text from %s. «come back to the office»" % sender)
	Hooks.write_ins_offline = false
	scene._update_desk()
	# Offline, a write-in's greyed out: the canned lines can't answer what's written.
	var cue := runner.find_child("Plant_cue_card") as Button
	# Each kind looks its own: a tag and a stripe (and the hover says what kind it is).
	assert_str((cue.get_node("Kind") as Label).text).is_equal("WRITE-IN")
	assert_str((runner.find_child("Plant_ppl").get_node("Kind") as Label).text).is_equal("SPONSOR")
	assert_str(cue.tooltip_text).starts_with("A write-in")
	assert_bool(cue.disabled).is_true()
	assert_str(cue.tooltip_text).contains("Needs the AI")
	Hooks.write_ins_offline = true
	scene._update_desk()
	assert_bool(cue.disabled).is_false()
	# Clicking it opens the box on the desk (the night carries on).
	var clock: float = scene._clock
	cue.pressed.emit()
	var box := runner.find_child("PlantWriting") as Control
	var typed := runner.find_child("PlantWritingText") as LineEdit
	assert_bool(box.visible).is_true()
	assert_str((runner.find_child("PlantWritingLabel") as Label).text).contains("The conversation turns to").contains(str(guest.customer["name"]))
	# Esc puts it back (and doesn't open Options).
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	scene._pd.writing_key(esc)
	assert_bool(box.visible).is_false()
	assert_bool((runner.find_child("OptionsPanel") as Control).visible).is_false()
	# Refused: why, and the card stays in the hand.
	cue.pressed.emit()
	typed.text_submitted.emit("hi")
	assert_str((runner.find_child("PlantWritingProblem") as Label).text).contains("a few words")
	typed.text_submitted.emit("a night out drinking jinro")
	assert_str((runner.find_child("PlantWritingProblem") as Label).text).contains("real brands")
	assert_bool(scene._pd.played.has("cue_card")).is_false()
	assert_int(scene._stats.written_refused).is_equal(2)
	# Played: in the scene as a cue card, their conversation's topic for a while, and logged.
	typed.text_submitted.emit("«her first love»")
	assert_bool(box.visible).is_false()
	assert_bool(scene._pd.played.has("cue_card")).is_true()
	assert_str(_transcript(runner)).contains("[PD]").contains("«her first love»")
	assert_str(guest.plant_moment).contains("«her first love»")
	assert_bool(guest.pd_topic_lines > 0 or scene._chat_of(guest) != null).is_true()
	assert_str(str(scene._stats.written[-1]["text"])).is_equal("her first love")
	assert_int(int(scene._stats.captions.get("plant_cue_card", 0))).is_equal(1)
	assert_float(scene._clock).is_greater_equal(clock)
	# An interview cut: their next line, straight to camera, set apart.
	scene._pd.play("interview", "Who do you wish was here tonight?")
	assert_bool(guest.to_camera).is_true()
	await scene._say(guest, false, "Honestly? My grandmother.")
	assert_bool(guest.to_camera).is_false()
	assert_str(_transcript(runner)).contains("● INTERVIEW").contains("to camera: Honestly? My grandmother.")
	# Whoever a card's just happened to speaks before the owner does (night 27: she spoke in between, and was answered).
	var at: int = guest.line
	guest.line = 4
	guest.plant_moment = "Their phone has just rung."
	assert_bool(scene._their_turn_first(guest)).is_true()
	assert_int(guest.line).is_equal(5)
	assert_bool(scene._their_turn_first(guest)).is_false()  # (theirs already)
	guest.plant_moment = ""
	guest.line = at
	# A word from our sponsor: on their table, label out, and not on their bill.
	var bill: int = Orders.bill(guest.order)
	scene._pd.play("ppl")
	assert_object(guest.drinks_row.find_child("Sponsor", true, false)).is_not_null()
	assert_int(Orders.bill(guest.order)).is_equal(bill)
	assert_int(int(scene._stats.captions.get("plant_ppl", 0))).is_equal(1)
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


func test_the_pds_edit() -> void:
	Hooks.stay_minutes_override = 600
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 1)
	assert_bool(await _wait_until(func(): return scene._guests.size() == 1)).is_true()
	var who := str(scene._guests[0].customer["name"])
	var reply := {"mood": "sad", "who": who, "caption": "LONG DAY", "flip_caption": "NAP TIME, THEN?", "roast_caption": "THE CONFIDENCE, THOUGH"}
	var spins := [{"mood": "sad", "caption": "LONG DAY"}, {"mood": "funny", "caption": "NAP TIME, THEN?"}, {"mood": "roast", "caption": "THE CONFIDENCE, THOUGH"}]
	var lines := [{"speaker": who, "text": "What a day."}]
	# Up on the desk: three spins, the AI's first; key 3 picks the roast.
	scene._pd.offer_edit(spins, reply, lines, [who], 0.0)
	assert_bool((runner.find_child("PdEdit") as Control).visible).is_true()
	assert_int(runner.find_child("PdEditSpins").get_child_count()).is_equal(3)
	assert_str((runner.find_child("Edit_1") as Button).text).contains("SAD").contains("LONG DAY")
	var three := InputEventKey.new()
	three.keycode = KEY_3
	three.pressed = true
	scene._unhandled_input(three)
	assert_bool((runner.find_child("PdEdit") as Control).visible).is_false()
	var aired: Array = scene._stats.events.filter(func(e): return str(e["kind"]) == "big_moment")
	assert_str(str(aired[-1]["mood"])).is_equal("roast")
	assert_str(str(aired[-1]["ai_mood"])).is_equal("sad")  # (for the diary: sincere, whatever aired)
	assert_str(str(aired[-1]["caption"])).is_equal("THE CONFIDENCE, THOUGH")
	assert_int(int(scene._stats.edits_made.get("sad→roast", 0))).is_equal(1)
	assert_int(int(scene._stats.edit_log[-1]["aired"])).is_equal(2)  # (logged: every spin offered, and which aired)
	assert_str(str(scene._stats.edit_log[-1]["spins"][2]["caption"])).is_equal("THE CONFIDENCE, THOUGH")
	# Left alone: the AI's own goes out when time's up.
	scene._pd.offer_edit(spins, reply, lines, [who], 0.0)
	assert_bool(await _wait_until(func(): return scene._pd.edit.is_empty(), 3000)).is_true()
	aired = scene._stats.events.filter(func(e): return str(e["kind"]) == "big_moment")
	assert_str(str(aired[-1]["mood"])).is_equal("sad")
	assert_bool(bool(aired[-1]["edited"])).is_false()
	assert_int(scene._stats.edits_offered).is_equal(2)
	assert_str(scene._stats.panel_text(0, 0)).contains("The edit: offered 2 · you picked a spin 1")
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


func test_more_of_the_pds_plant_cards() -> void:
	Hooks.stay_minutes_override = 600
	Hooks.company_override = "chatty"
	Hooks.chat_chance_override = 1.0
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 3)
	assert_bool(await _wait_until(func(): return scene._guests.size() == 3 and scene._guests.any(func(g): return scene._chat_partner(g) != null))).override_failure_message("nobody got chatting").is_true()
	scene._pd.hand = ["round_on", "small_world", "power_goes"]
	scene._update_desk()
	# Aimed with the camera: the hover says who.
	var buyer = scene._guests[0]
	_click_person(scene, buyer)
	assert_str((runner.find_child("Plant_round_on") as Button).tooltip_text).contains(str(buyer.customer["name"])).contains("the camera's on them")
	# A round on them: a bottle on their bill and their table, and everyone else told.
	var bill_before: Array = buyer.order.duplicate()
	scene._pd.press("round_on")
	assert_int(buyer.order.size()).is_equal(bill_before.size() + 1)
	assert_str(str(buyer.order[-1])).is_equal("soju")
	assert_str(buyer.plant_card).is_equal("round_on")
	for other in scene._guests:
		if other != buyer:
			assert_str(other.plant_moment).contains(Names.given_name(str(buyer.customer["name"])))
	assert_int(int(scene._stats.captions.get("plant_round_on", 0))).is_equal(1)
	# It lingers a line (a round's a smaller thing than the ex walking past), in their chat if they're in one.
	var lingering = scene._chat_of(buyer) if scene._chat_of(buyer) != null else buyer
	assert_int(lingering.pd_topic_lines).is_equal(Plants.lingers("round_on"))
	assert_str(lingering.pd_topic).contains("still on their minds")
	# Someone with it on their mind who starts a chat brings it with them (and it's the chat's now).
	var fresh = CounterChats.Chat.new()
	var mindful = scene._guests.filter(func(g): return g != buyer)[0]
	mindful.pd_topic = "the ex"
	mindful.pd_topic_lines = 2
	scene._bring_into_chat(fresh, [mindful])
	assert_str(fresh.pd_topic).is_equal("the ex")
	assert_int(fresh.pd_topic_lines).is_equal(2)
	assert_int(mindful.pd_topic_lines).is_equal(0)
	# In a chat, whoever a card's just happened to speaks next, even if they spoke last.
	var talking = CounterChats.Chat.new()
	var other = scene._guests.filter(func(g): return g != mindful)[0]
	talking.people = [mindful, other]
	talking.last_speaker = str(mindful.customer["name"])
	var voices := [str(mindful.customer["name"]), str(other.customer["name"])]
	var kept := [mindful.plant_moment, other.plant_moment]  # (put back after: the round's moments)
	mindful.plant_moment = ""
	other.plant_moment = ""
	assert_str(scene._chat_speaker(talking, voices, false)).is_equal(str(other.customer["name"]))  # (not whoever spoke last)
	mindful.plant_moment = "Their phone's just buzzed: a text from their sister."
	assert_str(scene._chat_speaker(talking, voices, false)).is_equal(str(mindful.customer["name"]))
	mindful.plant_moment = kept[0]
	other.plant_moment = kept[1]
	# Something's just happened to them: the owner turns to them sooner, and a chat of theirs carries on.
	var waiting = scene._guests.filter(func(g): return g != buyer)[0]
	assert_int(scene._neediness(waiting)).is_equal(waiting.attended - scene.PLANT_PULL - (3 if waiting.company == "owner" else 0))

	# Small world: two chatting, both told (not a chat about to break up).
	scene._camera_off("pd")
	var partner = scene._chat_partner(scene._pd.target("small_world")[0])
	var stays: float = partner.stay_left
	partner.stay_left = 5.0
	assert_bool(scene._pair_ok(partner)).is_false()
	partner.stay_left = stays
	var pair: Array = scene._pd.target("small_world")
	assert_int(pair.size()).is_equal(2)
	scene._pd.press("small_world")
	assert_str(pair[0].plant_card).is_equal("small_world")
	assert_str(pair[1].plant_card).is_equal("small_world")
	assert_str(pair[0].plant_moment).contains(Names.given_name(str(pair[1].customer["name"])))
	assert_bool(Plants.CARDS["small_world"]["variants"].any(func(v): return pair[0].plant_moment.contains(v))).is_true()  # (what it is, this time)
	# The tent's lights go out: out for a moment, and back.
	scene._pd.press("power_goes")
	assert_float(scene._lights_out).is_greater(0.0)
	# The whole tent's: the owner's next line reacts too, and it stays on everyone's minds a while.
	assert_str(scene._night.owner_plant_moment).contains("power")
	assert_str(scene._night.owner_plant_card).is_equal("power_goes")
	for chat in scene._chats:
		assert_str(chat.pd_topic).contains("still on their minds")
		assert_int(chat.pd_topic_lines).is_equal(Plants.lingers("power_goes"))
	assert_bool(await _wait_until(func(): return scene._lights_out <= 0.0, 5000)).is_true()
	assert_str(_transcript(runner)).contains("The tent's lights go out")
	assert_int(int(scene._stats.event_counts.get("plant_played", 0))).is_equal(3)
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


func test_last_times_cliffhanger_comes_true() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	scene._cliffhanger = {"kind": "comes_back", "who": ["Kim Jin-seok"], "teaser": "Will Jin-seok come back?", "answered": false}
	var flashes: int = scene._captions_part.red_flashes
	scene._watch_cliffhanger("sat_down", {"name": "Lee Ha-na"}, null, Vector2.ZERO)
	assert_bool(scene._cliffhanger["answered"]).is_false()  # (someone else)
	scene._watch_cliffhanger("sat_down", {"name": "Kim Jin-seok"}, null, Vector2.ZERO)
	assert_bool(scene._cliffhanger["answered"]).is_true()
	assert_str(_transcript(runner)).contains("Last time's cliffhanger, answered: \"Will Jin-seok come back?\"")
	assert_int(int(scene._stats.captions.get("cliffhanger", 0))).is_equal(1)
	assert_int(scene._captions_part.red_flashes).is_equal(flashes + 1)  # the red light
	scene._watch_cliffhanger("sat_down", {"name": "Kim Jin-seok"}, null, Vector2.ZERO)
	assert_int(int(scene._stats.captions.get("cliffhanger", 0))).is_equal(1)  # (once)
	assert_str(scene._diary_facts()["cliffhanger"]["teaser"]).is_equal("Will Jin-seok come back?")


func test_the_city_behind_the_tent_and_tonights_date() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	var city = runner.find_child("Skyline", true, false)
	assert_array(city.buildings).is_not_empty()
	city.set_minutes(21 * 60)
	var at_nine: int = city.lit_count()
	city.set_minutes(26 * 60)
	assert_int(city.lit_count()).is_less(at_nine)  # windows going dark
	var apt: Dictionary = city.buildings.filter(func(building): return building["kind"] == "apt")[0]
	var over := Vector2(float(apt["x"]) + 10, city.ground - 5)
	assert_str(city._get_tooltip(over)).contains("APT")  # Korean on screen explains itself
	assert_dict(city.hills).is_not_empty()  # (the mountains behind)
	var gaps: Array = city.buildings.filter(func(building): return building["kind"] == "gap")
	if not gaps.is_empty():  # (in a gap, the mountains: explained)
		assert_str(city._get_tooltip(Vector2(float(gaps[0]["x"]) + float(gaps[0]["width"]) / 2.0, city.ground - 2))).contains("산")
	var shops: Array = city.buildings.filter(func(building): return building["kind"] == "shops")
	if not shops.is_empty():
		var tip: String = city._get_tooltip(Vector2(float(shops[0]["x"]) + 10, city.ground - 5))
		assert_str(tip).contains("상가").contains(str(Skyline.SIGNS[int(shops[0]["signs"][0])]["hangul"]))
	# Tonight's date, in the season (the tests' calendar starts on 15 November).
	assert_str(str(scene._night_date["text"])).is_equal("15 November")
	assert_str((runner.find_child("MomentLabel", true, false) as Label).text).contains("15 Nov")
	assert_str(_transcript(runner)).contains("15 November, 6:00pm")
	assert_bool(Seasons.options(318).map(func(option): return option["text"]).has(scene._night_weather)).is_true()
	assert_str(str(Game.bar["last_weather"])).is_equal(scene._night_weather)
	assert_int(int(Game.bar["first_date"])).is_equal(318)


func test_the_cat_wanders_by_itself() -> void:
	# (The clock held: the cat's time runs on anyway, and with it running a customer can turn up
	# before the bar's seen to be open, and the whole night be over before the cat's watched.)
	var runner := await _open_bar()
	var scene = runner.scene()
	scene._cat_next = 2.0  # (soon: on a slow machine, half an hour of game time can take a while)
	var moved: bool = await _wait_until(func(): return scene._cat_spot != "stove")
	assert_bool(moved).override_failure_message("the cat never moved").is_true()


func test_the_cat_faces_the_way_its_going() -> void:
	Hooks.cat_wanders = false
	var runner := await _open_bar()
	var scene = runner.scene()
	var cat := runner.find_child("Cat") as Control
	scene._move_cat("counter")  # from the stove (left) to the far end of the counter (right)
	assert_float(cat.scale.x).is_equal(1.0)
	await get_tree().create_timer(0.1).timeout  # let it get there
	scene._move_cat("stove")  # and back to the left
	assert_float(cat.scale.x).is_equal(-1.0)


func test_a_prowling_cat_keeps_moving() -> void:
	Hooks.cat_wanders = false
	var runner := await _open_bar()
	var scene = runner.scene()
	var cat := runner.find_child("Cat") as Control
	scene._move_cat("stools")
	await get_tree().create_timer(0.1).timeout  # (there by now, at test speed)
	var first_x := cat.position.x
	assert_bool(await _wait_until(func(): return absf(cat.position.x - first_x) > 5.0, 5000)).override_failure_message("the cat just sat there").is_true()
	assert_float(cat.position.y).is_equal(348.0)  # along the floor
	# Off somewhere else: the prowling stops.
	scene._move_cat("stove")
	await get_tree().create_timer(0.1).timeout
	var at_stove := cat.position
	await get_tree().create_timer(0.2).timeout
	assert_vector(cat.position).is_equal(at_stove)


# --- How conversations flow -----------------------------------------------------------------

func test_the_owners_chat_turns_to_a_topic() -> void:
	Hooks.stay_minutes_override = 600
	Hooks.chat_chance_override = 0.0
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 1)
	assert_bool(await _wait_until(func(): return not scene._guests.is_empty() and scene._guests[0].topic != "")).is_true()
	assert_bool(Talk.OWNER_TOPICS.has(scene._guests[0].topic)).is_true()
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()


func test_a_line_written_before_a_dish_arrived_is_asked_for_again() -> void:
	Hooks.stay_minutes_override = 600
	Hooks.chat_chance_override = 0.0
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
	Hooks.stay_minutes_override = 600
	Hooks.chat_chance_override = 0.0
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
	Hooks.stay_minutes_override = 600
	Hooks.company_override = "chatty"
	Hooks.chat_chance_override = 0.0  # no chat while they settle in
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
	Hooks.stay_minutes_override = 600
	Hooks.company_override = "chatty"
	Hooks.chat_chance_override = 1.0
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
	Hooks.stay_minutes_override = 600
	Hooks.company_override = "chatty"
	Hooks.chat_chance_override = 1.0
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
	Hooks.stay_minutes_override = 600
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
	await _click(runner, runner.find_child("StatsTab_ALL", true, false))  # (everything at once)
	assert_bool(await _wait_until(func(): return panel.get_parsed_text().contains("Wait for first drinks") and panel.get_parsed_text().contains("HIGHLIGHTS"), 3000)).is_true()


func test_a_new_bars_cat_is_a_she_or_a_he_with_its_own_name() -> void:
	# Another bar (not called Golmok Pocha, like the new one, or they'd share an id).
	var other := SaveStore.new_bar("Sarang Pocha", "Love Tent", ANY_OWNER)
	other["cat"] = {"name": "Dubu", "coat": "black", "personality": "lazy", "sex": "she"}
	SaveStore.save_bar(other)
	CannedAi.scripted = [ANY_OWNER, A_BAR_NAME, A_CAT_NAME]  # the AI suggests Dubu: taken
	await _open_bar()
	var cat: Dictionary = Game.bar["cat"]
	assert_bool(cat["sex"] in CatRules.CAT_SEXES).is_true()
	assert_str(str(cat["name"])).is_not_equal("Dubu")


func test_customers_are_women_and_men_about_equally() -> void:
	var genders := {}
	for i in 200:
		var g: String = People.game_gender(randf())
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
	assert_bool((runner.find_child("Tarp") as Polygon2D).color.is_equal_approx(Color(BarLook.BAR_TARPS["blue"][0]))).is_true()
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
	var art := runner.find_child("TarpArt") as Control  # ...and drawn in pixel art: this colour, this shape
	var cover := art.get_child(0) as TextureRect
	assert_str(cover.texture.resource_path).ends_with("/tarps/%s_peaked.png" % Game.bar["look"]["tarp"])
	assert_int(cover.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_vector(cover.size).is_equal(cover.texture.get_size() * 3)  # (a pixel of it, 3 on screen: the street's grid)
	assert_vector(cover.position).is_equal(Vector2.ZERO)
	var counter := runner.find_child("Art_tent_counter", true, false) as TextureRect  # the counter and stools too
	assert_vector(counter.position).is_equal(Visit.COUNTER_ART_AT)
	var stools: Array = scene._stage.get_children().filter(func(node): return str(node.name).contains("Art_tent_stool"))
	assert_int(stools.size()).is_equal(NightRules.SEATS)
	for stool in stools:
		assert_int(int(stool.position.x) % 3).is_equal(0)  # (on the grid's lines, as the counter)
	for shape in BarLook.TENT_SHAPES:
		assert_int(scene._tent_view.tent_shape(shape).size()).is_greater_equal(4)


func test_stripes_are_cut_to_the_shape() -> void:
	var look := A_LOOK.duplicate()
	look["tarp"] = "red_stripes"
	look["shape"] = "rounded"
	CannedAi.scripted = [ANY_OWNER, A_BAR_NAME, A_CAT_NAME, look]
	var runner := await _open_bar()
	assert_int(runner.find_child("TarpStripes").get_child_count()).is_greater(0)


func test_people_walk_past_without_coming_in() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	Hooks.run_clock = true  # (once open: running before, a customer could keep the bar from being seen open)
	assert_bool(await _wait_until(func(): return scene._street.strollers >= 3)).override_failure_message("nobody walked past").is_true()
	var walker := runner.find_child("Stroller1", true, false) as Control
	if walker != null:
		assert_float(walker.position.y).is_greater(Visit.CUSTOMER_Y)  # on the pavement, nearer than the stools
	assert_int(scene._stats.arrived).is_less(scene._street.strollers)  # most just walk on by


func test_no_template_tent_while_the_ai_thinks() -> void:
	Ai.canned_think_seconds = 0.3
	var runner := scene_runner(SCENE)
	var art := runner.find_child("TarpArt") as Control  # (the cover in pixel art: art/tarps)
	assert_bool(art.visible).is_false()
	assert_bool(await _wait_until(func(): return art.visible and art.get_child_count() == 1)).override_failure_message("the tent never went up").is_true()
	assert_bool((runner.find_child("Tarp") as Polygon2D).visible).is_false()  # (the shape it stands in for, left out)


func test_a_new_bar_chooses_from_a_few_colours_and_shapes() -> void:
	Hooks.offer_every_look = false
	var runner := await _open_bar()
	var scene = runner.scene()
	var offer: Dictionary = scene._look_offer
	assert_int(offer["tarp"].size()).is_equal(BarLook.OFFERED_TARPS)
	assert_array(offer["tarp"]).contains([Game.bar["look"]["tarp"]])
	assert_array(offer["shape"]).contains([Game.bar["look"]["shape"]])


func test_a_loading_screen_covers_a_new_bar_being_set_up() -> void:
	Ai.canned_think_seconds = 0.3
	var runner := scene_runner(SCENE)
	var loading := runner.find_child("Loading") as Control
	assert_bool(loading.visible).is_true()
	assert_bool(await _wait_until(func(): return not loading.visible)).override_failure_message("the loading screen never went").is_true()
	assert_bool((runner.find_child("TarpArt") as Control).visible).is_true()
	assert_bool(loading.is_placeholder()).override_failure_message("the loading screen's tent became the bar's").is_false()
	assert_str((loading.find_child("SignHangul", true, false) as Label).text).is_equal(str(Game.bar["look"]["hangul"]))
	assert_str(str(runner.scene()._stats.story.get("loading_tent", runner.scene()._before_night.get("loading_tent", "")))).is_equal("placeholder, then the bar's")


func test_passers_by_carry_umbrellas_in_the_rain() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	scene._weather_kind = "rain"
	scene._street.stroll(Looks.rain_gear("rain", 0.9, 0.5, 0.5), 1)
	var walker := runner.find_child("Stroller%d" % scene._street.strollers, true, false) as Control
	var umbrella := walker.find_child("Umbrella", true, false) as Node2D
	assert_object(umbrella).is_not_null()
	assert_object(umbrella.find_child("Canopy", true, false)).is_not_null()
	assert_bool(walker.has_meta("running")).is_false()
	# Now and then someone has none, and runs for it, something held over their head.
	scene._street.stroll({"umbrella": false}, 1)
	var runner_by := runner.find_child("Stroller%d" % scene._street.strollers, true, false) as Control
	assert_object(runner_by.find_child("Umbrella", true, false)).is_null()
	assert_object(runner_by.find_child("OverHead", true, false)).is_not_null()
	assert_bool(runner_by.get_meta("running", false)).is_true()
	# A clear night: nothing.
	scene._weather_kind = "clear"
	scene._street.stroll({}, 1)
	var dry := runner.find_child("Stroller%d" % scene._street.strollers, true, false) as Control
	assert_object(dry.find_child("Umbrella", true, false)).is_null()
	assert_object(dry.find_child("OverHead", true, false)).is_null()


func test_people_in_the_street_walk_together_and_look_at_phones() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	scene._weather_kind = "clear"
	var strollers_before: int = scene._street.strollers
	scene._street.stroll({}, 3)
	assert_int(scene._street.strollers - strollers_before).is_equal(3)
	var group: Array = []
	for i in range(strollers_before + 1, strollers_before + 4):
		group.append(runner.find_child("Stroller%d" % i, true, false) as Control)
	# Together: one after another, the same way, the same pace, a little apart.
	for i in [1, 2]:
		assert_float(absf(group[i].position.x - group[0].position.x)).is_equal_approx(62.0 * i, 0.5)
	# Phones: a person on one has a lit screen in front of them.
	var person: Control = scene._people_view.new_person(scene._stage, Vector2(0, Visit.STROLL_Y), Color.WHITE)
	scene._people_view.add_phone(person)
	assert_object(person.find_child("Phone", true, false)).is_not_null()
	assert_object(person.find_child("Screen", true, false)).is_not_null()
	assert_bool(person.get_meta("on_phone", false)).is_true()
	# A pair sharing an umbrella in the rain: one umbrella between them, held out over the other.
	scene._weather_kind = "rain"
	var shared := false
	for attempt in 40:
		strollers_before = scene._street.strollers
		scene._street.stroll({}, 2)
		var first := runner.find_child("Stroller%d" % (strollers_before + 1), true, false) as Control
		var second := runner.find_child("Stroller%d" % (strollers_before + 2), true, false) as Control
		if second.find_child("Umbrella", true, false) == null:
			var umbrella := first.find_child("Umbrella", true, false) as Node2D
			assert_object(umbrella).is_not_null()
			assert_float(absf(umbrella.position.x - PeopleView.UMBRELLA_HAND.x)).is_greater(10.0)
			shared = true
			break
		# Not sharing: both have their own (nobody in a group runs off and leaves the other).
		assert_bool(scene._people_view.is_running(first) or scene._people_view.is_running(second)).is_false()
	assert_bool(shared).override_failure_message("no pair ever shared an umbrella").is_true()


func test_customers_come_in_under_umbrellas_and_put_them_down() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	scene._weather_kind = "rain"
	Hooks.rain_gear = {"umbrella": true, "shape": "wide", "size": 1.05, "tilt": 0.05}
	scene._arrive(scene._clock)
	assert_bool(await _wait_until(func(): return scene._guests.size() == 1)).is_true()
	var guest = scene._guests[0]
	assert_dict(guest.rain_gear).is_equal(Hooks.rain_gear)  # kept, to go back out with
	# Sat down: the umbrella's down.
	assert_bool(await _wait_until(func(): return not guest.walk.is_running())).is_true()
	assert_object(guest.node.find_child("Umbrella", true, false)).is_null()
	# The helpers, step by step: up in the street, down under the tarp.
	var person: Control = scene._people_view.new_person(scene._stage, Vector2(0, Visit.CUSTOMER_Y), Color.WHITE)
	scene._street.gear_up(person, Hooks.rain_gear, true)
	var umbrella := person.find_child("Umbrella", true, false) as Node2D
	assert_object(umbrella).is_not_null()
	assert_str(str(umbrella.get_meta("shape"))).is_equal("wide")
	scene._people_view.gear_down(person)
	assert_object(person.find_child("Umbrella", true, false)).is_null()
	# Running for it: the bobbing and leaning stop once they're in.
	scene._street.gear_up(person, {"umbrella": false}, true)
	assert_bool(scene._people_view.is_running(person)).is_true()
	assert_float(person.rotation).is_not_equal(0.0)
	scene._people_view.gear_down(person)
	assert_bool(scene._people_view.is_running(person)).is_false()
	assert_float(person.rotation).is_equal(0.0)
	assert_float(person.position.y).is_equal(Visit.CUSTOMER_Y)
	assert_object(person.find_child("OverHead", true, false)).is_null()
	# A dry night: nobody needs anything.
	scene._weather_kind = "clear"
	assert_dict(scene._street.pick_rain_gear()).is_empty()


func test_the_weather_lands_on_umbrellas() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	var gear := {"umbrella": true, "shape": "dome", "size": 1.0, "tilt": 0.0}
	# Snow builds up on top, and gets shaken off under the tarp.
	scene._weather_kind = "snow"
	var snowy: Control = scene._people_view.new_person(scene._stage, Vector2(0, Visit.CUSTOMER_Y), Color.WHITE)
	scene._street.gear_up(snowy, gear, true)
	assert_object(snowy.find_child("SnowCap", true, false)).is_not_null()
	assert_object(snowy.find_child("Drip", true, false)).is_null()
	scene._people_view.gear_down(snowy)
	assert_object(snowy.find_child("ShakenOff", true, false)).is_not_null()
	# Rain runs off the rim.
	scene._weather_kind = "rain"
	var wet: Control = scene._people_view.new_person(scene._stage, Vector2(0, Visit.CUSTOMER_Y), Color.WHITE)
	scene._street.gear_up(wet, gear, true)
	assert_object(wet.find_child("Drip", true, false)).is_not_null()
	assert_object(wet.find_child("SnowCap", true, false)).is_null()
	# A clear night: nothing lands on it.
	scene._weather_kind = "clear"
	var dry: Control = scene._people_view.new_person(scene._stage, Vector2(0, Visit.CUSTOMER_Y), Color.WHITE)
	scene._street.gear_up(dry, gear, true)
	assert_object(dry.find_child("Drip", true, false)).is_null()
	assert_object(dry.find_child("SnowCap", true, false)).is_null()


func test_a_couple_of_bottles_and_they_sway() -> void:
	Hooks.stay_minutes_override = 600
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 1)
	assert_bool(await _wait_until(func(): return not scene._guests.is_empty() and scene._guests[0].line >= 2)).is_true()
	var guest = scene._guests[0]
	scene._stop_swaying(guest.node)
	guest.order = ["tteokbokki", "soju"]
	scene._tipsy(guest)
	assert_bool(guest.node.has_meta("sway")).is_false()  # one bottle: steady
	guest.order.append("soju")
	scene._tipsy(guest)
	assert_bool(guest.node.has_meta("sway")).is_true()  # two: a gentle sway
	# (Waits for it to move, rather than a fixed time: on a slow machine a drink served just then
	# restarts the sway from upright, and a fixed wait could look just as it restarts.)
	assert_bool(await _wait_until(func(): return absf(guest.node.rotation) > 0.0)).override_failure_message("never swayed").is_true()
	assert_float(absf(guest.node.rotation)).is_less(0.08)  # (gentle)
	# Going home: the sway stops and the wobble starts.
	scene._guests.erase(guest)  # (off the counter first, so the night doesn't carry on with them)
	scene._walk_out(guest)
	assert_bool(guest.node.has_meta("sway")).is_false()
	assert_bool(guest.node.get_meta("wobbly", false)).is_true()


func test_a_customer_with_no_umbrella_runs_in() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	scene._weather_kind = "snow"
	Hooks.rain_gear = {"umbrella": false}
	scene._arrive(scene._clock)
	assert_bool(await _wait_until(func(): return scene._guests.size() == 1)).is_true()
	var guest = scene._guests[0]
	assert_bool(await _wait_until(func(): return not guest.walk.is_running())).is_true()
	assert_bool(scene._people_view.is_running(guest.node)).is_false()  # stopped, and sat down
	assert_float(guest.node.position.y).is_equal(Visit.CUSTOMER_Y)


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
	var music_on := runner.find_child("MusicToggle") as CheckBox  # and its own tick box
	assert_bool(music_on.button_pressed).is_true()
	music_on.button_pressed = false
	assert_bool(Music.load_enabled()).is_false()  # remembered for next time
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
	assert_str(tag.text).starts_with(str(Names.CAT_HANGUL[scene._cat["name"]]))  # Hangul first, like everyone's
	assert_str(tag.text).ends_with("♀" if scene._cat["sex"] == "she" else "♂")


func test_lines_show_in_speech_bubbles_with_who_they_are_to() -> void:
	Hooks.bubbles = true
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
	var regular := Regulars.new_regular(customer, Looks.pick_look("woman", "30s", ""), ["soju", "tteokbokki"], 1, 0, 21 * 60, 0.5)
	regular["visits"] = 4
	if founding:
		regular.merge({"founding": true, "role": "looks_out", "since": "for six years", "habit": "most Fridays", "usual": ["beer", "pajeon"],
			"owner_knows_name": true, "knows_owner_name": true, "pull": Regulars.FOUNDING_PULL}, true)
	return regular


func test_a_new_bar_opens_with_two_founding_regulars() -> void:
	Hooks.founding_regulars = true
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
	Hooks.regular_roll_override = 0.0  # if it's possible at all, it happens
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
	Hooks.regular_roll_override = 1.0
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
		"reason": "A double shift.", "speech_style": "brisk", "appearance": "Scrubs under a coat.", "look": Looks.pick_look("woman", "20s", "")}
	guest.first_order = ["soju", "odeng"]
	guest.arrived_minutes = int(scene._clock)
	guest.transcript = [{"speaker": "Yoon Na-rae", "text": "Double shift at the hospital again. My mum keeps telling me to quit."},
		{"speaker": scene._owner["name"], "text": "Eat something first."}]
	return guest


func test_a_loved_visit_is_remembered_and_makes_a_regular() -> void:
	Hooks.memories = true
	Hooks.regular_roll_override = 0.05  # under "loved it"'s 1 in 10, over "fine"'s 1 in 200
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
	Hooks.memories = true
	Hooks.regular_roll_override = 0.0
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
	Hooks.stay_minutes_override = 600
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
	Hooks.stay_minutes_override = 600  # nobody leaves, so the tent stays full
	Hooks.cat_wanders = false  # (a cat making off with a fish cake would be a second red light)
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 6)
	assert_bool(await _wait_until(func(): return scene._guests.size() == 5)).is_true()
	assert_int(int(scene._stats.captions.get("rush", 0))).is_equal(1)  # the counter filling up
	assert_str(_transcript(runner)).contains("[TV] ")
	scene._clock += NightRules.GIVE_UP_MINUTES + 1
	assert_bool(await _wait_until(func(): return scene._street.passers_by == 1)).is_true()
	assert_str(_transcript(runner)).contains("[TV] ")
	assert_int(int(scene._stats.captions["full_house"])).is_equal(1)
	assert_int(scene._captions_part.red_flashes).override_failure_message("no red light for an emergency").is_greater_equal(1)  # (six orders at once can pile up on the stove too: a second emergency)
	# Drawn: Hangul over the English, by the tent (at normal speed, so it's still up to look at).
	Hooks.pause_scale_override = 1.0
	scene._caption("stove")
	Hooks.pause_scale_override = 0.01
	var caption: Control = scene._captions_part.shown
	assert_object(caption).is_not_null()
	if caption != null:
		assert_str(caption.name).is_equal("Caption")
		var hangul: Array = Captions.CAPTIONS["stove"]["words"].map(func(w): return w[0])
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
	scene._clock = float(Captions.QUIET_AFTER + 10)
	_crowd(scene, 1)
	assert_bool(await _wait_until(func(): return scene._guests.size() == 1)).is_true()
	_time_up(scene)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()
	assert_int(int(scene._stats.captions.get("quiet", 0))).is_equal(1)


func test_a_big_moment_gets_a_tv_reaction() -> void:
	Hooks.reactions = true
	var runner := await _open_bar()
	var scene = runner.scene()
	var owner_name := str(Game.bar["owner"]["name"])
	var names := ["Kim Ji-ho", owner_name]
	var lines := [{"speaker": "Kim Ji-ho", "text": "I quit my job today."}, {"speaker": owner_name, "text": "You did what?"}]
	CannedAi.scripted = [{"size": 5, "mood": "shock", "who": "Ji-ho", "caption": "she quit her job?!"}]
	await scene._react(lines, names, [])
	assert_str(_transcript(runner)).contains("SHE QUIT HER JOB?!")
	assert_int(int(scene._stats.reactions_shown.get("shock", 0))).is_equal(1)
	assert_array(Captions.REACTIONS["shock"]["hangul"]).contains([(scene._captions_part.shown.find_child("Hangul", true, false) as Label).text])
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


func test_a_reaction_check_waits_for_the_owner_instead_of_being_lost() -> void:
	Hooks.reactions = true
	var runner := await _open_bar()
	var scene = runner.scene()
	var owner_name := str(Game.bar["owner"]["name"])
	var names := ["Kim Ji-ho", owner_name]
	var lines := [{"speaker": "Kim Ji-ho", "text": "I quit my job today."}, {"speaker": owner_name, "text": "You did what?"}]
	# Someone's waiting to be greeted: the check's put off, not asked (or lost).
	scene._owner_working = true  # (so the owner doesn't get to it before we've looked)
	scene._waiting.append(scene._clock)
	scene._waiting_who.append("")
	await scene._react(lines, names, [])
	assert_int(scene._stats.reactions_put_off).is_equal(1)
	assert_int(scene._stats.reactions_asked).is_equal(0)
	assert_dict(scene._reaction_pending).is_not_empty()
	# Once she's free, it's the next thing she does.
	scene._waiting.clear()
	scene._waiting_who.clear()
	CannedAi.scripted = [{"size": 5, "mood": "shock", "who": "Ji-ho", "caption": "she quit her job?!"}]
	scene._owner_working = false
	assert_bool(await _wait_until(func(): return scene._stats.reactions_asked == 1)).override_failure_message("the put-off check was never asked").is_true()
	assert_bool(await _wait_until(func(): return _transcript(runner).contains("SHE QUIT HER JOB?!"))).is_true()
	assert_dict(scene._reaction_pending).is_empty()
	# Too long ago: dropped, not asked.
	scene._owner_working = true
	scene._reaction_pending = {"lines": lines, "names": names, "items": [], "at": scene._clock - Captions.REACTION_STALE_MINUTES - 5.0}
	await scene._ask_pending_reaction()
	assert_int(scene._stats.reactions_asked).is_equal(1)
	assert_int(scene._stats.reactions_skipped).is_equal(1)
	CannedAi.scripted = []


func test_the_diary_can_be_read_during_a_night() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	Game.bar["diary"] = [{"night": 1, "episode": 1, "day": "Friday", "weather": "rain", "text": "The first night.", "stamp": "rain"},
		{"night": 2, "episode": 2, "day": "Saturday", "weather": "snow", "text": "The second night. Jeong Min-ho had the tteokbokki, aigoo.", "stamp": "snow",
			"facts": {"owner": "Park Mi-sook", "people": [{"name": "Jeong Min-ho"}]}}]
	(runner.find_child("DiaryButton") as Button).pressed.emit()  # (top-bar buttons: see the stats test)
	var book = runner.find_child("DiaryBook", true, false)
	assert_object(book).is_not_null()
	assert_int(book.showing_night()).is_equal(2)
	scene._open_diary()  # a second click doesn't open a second book
	assert_int(scene.get_children().filter(func(c): return c.name == "DiaryBook").size()).is_equal(1)
	# Korean words have hover hints in the diary (it's read at leisure); names don't.
	var page_text := (book.find_child("Entry", true, false) as RichTextLabel).text
	assert_str(page_text).contains("Tteokbokki: spicy rice cakes")
	assert_str(page_text).contains("[color=#%s]aigoo" % DiaryPage.WORD_INK)
	assert_str(page_text).contains("Jeong Min-ho had")
	assert_str((book.find_child("Entry", true, false) as RichTextLabel).get_parsed_text()).is_equal("The second night. Jeong Min-ho had the tteokbokki, aigoo.")
	book._flip(-1)
	assert_str((book.find_child("Entry", true, false) as RichTextLabel).get_parsed_text()).is_equal("The first night.")
	book.close()


func test_a_new_bar_opens_with_its_first_episode() -> void:
	Hooks.recaps = true
	var runner := scene_runner(SCENE)
	var scene = runner.scene()
	assert_bool(await _wait_until(func(): return scene._night_number == 1)).override_failure_message("night one never started").is_true()
	assert_str(_transcript(runner)).contains("Series opener: Under a Seoul overpass")


func test_skip_ends_the_recap() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	var screen := RecapScreen.new()
	scene.add_child(screen)
	var ended := [false]
	screen.finished.connect(func(): ended[0] = true)
	screen.play(["Ji-ho quits.", "Tae-oh stays away."], "Will he come back?", 5, "Golmok Pocha", false,
		{"people": {"Kim Ji-ho": "김지호"}, "moments": [{"who": "Kim Ji-ho", "mood": "shock", "caption": "SHE QUIT?!"}], "style": "makjang",
		"quotes": [{"speaker": "Kim Ji-ho", "text": "I quit today, and I'm glad."}]})  # at full speed: still on the first beat
	await get_tree().create_timer(1.0).timeout  # past the title card
	assert_str(screen.beat_text()).is_equal("Ji-ho quits.")
	assert_str((screen.find_child("RecapEpisode", true, false) as Label).text).is_equal("제5화")
	assert_str(screen.who_text()).is_equal("김지호 Kim Ji-ho")  # her name tag, in Hangul too
	assert_str(screen.quote_text()).is_equal("“I quit today, and I'm glad.”  — Ji-ho")  # (the line the PD pinned, under its beat)
	assert_str(screen.style_name()).is_equal("makjang")
	assert_str((screen.find_child("RecapTitle", true, false).get_child(0) as Label).text).is_equal(str(Story.RECAP_STYLES["makjang"]["title"]))
	assert_object(screen.find_child("RecapSticker", true, false)).is_not_null()  # and last time's big moment, stuck on
	(screen.find_child("RecapSkip", true, false) as Button).pressed.emit()
	assert_bool(ended[0]).is_true()


func test_waits_belong_to_the_tent_and_stop_when_the_bar_closes() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	assert_bool(scene._closed()).is_false()
	# A pause is the tent's own timer (gone with the tent, so the wait can't come back to it).
	var timers_before: int = scene.get_children().filter(func(c): return c is Timer).size()
	var timer: Timer = scene._timer(60.0)
	assert_object(timer.get_parent()).is_same(scene)
	assert_int(scene.get_children().filter(func(c): return c is Timer).size()).is_equal(timers_before + 1)
	timer.stop()
	timer.queue_free()
	# Closing the bar: anything that was waiting sees it, and stops.
	scene._stopped = true
	assert_bool(scene._closed()).is_true()
	scene._stopped = false


func test_the_autopilot_pd_plays_a_card_when_its_due() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	assert_object(scene._autopilot).is_null()  # (a player's at the desk: no autopilot)
	scene._autopilot = Autopilot.new("a test night")
	scene._pd.hand = ["power_goes", "rain", "phone"]
	scene._autopilot.plan(["power_goes"], scene._clock)
	scene._autopilot.schedule[0]["at"] = scene._clock  # (due now)
	scene._autopilot_tick()
	assert_bool(scene._pd.played.has("power_goes")).is_true()
	assert_str(_transcript(runner)).contains("(Autopilot PD plays The power goes.)\n\nThe tent's lights go out")  # (said first, then what happens)
	assert_int(int(scene._stats.autopilot["cards"])).is_equal(1)
	assert_str(scene._stats.panel_text(0, 0)).contains("Autopilot PD (an autoplay batch): cards played 1")
	assert_array(scene._autopilot.schedule).is_empty()  # (played: not again)
	# A card nobody's here for isn't played (or said to be), and is tried again later.
	scene._autopilot.plan(["phone"], scene._clock)
	scene._autopilot.schedule[0]["at"] = scene._clock
	scene._autopilot_tick()
	assert_bool(scene._pd.played.has("phone")).is_false()
	assert_str(_transcript(runner)).not_contains("Autopilot PD plays A phone rings")
	assert_float(float(scene._autopilot.schedule[0]["at"])).is_greater(scene._clock)
