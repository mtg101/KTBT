extends GdUnitTestSuite
## Tests for scripts/autoplay.gd: a batch of nights playing themselves, on its own (a whole
## batch played through is in test_night.gd).

const Autoplay = preload("res://scripts/autoplay.gd")

const TEST_FOLDER := "user://test_autoplay/"


func after_test() -> void:
	Autoplay.folder = ""
	var dir := DirAccess.open(TEST_FOLDER)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)


func test_the_command_line_starts_a_batch() -> void:
	assert_object(Autoplay.from_args(PackedStringArray([]))).is_null()  # (an ordinary game)
	assert_object(Autoplay.from_args(PackedStringArray(["--autoplay=0"]))).is_null()
	var batch = Autoplay.from_args(PackedStringArray(["--autoplay=10"]))
	assert_int(batch.nights).is_equal(10)
	assert_str(batch.bar_id).is_empty()  # (a new bar of its own)
	batch = Autoplay.from_args(PackedStringArray(["--autoplay-bar=daegongne-17", "--autoplay=3"]))
	assert_int(batch.nights).is_equal(3)
	assert_str(batch.bar_id).is_equal("daegongne-17")


func test_it_stops_after_its_nights_or_when_told_why() -> void:
	var batch := Autoplay.new(2)
	assert_str(batch.progress_text()).is_equal("night 1 of 2")
	batch.night_done(1, 12, false, 9, 1)
	assert_bool(batch.finished()).is_false()
	assert_str(batch.progress_text()).is_equal("night 2 of 2")
	batch.night_done(2, 15, false, 7, 0)
	assert_bool(batch.finished()).is_true()
	var early := Autoplay.new(10)
	early.stop("the AI stopped answering (connection refused)")
	early.stop("something later")  # (the first reason's kept)
	assert_bool(early.finished()).is_true()
	assert_str(early.stop_reason).is_equal("the AI stopped answering (connection refused)")


func test_the_summary_says_how_each_night_went() -> void:
	Autoplay.folder = TEST_FOLDER
	var batch := Autoplay.new(3)
	batch.errors.note("Couldn't save the bar (save_store.gd:40, save_bar)")
	batch.night_done(1, 12, false, 9, 1)
	batch.night_done(2, 4, true, 0, 0)
	batch.stop("the AI stopped answering (connection refused)")
	var text := batch.summary_text("Daegongne")
	assert_str(text).contains("KTBT autoplay: Daegongne").contains("2 of 3 nights played, stopped early: the AI stopped answering")
	assert_str(text).contains("Night 1: ").contains("12 customers, AI rejected 9, gave up 1, 1 errors")
	assert_str(text).contains("Night 2: ").contains("4 customers, AI rejected 0, gave up 0, OFFLINE\n")
	assert_str(text).contains("Errors: 1:\n  Couldn't save the bar")
	var path := batch.save_summary("Daegongne", "daegongne-17")
	assert_str(path).starts_with(TEST_FOLDER).ends_with("_daegongne-17.txt")
	assert_str(FileAccess.get_file_as_string(path)).is_equal(text)
