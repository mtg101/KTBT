extends GdUnitTestSuite
## Click-through tests for bars and saves: the title screen, new and saved bars, and
## autosave. Like test_visit.gd, these use offline mode and their own save folder.

const Visit = preload("res://scripts/visit.gd")
const AiSettings = preload("res://scripts/ai_settings.gd")
const CannedAi = preload("res://scripts/canned_ai.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const NightStats = preload("res://scripts/night_stats.gd")
const Menu = preload("res://scripts/menu.gd")
const Rules = preload("res://scripts/rules.gd")

const TITLE := "res://scenes/title.tscn"
const VISIT := "res://scenes/visit.tscn"
const TEST_SAVES := "user://test_saves_bars/"
const TIMEOUT_MS := 15000
const OWNER_DATA := {"name": "Kim Sung-ho", "age": 58, "gender": "man", "title": "Ajusshi", "archetype": "quiet ajusshi with a mysterious past", "appearance": "A grey cardigan.", "personality": "calm, kind", "speech_style": "few words", "secret": "He was once a bodyguard."}

var _real_saves := ""
var _real_stats := ""
const TEST_STATS := "user://test_stats_bars/"


func before_test() -> void:
	_real_saves = SaveStore.folder
	SaveStore.folder = TEST_SAVES
	_real_stats = NightStats.folder
	NightStats.folder = TEST_STATS  # night logs go here, not among real ones
	_clear_folder(TEST_STATS)
	_clear_saves()
	Game.bar = {}
	Game.change_scenes = false
	Game.requested_scene = ""
	AiSettings.override = {"backend": "canned"}
	CannedAi.scripted = []
	Visit.pause_scale_override = 0.01
	Visit.random_seed = 4321
	Visit.run_clock = false  # no automatic customers: these tests click Next customer themselves


func after_test() -> void:
	_clear_saves()
	SaveStore.folder = _real_saves
	_clear_folder(TEST_STATS)
	NightStats.folder = _real_stats
	Game.bar = {}
	Game.change_scenes = true
	Game.requested_scene = ""
	AiSettings.override = {}
	CannedAi.scripted = []
	Visit.pause_scale_override = -1.0
	Visit.random_seed = 0
	Visit.run_clock = true
	Visit.stay_minutes_override = -1
	Visit.company_override = ""
	Visit.chat_chance_override = -1.0


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


func _wait_until(condition: Callable, timeout_ms := TIMEOUT_MS) -> bool:
	var start := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - start > timeout_ms:
			return false
		await get_tree().process_frame
	return true


func _click(runner: GdUnitSceneRunner, button: Button) -> void:
	# Containers (like the title screen's) lay themselves out over the first frames after a
	# scene loads; let that settle so we aim at where the button really is.
	for i in 3:
		await get_tree().process_frame
	runner.simulate_mouse_move(button.get_global_rect().get_center())
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()


## Waits until the game has asked for this scene (a click only lands on release, which can
## be a frame or two after the simulated press). Returns false on timeout.
func _wait_for_scene(scene_path: String) -> bool:
	return await _wait_until(func(): return Game.requested_scene == scene_path, 3000)


## A saved bar with this name and takings, written straight to the test folder.
func _saved_bar(bar_name: String, takings: int, last_played := 0) -> Dictionary:
	var bar := SaveStore.new_bar(bar_name, "A test tent", OWNER_DATA)
	bar["takings"] = takings
	SaveStore.save_bar(bar)
	if last_played > 0:
		# save_bar stamps "now"; rewrite the file to fake an older or newer last visit.
		bar["last_played"] = last_played
		var file := FileAccess.open(TEST_SAVES.path_join(bar["id"] + ".json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(bar))
		file.close()
	return bar


## Opens the visit scene and waits until the owner is in and nothing's happening.
func _open_visit() -> GdUnitSceneRunner:
	var runner := scene_runner(VISIT)
	var scene = runner.scene()
	var bar_open: bool = await _wait_until(func(): return not scene.busy and not scene._owner.is_empty())
	assert_bool(bar_open).override_failure_message("the bar never opened").is_true()
	return runner


## Someone turns up, and this waits for their whole visit to finish.
func _run_one_visit(runner: GdUnitSceneRunner) -> void:
	var scene = runner.scene()
	scene._arrive(scene._clock)
	assert_bool(scene.busy).override_failure_message("nobody turned up").is_true()
	var done: bool = await _wait_until(func(): return not scene.busy)
	assert_bool(done).override_failure_message("the visit never finished").is_true()


# --- The title screen ----------------------------------------------------------------------

func test_title_says_when_there_are_no_bars() -> void:
	var runner := scene_runner(TITLE)
	assert_object(runner.find_child("NoBars")).is_not_null()
	assert_object(runner.find_child("Bar0")).is_null()


func test_title_lists_saved_bars_newest_first() -> void:
	_saved_bar("Golmok Pocha", 12000, 1000)
	_saved_bar("Sarang Pocha", 34000, 2000)
	var runner := scene_runner(TITLE)
	var first := runner.find_child("Bar0") as Button
	var second := runner.find_child("Bar1") as Button
	assert_str(first.text).contains("Sarang Pocha")
	assert_str(first.text).contains("Kim Sung-ho (Ajusshi)")
	assert_str(first.text).contains(Menu.format_won(34000))
	assert_str(second.text).contains("Golmok Pocha")


func test_title_shows_nights_and_visits() -> void:
	var bar := SaveStore.new_bar("Golmok Pocha", "A test tent", OWNER_DATA)
	bar["nights"] = 3
	bar["visits"] = 1
	SaveStore.save_bar(bar)
	var runner := scene_runner(TITLE)
	assert_str((runner.find_child("Bar0") as Button).text).contains("3 nights, 1 visit")


func test_deleting_a_bar_takes_two_clicks() -> void:
	_saved_bar("Golmok Pocha", 12000, 1000)
	_saved_bar("Sarang Pocha", 34000, 2000)
	var runner := scene_runner(TITLE)
	await _click(runner, runner.find_child("Delete0"))
	# One click only asks: nothing's gone yet.
	assert_bool(await _wait_until(func(): return (runner.find_child("Delete0") as Button).text == "Sure?", 3000)).is_true()
	assert_int(SaveStore.list_bars().size()).is_equal(2)
	await _click(runner, runner.find_child("Delete0"))
	assert_bool(await _wait_until(func(): return SaveStore.list_bars().size() == 1, 3000)).override_failure_message("the bar wasn't deleted").is_true()
	assert_str(str(SaveStore.list_bars()[0]["name"])).is_equal("Golmok Pocha")
	assert_bool(await _wait_until(func(): return (runner.find_child("Bar0") as Button).text.contains("Golmok Pocha"), 3000)).is_true()


func test_new_bar_button_starts_a_new_bar() -> void:
	Game.bar = {"id": "leftover"}
	var runner := scene_runner(TITLE)
	await _click(runner, runner.find_child("NewBarButton"))
	assert_bool(await _wait_for_scene(VISIT)).override_failure_message("New bar didn't ask for the visit scene").is_true()
	assert_bool(Game.bar.is_empty()).is_true()


func test_clicking_a_saved_bar_opens_it() -> void:
	var saved := _saved_bar("Byeolbit Pocha", 20000)
	var runner := scene_runner(TITLE)
	await _click(runner, runner.find_child("Bar0"))
	assert_bool(await _wait_for_scene(VISIT)).override_failure_message("clicking the bar didn't ask for the visit scene").is_true()
	assert_str(str(Game.bar.get("id", ""))).is_equal(saved["id"])
	assert_int(int(Game.bar["takings"])).is_equal(20000)


# --- New bars ------------------------------------------------------------------------------

func test_a_new_bar_is_named_and_saved_straight_away() -> void:
	var runner := await _open_visit()
	var bars := SaveStore.list_bars()
	assert_int(bars.size()).is_equal(1)
	var bar: Dictionary = bars[0]
	assert_str(str(bar["owner"]["name"])).is_equal(str(runner.scene()._owner["name"]))
	assert_str((runner.find_child("BarName") as Label).text).contains(str(bar["name"]))
	assert_str((runner.find_child("Transcript") as RichTextLabel).get_parsed_text()).contains("The sign over the tarp reads %s" % bar["name"])


func test_a_bad_bar_name_falls_back_to_the_owners_name() -> void:
	var owner_reply := {"name": "Han Jeong-hee", "age": 47, "archetype": "former chef who walked out of a hotel kitchen", "appearance": "Sleeves rolled up.", "personality": "proud", "speech_style": "quick", "secret": "Job offers."}
	CannedAi.scripted = [owner_reply, {"name": "별빛"}, {"name": "별빛"}, {"name": "별빛"}]
	await _open_visit()
	assert_str(str(SaveStore.list_bars()[0]["name"])).is_equal("Jeong-hee-ne Pocha")


func test_each_visit_is_saved() -> void:
	var runner := await _open_visit()
	var scene = runner.scene()
	await _run_one_visit(runner)
	var saved := SaveStore.load_bar(Game.bar["id"])
	assert_int(saved["visits"]).is_equal(1)
	assert_int(saved["takings"]).is_equal(scene._takings)
	assert_int(saved["history"].size()).is_equal(1)
	assert_str(str(saved["history"][0]["customer"])).is_equal(str(scene._customer["name"]))
	assert_int(int(saved["history"][0]["bill"])).is_equal(scene._takings)


# --- Saved bars ----------------------------------------------------------------------------

func test_a_saved_bar_reopens_with_its_owner_and_takings() -> void:
	var saved := _saved_bar("Dalbit Pojangmacha", 50000)
	Game.bar = SaveStore.load_bar(saved["id"])
	var runner := await _open_visit()
	var scene = runner.scene()
	assert_str(str(scene._owner["name"])).is_equal("Kim Sung-ho")
	assert_str((runner.find_child("TakingsLabel") as Label).text).is_equal("Takings: %s" % Menu.format_won(50000))
	assert_str((runner.find_child("BarName") as Label).text).contains("Dalbit Pojangmacha")
	assert_str((runner.find_child("Transcript") as RichTextLabel).get_parsed_text()).contains("again for the night")
	# Takings carry on from where they were, and the save keeps up.
	await _run_one_visit(runner)
	assert_int(scene._takings).is_greater(50000)
	assert_int(SaveStore.load_bar(saved["id"])["takings"]).is_equal(scene._takings)


func test_reopening_a_bar_doesnt_invent_a_new_owner() -> void:
	var saved := _saved_bar("Golmok Pocha", 0)
	CannedAi.scripted = [{"should": "never be used"}]
	Game.bar = SaveStore.load_bar(saved["id"])
	await _open_visit()
	assert_array(CannedAi.scripted).override_failure_message("the AI was asked for something on opening a saved bar").is_not_empty()
	assert_int(SaveStore.list_bars().size()).is_equal(1)


# --- Leaving and closing --------------------------------------------------------------------

func test_close_the_bar_saves_and_goes_back_to_the_title() -> void:
	var runner := await _open_visit()
	var id := str(Game.bar["id"])
	await _click(runner, runner.find_child("LeaveButton"))
	assert_bool(await _wait_for_scene(TITLE)).override_failure_message("Close the bar didn't ask for the title scene").is_true()
	assert_bool(Game.bar.is_empty()).is_true()
	assert_bool(SaveStore.load_bar(id).is_empty()).is_false()


func test_close_the_bar_waits_until_the_owner_is_free() -> void:
	var runner := await _open_visit()
	var scene = runner.scene()
	var id := str(Game.bar["id"])
	var leave := runner.find_child("LeaveButton") as Button
	scene._arrive(scene._clock)  # someone turns up
	assert_bool(await _wait_until(func(): return scene._owner_working)).is_true()
	await _click(runner, leave)
	# Mid-task, the owner finishes what they're doing first...
	if scene._owner_working:
		assert_bool(leave.disabled).is_true()
	# ...then the bar closes and goes back to the title.
	assert_bool(await _wait_for_scene(TITLE)).override_failure_message("Close the bar never went back to the title").is_true()
	assert_bool(SaveStore.load_bar(id).is_empty()).is_false()


func test_closing_the_window_saves_the_bar() -> void:
	var saved := _saved_bar("Saebyeok Pocha", 1000)
	Game.bar = SaveStore.load_bar(saved["id"])
	Game.bar["takings"] = 77000
	Game.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	assert_int(SaveStore.load_bar(saved["id"])["takings"]).is_equal(77000)
