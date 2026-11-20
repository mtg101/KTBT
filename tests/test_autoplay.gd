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
	var rated := Autoplay.new(1)
	rated.night_done(1, 18, false, 3, 0, 6.4)
	assert_str(rated.summary_text("Daegongne")).contains("18 customers, ratings 6.4%, AI rejected 3")
	var finale := Autoplay.new(1)  # (where it was in the seasons, and a finale's verdict)
	finale.night_done(8, 18, false, 3, 0, 6.4, "S1 · EP 8/8 · FINALE · Season 1: average 6.2% = 6.2: stay (재계약!)")
	assert_str(finale.summary_text("Daegongne")).contains("gave up 0 (S1 · EP 8/8 · FINALE · Season 1: average 6.2%")
	var path := batch.save_summary("Daegongne", "daegongne-17")
	assert_str(path).starts_with(TEST_FOLDER).ends_with("_daegongne-17.txt")
	assert_str(FileAccess.get_file_as_string(path)).is_equal(text)


func test_a_running_batch_says_so_with_its_process() -> void:
	Autoplay.folder = TEST_FOLDER
	var batch := Autoplay.new(5)
	batch.write_running()
	var running = JSON.parse_string(FileAccess.get_file_as_string(Autoplay.running_path()))
	assert_int(int(running["pid"])).is_equal(OS.get_process_id())  # (the helper checks this process is alive, and stops it)
	assert_int(int(running["nights"])).is_equal(5)
	assert_int(int(running["played"])).is_equal(0)
	batch.night_done(1, 12, false, 9, 1)
	batch.write_running("Daegongne")
	running = JSON.parse_string(FileAccess.get_file_as_string(Autoplay.running_path()))
	assert_int(int(running["played"])).is_equal(1)
	assert_str(str(running["bar"])).is_equal("Daegongne")
	Autoplay.clear_running()
	assert_bool(FileAccess.file_exists(Autoplay.running_path())).is_false()
	Autoplay.clear_running()  # (and again, with nothing there: fine)


func test_the_crew_run_it_from_the_menu_and_hand_it_back_when_done_or_stopped() -> void:
	var cmd = Autoplay.from_args(PackedStringArray(["--autoplay=3"]))
	assert_bool(cmd.from_command_line).is_true()
	assert_bool(cmd.quits_when_done()).is_true()  # (a test batch: the game quits when it's done)
	assert_str(cmd.started_from()).is_equal("the command line")
	var crew = Autoplay.in_game(5, "golmok-1")
	assert_bool(crew.from_command_line).is_false()
	assert_bool(crew.begun).is_true()  # (the bar's open already: the title screen doesn't start it again)
	assert_str(crew.bar_id).is_equal("golmok-1")  # (the open bar, never marked a test bar)
	assert_bool(crew.quits_when_done()).is_false()  # (the bar's handed back)
	assert_str(crew.started_from()).is_equal("the menu")
	assert_int(Autoplay.in_game(0, "x").nights).is_equal(1)
	assert_int(Autoplay.in_game(99, "x").nights).is_equal(Autoplay.MOST_NIGHTS)
	cmd.stop_by_hand("stopped by hand, after night 2")  # (stopped by hand: the bar's handed back, even from the command line)
	assert_bool(cmd.by_hand).is_true()
	assert_bool(cmd.finished()).is_true()
	assert_bool(cmd.quits_when_done()).is_false()
	cmd.stop_by_hand("something later")
	assert_str(cmd.stop_reason).is_equal("stopped by hand, after night 2")  # (the first reason's kept)
	assert_str(crew.summary_text("Golmok Pocha")).contains("from the menu. 0 of 5 nights played")
