extends "res://tests/support/bar_test.gd"
## Click-through tests for a full night: the clock runs on its own, customers arrive without
## anyone clicking, and at 3am the night ends with a summary and a save. Offline mode, with
## pauses (and so the clock) sped right up, so a whole night takes a few seconds.

const Visit = preload("res://scripts/visit.gd")
const AiSettings = preload("res://scripts/ai/ai_settings.gd")
const CannedAi = preload("res://scripts/ai/canned_ai.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")
const NightStats = preload("res://scripts/bar/night_stats.gd")
const Story = preload("res://scripts/rules/story.gd")
const Autoplay = preload("res://scripts/autoplay.gd")
const Ratings = preload("res://scripts/rules/ratings.gd")
const ShowSeasons = preload("res://scripts/rules/show_seasons.gd")
const Ladder = preload("res://scripts/rules/ladder.gd")

const SCENE := "res://scenes/visit.tscn"
const TITLE := "res://scenes/title.tscn"
const TEST_SAVES := "user://test_saves_night/"
const NIGHT_TIMEOUT_MS := 60000
const TEST_TRANSCRIPTS := "user://test_transcripts_night/"
const TEST_STATS := "user://test_stats_night/"
const TEST_AUTOPLAY := "user://test_autoplay_night/"


func _setup() -> void:
	Hooks.random_seed = 2468
	Hooks.run_clock = true  # whole nights, by themselves


# --- Helpers ---------------------------------------------------------------------------

func _open_bar() -> GdUnitSceneRunner:
	var runner := scene_runner(SCENE)
	var scene = runner.scene()
	var open: bool = await _wait_until(func(): return scene._night_open)
	assert_bool(open).override_failure_message("the night never started").is_true()
	return runner


func _wait_for_summary(runner: GdUnitSceneRunner) -> bool:
	var summary := runner.find_child("NightSummary") as Control
	return await _wait_until(func(): return summary.visible, NIGHT_TIMEOUT_MS)


# --- Tests -------------------------------------------------------------------------------

func test_the_first_night_starts_at_six() -> void:
	Hooks.run_clock = false  # hold the clock at opening time
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
	# The ratings so far, in the top bar, as things happen (the final one's at 3am).
	assert_str((runner.find_child("RatingsLabel") as Label).text).starts_with("조회수 views ").ends_with(" so far  ·  phone stream")  # (a new bar's show: a phone stream, in views)


func test_someone_turning_up_mid_night_is_served() -> void:
	Hooks.run_clock = false
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
	assert_str(summary).contains(Ladder.text(float(scene._night_ratings["rating"]), "phone"))  # (a new bar's on the phone stream: views and likes)
	assert_str(summary).contains("on a phone stream")
	assert_str(summary).contains("Season 1, episode 1 of 8")  # (the show's first season)
	assert_bool((runner.find_child("SeasonButton") as Control).visible).is_false()  # (not a finale)
	assert_str(_transcript(runner)).contains("pulls down the tarp")
	assert_array(scene._guests).is_empty()


func test_the_night_ends_with_the_owners_diary() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	assert_bool(await _wait_for_summary(runner)).is_true()
	var page = runner.find_child("DiaryPage")  # (untyped: it has its own methods)
	assert_bool(await _wait_until(func(): return Game.bar.has("diary"))).override_failure_message("no diary entry").is_true()
	assert_bool(page.visible).is_true()
	assert_str((page.find_child("Episode", true, false) as Label).text).is_equal("S1 · EP 1")
	var entry: Dictionary = Game.bar["diary"][0]
	assert_str(page.entry_text()).is_equal(str(entry["text"]))
	assert_str(str(entry["by"])).is_equal("game")  # (diaries off: the game writes it)
	assert_int(int(entry["facts"]["customers"])).is_equal(scene._night_visits)  # kept for "Previously on…"
	assert_bool(Story.DIARY_STAMPS.has(str(entry["stamp"]))).is_true()
	# The episode's TV ratings, kept with it and shown by the owner's name, with its hover.
	assert_float(float(entry["ratings"]["rating"])).is_greater(0.0)
	assert_str(str(entry["ratings"]["rung"])).is_equal("phone")  # (kept with the episode, so it's always shown in its rung's units)
	assert_str(page.ratings_text()).starts_with(Ladder.label(float(entry["ratings"]["rating"]), "phone"))
	assert_str((page.find_child("Ratings", true, false) as Label).tooltip_text.replace("\n", " ")).contains("johoesu").contains("phone stream")  # (Text.tip wraps it)
	# And in the top bar, all night: so far, then tonight's (its own section in the stats too).
	var beside := runner.find_child("RatingsLabel") as Label
	assert_str(beside.text).is_equal("%s  ·  phone stream" % Ladder.label(float(entry["ratings"]["rating"]), "phone"))  # (and which rung, in English)
	assert_str(beside.tooltip_text.replace("\n", " ")).contains("views")
	assert_str(scene._stats.panel_text(0, 0)).contains("[b]RATINGS[/b]\nTonight: %.1f%%" % float(entry["ratings"]["rating"])).contains("Shown as: %s on a phone stream" % Ladder.text(float(entry["ratings"]["rating"]), "phone"))
	assert_int(SaveStore.load_bar(str(Game.bar["id"]))["diary"].size()).is_equal(1)
	# The header keeps to its rows, however long the title (regression: 19 Nov, a long title ran over the day).
	var titled := entry.duplicate(true)
	titled["title"] = {"hangul": "그늘에 피어나는 슬픔", "english": "Sadness that Blooms in the Shade, and Everything After It"}
	titled["weather"] = "crisp and clear, a bitterly cold wind"  # (regression: 20 Nov, the weather was always cut short)
	titled["day"] = "Wednesday"
	titled["ratings"]["banner"] = Ladder.VIEWS_HIT_HANGUL
	page.show_entry(titled, "Kim Sung-jin's diary")
	await get_tree().process_frame
	var pill := page.find_child("EpisodePill", true, false) as Control
	var day := page.find_child("Day", true, false) as Control
	assert_str((page.find_child("Episode", true, false) as Label).text).starts_with("S1 · EP 1 · 그늘에 피어나는 슬픔")
	assert_float(pill.position.x + pill.size.x).is_less_equal(page.size.x - 20.0)  # (never past the page)
	assert_float(pill.position.y + pill.size.y).is_less_equal(day.position.y)  # (above the day, not over it)
	var day_label := day as Label
	assert_float(day_label.get_theme_font("font").get_string_size(day_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, day_label.get_theme_font_size("font_size")).x) \
		.override_failure_message("the weather's cut short: %s" % day_label.text).is_less_equal(day_label.size.x)
	var whose := page.find_child("Whose", true, false) as Control
	var ratings := page.find_child("Ratings", true, false) as Control
	assert_float(whose.position.y).is_greater_equal(day.position.y + day.size.y)
	assert_float(ratings.position.y).is_greater_equal(day.position.y + day.size.y)  # (beside whose diary it is, under the day)
	assert_float(whose.position.x + whose.size.x).is_less_equal(ratings.position.x)
	assert_float(ratings.position.x + ratings.size.x).is_less_equal(page.size.x - 20.0)
	assert_str(page.ratings_text()).contains("떡상! blown up")  # (the banner's English beside it)
	page.show_entry(entry, "Kim Sung-jin's diary")
	# The numbers are behind the Stats button.
	var numbers := runner.find_child("SummaryText") as Control
	assert_bool(numbers.visible).is_false()
	await _click(runner, runner.find_child("SummaryStatsButton"))
	assert_bool(numbers.visible).is_true()
	assert_bool(page.visible).is_false()
	assert_float((runner.find_child("NightSummary") as Control).size.y).is_less(1080.0)  # the buttons still on screen
	await _click(runner, runner.find_child("SummaryStatsButton"))  # now says "Diary": back to the page
	assert_bool(page.visible).is_true()
	assert_bool(numbers.visible).is_false()


func test_the_ai_writes_the_diary_when_it_can() -> void:
	Hooks.diaries = true
	var runner := await _open_bar()
	assert_bool(await _wait_for_summary(runner)).is_true()
	assert_bool(await _wait_until(func(): return Game.bar.has("diary"))).is_true()
	assert_str(str(Game.bar["diary"][0]["by"])).is_equal("owner")  # (the canned AI, here)


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
	assert_bool(entry.has("takings")).is_false()  # (not kept: the ratings are the score, 19 Nov)
	assert_float(float(entry["ratings"])).is_equal_approx(float(scene._night_ratings["rating"]), 0.001)  # (for the next nights' nudge)
	assert_str(str(scene._stats.story["ratings_text"])).starts_with("%.1f%%" % float(entry["ratings"]))
	assert_int(int(entry["season"])).is_equal(1)  # (its place in the show's seasons)
	assert_int(int(entry["season_episode"])).is_equal(1)
	assert_int(int(saved["show"]["aired"])).is_equal(1)
	assert_array(saved["show"]["nights"].map(func(n): return int(n))).is_equal([1])


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
	# The night's timeline, event by event, for looking back over a night.
	var paid: Array = data["events"].filter(func(e): return str(e["kind"]) == "paid")
	assert_int(paid.size()).is_equal(scene._night_visits)
	assert_bool(data["events"].any(func(e): return str(e["kind"]) == "sat_down" and e.has("at"))).is_true()


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
	Hooks.run_clock = false  # hold the night, so it's still going when we look
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
	Hooks.run_clock = false  # hold night two at opening time
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
	Hooks.run_clock = false
	var runner := await _open_bar()
	assert_str(_transcript(runner)).contains("Night 4")
	assert_str((runner.find_child("MomentLabel") as Label).text).contains("Thursday")


func test_autoplay_plays_its_nights_then_stops() -> void:
	Autoplay.folder = TEST_AUTOPLAY
	var batch := Autoplay.new(2)
	batch.pause_seconds = 0.0
	Game.autoplay = batch
	var first := await _open_bar()
	# After the first night, it opens the saved bar again, as the next day does ("Previously on…").
	var reopened: bool = await _wait_until(func(): return Game.requested_scene == Game.VISIT_SCENE, NIGHT_TIMEOUT_MS)
	assert_bool(reopened).override_failure_message("the bar was never opened again for night 2").is_true()
	# The autopilot PD was at the desk (what it plays depends on the hand: see test_visit.gd).
	assert_object(first.scene()._autopilot).is_not_null()
	assert_dict(first.scene()._stats.autopilot).is_not_empty()
	assert_bool(bool(Game.bar.get("autoplay", false))).is_true()  # (its own bar, marked as such, and saved so)
	assert_bool(FileAccess.file_exists(Autoplay.running_path())).is_true()  # (it says it's running...)
	var runner := await _open_bar()  # (the scene the game asked for: tests don't switch scenes themselves)
	var scene = runner.scene()
	assert_int(scene._night_number).is_equal(2)
	var quit: bool = await _wait_until(func(): return Game.requested_scene == "quit", NIGHT_TIMEOUT_MS)
	assert_bool(quit).override_failure_message("it didn't stop after its two nights").is_true()
	assert_int(batch.played.size()).is_equal(2)
	assert_bool(FileAccess.file_exists(Autoplay.running_path())).is_false()  # (...until it's done)
	assert_str(_transcript(runner)).contains("Night 2")
	var summaries := DirAccess.get_files_at(TEST_AUTOPLAY)
	assert_int(summaries.size()).is_equal(1)
	assert_str(FileAccess.get_file_as_string(TEST_AUTOPLAY + summaries[0])).contains("2 of 2 nights played, all done").contains("Night 2: ")
	Game.autoplay = null
	Autoplay.folder = ""
	for file_name in summaries:
		DirAccess.remove_absolute(TEST_AUTOPLAY + file_name)


func test_the_eighth_episode_is_the_finale_and_the_season_is_looked_back_on() -> void:
	var bar := SaveStore.new_bar("Mi-sook-ne Pocha", "Mi-sook's place", {"name": "Park Mi-sook", "hangul": "박미숙", "age": 61, "gender": "woman", "title": "Ajumma", "archetype": "gruff-but-soft ajumma", "appearance": "Apron.", "personality": "blunt", "speech_style": "short", "secret": "Trot singer."})
	bar["nights"] = 7
	bar["show"] = {"season": 1, "aired": 7, "nights": [1, 2, 3, 4, 5, 6, 7], "ratings": [6.0, 7.0, 6.5, 8.0, 5.5, 7.5, 6.0], "seasons": []}
	SaveStore.save_bar(bar)
	Game.bar = SaveStore.load_bar(bar["id"])
	var runner := await _open_bar()
	var scene = runner.scene()
	assert_str(_transcript(runner)).contains("Season 1, episode 8 of 8, the finale").contains("Tonight's the finale of season 1")
	assert_str((runner.find_child("MomentLabel") as Label).text).contains("S1 · EP 8/8 · FINALE")
	assert_bool(await _wait_for_summary(runner)).is_true()
	var page = runner.find_child("SeasonPage")  # (untyped: it has its own methods)
	assert_bool(await _wait_until(func(): return page.visible)).override_failure_message("the season was never looked back on").is_true()
	assert_bool((runner.find_child("DiaryPage") as Control).visible).is_false()
	assert_int(page.rows_shown()).is_equal(8)
	# Nothing runs off its row, however long the line pinned (regression: 19 Nov, a long line ran off the page).
	var long_line := {"speaker": "Choi Woo-jin", "text": "But it's not just about perfection, is it, Samchon? Today I had to deal with a department head who doesn't understand what I'm trying to do, and an email that made everything worse."}
	page.show_season([{"episode": 1, "night": 1, "title": "스트레스의 무게 · The Weight of Stress and Everything That Comes With It", "rating": 5.5, "quote": long_line},
		{"episode": 2, "night": 2, "title": "", "rating": 1.1, "quote": {}}], Game.bar["show"]["seasons"][0], "Doldol Pocha")
	await get_tree().process_frame
	var quotes: Array = []
	for row in (page.find_child("SeasonRows", true, false) as Control).get_children():
		if row.is_queued_for_deletion():
			continue
		for label in row.find_children("*", "Label", true, false):
			assert_float((label as Label).position.x + (label as Label).size.x).override_failure_message("%s runs off its row: %s" % [label.name, (label as Label).text]) \
				.is_less_equal((row as Control).size.x)
		quotes.append((row.find_child("Quote", true, false) as Label).text)
	assert_str(str(quotes[0])).starts_with("“But it's not just").ends_with("— Choi Woo-jin")
	# The verdict: kept with the season, and the next one begins.
	var the_show: Dictionary = Game.bar["show"]
	assert_int(int(the_show["season"])).is_equal(2)
	assert_int(int(the_show["aired"])).is_equal(0)
	assert_array(the_show["seasons"]).has_size(1)
	var judged: Dictionary = the_show["seasons"][0]
	assert_array(judged["nights"]).is_equal([1, 2, 3, 4, 5, 6, 7, 8])
	assert_bool(ShowSeasons.OUTCOMES.has(str(judged["outcome"]))).is_true()
	assert_str(page.verdict_text()).is_equal("%s  %s" % [judged["stamp"], judged["words"]])
	assert_str((page.find_child("SeasonVerdict", true, false) as Label).tooltip_text.replace("\n", " ")).contains("average ratings")  # (its hover: how it was decided)
	assert_bool(SaveStore.load_bar(str(Game.bar["id"]))["show"]["seasons"].size() == 1).is_true()  # (saved)
	assert_bool(bool(Game.bar["diary"][-1]["finale"])).is_true()
	# Logged, counted, and in the summary.
	assert_str(_transcript(runner)).contains("That's season 1.").contains("Season 1, looked back on: EP 1 6.0%")
	assert_str(scene._stats.panel_text(0, 0)).contains("Season: Season 1, episode 8 of 8, the finale · on network · the season before tonight: average 6.6%").contains("· Season 1: average")
	assert_str((runner.find_child("SummaryText") as RichTextLabel).get_parsed_text()).contains(str(judged["words"]))
	# The button beside Stats flips back to the diary, and to the season again; Stats still works.
	var button := runner.find_child("SeasonButton") as Button
	assert_bool(button.visible).is_true()
	await _click(runner, button)
	assert_bool((runner.find_child("DiaryPage") as Control).visible).is_true()
	assert_bool(page.visible).is_false()
	await _click(runner, button)
	assert_bool(page.visible).is_true()
	await _click(runner, runner.find_child("SummaryStatsButton"))
	assert_bool(page.visible).is_false()
	await _click(runner, runner.find_child("SummaryStatsButton"))
	assert_bool(page.visible).is_true()
	# The next night's the new season's first.
	Hooks.run_clock = false
	await _click(runner, runner.find_child("NextNightButton"))
	assert_bool(await _wait_until(func(): return scene._night_number == 9)).is_true()
	assert_str(_transcript(runner)).contains("Season 2, episode 1 of 8")
	assert_bool(page.visible).is_false()


func test_a_good_season_on_the_phone_stream_moves_the_show_up_a_rung() -> void:
	var bar := SaveStore.new_bar("Mi-sook-ne Pocha", "Mi-sook's place", {"name": "Park Mi-sook", "hangul": "박미숙", "age": 61, "gender": "woman", "title": "Ajumma", "archetype": "gruff-but-soft ajumma", "appearance": "Apron.", "personality": "blunt", "speech_style": "short", "secret": "Trot singer."})
	bar["nights"] = 7
	bar["show"] = {"season": 1, "rung": "phone", "aired": 7, "nights": [1, 2, 3, 4, 5, 6, 7], "ratings": [11.0, 11.5, 10.0, 12.0, 11.0, 10.5, 11.0], "seasons": []}
	SaveStore.save_bar(bar)
	Game.bar = SaveStore.load_bar(bar["id"])
	var runner := await _open_bar()
	var scene = runner.scene()
	assert_str(_transcript(runner)).contains("on a phone stream").contains("at 3am, the audience decides")
	assert_bool(await _wait_for_summary(runner)).is_true()
	var page = runner.find_child("SeasonPage")
	assert_bool(await _wait_until(func(): return page.visible)).is_true()
	var judged: Dictionary = Game.bar["show"]["seasons"][0]
	assert_str(str(judged["outcome"])).is_equal("up")
	assert_str(ShowSeasons.rung_of(Game.bar["show"])).is_equal("video")
	assert_str(page.verdict_text()).contains("views a night! The show's got its own online video channel")
	assert_str((page.find_child("SeasonSub", true, false) as Label).text).contains("A PHONE STREAM")  # (the season's numbers in its rung's units)
	# The next night: the new season, on the video channel, said in plain words.
	Hooks.run_clock = false
	await _click(runner, runner.find_child("NextNightButton"))
	assert_bool(await _wait_until(func(): return scene._night_number == 9)).is_true()
	assert_str(_transcript(runner)).contains("Your show's been picked up by an online video channel! Season 2 starts tonight").contains("Season 2, episode 1 of 8  ·  on an online video channel")
	assert_str(str(scene._stats.story["show"]["moved"])).contains("picked up by an online video channel")
	assert_int(int(Game.bar["show"].get("subscribers", 0))).is_equal(0)  # (none yet: the channel's first episode is tonight)
	assert_str(scene._stats.panel_text(0, 0)).contains("· on video · Your show's been picked up")


func test_a_night_on_the_online_video_channel_adds_to_its_subscribers() -> void:
	var bar := SaveStore.new_bar("Mi-sook-ne Pocha", "Mi-sook's place", {"name": "Park Mi-sook", "hangul": "박미숙", "age": 61, "gender": "woman", "title": "Ajumma", "archetype": "gruff-but-soft ajumma", "appearance": "Apron.", "personality": "blunt", "speech_style": "short", "secret": "Trot singer."})
	bar["show"]["rung"] = "video"
	bar["show"]["subscribers"] = 1000
	SaveStore.save_bar(bar)
	Game.bar = SaveStore.load_bar(bar["id"])
	var runner := await _open_bar()
	var scene = runner.scene()
	assert_bool(await _wait_for_summary(runner)).is_true()
	assert_bool(await _wait_until(func(): return Game.bar.has("diary"))).is_true()
	var rating := float(scene._night_ratings["rating"])
	var total := Ladder.subscribers_after(1000, rating, "video")
	assert_int(int(Game.bar["show"]["subscribers"])).is_equal(total)  # (the channel's total: won and lost, episode by episode)
	assert_int(int(Game.bar["diary"][-1]["ratings"]["subscribers"])).is_equal(total)  # (kept with the episode)
	assert_str((runner.find_child("SummaryText") as RichTextLabel).get_parsed_text()).contains(Ladder.text(rating, "video", total))
	assert_str(runner.find_child("DiaryPage").ratings_text()).starts_with(Ladder.label(rating, "video", total))
	assert_str((runner.find_child("RatingsLabel") as Label).text).is_equal("%s  ·  online video channel" % Ladder.label(rating, "video", total))
	assert_int(int(SaveStore.load_bar(str(Game.bar["id"]))["show"]["subscribers"])).is_equal(total)  # (saved)


func test_the_esc_menu_has_tabs_for_the_options_and_the_diary_and_an_action_to_close_up() -> void:
	Hooks.run_clock = false
	var runner := await _open_bar()
	var scene = runner.scene()
	var menu := runner.find_child("OptionsPanel") as Control
	assert_bool(menu.visible).is_false()
	# The top bar's just the one button; closing up is an action in the menu.
	assert_bool(menu.is_ancestor_of(runner.find_child("LeaveButton"))).is_true()
	assert_object(runner.find_child("DiaryButton", true, false)).is_null()
	assert_str((runner.find_child("OptionsButton") as Button).text).contains("Menu (Esc)")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	scene._unhandled_input(esc)
	assert_bool(menu.visible).is_true()
	var tabs := runner.find_child("MenuTabs") as TabContainer
	assert_array(range(tabs.get_tab_count()).map(func(k): return tabs.get_tab_title(k))).is_equal(["⚙ Options", "📖 Diary"])  # (the options first)
	assert_bool(tabs.is_ancestor_of(runner.find_child("SoundToggle", true, false))).is_true()
	assert_bool(tabs.is_ancestor_of(runner.find_child("DiaryBook", true, false))).is_true()  # (the book itself, in its tab)
	scene._unhandled_input(esc)  # Esc again: closed
	assert_bool(menu.visible).is_false()
	scene._open_diary()  # the diary: the menu, on its tab
	assert_bool(menu.visible).is_true()
	assert_int(tabs.current_tab).is_equal(scene.MENU_DIARY)
	await _click(runner, runner.find_child("MenuClose"))
	assert_bool(menu.visible).is_false()
	# The ladder's rules are on the ratings' hover in the top bar: how to move on, and how it's going.
	scene._update_ratings()
	var hover := (runner.find_child("RatingsLabel") as Label).tooltip_text.replace("\n", " ")
	assert_str(hover).contains("Moving on:").contains("1,000+ views a night").contains("This season:")
	# The transcript's text at the side panel's size (it scrolled by too fast).
	assert_int((runner.find_child("Transcript") as RichTextLabel).get_theme_font_size("normal_font_size")).is_equal(15)
