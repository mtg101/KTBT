extends GdUnitTestSuite
## What every test of the bar's scenes shares (test_visit, test_night, test_bars): each test
## starts from the same known state (Hooks.for_tests: quick, repeatable, quiet, offline, every
## extra AI call off, and the suite's own folders for saves, night logs and transcripts) and
## ends with everything back to normal (Hooks.restore), so nothing one test or suite sets can
## leak into another. Plus the helpers they all use. A suite sets its own TEST_SAVES,
## TEST_STATS and TEST_TRANSCRIPTS consts, and can add to the setup in _setup().

const Hooks = preload("res://scripts/test_hooks.gd")

const TIMEOUT_MS := 15000

var _saves := ""
var _stats := ""
var _transcripts := ""


func before_test() -> void:
	var consts: Dictionary = (get_script() as Script).get_script_constant_map()
	_saves = str(consts.get("TEST_SAVES", "user://test_saves/"))
	_stats = str(consts.get("TEST_STATS", "user://test_stats/"))
	_transcripts = str(consts.get("TEST_TRANSCRIPTS", "user://test_transcripts/"))
	Hooks.for_tests(_saves, _stats, _transcripts)
	for folder in [_saves, _stats, _transcripts]:
		_clear_folder(folder)
	Game.bar = {}  # a new bar each test
	Game.change_scenes = false  # leaving the bar only records where it would go
	Game.requested_scene = ""
	_setup()


func after_test() -> void:
	for folder in [_saves, _stats, _transcripts]:
		_clear_folder(folder)
	Hooks.restore()
	Game.bar = {}
	Game.change_scenes = true
	Game.requested_scene = ""


## A suite's own setup, after the shared one (a seed of its own, the clock held still...).
func _setup() -> void:
	pass


# --- Helpers ---------------------------------------------------------------------------

func _clear_folder(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name in dir.get_files():
		dir.remove(file_name)


func _clear_saves() -> void:
	_clear_folder(_saves)


## Waits (a frame at a time) until condition() is true. Returns false on timeout.
func _wait_until(condition: Callable, timeout_ms := TIMEOUT_MS) -> bool:
	var start := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - start > timeout_ms:
			return false
		await get_tree().process_frame
	return true


## Clicks a button the way a player would: move the mouse over it and press. Layouts settle
## first: a button that's only just appeared may not be in its place yet.
func _click(runner: GdUnitSceneRunner, button: Button) -> void:
	for i in 3:
		await get_tree().process_frame
	runner.simulate_mouse_move(button.get_global_rect().get_center())
	await runner.await_input_processed()
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.await_input_processed()


func _transcript(runner: GdUnitSceneRunner) -> String:
	return (runner.find_child("Transcript") as RichTextLabel).get_parsed_text()
