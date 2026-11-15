extends GdUnitTestSuite
## Tests for scripts/night_stats.gd: the debug stats and the night log.

const NightStats = preload("res://scripts/night_stats.gd")

const TEST_FOLDER := "user://test_stats/"

var _real_folder := ""


func before_test() -> void:
	_real_folder = NightStats.folder
	NightStats.folder = TEST_FOLDER
	_clear()


func after_test() -> void:
	_clear()
	NightStats.folder = _real_folder


func _clear() -> void:
	var dir := DirAccess.open(TEST_FOLDER)
	if dir == null:
		return
	for file_name in dir.get_files():
		dir.remove(file_name)


func test_ai_calls_are_counted_with_their_problems() -> void:
	var stats := NightStats.new()
	stats.record_ai(2.0, [], true)
	stats.record_ai(4.0, ["someone called Kim Ji-ho is already at the counter: pick a different name"], true)
	stats.record_ai(6.0, ["it wasn't a JSON object", "it wasn't a JSON object", "it left out \"line\""], false)
	assert_int(stats.ai_calls).is_equal(3)
	assert_float(NightStats.average(stats.ai_seconds)).is_equal(4.0)
	assert_int(stats.rejected).is_equal(4)
	assert_int(stats.gave_up).is_equal(1)
	assert_int(int(stats.rejections["missing or broken JSON"])).is_equal(3)
	# Most common first.
	assert_str(stats.rejection_text()).is_equal("missing or broken JSON 3, same name 1")


func test_averages_cope_with_nothing_yet() -> void:
	assert_float(NightStats.average([])).is_equal(0.0)
	assert_float(NightStats.longest([])).is_equal(0.0)
	assert_float(NightStats.shortest([])).is_equal(0.0)
	assert_int(NightStats.percent(1.0, 0.0)).is_equal(0)


func test_panel_shows_every_section() -> void:
	var stats := NightStats.new()
	stats.arrived = 7
	stats.chats_started = 2
	stats.chat_lines = 10
	stats.owner_lines = 30
	var text := stats.panel_text(3, 1)
	for part in ["PEOPLE", "TALK", "FOOD", "AI", "Arrived 7", "At the counter 3", "Wait for the owner", "Wait for first drinks", "on the stove now 1", "2 started, 10 lines (25% of all lines)"]:
		assert_str(text).contains(part)


func test_the_night_log_is_saved_as_json() -> void:
	var stats := NightStats.new()
	stats.served = 4
	stats.chats_started = 1
	var path := stats.save({"bar": "Golmok Pocha", "night": 3}, "golmok-pocha", 3)
	assert_str(path).ends_with("_golmok-pocha_night3.json")
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_int(int(data["people"]["served"])).is_equal(4)
	assert_int(int(data["talk"]["chats_started"])).is_equal(1)
	assert_str(str(data["context"]["bar"])).is_equal("Golmok Pocha")


func test_the_log_keeps_the_actual_reasons_with_what_was_asked() -> void:
	var stats := NightStats.new()
	var two_mains := "they ordered 2 main dishes, but most people order just one main (add a side instead)"
	stats.record_ai(1.0, [two_mains, two_mains], true, "order")
	stats.record_ai(1.0, ["there's no food: nobody drinks on an empty stomach, so order at least one food"], true, "order")
	var reasons: Dictionary = stats.summary({})["ai"]["rejection_reasons"]["order rules"]
	assert_int(int(reasons["order: " + two_mains])).is_equal(2)
	assert_int(reasons.size()).is_equal(2)


func test_how_full_the_tent_was() -> void:
	var stats := NightStats.new()
	stats.real_seconds = 100.0
	stats.seated_seconds = 150.0  # e.g. one person for half the night, two for the other half
	stats.together_seconds = 50.0
	assert_float(stats.average_seated()).is_equal(1.5)
	var text := stats.panel_text(2, 0)
	assert_str(text).contains("avg 1.5")
	assert_str(text).contains("Two or more in: 50% of the night")
	assert_float(float(stats.summary({})["people"]["average_seated"])).is_equal(1.5)


func test_chat_chances_are_counted() -> void:
	var stats := NightStats.new()
	stats.chat_chances = 10
	stats.chats_started = 2
	stats.chats_continued = 3
	assert_str(stats.panel_text(2, 0)).contains("Chat chances: 10 · taken 5 (2 new, 3 carried on)")
	assert_int(int(stats.summary({})["talk"]["chat_chances"])).is_equal(10)
	stats.free_turns = 30
	assert_str(stats.panel_text(2, 0)).contains("Owner free: 30 times (a chat possible in 10)")
