extends GdUnitTestSuite
## Tests for scripts/debug_log.gd: the game's notes, quiet on the console, each night's in its
## own file.

const DebugLog = preload("res://scripts/debug_log.gd")

const TEST_FOLDER := "user://test_debug_log/"


func before_test() -> void:
	DebugLog.folder = TEST_FOLDER
	DebugLog.everything_to_console = false
	DebugLog.printed = []
	DebugLog._file = null  # (no night's file open yet: notes wait for it)
	DebugLog._waiting = []


func after_test() -> void:
	DebugLog.folder = ""
	DebugLog.everything_to_console = false
	DebugLog.printed = []
	var dir := DirAccess.open(TEST_FOLDER)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)


func test_notes_go_to_the_nights_file_and_only_a_few_to_the_console() -> void:
	DebugLog.say("Regulars", "Ji-ho's coming in around the same time as her friend Min-jun")  # (before tonight's file: kept for it)
	var path := DebugLog.start_night("golmok-1", 3)
	assert_str(path).contains("golmok-1_night3.txt")
	DebugLog.say("Facts", "Ji-ho's job, \"a nurse\"")
	DebugLog.say("Light", "11:00pm · the night -1.7 steps")
	var text := FileAccess.get_file_as_string(path)
	assert_str(text).contains("Regulars: Ji-ho's coming in").contains("Facts: Ji-ho's job").contains("Light: 11:00pm")
	assert_int(text.find("Regulars:")).is_less(text.find("Facts:"))  # (in the order they happened)
	assert_array(DebugLog.printed).is_equal(["Light: 11:00pm · the night -1.7 steps"])  # (the console: only what's worth watching)
	for kind in ["Autoplay", "Season", "Night transcript", "Night stats saved", "Debug log"]:
		assert_bool(kind in DebugLog.CONSOLE).override_failure_message(kind).is_true()
	assert_bool("Owner" in DebugLog.CONSOLE).is_false()


func test_log_all_puts_everything_on_the_console() -> void:
	DebugLog.from_args(PackedStringArray(["--autoplay=3"]))
	assert_bool(DebugLog.everything_to_console).is_false()
	DebugLog.from_args(PackedStringArray(["--log-all"]))
	assert_bool(DebugLog.everything_to_console).is_true()
	DebugLog.say("Threads", "Ji-ho has something coming up: an exam")
	assert_array(DebugLog.printed).contains(["Threads: Ji-ho has something coming up: an exam"])
