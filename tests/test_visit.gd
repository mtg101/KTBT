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

const SCENE := "res://scenes/visit.tscn"
const TEST_SAVES := "user://test_saves_visit/"
const TIMEOUT_MS := 15000

## A reply that's valid for either gender of owner (the archetype names no gendered term).
const ANY_OWNER := {"name": "Han Jeong-hee", "age": 47, "archetype": "former chef who walked out of a hotel kitchen", "appearance": "Sleeves rolled up.", "personality": "proud, funny", "speech_style": "quick and teasing", "secret": "She still gets job offers from the hotel."}
const A_BAR_NAME := {"name": "Golmok Pocha", "meaning": "Back Alley Tent"}
const A_CUSTOMER := {"name": "Kim Ji-ho", "age": 34, "job": "office worker", "mood": "worn out", "reason": "Her team lead took credit for her work again.", "speech_style": "dry, tired", "appearance": "A crumpled blazer."}


var _real_saves := ""


func before_test() -> void:
	_real_saves = SaveStore.folder
	SaveStore.folder = TEST_SAVES
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
	Game.bar = {}
	Ai.simulate_unreachable = false
	AiSettings.override = {}
	CannedAi.scripted = []
	Visit.pause_scale_override = -1.0
	Visit.random_seed = 0
	Visit.run_clock = true


# --- Helpers ---------------------------------------------------------------------------

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
	runner.simulate_mouse_move(button.get_global_rect().get_center())
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()


## Loads the scene and waits until the owner is in and the button is ready.
func _open_bar() -> GdUnitSceneRunner:
	var runner := scene_runner(SCENE)
	var scene = runner.scene()
	var bar_open: bool = await _wait_until(func(): return not scene._busy and not scene._owner.is_empty())
	assert_bool(bar_open).override_failure_message("the owner never arrived").is_true()
	return runner


## Clicks Next customer and waits for the whole visit to finish.
func _run_one_visit(runner: GdUnitSceneRunner) -> void:
	var scene = runner.scene()
	await _click(runner, runner.find_child("NextButton"))
	assert_bool(scene._busy).override_failure_message("clicking Next customer didn't start a visit").is_true()
	var done: bool = await _wait_until(func(): return not scene._busy)
	assert_bool(done).override_failure_message("the visit never finished").is_true()
	await get_tree().process_frame  # let freed dishes disappear


func _transcript(runner: GdUnitSceneRunner) -> String:
	return (runner.find_child("Transcript") as RichTextLabel).get_parsed_text()


# --- Tests -------------------------------------------------------------------------------

func test_owner_arrives_and_the_bar_is_ready() -> void:
	var runner := await _open_bar()
	var button := runner.find_child("NextButton") as Button
	assert_bool(button.disabled).is_false()
	assert_str(button.text).is_equal("Next customer")
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
	# They've gone, the counter's clear, and the button still works.
	assert_array(scene._guests).is_empty()
	assert_int(scene._table_item_count()).is_equal(0)
	assert_bool((runner.find_child("NextButton") as Button).disabled).is_false()


func test_next_customer_still_works_during_a_visit() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	var button := runner.find_child("NextButton") as Button
	await _click(runner, button)
	assert_bool(button.disabled).is_false()
	await _click(runner, button)
	assert_bool(await _wait_until(func(): return not scene._busy)).is_true()
	assert_int(int(Game.bar["visits"])).is_equal(2)


# --- Several at once ---------------------------------------------------------------------

## As if this many people turned up at the same moment.
func _crowd(scene, count: int) -> void:
	for i in count:
		scene._waiting.append(scene._clock)


func test_several_customers_sit_at_once() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 3)
	var together: bool = await _wait_until(func(): return scene._guests.size() >= 2)
	assert_bool(together).override_failure_message("never more than one customer at a time").is_true()
	assert_bool(await _wait_until(func(): return not scene._busy)).override_failure_message("the customers never all left").is_true()
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
		return not scene._busy
	var done: bool = await _wait_until(watch, 30000)
	assert_bool(done).is_true()
	assert_int(most[0]).is_equal(5)
	assert_bool(seats_ok[0]).override_failure_message("two customers shared a stool").is_true()
	assert_int(int(Game.bar["visits"])).is_equal(7)


func test_someone_who_waits_too_long_walks_past() -> void:
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
	assert_bool(await _wait_until(func(): return not scene._busy, 30000)).is_true()
	assert_int(int(Game.bar["visits"])).is_equal(5)


func test_cooked_food_waits_at_the_stove() -> void:
	var order := {"items": ["beer", "tteokbokki"], "line": "A cold beer and the tteokbokki, please."}
	CannedAi.scripted = [ANY_OWNER, A_BAR_NAME, A_CUSTOMER, order]
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
	CannedAi.scripted = [ANY_OWNER, A_BAR_NAME, A_CUSTOMER, order]
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
	var runner := await _open_bar()
	var scene = runner.scene()
	_crowd(scene, 2)
	assert_bool(await _wait_until(func(): return not scene._busy)).is_true()
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
	var button := runner.find_child("NextButton") as Button
	var gave_up: bool = await _wait_until(func(): return button.text == "Try again" and not button.disabled)
	assert_bool(gave_up).is_true()
	assert_bool((runner.find_child("Owner") as Control).visible).is_false()
	# Trying again (the queue's empty now) brings the owner in.
	await _click(runner, button)
	var arrived: bool = await _wait_until(func(): return not scene._busy and not scene._owner.is_empty())
	assert_bool(arrived).is_true()
	assert_str(button.text).is_equal("Next customer")


func test_order_falls_back_to_soju_and_odeng_when_the_ai_keeps_failing() -> void:
	CannedAi.scripted = [ANY_OWNER, A_BAR_NAME, A_CUSTOMER, {"items": ["pizza"], "line": "Pizza!"}, {"items": []}, {"nope": true}]
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
	var bar_open: bool = await _wait_until(func(): return not scene._busy and not scene._owner.is_empty())
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
	var button := runner.find_child("NextButton") as Button
	var gave_up: bool = await _wait_until(func(): return button.text == "Try again" and not button.disabled)
	assert_bool(gave_up).is_true()
	assert_bool((runner.find_child("ModeLabel") as Label).visible).is_false()
	assert_str(_transcript(runner)).contains("Couldn't invent the owner")
