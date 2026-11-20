extends "res://tests/support/bar_test.gd"
## Click-through tests for bars and saves: the title screen, new and saved bars, and
## autosave. Like test_visit.gd, these use offline mode and their own save folder.

const Orders = preload("res://scripts/rules/orders.gd")
const Visit = preload("res://scripts/visit.gd")
const AiSettings = preload("res://scripts/ai/ai_settings.gd")
const CannedAi = preload("res://scripts/ai/canned_ai.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")
const NightStats = preload("res://scripts/bar/night_stats.gd")
const Menu = preload("res://scripts/rules/menu.gd")
const Catalogue = preload("res://scripts/rules/catalogue.gd")
const MenuChanges = preload("res://scripts/rules/menu_changes.gd")
const Ladder = preload("res://scripts/rules/ladder.gd")
const ShowSeasons = preload("res://scripts/rules/show_seasons.gd")

const TITLE := "res://scenes/title.tscn"
const VISIT := "res://scenes/visit.tscn"
const TEST_SAVES := "user://test_saves_bars/"
const OWNER_DATA := {"name": "Kim Sung-ho", "hangul": "김성호", "age": 58, "gender": "man", "title": "Ajusshi", "archetype": "quiet ajusshi with a mysterious past", "appearance": "A grey cardigan.", "personality": "calm, kind", "speech_style": "few words", "secret": "He was once a bodyguard."}

const TEST_TRANSCRIPTS := "user://test_transcripts_bars/"
const TEST_STATS := "user://test_stats_bars/"


func _setup() -> void:
	Hooks.random_seed = 4321
	Hooks.run_clock = false  # no automatic customers: these tests bring people in themselves


# --- Helpers ---------------------------------------------------------------------------

func _wait_for_scene(scene_path: String) -> bool:
	return await _wait_until(func(): return Game.requested_scene == scene_path, 3000)


## A saved bar with this name and this many visits, written straight to the test folder.
func _saved_bar(bar_name: String, visits: int, last_played := 0) -> Dictionary:
	var bar := SaveStore.new_bar(bar_name, "A test tent", OWNER_DATA)
	bar["visits"] = visits
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
	_saved_bar("Golmok Pocha", 12, 1000)
	_saved_bar("Sarang Pocha", 34, 2000)
	var runner := scene_runner(TITLE)
	var first := runner.find_child("Bar0") as Button
	var second := runner.find_child("Bar1") as Button
	assert_str(first.text).contains("Sarang Pocha")
	assert_str(first.text).contains("Kim Sung-ho (Ajusshi)")
	assert_str(first.text).contains("34 visits")
	assert_str(first.text).not_contains("₩")  # (takings aren't kept: 19 Nov)
	assert_str(second.text).contains("Golmok Pocha")


func test_title_shows_nights_and_visits() -> void:
	var bar := SaveStore.new_bar("Golmok Pocha", "A test tent", OWNER_DATA)
	bar["nights"] = 3
	bar["visits"] = 1
	bar["show"]["season"] = 2
	bar["show"]["aired"] = 3
	SaveStore.save_bar(bar)
	var runner := scene_runner(TITLE)
	assert_str((runner.find_child("Bar0") as Button).text).contains("3 nights, 1 visit")
	assert_str((runner.find_child("Bar0") as Button).text).contains("season 2 on a phone stream, 3 of 8 aired")  # (where the show's got to)


func test_a_bars_diary_can_be_read_from_the_title() -> void:
	_saved_bar("Golmok Pocha", 12, 1000)  # no diary yet: no Diary button
	var bar := SaveStore.new_bar("Sarang Pocha", "A test tent", OWNER_DATA)
	for night in [1, 2, 3]:
		SaveStore.record_diary(bar, {"night": night, "episode": night, "season": 1, "season_episode": night, "day": "Friday", "weather": "rain", "text": "Night %d was a night." % night, "stamp": "soju"})
	SaveStore.save_bar(bar)
	var runner := scene_runner(TITLE)
	assert_object(runner.find_child("Diary1", true, false)).is_null()  # the older bar (listed second) has none
	await _click(runner, runner.find_child("Diary0"))
	var book = runner.find_child("DiaryBook", true, false)
	assert_object(book).is_not_null()
	assert_int(book.showing_night()).is_equal(3)  # opens at the latest
	assert_str((book.find_child("Episode", true, false) as Label).text).is_equal("S1 · EP 3")  # (always its season and episode)
	assert_str((book.find_child("DiaryWhere", true, false) as Label).text).is_equal("3 of 3")
	assert_bool((book.find_child("DiaryNewer", true, false) as Button).disabled).is_true()
	await _click(runner, book.find_child("DiaryOlder", true, false))
	await _click(runner, book.find_child("DiaryOlder", true, false))
	assert_int(book.showing_night()).is_equal(1)
	assert_bool((book.find_child("DiaryOlder", true, false) as Button).disabled).is_true()
	await _click(runner, book.find_child("DiaryClose", true, false))
	assert_bool(await _wait_until(func(): return runner.find_child("DiaryBook", true, false) == null, 3000)).is_true()


func test_deleting_a_bar_takes_two_clicks() -> void:
	_saved_bar("Golmok Pocha", 12, 1000)
	_saved_bar("Sarang Pocha", 34, 2000)
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
	var saved := _saved_bar("Byeolbit Pocha", 20)
	var runner := scene_runner(TITLE)
	await _click(runner, runner.find_child("Bar0"))
	assert_bool(await _wait_for_scene(VISIT)).override_failure_message("clicking the bar didn't ask for the visit scene").is_true()
	assert_str(str(Game.bar.get("id", ""))).is_equal(saved["id"])
	assert_int(int(Game.bar["visits"])).is_equal(20)


# --- New bars ------------------------------------------------------------------------------

func test_a_new_bar_is_named_and_saved_straight_away() -> void:
	var runner := await _open_visit()
	var bars := SaveStore.list_bars()
	assert_int(bars.size()).is_equal(1)
	var bar: Dictionary = bars[0]
	assert_str(str(bar["owner"]["name"])).is_equal(str(runner.scene()._owner["name"]))
	assert_str((runner.find_child("BarName") as Label).text).contains(str(bar["name"]))
	assert_str((runner.find_child("Transcript") as RichTextLabel).get_parsed_text()).contains("The sign over the tarp reads %s" % bar["name"])


func test_the_pd_sets_up_a_new_show_and_the_bar_waits_for_them() -> void:
	var runner := scene_runner(VISIT)
	var scene = runner.scene()
	assert_object(runner.find_child("LoadingSetUp", true, false)).is_not_null()  # (offered on the loading screen)
	var enter := InputEventKey.new()  # Enter opens it, as the button does
	enter.keycode = KEY_ENTER
	enter.pressed = true
	scene._unhandled_input(enter)
	var setup = runner.find_child("ShowSetup", true, false)
	assert_object(setup).override_failure_message("Enter didn't open the setup").is_not_null()
	assert_bool((setup.find_child("Rung_phone", true, false) as CheckBox).button_pressed).is_true()  # (the game's pick: a phone stream)
	assert_str((setup.find_child("About_video", true, false) as Label).text).is_equal(Ladder.describe("video"))
	assert_str((setup.find_child("Rung_network", true, false) as CheckBox).text).starts_with("Network TV")
	await _click(runner, setup.find_child("Rung_video", true, false))
	for k in 10:  # the bar waits for the PD: nothing opens while they're in here
		await get_tree().process_frame
	assert_bool(scene._night_open).is_false()
	await _click(runner, setup.find_child("SetupDone", true, false))
	assert_bool(await _wait_until(func(): return scene._night_open)).override_failure_message("the bar never opened").is_true()
	assert_str(ShowSeasons.rung_of(Game.bar["show"])).is_equal("video")
	assert_str(str(SaveStore.load_bar(str(Game.bar["id"]))["show"]["rung"])).is_equal("video")  # (saved)
	assert_str((runner.find_child("Transcript") as RichTextLabel).get_parsed_text()).contains("The PD sets up the show: it starts on an online video channel.")
	assert_str(scene._stats.panel_text(0, 0)).contains("Setup: the show starts on video (the PD's)")
	var beside := (runner.find_child("RatingsLabel") as Label).text  # the Korean, and the English beside it
	assert_str(beside).starts_with("구독자 subscribers ").not_contains("+").ends_with("·  online video channel")  # (the channel's total subscribers)


func test_a_new_bar_chooses_its_own_menu() -> void:
	Hooks.bar_menus = true
	var runner := await _open_visit()
	var saved := SaveStore.load_bar(Game.bar["id"])
	var menu: Array = saved.get("menu", [])
	var ids: Array = menu.map(func(item): return str(item["id"]))
	assert_array(ids).contains(["soju", "beer", "gonggibap"])  # (every pocha)
	var chosen: Array = ids.filter(func(id): return not str(id).begins_with("own_"))
	assert_str(Catalogue.validate_menu({"dishes": chosen, "why": "Checked again."})).is_empty()  # (the house rules)
	# And the owner's own signature dish, invented from their story (the canned AI gives one of the game's).
	var own: Array = menu.filter(func(item): return bool(item.get("signature", false)))
	assert_int(own.size()).is_equal(1)
	assert_str(str(saved.get("signatures_by", ""))).is_equal("ai")
	assert_str(_transcript(runner)).contains("The house's own: %s %s" % [own[0]["hangul"], own[0]["name"]])
	assert_int(menu.size()).is_less_equal(Catalogue.MENU_SIZE.y + Catalogue.MIXED.size())
	# How the bar opened is at the top of the night's transcript, and the AI's work on it in tonight's stats.
	var scene = runner.scene()
	assert_bool(await _wait_until(func(): return scene._night_open)).is_true()
	var files: Array = Array(DirAccess.get_files_at(_transcripts)).filter(func(f): return str(f).ends_with(".txt"))
	assert_array(files).is_not_empty()
	var written := FileAccess.get_file_as_string(_transcripts.path_join(str(files[-1])))
	assert_str(written).contains("On the menu: the pocha classics").contains("The house's own: ")
	assert_int(int(scene._stats.calls_by.get("menu", 0))).is_greater_equal(1)
	assert_int(int(scene._stats.calls_by.get("signatures", 0))).is_greater_equal(1)
	assert_str(scene._stats.panel_text(0, 0)).contains("Getting ready: menu")
	assert_array(Menu.items().map(func(item): return str(item["id"]))).is_equal(ids)  # in use tonight
	assert_str(_transcript(runner)).contains("On the menu: the pocha classics, and ")
	assert_str(str(saved.get("menu_why", ""))).is_not_empty()
	# Customers order from it, and pay for it.
	await _run_one_visit(runner)
	assert_int(int(SaveStore.load_bar(Game.bar["id"])["visits"])).is_equal(1)
	for id in SaveStore.load_bar(Game.bar["id"])["history"][0]["order"]:
		assert_array(ids).contains([id])


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
	assert_bool(saved.has("takings")).is_false()
	assert_int(saved["history"].size()).is_equal(1)
	assert_str(str(saved["history"][0]["customer"])).is_equal(str(scene._customer["name"]))
	assert_int(int(saved["history"][0]["bill"])).is_equal(Orders.bill(scene._order))


# --- Saved bars ----------------------------------------------------------------------------

func test_a_saved_bar_reopens_with_its_owner_and_visits() -> void:
	var saved := _saved_bar("Dalbit Pojangmacha", 50)
	Game.bar = SaveStore.load_bar(saved["id"])
	var runner := await _open_visit()
	var scene = runner.scene()
	assert_str(str(scene._owner["name"])).is_equal("Kim Sung-ho")
	assert_str((runner.find_child("BarName") as Label).text).contains("Dalbit Pojangmacha")
	assert_str((runner.find_child("Transcript") as RichTextLabel).get_parsed_text()).contains("again for the night")
	# Visits carry on from where they were, and the save keeps up.
	await _run_one_visit(runner)
	assert_int(int(SaveStore.load_bar(saved["id"])["visits"])).is_equal(51)


func test_reopening_a_bar_doesnt_invent_a_new_owner() -> void:
	var saved := _saved_bar("Golmok Pocha", 0)
	CannedAi.scripted = [{"should": "never be used"}]
	Game.bar = SaveStore.load_bar(saved["id"])
	await _open_visit()
	assert_array(CannedAi.scripted).override_failure_message("the AI was asked for something on opening a saved bar").is_not_empty()
	assert_int(SaveStore.list_bars().size()).is_equal(1)


func test_reopening_a_bar_plays_previously_on() -> void:
	Hooks.recaps = true
	var bar := SaveStore.new_bar("Golmok Pocha", "A test tent", OWNER_DATA)
	bar["nights"] = 4
	SaveStore.record_diary(bar, {"night": 4, "episode": 4, "season": 1, "season_episode": 4, "day": "Friday", "weather": "rain", "text": "Ji-ho quit tonight.", "stamp": "rain",
		"facts": {"people": [{"name": "Kim Ji-ho", "job": "nurse"}], "moments": [{"who": "Kim Ji-ho", "mood": "shock", "caption": "SHE QUIT?!", "said": "I quit today."}]}})
	SaveStore.save_bar(bar)
	Game.bar = SaveStore.load_bar(bar["id"])
	var asked: Array = []
	var runner := scene_runner(VISIT)
	var scene = runner.scene()
	scene._ai.answered.connect(func(purpose, _s, _p, _ok): asked.append(purpose))
	assert_bool(await _wait_until(func(): return scene._night_number == 5, 10000)).override_failure_message("the night never started after the recap").is_true()
	assert_array(asked).contains(["recap"])
	# Last night's episode got its titles (here, the game's own) and the writers' went out.
	assert_int(Game.bar["diary"][-1]["titles"].size()).is_equal(3)
	assert_str(str(Game.bar["diary"][-1]["title"]["english"])).is_equal("She Quit?!")
	assert_str((runner.find_child("Transcript") as RichTextLabel).get_parsed_text()).contains("Previously on… (She Quit?!) Ji-ho")  # (the canned recap, from last night's facts)
	assert_str(scene._stats.panel_text(0, 0)).contains("Last night's episode: the writers' cut")


func test_the_pd_steps_in_and_cuts_last_nights_episode() -> void:
	Hooks.recaps = true
	var bar := SaveStore.new_bar("Golmok Pocha", "A test tent", OWNER_DATA)
	bar["nights"] = 4
	SaveStore.record_diary(bar, {"night": 4, "episode": 4, "season": 1, "season_episode": 4, "day": "Friday", "weather": "rain", "text": "Ji-ho quit tonight.", "stamp": "rain",
		"facts": {"owner": str(OWNER_DATA["name"]), "people": [{"name": "Kim Ji-ho", "job": "nurse"}], "missing": ["Hwang Tae-oh"],
			"moments": [{"who": "Kim Ji-ho", "mood": "shock", "caption": "SHE QUIT?!", "said": "I quit today."}]}})
	SaveStore.save_bar(bar)
	Game.bar = SaveStore.load_bar(bar["id"])
	var runner := scene_runner(VISIT)
	var scene = runner.scene()
	# Stepping in while it's loading: the suite opens once it can.
	var step_in := runner.find_child("LoadingStepIn") as Button
	assert_object(step_in).is_not_null()
	step_in.text = "✂  The writers are cutting episode 10…  Step in as the PD (Enter): a much longer label than it really has"
	await await_idle_frame()
	assert_float(step_in.get_global_rect().end.x).is_less_equal(1920.0)  # (it ran off the edge, 19 Nov)
	scene._step_in()
	assert_bool(await _wait_until(func(): return runner.find_child("EditSuite") != null, 10000)).override_failure_message("the edit suite never opened").is_true()
	var suite = runner.find_child("EditSuite")
	suite.own_title.text = "Salt and Overtime"
	suite.pick_title(3)  # (your own)
	suite.pick_cliffhanger(1)  # (the game's first: will Tae-oh stay away again?)
	suite.cut()
	# "Previously on…" plays with the PD's cut, then the night starts.
	assert_bool(await _wait_until(func(): return scene._night_number == 5, 10000)).override_failure_message("the night never started after the cut").is_true()
	var transcript := (runner.find_child("Transcript") as RichTextLabel).get_parsed_text()
	assert_str(transcript).contains("The PD steps in: season 1, episode 4, \"Salt and Overtime\"").contains("Previously on… (Salt and Overtime)").contains("Will Tae-oh stay away again?")
	assert_dict(scene._cliffhanger).contains_key_value("kind", "stays_away")  # (it nudges him in, as the game's cliffhangers do)
	assert_str(str(Game.bar["diary"][-1]["title"]["english"])).is_equal("Salt and Overtime")
	assert_dict(Game.bar["diary"][-1]["cut_by"]).is_equal({"title": "pd", "cliffhanger": "pd", "scenes": "writers"})
	assert_str(scene._stats.panel_text(0, 0)).contains("Last night's episode: cut by the PD (stepped in while loading) · title the PD's · cliffhanger the PD's")
	# Until the first customer, the desk offers to cut it again; then not.
	assert_str((runner.find_child("PdDeskText") as RichTextLabel).get_parsed_text()).contains("re-cut season 1, episode 4")
	scene._arrive(scene._clock)
	assert_str((runner.find_child("PdDeskText") as RichTextLabel).get_parsed_text()).not_contains("re-cut")
	scene._step_in()  # (too late: nothing)
	assert_object(runner.find_child("EditSuite")).is_null()


func test_the_pd_chooses_the_scenes_and_it_is_rewritten() -> void:
	Hooks.recaps = true
	var bar := SaveStore.new_bar("Golmok Pocha", "A test tent", OWNER_DATA)
	bar["nights"] = 4
	SaveStore.record_diary(bar, {"night": 4, "episode": 4, "season": 1, "season_episode": 4, "day": "Friday", "weather": "rain", "text": "Ji-ho quit tonight.", "stamp": "rain",
		"facts": {"owner": str(OWNER_DATA["name"]), "people": [{"name": "Kim Ji-ho", "job": "nurse"}, {"name": "Lee Da-eun", "job": "teacher"}],
			"pinned": [{"speaker": "Kim Ji-ho", "text": "I quit today, and I'm glad.", "at": 1260}],
			"moments": [{"who": "Kim Ji-ho", "mood": "shock", "caption": "SHE QUIT?!", "said": "I quit today.", "at": 1262}],
			"happenings": [{"at": 1300, "text": "Lee Da-eun looks like becoming a regular.", "who": ["Lee Da-eun"]}, {"at": 1380, "text": "Every stool was taken.", "who": []}]}})
	SaveStore.save_bar(bar)
	Game.bar = SaveStore.load_bar(bar["id"])
	var runner := scene_runner(VISIT)
	var scene = runner.scene()
	scene._step_in()
	assert_bool(await _wait_until(func(): return runner.find_child("EditSuite") != null, 10000)).override_failure_message("the edit suite never opened").is_true()
	var suite = runner.find_child("EditSuite")
	assert_array(suite.ticked_scenes().map(func(s): return s["kind"])).is_equal(["pin"])  # (the PD's pin, ticked to start with)
	suite.tick_scene(0, false)  # (not the pin after all...)
	suite.tick_scene(2)  # (...Da-eun becoming a regular...)
	suite.tick_scene(3)  # (...and the full house)
	suite.cut()
	assert_bool(await _wait_until(func(): return scene._night_number == 5, 10000)).override_failure_message("the night never started after the cut").is_true()
	var transcript := (runner.find_child("Transcript") as RichTextLabel).get_parsed_text()
	assert_str(transcript).contains("Previously on… (She Quit?!) Lee Da-eun looks like becoming a regular. Every stool was taken.")  # (the PD's scenes, as the beats, in order)
	assert_array(Game.bar["diary"][-1]["scenes"].map(func(s): return s["text"])).is_equal(["Lee Da-eun looks like becoming a regular.", "Every stool was taken."])
	assert_str(str(Game.bar["diary"][-1]["cut_by"]["scenes"])).is_equal("pd")
	assert_dict(scene._stats.story["edit"]["rewrite"]).contains_key_value("kept", "2/2")
	assert_str(scene._stats.panel_text(0, 0)).contains("scenes the PD's (2, rewritten in").contains("kept 2/2)")


func test_the_pd_steps_in_mid_recap_and_it_plays_again() -> void:
	Hooks.recaps = true
	var bar := SaveStore.new_bar("Golmok Pocha", "A test tent", OWNER_DATA)
	bar["nights"] = 4
	SaveStore.record_diary(bar, {"night": 4, "episode": 4, "season": 1, "season_episode": 4, "day": "Friday", "weather": "rain", "text": "Ji-ho quit tonight.", "stamp": "rain",
		"facts": {"owner": str(OWNER_DATA["name"]), "people": [{"name": "Kim Ji-ho", "job": "nurse"}], "moments": [{"who": "Kim Ji-ho", "mood": "shock", "caption": "SHE QUIT?!"}]}})
	SaveStore.save_bar(bar)
	Game.bar = SaveStore.load_bar(bar["id"])
	var runner := scene_runner(VISIT)
	var scene = runner.scene()
	assert_bool(await _wait_until(func(): return scene._recap_screen != null, 10000)).override_failure_message("the recap never played").is_true()
	assert_object(runner.find_child("RecapStepIn", true, false)).is_not_null()  # (it says you can)
	assert_str(scene._recap_screen.episode_title_text()).is_equal("S1 · EP 4 · She Quit?!")  # (the writers' title)
	scene._step_in()  # (mid-recap: it stops, for the suite)
	assert_bool(await _wait_until(func(): return runner.find_child("EditSuite") != null, 10000)).override_failure_message("the edit suite never opened").is_true()
	runner.find_child("EditSuite").leave_it()
	assert_bool(await _wait_until(func(): return scene._night_number == 5, 10000)).override_failure_message("the night never started").is_true()
	assert_int((runner.find_child("Transcript") as RichTextLabel).get_parsed_text().count("Previously on… (She Quit?!)")).is_equal(1)  # (played again, in full, once)
	assert_str(scene._stats.panel_text(0, 0)).contains("Last night's episode: stepped in, then left it to the writers")


# --- Leaving and closing --------------------------------------------------------------------

func test_close_the_bar_closes_up_early_then_goes_back_to_the_title() -> void:
	var runner := await _open_visit()
	var id := str(Game.bar["id"])
	var nights := int(Game.bar.get("nights", 0))
	(runner.find_child("LeaveButton") as Button).pressed.emit()  # (top-bar buttons: see the stats test)
	# Closing up early: the night ends now, counted, with the diary page.
	var summary := runner.find_child("NightSummary") as Control
	assert_bool(await _wait_until(func(): return summary.visible)).override_failure_message("closing early never ended the night").is_true()
	assert_bool(await _wait_until(func(): return Game.bar.has("diary"))).override_failure_message("no diary entry").is_true()
	assert_int(int(Game.bar["nights"])).is_equal(nights + 1)
	var entry: Dictionary = Game.bar["diary"][-1]
	assert_str(str(entry["facts"]["closed_early"])).is_not_empty()
	assert_str(str(entry["stamp"])).is_equal("early")
	assert_str(_transcript(runner)).contains("decides to close up early tonight")
	assert_str(str(entry["facts"]["closed_said"])).is_not_empty()  # (the owner said why, and the diary has it)
	assert_object(runner.find_child("ClosedSign")).is_not_null()  # the 마감 board out front
	# Then Close the bar (on the diary page) goes back to the title, saved.
	await _click(runner, runner.find_child("SummaryLeaveButton"))
	assert_bool(await _wait_for_scene(TITLE)).override_failure_message("Close the bar didn't ask for the title scene").is_true()
	assert_bool(Game.bar.is_empty()).is_true()
	assert_bool(SaveStore.load_bar(id).is_empty()).is_false()


func test_closing_early_sees_everyone_off_first() -> void:
	var runner := await _open_visit()
	var scene = runner.scene()
	var leave := runner.find_child("LeaveButton") as Button
	Hooks.stay_minutes_override = 600  # (they stay until the test says their time's up)
	scene._arrive(scene._clock)  # someone turns up
	assert_bool(await _wait_until(func(): return not scene._guests.is_empty())).is_true()
	var guest = scene._guests[0]
	var stay: float = guest.stay_left
	leave.pressed.emit()  # (top-bar buttons: a caption can pop up over them, see the stats test)
	assert_bool(leave.disabled).is_true()  # closing up
	# No hurry for them: their night carries on as it was.
	assert_float(guest.stay_left).is_equal(stay)
	assert_bool(scene._last_orders).is_false()
	# The owner tells them why, and it's on TV.
	assert_bool(await _wait_until(func(): return scene._closing_said != "")).override_failure_message("the owner never said why").is_true()
	assert_bool(await _wait_until(func(): return guest.transcript.any(func(entry): return str(entry.get("text", "")) == scene._closing_said))).is_true()  # (once there's been time to read the last line)
	assert_int(int(scene._stats.captions.get("closing_reason", 0))).is_equal(1)
	# Nobody new: someone turning up sees the sign and walks on.
	scene._arrive(scene._clock)
	assert_array(scene._waiting).is_empty()
	assert_str(_transcript(runner)).contains("sees the 마감 sign, and walks on")
	var board := runner.find_child("ClosedSign") as Control
	assert_str(board.tooltip_text).contains("마감 magam")
	assert_bool(scene._night_open).is_true()  # (still open while they're here)
	# Their time comes: they settle up and go, and then the night ends.
	guest.stay_left = 0.0
	var summary := runner.find_child("NightSummary") as Control
	assert_bool(await _wait_until(func(): return summary.visible)).override_failure_message("the night never ended").is_true()
	assert_array(scene._guests).is_empty()
	assert_int(int(Game.bar["visits"])).is_greater(0)  # (they paid)


func test_closing_the_window_saves_the_bar() -> void:
	var saved := _saved_bar("Saebyeok Pocha", 10)
	Game.bar = SaveStore.load_bar(saved["id"])
	Game.bar["visits"] = 77
	Game.notification(NOTIFICATION_WM_CLOSE_REQUEST)
	assert_int(int(SaveStore.load_bar(saved["id"])["visits"])).is_equal(77)


func test_a_bar_saved_before_hangul_names_gets_them() -> void:
	var the_owner := OWNER_DATA.duplicate()
	the_owner.erase("hangul")
	var bar := SaveStore.new_bar("Golmok Pocha", "A test tent", the_owner)
	SaveStore.save_bar(bar)
	Game.bar = SaveStore.load_bar(bar["id"])
	await _open_visit()
	assert_str(str(Game.bar["owner"].get("hangul", ""))).is_equal("김성호")
	assert_str(str(SaveStore.load_bar(bar["id"])["owner"].get("hangul", ""))).is_equal("김성호")  # saved, so it's only asked once


func test_a_bar_saved_before_owners_had_a_life_gets_one_once() -> void:
	var bar := SaveStore.new_bar("Golmok Pocha", "A test tent", OWNER_DATA.duplicate())
	SaveStore.save_bar(bar)
	Game.bar = SaveStore.load_bar(bar["id"])
	CannedAi.scripted = [{"should": "never be used"}]  # the game picks it: no AI
	await _open_visit()
	var saved: Dictionary = SaveStore.load_bar(bar["id"])["owner"]
	assert_str(str(saved.get("family", ""))).is_not_empty()
	assert_str(str(saved.get("before", ""))).is_not_empty()
	var family := str(saved["family"])
	Game.bar = SaveStore.load_bar(bar["id"])
	await _open_visit()
	assert_str(str(SaveStore.load_bar(bar["id"])["owner"]["family"])).is_equal(family)  # kept, not picked again
	CannedAi.scripted = []


func test_a_bar_saved_before_regulars_gets_its_two_once() -> void:
	Hooks.founding_regulars = true
	var bar := _saved_bar("Golmok Pocha", 0)
	Game.bar = SaveStore.load_bar(bar["id"])
	await _open_visit()
	assert_int(SaveStore.load_bar(bar["id"])["regulars"].size()).is_equal(2)
	# Opening it again asks the AI for nobody new.
	Game.bar = SaveStore.load_bar(bar["id"])
	CannedAi.scripted = [{"should": "never be used"}]
	await _open_visit()
	assert_array(CannedAi.scripted).is_not_empty()
	assert_int(SaveStore.load_bar(bar["id"])["regulars"].size()).is_equal(2)


func test_a_bars_menu_changes_slowly() -> void:
	Hooks.bar_menus = true
	Hooks.menu_change_roll = 0.0  # (once it's been long enough: tonight)
	var bar := _saved_bar("Golmok Pocha", 0)
	var dice := RandomNumberGenerator.new()
	dice.seed = 3
	bar["menu"] = Catalogue.fallback_menu(dice)
	bar["signatures_by"] = "game"  # (none, and not to be invented: this is about the change)
	bar["nights"] = MenuChanges.EVERY  # three weeks of nights, and nobody's ordered anything
	SaveStore.save_bar(bar)
	Game.bar = SaveStore.load_bar(bar["id"])
	var runner := await _open_visit()
	var saved := SaveStore.load_bar(bar["id"])
	assert_int(saved.get("menu_changes", []).size()).is_equal(1)
	var change: Dictionary = saved["menu_changes"][0]
	var ids: Array = saved["menu"].map(func(item): return str(item["id"]))
	assert_array(ids).not_contains([change["out"]]).contains([change["in"]])
	assert_int(ids.size()).is_equal(bar["menu"].size())
	assert_str(Catalogue.layer(str(change["out"]))).is_equal("own")  # (never a classic, a staple or the owner's own)
	assert_str(str(change["by"])).is_equal("ai")
	assert_int(int(saved["menu_changed_night"])).is_equal(MenuChanges.EVERY + 1)
	assert_str(_transcript(runner)).contains("rubbed off the menu board").contains("New tonight: ")
	# Tonight's stats, highlights and diary know.
	var scene = runner.scene()
	assert_bool(await _wait_until(func(): return scene._stats != null and scene._stats.story.has("menu_change"))).is_true()
	assert_str("\n".join(PackedStringArray(scene._stats.highlights()))).contains("menu change: %s off, %s on" % [change["out"], change["in"]])
	assert_str(str(scene._diary_facts()["menu_change"].get("in", ""))).is_equal(change["in"])
	# Not again until it's been another few weeks.
	Game.bar = SaveStore.load_bar(bar["id"])
	await _open_visit()
	assert_int(SaveStore.load_bar(bar["id"])["menu_changes"].size()).is_equal(1)
