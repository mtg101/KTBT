extends GdUnitTestSuite
## Tests for scripts/save_store.gd: bars must save and load back exactly, safely.
## These use their own folder (user://test_saves/), never the real saves.

const SaveStore = preload("res://scripts/save_store.gd")

const TEST_FOLDER := "user://test_saves/"
const OWNER_DATA := {"name": "Park Mi-sook", "age": 61, "gender": "woman", "title": "Ajumma", "archetype": "gruff-but-soft ajumma", "appearance": "Apron.", "personality": "blunt", "speech_style": "short", "secret": "Trot singer."}

var _real_folder := ""


func before_test() -> void:
	_real_folder = SaveStore.folder
	SaveStore.folder = TEST_FOLDER
	_clear()


func after_test() -> void:
	_clear()
	SaveStore.folder = _real_folder


func _clear() -> void:
	var dir := DirAccess.open(TEST_FOLDER)
	if dir == null:
		return
	for file_name in dir.get_files():
		dir.remove(file_name)


## Writes a file into the test folder directly, bypassing save_bar.
func _write_raw(file_name: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(TEST_FOLDER)
	var file := FileAccess.open(TEST_FOLDER.path_join(file_name), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _bar(bar_name := "Mi-sook-ne Pocha") -> Dictionary:
	return SaveStore.new_bar(bar_name, "Mi-sook's family's tent", OWNER_DATA)


func test_new_bar_starts_empty() -> void:
	var bar := _bar()
	assert_int(bar["version"]).is_equal(SaveStore.VERSION)
	assert_int(bar["takings"]).is_equal(0)
	assert_int(bar["visits"]).is_equal(0)
	assert_array(bar["history"]).is_empty()
	assert_str(str(bar["owner"]["name"])).is_equal("Park Mi-sook")


func test_new_bar_copies_the_owner() -> void:
	var owner_data := OWNER_DATA.duplicate()
	var bar := SaveStore.new_bar("Haengbok Pocha", "Happiness Tent", owner_data)
	owner_data["name"] = "changed"
	assert_str(str(bar["owner"]["name"])).is_equal("Park Mi-sook")


func test_ids_are_readable_and_unique_per_time() -> void:
	assert_str(SaveStore.make_id("Mi-sook-ne Pocha", 1794600000)).is_equal("mi-sook-ne-pocha-1794600000")
	assert_str(SaveStore.make_id("Uri-jip  Pocha!!", 5)).is_equal("uri-jip-pocha-5")
	assert_str(SaveStore.make_id("???", 5)).is_equal("bar-5")


func test_saved_bar_loads_back_the_same() -> void:
	var bar := _bar()
	bar["takings"] = 41000
	assert_int(SaveStore.save_bar(bar)).is_equal(OK)
	var loaded := SaveStore.load_bar(bar["id"])
	assert_str(str(loaded["name"])).is_equal("Mi-sook-ne Pocha")
	assert_str(str(loaded["name_meaning"])).is_equal("Mi-sook's family's tent")
	assert_str(str(loaded["owner"]["title"])).is_equal("Ajumma")
	assert_int(loaded["takings"]).is_equal(41000)


func test_whole_numbers_come_back_as_whole_numbers() -> void:
	# JSON stores every number as a decimal; the game expects ints for money and ages.
	var bar := _bar()
	SaveStore.save_bar(bar)
	var loaded := SaveStore.load_bar(bar["id"])
	assert_int(typeof(loaded["takings"])).is_equal(TYPE_INT)
	assert_int(typeof(loaded["owner"]["age"])).is_equal(TYPE_INT)


func test_saving_leaves_no_temporary_file() -> void:
	var bar := _bar()
	SaveStore.save_bar(bar)
	assert_bool(FileAccess.file_exists(TEST_FOLDER.path_join(bar["id"] + ".json"))).is_true()
	assert_bool(FileAccess.file_exists(TEST_FOLDER.path_join(bar["id"] + ".json.tmp"))).is_false()


func test_saving_again_replaces_the_old_save() -> void:
	var bar := _bar()
	SaveStore.save_bar(bar)
	bar["takings"] = 99000
	SaveStore.save_bar(bar)
	assert_int(SaveStore.load_bar(bar["id"])["takings"]).is_equal(99000)
	assert_int(SaveStore.list_bars().size()).is_equal(1)


func test_a_save_left_as_tmp_by_a_crash_is_recovered() -> void:
	var bar := _bar()
	_write_raw(bar["id"] + ".json.tmp", JSON.stringify(bar))
	assert_str(str(SaveStore.load_bar(bar["id"]).get("name", ""))).is_equal("Mi-sook-ne Pocha")
	assert_int(SaveStore.list_bars().size()).is_equal(1)


func test_list_puts_the_most_recently_played_first() -> void:
	var older := _bar("Golmok Pocha")
	older["last_played"] = 1000
	var newer := _bar("Sarang Pocha")
	newer["last_played"] = 2000
	_write_raw(older["id"] + ".json", JSON.stringify(older))
	_write_raw(newer["id"] + ".json", JSON.stringify(newer))
	var bars := SaveStore.list_bars()
	assert_int(bars.size()).is_equal(2)
	assert_str(str(bars[0]["name"])).is_equal("Sarang Pocha")


func test_unreadable_files_are_skipped() -> void:
	_write_raw("broken.json", "this is not json")
	_write_raw("not-a-bar.json", JSON.stringify({"hello": "world"}))
	SaveStore.save_bar(_bar())
	assert_int(SaveStore.list_bars().size()).is_equal(1)


func test_missing_bar_loads_as_empty() -> void:
	assert_bool(SaveStore.load_bar("no-such-bar").is_empty()).is_true()


func test_list_is_empty_when_there_are_no_saves() -> void:
	assert_array(SaveStore.list_bars()).is_empty()


func test_recording_a_visit_adds_takings_and_history() -> void:
	var bar := _bar()
	SaveStore.record_visit(bar, {"customer": "Kim Ji-ho", "bill": 17000})
	SaveStore.record_visit(bar, {"customer": "Lee Min-ji", "bill": 12000})
	assert_int(bar["visits"]).is_equal(2)
	assert_int(bar["takings"]).is_equal(29000)
	assert_str(str(bar["history"][1]["customer"])).is_equal("Lee Min-ji")


func test_history_is_kept_to_a_limit() -> void:
	var bar := _bar()
	for i in SaveStore.HISTORY_LIMIT + 5:
		SaveStore.record_visit(bar, {"customer": "Customer %d" % i, "bill": 1000})
	assert_int(bar["history"].size()).is_equal(SaveStore.HISTORY_LIMIT)
	assert_str(str(bar["history"][0]["customer"])).is_equal("Customer 5")
	assert_int(bar["visits"]).is_equal(SaveStore.HISTORY_LIMIT + 5)


func test_new_bar_has_had_no_nights() -> void:
	var bar := _bar()
	assert_int(bar["nights"]).is_equal(0)
	assert_array(bar["night_log"]).is_empty()


func test_recording_a_night_counts_it_and_logs_it() -> void:
	var bar := _bar()
	SaveStore.record_night(bar, {"night": 1, "customers": 7, "takings": 98000})
	SaveStore.record_night(bar, {"night": 2, "customers": 9, "takings": 121000})
	assert_int(bar["nights"]).is_equal(2)
	assert_int(int(bar["night_log"][1]["customers"])).is_equal(9)


func test_night_log_is_kept_to_a_limit() -> void:
	var bar := _bar()
	for i in SaveStore.NIGHT_LOG_LIMIT + 3:
		SaveStore.record_night(bar, {"night": i + 1})
	assert_int(bar["night_log"].size()).is_equal(SaveStore.NIGHT_LOG_LIMIT)
	assert_int(int(bar["night_log"][0]["night"])).is_equal(4)
	assert_int(bar["nights"]).is_equal(SaveStore.NIGHT_LOG_LIMIT + 3)


func test_nights_come_back_as_whole_numbers() -> void:
	var bar := _bar()
	bar["first_day"] = 2
	SaveStore.record_night(bar, {"night": 1})
	SaveStore.save_bar(bar)
	var loaded := SaveStore.load_bar(bar["id"])
	assert_int(loaded["nights"]).is_equal(1)
	assert_int(loaded["first_day"]).is_equal(2)
	assert_int(typeof(loaded["nights"])).is_equal(TYPE_INT)


func test_a_bar_can_be_deleted() -> void:
	var bar := _bar()
	SaveStore.save_bar(bar)
	assert_bool(SaveStore.delete_bar(bar["id"])).is_true()
	assert_bool(SaveStore.load_bar(bar["id"]).is_empty()).is_true()
	assert_array(SaveStore.list_bars()).is_empty()
	assert_bool(SaveStore.delete_bar(bar["id"])).is_false()  # nothing left to delete
