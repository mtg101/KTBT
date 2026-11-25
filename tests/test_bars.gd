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
const Channels = preload("res://scripts/rules/channels.gd")
const ShowSeasons = preload("res://scripts/rules/show_seasons.gd")
const PortraitRules = preload("res://scripts/rules/portraits.gd")
const Captions = preload("res://scripts/rules/captions.gd")
const PeopleArt = preload("res://scripts/ui/people_art.gd")
const Art = preload("res://scripts/ui/art.gd")

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



func test_title_doesnt_warm_the_model_up_offline() -> void:
	# The title screen warms Ollama's model up (Game.warm_up_ai), but not in offline mode: nothing
	# for the next night's stats, and nothing left running.
	var _runner := scene_runner(TITLE)
	assert_bool(await _wait_until(func(): return Game.get_node_or_null("WarmUp") == null, 3000)).is_true()
	assert_dict(Game.warmed).is_empty()

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


# --- Faces of their own (ai/portrait_maker.gd: here from the test's pictures, not ComfyUI) -----------

const CASTING := ["portrait_m_50s_balding_glasses_9050.png", "portrait_m_50s_balding_glasses_9051.png", "portrait_m_50s_balding_glasses_9052.png"]
const FACES_WAIT_MS := 90000  # (each picture's split takes a few seconds)


func _casting_pictures() -> Array:
	return CASTING.map(func(file): return Image.load_from_file(ProjectSettings.globalize_path("res://tests/support/portraits/" + file)))


func test_a_new_bars_owner_gets_a_face_of_their_own() -> void:
	Hooks.fake_comfy = _casting_pictures()
	Hooks.recaps = true  # (the series opener: their face beside their beat and on its card)
	var runner := await _open_visit()
	var scene = runner.scene()
	assert_bool(await _wait_until(func(): return scene._night_open, FACES_WAIT_MS)).override_failure_message("the bar never opened").is_true()
	var face: Dictionary = Game.bar["owner"].get("face", {})
	assert_dict(face).is_not_empty()
	var scores: Array = scene._casting_photos.map(func(photo): return snappedf(float(photo["score"]), 0.001))
	assert_float(float(face["score"])).is_equal(scores.min())  # (the game's pick: the cleanest split)
	assert_str(str(face["by"])).is_equal("game")
	assert_str(str(face["key"])).is_equal(PortraitRules.own_key(str(Game.bar["id"]), "owner", int(face["seed"])))
	var id := str(Game.bar["id"])
	assert_object(SaveStore.load_picture(id, str(face["file"]))).is_not_null()  # (kept with the bar: the layer, and the model's picture)
	assert_object(SaveStore.load_picture(id, str(face["picture"]))).is_not_null()
	assert_str(str(SaveStore.load_bar(id)["owner"]["face"]["key"])).is_equal(str(face["key"]))  # (saved)
	var hover = scene._owner_node.get_node("Hover")
	assert_str(hover.picked_how).is_equal("own")
	assert_str(hover.picked_key).is_equal(str(face["key"]))
	assert_int(int(scene._stats.portraits.get("own", 0))).is_equal(1)
	var panel: String = scene._stats.panel_text(0, 0)
	assert_str(panel).contains("Faces of their own: the owner's (picked by the game, score %.3f) · 3 made, 0 failed · the test's pictures" % float(face["score"]))
	assert_str(panel).contains("Portraits: their own 1 · ")
	var owner_name := str(scene._owner["name"])
	var opener: Dictionary = scene._stats.story["recap_faces"]
	assert_array(opener["card"]).is_equal([owner_name])
	assert_array(opener["beats"]).contains([owner_name])
	assert_bool(opener["own"]).is_true()
	assert_str(panel).contains("on the card 1 (of 1 kept) (the owner's own face)")
	assert_bool(scene._maker == null).override_failure_message("the image model's still held").is_true()


func test_offline_the_owner_keeps_the_librarys_face() -> void:
	Hooks.recaps = true
	var runner := await _open_visit()
	var scene = runner.scene()
	assert_bool(await _wait_until(func(): return scene._night_open)).is_true()
	assert_bool(Game.bar["owner"].has("face")).is_false()
	assert_str(scene._owner_node.get_node("Hover").picked_how).is_not_equal("own")
	assert_str(scene._stats.panel_text(0, 0)).contains("Faces of their own: the owner keeps the library's (offline: chosen in the AI settings)")
	assert_array(scene._stats.story["recap_faces"]["card"]).is_equal([str(scene._owner["name"])])  # (the series opener: the library's face, on its card)
	assert_bool(scene._stats.story["recap_faces"]["own"]).is_false()


func test_the_pd_picks_another_casting_photo_and_has_three_more_taken() -> void:
	Hooks.fake_comfy = _casting_pictures()
	var runner := scene_runner(VISIT)
	var scene = runner.scene()
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	scene._unhandled_input(enter)
	var setup = runner.find_child("ShowSetup", true, false)
	assert_object(setup).is_not_null()
	assert_str((setup.find_child("CastingNote", true, false) as Label).text).contains("once the tent's up")  # (before the photographer comes)
	assert_bool(await _wait_until(func(): return setup.find_child("CastingPhoto_2", true, false) != null and not scene._casting, FACES_WAIT_MS)).override_failure_message("no casting photos").is_true()
	assert_str((setup.find_child("CastingNote", true, false) as Label).text).contains("the game's picked")
	var picked: int = scene._casting_pick
	var other := (picked + 1) % 3
	await _click(runner, setup.find_child("CastingPhoto_%d" % other, true, false))
	assert_bool(await _wait_until(func(): return scene._casting_pick == other)).override_failure_message("the PD's pick wasn't taken").is_true()
	assert_str(str(Game.bar["owner"]["face"]["by"])).is_equal("pd")
	assert_int(int(Game.bar["owner"]["face"]["seed"])).is_equal(int(scene._casting_photos[other]["seed"]))
	var frame := setup.find_child("CastingFrame_%d" % other, true, false) as PanelContainer
	assert_int((frame.get_theme_stylebox("panel") as StyleBoxFlat).border_width_left).is_equal(5)  # (framed: the face on the show)
	var first_seeds: Array = scene._casting_photos.map(func(photo): return photo["seed"])
	await _click(runner, setup.find_child("CastingReshoot", true, false))
	assert_bool(await _wait_until(func(): return scene._casting_rounds == 2 and not scene._casting, FACES_WAIT_MS)).override_failure_message("never reshot").is_true()
	assert_array(scene._casting_photos.map(func(photo): return photo["seed"])).not_contains(first_seeds)  # (three new ones)
	assert_bool(scene._night_open).is_false()  # (the bar waits for the PD)
	await _click(runner, setup.find_child("SetupDone", true, false))
	assert_bool(await _wait_until(func(): return scene._night_open)).override_failure_message("the bar never opened").is_true()
	var panel: String = scene._stats.panel_text(0, 0)
	assert_str(panel).contains("Faces of their own: the owner's (picked by the PD").contains("6 made, 0 failed · 2 rounds")


## Faces of their own for the regulars too (the setting's "owner_and_regulars"; the test's
## pictures, and how cleanly they must split: INF any, -INF none).
func _faces_for_regulars(clean_enough: float, scene = null) -> void:
	AiSettings.override["faces"] = "owner_and_regulars"
	if scene != null:
		scene._ai.settings["faces"] = "owner_and_regulars"  # (read as the scene opened)
	Hooks.fake_comfy = _casting_pictures()
	Hooks.clean_enough = clean_enough


func test_a_new_bars_founding_regulars_get_faces_of_their_own_too() -> void:
	Hooks.founding_regulars = true
	_faces_for_regulars(INF)
	var runner := scene_runner(VISIT)  # (not _open_visit: nine photos take longer than its wait)
	var scene = runner.scene()
	assert_bool(await _wait_until(func(): return scene._night_open, FACES_WAIT_MS * 2)).override_failure_message("the bar never opened").is_true()
	var regulars: Array = Game.bar["regulars"]
	assert_int(regulars.size()).is_equal(2)
	var id := str(Game.bar["id"])
	for regular in regulars:
		var face: Dictionary = regular["face"]
		assert_str(str(face["by"])).is_equal("game")
		assert_str(str(face["key"])).is_equal(PortraitRules.own_key(id, scene._face_tag(regular), int(face["seed"])))
		assert_object(SaveStore.load_picture(id, str(face["file"]))).is_not_null()  # (kept with the bar, and the model's picture)
		assert_object(SaveStore.load_picture(id, str(face["picture"]))).is_not_null()
		assert_str(scene._own_face(regular)).is_equal(str(face["key"]))
	var saved: Dictionary = SaveStore.load_bar(id)
	assert_str(str(saved["regulars"][0]["face"]["key"])).is_equal(str(regulars[0]["face"]["key"]))  # (saved)
	assert_str(scene._stats.panel_text(0, 0)).contains("· 9 made, 0 failed · the test's pictures").contains(" · the regulars' own 2, the library's 0 (%s, %s)" % [regulars[0]["name"], regulars[1]["name"]])
	assert_bool(scene._maker == null).override_failure_message("the image model's still held").is_true()


func test_after_closing_regulars_without_a_face_get_one_or_keep_the_librarys() -> void:
	Hooks.founding_regulars = true
	var runner := await _open_visit()  # (offline: no photos as the bar's made)
	var scene = runner.scene()
	assert_bool(await _wait_until(func(): return scene._night_open)).is_true()
	assert_array(scene._regulars_without_faces()).has_size(2)
	await scene._faces_after_closing()  # (the setting's the owner's only: nothing)
	assert_bool(scene._stats.story.has("faces_after")).is_false()
	_faces_for_regulars(INF, scene)
	await scene._faces_after_closing()
	var regulars: Array = Game.bar["regulars"]
	assert_array(scene._regulars_without_faces()).is_empty()
	assert_str(str(regulars[1]["face"]["by"])).is_equal("game")
	assert_bool(scene._maker == null).override_failure_message("the image model's still held").is_true()
	assert_bool(scene._writing_up).is_false()  # (the summary page's buttons back)
	assert_str(scene._stats.panel_text(0, 0)).contains("Faces of their own after closing: the regulars' own 2, the library's 0 (%s, %s) · 6 made, 0 failed · the test's pictures" % [regulars[0]["name"], regulars[1]["name"]])
	# A regular coming in brings their face with them (the hover's their own).
	var customer := {"look": regulars[1]["look"], "face": regulars[1]["face"]}
	assert_str(scene._own_face(customer)).is_equal(str(regulars[1]["face"]["key"]))
	# None of three splitting cleanly: the library's, for good (the PD can recast them).
	regulars[1].erase("face")
	Hooks.clean_enough = -INF
	await scene._faces_after_closing()
	assert_str(str(regulars[1]["face"]["key"])).is_empty()
	assert_str(str(regulars[1]["face"]["why"])).starts_with("none split cleanly enough")
	assert_str(scene._own_face(regulars[1])).is_empty()
	assert_array(scene._regulars_without_faces()).is_empty()  # (not tried again)
	assert_str(scene._stats.panel_text(0, 0)).contains("the regulars' own 0, the library's 1 (%s (the library's))" % regulars[1]["name"])


func test_after_closing_faces_of_their_own_get_their_tv_moods() -> void:
	Hooks.founding_regulars = true
	var runner := await _open_visit()  # (offline: no photos as the bar's made)
	var scene = runner.scene()
	assert_bool(await _wait_until(func(): return scene._night_open)).is_true()
	_faces_for_regulars(INF, scene)
	Hooks.own_moods = true
	Hooks.mood_clean_enough = INF
	await scene._faces_after_closing()  # (their faces first, then the moods of both: two a gap)
	var id := str(Game.bar["id"])
	var regulars: Array = Game.bar["regulars"]
	var moods_count: int = Captions.REACTIONS.size()
	for regular in regulars:
		var face: Dictionary = regular["face"]
		var moods: Dictionary = face["moods"]
		assert_int(moods.size()).is_equal(moods_count)
		assert_str(str(moods["shock"]["file"])).is_equal("portrait_%s_%d_shock.png" % [scene._face_tag(regular), int(face["seed"])])
		assert_object(SaveStore.load_picture(id, str(moods["shock"]["file"]))).is_not_null()  # (kept with the bar)
		assert_object(PeopleArt.portrait(regular["look"], str(face["key"]), "shock")).is_not_null()
	assert_array(scene._faces_wanting_moods()).is_empty()
	assert_str(scene._stats.panel_text(0, 0)).contains("their moods: %d kept, 0 the calm face's (%s %d, %s %d)" % [moods_count * 2, regulars[0]["name"], moods_count, regulars[1]["name"], moods_count])
	assert_bool(scene._maker == null).override_failure_message("the image model's still held").is_true()
	assert_int(SaveStore.load_bar(id)["regulars"][0]["face"]["moods"].size()).is_equal(moods_count)  # (saved)
	# Their TV box is in the mood (not the calm face standing in).
	var who := str(regulars[0]["name"])
	var key := str(regulars[0]["face"]["key"])
	scene._faces_kept[who] = {"key": key, "look": regulars[0]["look"]}
	assert_str(str(scene._tv_face(who, "sad")["how"])).is_equal("mood")
	# Read back as a saved bar opens: from the bar's pictures into Art.own.
	for mood in Captions.REACTIONS:
		Art.own.erase("reaction/%s_%s" % [key, mood])
	PeopleArt.reset()
	assert_object(PeopleArt.portrait(regulars[0]["look"], key, "sad")).is_null()
	assert_str(scene._own_face(regulars[0])).is_equal(key)
	assert_bool(Art.own.has("reaction/%s_sad" % key)).is_true()
	assert_object(PeopleArt.portrait(regulars[0]["look"], key, "sad")).is_not_null()  # (the null looked up before, forgotten)
	# A mood scoring too badly: the calm face stands in, and it's tried again another night.
	(regulars[1]["face"]["moods"] as Dictionary).erase("shock")
	Art.own.erase("reaction/%s_shock" % str(regulars[1]["face"]["key"]))
	Hooks.mood_clean_enough = -INF
	await scene._faces_after_closing()
	assert_bool((regulars[1]["face"]["moods"] as Dictionary).has("shock")).is_false()
	assert_str(scene._stats.panel_text(0, 0)).contains("their moods: 0 kept, 1 the calm face's (%s 0 (1 the calm face's))" % regulars[1]["name"])
	assert_int(scene._faces_wanting_moods().size()).is_equal(1)  # (again next time)
	scene._faces_kept[str(regulars[1]["name"])] = {"key": str(regulars[1]["face"]["key"]), "look": regulars[1]["look"]}
	assert_str(str(scene._tv_face(str(regulars[1]["name"]), "shock")["how"])).is_equal("stood_in")
	# Three to do: the owner first, two a gap, the third the next night.
	var owner_face: Dictionary = (regulars[0]["face"] as Dictionary).duplicate(true)
	owner_face["key"] = PortraitRules.own_key(id, "owner", int(owner_face["seed"]))
	owner_face.erase("moods")
	scene._owner["face"] = owner_face
	Game.bar["owner"]["face"] = owner_face.duplicate(true)
	(regulars[0]["face"] as Dictionary).erase("moods")
	Hooks.mood_clean_enough = INF
	assert_int(scene._faces_wanting_moods().size()).is_equal(3)
	await scene._faces_after_closing()
	assert_int(Game.bar["owner"]["face"]["moods"].size()).is_equal(moods_count)  # (the owner first, and the bar's copy)
	assert_int(regulars[0]["face"]["moods"].size()).is_equal(moods_count)
	assert_bool((regulars[1]["face"]["moods"] as Dictionary).has("shock")).is_false()
	assert_str(scene._stats.panel_text(0, 0)).contains(", 1 still to do (")
	await scene._faces_after_closing()
	assert_bool((regulars[1]["face"]["moods"] as Dictionary).has("shock")).is_true()
	assert_array(scene._faces_wanting_moods()).is_empty()
	# A recast's a new face: its moods start again, the old ones not used.
	var recast: Dictionary = (regulars[0]["face"] as Dictionary).duplicate(true)
	recast["seed"] = int(recast["seed"]) + 1
	recast["key"] = PortraitRules.own_key(id, scene._face_tag(regulars[0]), int(recast["seed"]))
	recast.erase("moods")
	regulars[0]["face"] = recast
	assert_array(scene._moods_wanting(recast)).has_size(moods_count)
	assert_object(PeopleArt.portrait(regulars[0]["look"], str(recast["key"]), "sad")).is_null()
	assert_int(scene._faces_wanting_moods().size()).is_equal(1)


func test_the_pd_recasts_a_regulars_face_at_3am() -> void:
	Hooks.founding_regulars = true
	var runner := await _open_visit()
	var scene = runner.scene()
	assert_bool(await _wait_until(func(): return scene._night_open)).is_true()
	var button := runner.find_child("RecastButton", true, false) as Button
	scene._night_written = true
	scene._update_recast_button()
	assert_bool(button.visible).is_false()  # (offline, and the owner's only)
	_faces_for_regulars(INF, scene)
	scene._update_recast_button()
	assert_bool(button.visible).is_true()
	scene._open_recast()
	var recast = runner.find_child("RecastScreen", true, false)
	assert_object(recast).is_not_null()
	var regular: Dictionary = Game.bar["regulars"][0]
	await _click(runner, recast.find_child("RecastRegular_0", true, false))
	assert_str(str((recast.find_child("RecastNote", true, false) as Label).text)).contains("taking %s's photos" % regular["name"])
	assert_bool((recast.find_child("RecastDone", true, false) as Button).disabled).is_true()  # (not while they're being taken)
	assert_bool(await _wait_until(func(): return recast.find_child("RecastPhoto_2", true, false) != null and not scene._recast_shooting, FACES_WAIT_MS)).override_failure_message("no photos").is_true()
	assert_bool(regular.has("face")).is_false()  # (none picked yet: theirs as it was)
	await _click(runner, recast.find_child("RecastPhoto_1", true, false))
	assert_bool(await _wait_until(func(): return regular.has("face"))).override_failure_message("the PD's pick wasn't taken").is_true()
	assert_str(str(regular["face"]["by"])).is_equal("pd")
	assert_int(int(regular["face"]["seed"])).is_equal(int(scene._recast_photos[1]["seed"]))
	assert_int(((recast.find_child("RecastFrame_1", true, false) as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat).border_width_left).is_equal(5)  # (framed)
	await _click(runner, recast.find_child("RecastDone", true, false))
	assert_bool(await _wait_until(func(): return scene._maker == null and scene._before_night.has("faces_recast"))).override_failure_message("never closed").is_true()
	assert_str(NightStats.recast_text(scene._before_night["faces_recast"])).starts_with("Faces recast by the PD before tonight: 1 round of photos, new faces for %s · 3 made, 0 failed · the test's pictures" % regular["name"])


func test_a_new_bar_gets_its_niece_or_nephew_and_its_stream() -> void:
	Hooks.channels = true  # (the AI names them: here, the canned AI)
	var runner := await _open_visit()
	var scene = runner.scene()
	var the_show: Dictionary = Game.bar["show"]
	var relative: Dictionary = the_show["pd"]
	assert_str(Channels.validate_relative(relative.duplicate())).is_empty()
	assert_array(["niece", "nephew"]).contains([str(relative["relation"])])
	assert_str(str(relative["gender"])).is_equal(Channels.gender_of(str(relative["relation"])))
	assert_str(str(the_show["channel"]["english"])).is_equal("@" + str(relative["handle"]))  # (the phone stream: their own handle)
	assert_str(str(the_show["channel"]["rung"])).is_equal("phone")
	var transcript := (runner.find_child("Transcript") as RichTextLabel).get_parsed_text()
	assert_str(transcript).contains("Behind the camera: %s" % relative["name"]).contains("@" + str(relative["handle"]))
	assert_str(scene._on_air_text()).is_equal("on a phone stream (@%s)" % relative["handle"])
	assert_bool(await _wait_until(func(): return scene._night_open)).is_true()
	assert_str(scene._stats.panel_text(0, 0)).contains("On air: on a phone stream (@%s) · filmed by %s" % [relative["handle"], Channels.camera_crew(the_show).trim_suffix(",")])
	assert_str(scene._camera.crew).is_equal(Channels.camera_crew(the_show))  # (the camera's moments say who's filming)
	assert_str(str(scene._stats.story["relative"]["by"])).is_equal("ai")  # (asked the AI: here, the canned one)
	assert_str(str(SaveStore.load_bar(str(Game.bar["id"]))["show"]["pd"]["name"])).is_equal(str(relative["name"]))  # (saved)


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


const ONLINE_POST := {"about": "cat_theft", "poster": "Kim Ji-ho", "handle": "ji-ho_eats", "shot": "cat", "text": "The tent cat just stole my odeng. Respect.",
	"tags": ["#tentcat"], "at": 1350, "mood": "funny", "dish": "Odeng", "dish_id": "", "snap": "", "face": {}}
const ONLINE_BOARD := {"rung": "phone", "place": "live", "crowd": "130 watching", "figure": "11.4K",
	"comments": [{"viewer": "night_owl", "about": "ratings", "who": "", "mood": "", "dish": "", "said": "", "likes": 12, "text": "11.4K for a tent bar?!", "by": "game"}]}


## Last night with a post (and, if asked, the viewers' comments) kept with its diary entry.
func _bar_with_posts(comments: bool) -> void:
	var bar := SaveStore.new_bar("Golmok Pocha", "A test tent", OWNER_DATA)
	bar["nights"] = 4
	SaveStore.record_diary(bar, {"night": 4, "episode": 4, "season": 1, "season_episode": 4, "day": "Friday", "weather": "rain", "text": "Ji-ho quit tonight.", "stamp": "rain",
		"facts": {"owner": str(OWNER_DATA["name"]), "people": [{"name": "Kim Ji-ho", "job": "nurse"}], "moments": [{"who": "Kim Ji-ho", "mood": "shock", "caption": "SHE QUIT?!", "at": 1262}]},
		"socials": [ONLINE_POST.duplicate(true)], "viewers": ONLINE_BOARD.duplicate(true) if comments else {}})
	SaveStore.save_bar(bar)
	Game.bar = SaveStore.load_bar(bar["id"])


func test_the_writers_recap_ends_on_last_nights_post() -> void:
	Hooks.recaps = true
	Hooks.online_roll = 0.0  # (whenever there's one)
	_bar_with_posts(false)
	var runner := scene_runner(VISIT)
	var scene = runner.scene()
	assert_bool(await _wait_until(func(): return scene._night_number == 5, 10000)).override_failure_message("the night never started after the recap").is_true()
	var transcript := (runner.find_child("Transcript") as RichTextLabel).get_parsed_text()
	assert_str(transcript).contains("And then Ji-ho posted it for the internet to see…")
	assert_str(str(scene._stats.story.get("recap_online", ""))).is_equal("post ji-ho_eats")
	assert_str(scene._stats.panel_text(0, 0)).contains("cut to the internet: post ji-ho_eats")


func test_the_pd_cuts_to_a_viewers_comment() -> void:
	Hooks.recaps = true
	_bar_with_posts(true)
	var runner := scene_runner(VISIT)
	var scene = runner.scene()
	scene._step_in()
	assert_bool(await _wait_until(func(): return runner.find_child("EditSuite") != null, 10000)).override_failure_message("the edit suite never opened").is_true()
	var suite = runner.find_child("EditSuite")
	assert_array(suite._scenes.map(func(s): return s["kind"])).is_equal(["moment", "post", "comment"])
	suite.tick_scene(2)  # (the comment)
	suite.cut()
	assert_bool(await _wait_until(func(): return scene._night_number == 5, 10000)).override_failure_message("the night never started after the cut").is_true()
	assert_str((runner.find_child("Transcript") as RichTextLabel).get_parsed_text()).contains("And the internet had opinions…")
	assert_str(str(Game.bar["diary"][-1]["scenes"][0]["kind"])).is_equal("comment")
	assert_str(str(scene._stats.story.get("recap_online", ""))).is_equal("comment night_owl")
	assert_str(scene._stats.panel_text(0, 0)).contains("online: comment 1)")


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


func test_close_the_bar_at_3am_waits_for_the_faces_after_closing_regression() -> void:
	Hooks.founding_regulars = true
	var runner := await _open_visit()  # (offline: no photos as the bar's made)
	var scene = runner.scene()
	var id := str(Game.bar["id"])
	_faces_for_regulars(INF, scene)
	Hooks.own_moods = true
	Hooks.mood_clean_enough = INF
	(runner.find_child("LeaveButton") as Button).pressed.emit()  # (closing up early, to get to 3am)
	var summary := runner.find_child("NightSummary") as Control
	assert_bool(await _wait_until(func(): return summary.visible)).override_failure_message("closing early never ended the night").is_true()
	# Close the bar while tonight's still being written up and the faces made: it waits (25 Nov: it
	# shut the bar, ComfyUI stopped three seconds in, nothing made and nothing said).
	var leave := runner.find_child("SummaryLeaveButton") as Button
	assert_bool(scene._night_written).is_false()
	leave.pressed.emit()
	assert_bool(scene._leave_requested).is_true()
	assert_bool(leave.disabled).is_true()
	assert_str(leave.text).is_equal("Closing up after...")
	assert_str(str(Game.requested_scene)).is_not_equal(TITLE)
	assert_bool(await _wait_until(func(): return Game.requested_scene == TITLE, FACES_WAIT_MS)).override_failure_message("never went back to the title").is_true()
	var saved: Dictionary = SaveStore.load_bar(id)
	for regular in saved["regulars"]:
		assert_int((regular["face"]["moods"] as Dictionary).size()).is_equal(Captions.REACTIONS.size())  # (made, then closed)


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
