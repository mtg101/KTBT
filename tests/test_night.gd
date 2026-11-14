extends GdUnitTestSuite
## Click-through tests for a full night: the clock runs on its own, customers arrive without
## anyone clicking, and at 3am the night ends with a summary and a save. Offline mode, with
## pauses (and so the clock) sped right up, so a whole night takes a few seconds.

const Visit = preload("res://scripts/visit.gd")
const AiSettings = preload("res://scripts/ai_settings.gd")
const CannedAi = preload("res://scripts/canned_ai.gd")
const SaveStore = preload("res://scripts/save_store.gd")
const NightStats = preload("res://scripts/night_stats.gd")

const SCENE := "res://scenes/visit.tscn"
const TITLE := "res://scenes/title.tscn"
const TEST_SAVES := "user://test_saves_night/"
const TIMEOUT_MS := 15000
const NIGHT_TIMEOUT_MS := 60000

var _real_saves := "user://saves/"  # (never "", which would save into the project folder)
var _real_stats := "user://stats/"
const TEST_TRANSCRIPTS := "user://test_transcripts_night/"
const TEST_STATS := "user://test_stats_night/"


func before_test() -> void:
	_real_saves = SaveStore.folder
	SaveStore.folder = TEST_SAVES
	_real_stats = NightStats.folder
	NightStats.folder = TEST_STATS  # night logs go here, not among real ones
	Ambience.make_sound = false  # quiet tests (and quick ones)
	Ambience.settings_path = "user://test_settings.cfg"
	_clear_folder(TEST_STATS)
	Visit.transcript_folder = TEST_TRANSCRIPTS  # and transcripts, not into the project
	_clear_folder(TEST_TRANSCRIPTS)
	_clear_saves()
	Game.bar = {}
	Game.change_scenes = false
	Game.requested_scene = ""
	AiSettings.override = {"backend": "canned"}
	CannedAi.scripted = []
	Visit.pause_scale_override = 0.01
	Visit.random_seed = 2468
	Visit.run_clock = true


func after_test() -> void:
	_clear_saves()
	SaveStore.folder = _real_saves
	_clear_folder(TEST_STATS)
	NightStats.folder = _real_stats
	_clear_folder(TEST_TRANSCRIPTS)
	Visit.transcript_folder = ""
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
	await get_tree().process_frame  # let containers lay out before aiming at the button
	await get_tree().process_frame
	await get_tree().process_frame
	runner.simulate_mouse_move(button.get_global_rect().get_center())
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()


## Loads the scene and waits until the night has opened.
func _open_bar() -> GdUnitSceneRunner:
	var runner := scene_runner(SCENE)
	var scene = runner.scene()
	var open: bool = await _wait_until(func(): return scene._night_open)
	assert_bool(open).override_failure_message("the night never started").is_true()
	return runner


func _wait_for_summary(runner: GdUnitSceneRunner) -> bool:
	var summary := runner.find_child("NightSummary") as Control
	return await _wait_until(func(): return summary.visible, NIGHT_TIMEOUT_MS)


func _transcript(runner: GdUnitSceneRunner) -> String:
	return (runner.find_child("Transcript") as RichTextLabel).get_parsed_text()


# --- Tests -------------------------------------------------------------------------------

func test_the_first_night_starts_at_six() -> void:
	Visit.run_clock = false  # hold the clock at opening time
	var runner := await _open_bar()
	assert_str(_transcript(runner)).contains("Night 1")
	assert_str(_transcript(runner)).contains("6:00pm")
	var moment := (runner.find_child("MomentLabel") as Label).text
	assert_str(moment).contains("Night 1")
	assert_str(moment).contains("6:00pm")
	assert_bool((runner.find_child("NightSummary") as Control).visible).is_false()


func test_the_clock_runs_by_itself() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	var start: float = scene._clock
	var moved: bool = await _wait_until(func(): return scene._clock > start + 10)
	assert_bool(moved).override_failure_message("the clock didn't move").is_true()


func test_customers_arrive_without_clicking() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	var served: bool = await _wait_until(func(): return scene._night_visits >= 1, NIGHT_TIMEOUT_MS)
	assert_bool(served).override_failure_message("nobody turned up on their own").is_true()
	assert_int(int(Game.bar["visits"])).is_greater_equal(1)


func test_someone_turning_up_mid_night_is_served() -> void:
	Visit.run_clock = false
	var runner := await _open_bar()
	var scene = runner.scene()
	scene._arrive(scene._clock)
	assert_bool(scene.busy).override_failure_message("nobody turned up").is_true()
	var done: bool = await _wait_until(func(): return not scene.busy)
	assert_bool(done).override_failure_message("the visit never finished").is_true()
	assert_int(scene._night_visits).is_equal(1)


func test_the_night_ends_at_three_with_a_summary() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	assert_bool(await _wait_for_summary(runner)).override_failure_message("the night never ended").is_true()
	assert_int(int(scene._clock)).is_greater_equal(27 * 60)  # the last customers may finish after 3am
	assert_bool(scene._night_open).is_false()
	var summary := (runner.find_child("SummaryText") as RichTextLabel).get_parsed_text()
	assert_str(summary).contains("Night 1 at %s" % Game.bar["name"])
	assert_str(summary).contains("customer")
	assert_str(_transcript(runner)).contains("pulls down the tarp")
	assert_array(scene._guests).is_empty()


func test_the_finished_night_is_saved() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	assert_bool(await _wait_for_summary(runner)).is_true()
	var saved := SaveStore.load_bar(str(Game.bar["id"]))
	assert_int(int(saved["nights"])).is_equal(1)
	assert_int(saved["night_log"].size()).is_equal(1)
	var entry: Dictionary = saved["night_log"][0]
	assert_int(int(entry["night"])).is_equal(1)
	assert_int(int(entry["customers"])).is_equal(scene._night_visits)
	assert_int(int(entry["takings"])).is_equal(scene._night_takings)


func test_the_night_log_is_written() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	assert_bool(await _wait_for_summary(runner)).is_true()
	var files := DirAccess.get_files_at(TEST_STATS)
	assert_int(files.size()).is_equal(1)
	assert_str(files[0]).ends_with("_night1.json")
	var data = JSON.parse_string(FileAccess.get_file_as_string(TEST_STATS.path_join(files[0])))
	assert_bool(bool(data["context"]["finished"])).is_true()
	assert_int(int(data["people"]["served"])).is_equal(scene._night_visits)


func test_the_night_transcript_is_written() -> void:
	var runner := await _open_bar()
	assert_bool(await _wait_for_summary(runner)).is_true()
	var files := DirAccess.get_files_at(TEST_TRANSCRIPTS)
	assert_int(files.size()).is_equal(1)
	assert_str(files[0]).ends_with("_night1.txt")
	var text := FileAccess.get_file_as_string(TEST_TRANSCRIPTS.path_join(files[0]))
	assert_str(text).starts_with("KTBT transcript: %s, night 1" % Game.bar["name"])
	assert_str(text).contains("Finished at")
	assert_str(text).contains("Started ")
	assert_str(text).contains("Night 1")  # the night's own divider
	assert_str(text).contains("pulls down the tarp")  # through to closing time
	assert_str(text).contains("STATS")
	assert_str(text).not_contains("[b]")


func test_the_transcript_is_written_as_the_night_goes() -> void:
	Visit.run_clock = false  # hold the night, so it's still going when we look
	var runner := await _open_bar()
	var scene = runner.scene()
	scene._arrive(scene._clock)
	assert_bool(await _wait_until(func(): return not scene.busy)).is_true()
	var files := DirAccess.get_files_at(TEST_TRANSCRIPTS)
	assert_int(files.size()).is_equal(1)
	var text := FileAccess.get_file_as_string(TEST_TRANSCRIPTS.path_join(files[0]))
	assert_str(text).contains("Someone ducks under the tarp")
	assert_str(text).contains("heads back out into the night")  # their visit's already in the file
	assert_str(text).not_contains("STATS")  # the night's not over yet


func test_open_for_another_night_starts_night_two() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	assert_bool(await _wait_for_summary(runner)).is_true()
	Visit.run_clock = false  # hold night two at opening time
	var first_day: String = scene._night_day
	await _click(runner, runner.find_child("NextNightButton"))
	assert_bool(await _wait_until(func(): return scene._night_number == 2)).override_failure_message("night two never started").is_true()
	assert_bool((runner.find_child("NightSummary") as Control).visible).is_false()
	assert_str(_transcript(runner)).contains("Night 2")
	assert_str(scene._night_day).is_not_equal(first_day)
	assert_int(int(scene._clock)).is_equal(18 * 60)
	assert_int(scene._night_visits).is_equal(0)


func test_close_the_bar_saves_and_goes_back_to_the_title() -> void:
	var runner := await _open_bar()
	assert_bool(await _wait_for_summary(runner)).is_true()
	var id := str(Game.bar["id"])
	await _click(runner, runner.find_child("SummaryLeaveButton"))
	assert_bool(await _wait_until(func(): return Game.requested_scene == TITLE, 3000)).override_failure_message("Close the bar didn't go to the title").is_true()
	assert_bool(Game.bar.is_empty()).is_true()
	assert_bool(SaveStore.load_bar(id).is_empty()).is_false()


func test_a_saved_bar_carries_on_from_its_next_night() -> void:
	var bar := SaveStore.new_bar("Mi-sook-ne Pocha", "Mi-sook's place", {"name": "Park Mi-sook", "hangul": "박미숙", "age": 61, "gender": "woman", "title": "Ajumma", "archetype": "gruff-but-soft ajumma", "appearance": "Apron.", "personality": "blunt", "speech_style": "short", "secret": "Trot singer."})
	bar["nights"] = 3
	bar["first_day"] = 0  # Monday, so night 4 is a Thursday
	SaveStore.save_bar(bar)
	Game.bar = SaveStore.load_bar(bar["id"])
	Visit.run_clock = false
	var runner := await _open_bar()
	assert_str(_transcript(runner)).contains("Night 4")
	assert_str((runner.find_child("MomentLabel") as Label).text).contains("Thursday")
