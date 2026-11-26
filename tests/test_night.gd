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
const Captions = preload("res://scripts/rules/captions.gd")
const Socials = preload("res://scripts/rules/socials.gd")
const Viewers = preload("res://scripts/rules/viewers.gd")

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


func test_the_night_s_biggest_moment_gets_an_end_card_and_the_diary_its_polaroids() -> void:
	var runner := await _open_bar()
	var scene = runner.scene()
	scene._arrive(scene._clock)
	assert_bool(await _wait_until(func(): return scene._guests.size() == 1 and scene._guests[0].node.get_node_or_null("Hover") != null \
		and scene._guests[0].node.get_node("Hover").picked_key != "")).is_true()
	var who := str(scene._guests[0].customer["name"])
	var owner_name := str(Game.bar["owner"]["name"])
	var lines := [{"speaker": who, "text": "I quit my job today."}, {"speaker": owner_name, "text": "You did what?"}]
	scene._air_moment(0, [{"mood": "warm", "caption": "SMALL WIN"}], {"who": owner_name, "topic": "", "size": 4}, lines, [who, owner_name], 0.0)
	scene._air_moment(0, [{"mood": "shock", "caption": "THEY QUIT?!"}], {"who": who, "topic": "", "size": 5}, lines, [who, owner_name], 0.0)
	var aired: Array = scene._events.of_kind("big_moment")
	assert_int(int(aired[-1]["size"])).is_equal(5)
	assert_array(Captions.REACTIONS["shock"]["hangul"]).contains([str(aired[-1]["hangul"])])  # (the words it aired with, for the card)
	assert_bool(await _wait_for_summary(runner)).is_true()
	assert_bool(await _wait_until(func(): return Game.bar.has("diary"))).is_true()
	# The card: their moment again, though they'd long gone home (the face kept from tonight).
	assert_str(str(scene._stats.keepsakes.get("end_card", ""))).is_equal("%s, shock (size 5)" % who)
	assert_str(_transcript(runner)).contains("THEY QUIT?!")
	var entry: Dictionary = Game.bar["diary"][0]
	assert_str(str(entry["photos"][0]["name"])).is_equal(who)
	assert_str(str(entry["photos"][0]["mood"])).is_equal("shock")
	assert_bool(entry["faces"].has(who) and entry["faces"].has(owner_name)).is_true()  # (everyone tonight's, for the diary book)
	assert_int(int(entry["facts"]["moments"][-1]["size"])).is_equal(5)
	assert_str(str(runner.find_child("DiaryPage").photo_names()[0])).is_equal(who)
	assert_int(int(scene._stats.keepsakes["polaroids"])).is_equal(entry["photos"].size())
	assert_str(scene._stats.panel_text(0, 0)).contains("Keepsakes: end card %s" % who)
	# Kept with the bar: the diary book shows them too.
	assert_str(str(SaveStore.load_bar(str(Game.bar["id"]))["diary"][0]["photos"][0]["name"])).is_equal(who)


func test_the_customers_post_about_their_night_round_the_diary_page() -> void:
	Hooks.cat_wanders = false
	Hooks.socials = true  # (offline: the canned AI answers with the game's own words)
	var runner := await _open_bar()
	var scene = runner.scene()
	scene._arrive(scene._clock)
	assert_bool(await _wait_until(func(): return scene._guests.size() == 1 and scene._guests[0].node.get_node_or_null("Hover") != null \
		and scene._guests[0].node.get_node("Hover").picked_key != "")).is_true()
	var guest = scene._guests[0]
	var who := str(guest.customer["name"])
	guest.served.append("odeng")
	scene._add_dish(guest, "odeng")
	scene._cat_steals(guest)
	var stole: Dictionary = scene._events.of_kind("cat_stole")[-1]
	assert_int(int(scene._snaps.counts["asked"])).is_greater_equal(1)  # (a snapshot wanted of the cat mid-theft)
	# Headless, there's no screen to take it from: one stands in, as if there were.
	var shot := Image.create(300, 200, false, Image.FORMAT_RGBA8)
	shot.fill(Color("e8833a"))
	scene._snaps.shots[Socials.snap_key(stole)] = shot
	assert_bool(await _wait_for_summary(runner)).is_true()
	var feed = runner.find_child("SocialFeed")
	assert_bool(await _wait_until(func(): return Game.bar.has("diary") and feed.visible)).is_true()
	var entry: Dictionary = Game.bar["diary"][0]
	var theft: Array = entry["socials"].filter(func(p): return p["about"] == "cat_theft")
	assert_int(theft.size()).is_equal(1)
	assert_str(str(theft[0]["poster"])).is_equal(who)
	assert_str(str(theft[0]["text"])).contains(str(Game.bar["cat"]["name"]))
	assert_str(str(theft[0]["picture"])).is_not_empty()
	assert_bool(theft[0].has("snap") or theft[0].has("what")).is_false()  # (only what's kept)
	assert_str(str(theft[0]["by"])).is_equal("game")
	assert_str(scene._stats.panel_text(0, 0)).contains("words: AI 0, game %d" % int(scene._stats.socials["picked"]))
	assert_object(SaveStore.load_picture(str(Game.bar["id"]), str(theft[0]["picture"]))).is_not_null()
	assert_array(feed.posters()).contains([who])
	assert_array(feed.pictures()).contains(["snapshot"])
	assert_str(scene._stats.panel_text(0, 0)).contains("Socials: posts %d" % entry["socials"].size())
	assert_str(_transcript(runner)).contains("On 달밤 Dalbam tonight")
	# The viewers comment on the episode, where the show's rung has them: the game's words, offline.
	var board: Dictionary = entry["viewers"]
	assert_str(str(board["rung"])).is_equal(str(entry["ratings"]["rung"]))
	assert_int(board["comments"].size()).is_greater_equal(Viewers.FEWEST)
	assert_str(str(board["comments"][0]["about"])).is_equal("ratings")
	assert_bool(board["comments"].any(func(c): return c["about"] == "cat_theft")).is_true()
	assert_int(feed.comment_count()).is_equal(board["comments"].size())
	assert_str(scene._stats.panel_text(0, 0)).contains("viewer comments %d (words: AI 0, game %d)" % [board["comments"].size(), board["comments"].size()])
	assert_str(_transcript(runner)).contains("Viewers, %s" % Viewers.place_of(str(board["rung"]))["hangul"])
	# Kept with the bar, for the diary book.
	assert_array(SaveStore.load_bar(str(Game.bar["id"]))["diary"][0]["socials"].map(func(p): return p["poster"])).contains([who])
	# The stats up in the page's place: the posts come down with it, and back.
	scene._on_summary_stats_toggled(true)
	assert_bool(feed.visible).is_false()
	scene._on_summary_stats_toggled(false)
	assert_bool(feed.visible).is_true()


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
	batch.from_command_line = true  # (as tools/autoplay.bat starts it: it quits when it's done)
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
	# The finale's row has its title too (regression: 20 Nov, its titles were drafted only after the page).
	var finale_title := Story.title_text(Game.bar["diary"][-1].get("title", {}))
	assert_str(finale_title).is_not_empty()
	var looked_back := _transcript(runner)
	assert_str(looked_back.substr(looked_back.find("EP 8 "), 20 + finale_title.length())).contains("«%s»" % finale_title)
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
	assert_str(_transcript(runner)).contains("Your show's been picked up by an online video channel, 포차로그 (Pocha Log)! Season 2 starts tonight").contains("Season 2, episode 1 of 8  ·  on an online video channel")
	assert_str(str(scene._stats.story["show"]["moved"])).contains("picked up by an online video channel")
	# Booked on a channel of its own (the game's name here: the AI's off in tests), kept with its history.
	var channel: Dictionary = Game.bar["show"]["channel"]
	assert_str(str(channel["rung"])).is_equal("video")
	assert_str(str(channel["english"])).is_equal("Pocha Log")
	assert_int(int(channel["from_season"])).is_equal(2)
	assert_array(Game.bar["show"]["channels"].map(func(c): return str(c["rung"]))).is_equal(["phone", "video"])  # (the stream, then the channel)
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


func test_the_side_panel_has_the_show_and_the_diary_and_the_esc_menu_the_options() -> void:
	Hooks.run_clock = false
	var runner := await _open_bar()
	var scene = runner.scene()
	var menu := runner.find_child("OptionsPanel") as Control
	assert_bool(menu.visible).is_false()
	# The Esc menu: closing up, and the options (no tabs: the diary and the show are in the side panel).
	assert_bool(menu.is_ancestor_of(runner.find_child("LeaveButton"))).is_true()
	assert_bool(menu.is_ancestor_of(runner.find_child("SoundToggle", true, false))).is_true()
	assert_object(runner.find_child("MenuTabs", true, false)).is_null()
	assert_str((runner.find_child("OptionsButton") as Button).text).contains("Menu (Esc)")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	scene._unhandled_input(esc)
	assert_bool(menu.visible).is_true()
	# As other games' Esc menus: the screen dimmed, the menu in the middle, Commands (Resume,
	# Close the bar, the crew's row, Quit game, in that order) then the Options in groups.
	var dim := runner.find_child("MenuDim") as Control
	assert_bool(dim.visible).is_true()
	assert_float(menu.position.x + menu.size.x / 2).is_equal_approx(scene.SCREEN.x / 2, 1.0)
	var commands := runner.find_child("Commands", true, false) as Control
	var order: Array = [runner.find_child("MenuClose"), runner.find_child("LeaveButton"), runner.find_child("CrewRow"), runner.find_child("QuitButton")]
	for i in order.size():
		assert_bool(commands.is_ancestor_of(order[i])).override_failure_message("%s isn't in Commands" % order[i].name).is_true()
		if i > 0:
			assert_bool(order[i].is_greater_than(order[i - 1])).override_failure_message("%s comes before %s" % [order[i].name, order[i - 1].name]).is_true()
	assert_bool(runner.find_child("ScreenOptions", true, false).is_ancestor_of(runner.find_child("BubblesToggle", true, false))).is_true()
	assert_bool(runner.find_child("SoundOptions", true, false).is_ancestor_of(runner.find_child("MusicToggle", true, false))).is_true()
	assert_int(scene._stats.esc_menu).is_equal(1)  # (counted)
	scene._unhandled_input(esc)  # Esc again: closed
	assert_bool(menu.visible).is_false()
	assert_bool(dim.visible).is_false()
	scene._unhandled_input(esc)
	var outside := InputEventMouseButton.new()  # a click outside the menu closes it too
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	dim.gui_input.emit(outside)
	assert_bool(menu.visible).is_false()
	# The top bar's numbers: a short hover, and a click opens the whole story in the side panel's The show.
	scene._update_ratings()
	var numbers := runner.find_child("RatingsLabel") as Label
	var hover := numbers.tooltip_text.replace("\n", " ")
	assert_str(hover).contains("To move on:").contains("1,000+ views a night").contains("Click for the whole story.").not_contains("johoesu")
	var click := InputEventMouseButton.new()  # (a click on a label: _click is for buttons)
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	numbers.gui_input.emit(click)
	var side := runner.find_child("StatsText") as RichTextLabel
	assert_str(scene._stats_view.tab).is_equal("THE SHOW")
	var relative: Dictionary = Game.bar["show"]["pd"]
	assert_str(side.get_parsed_text()).contains("BEHIND THE CAMERA").contains(str(relative["name"])).contains("@" + str(relative["handle"]))  # (the niece or nephew, easy to see)
	assert_str(side.get_parsed_text()).contains("ON AIR").contains("MOVING ON").contains(Ladder.rule("phone")).contains("This season:").contains("TONIGHT").contains("WHERE IT'S BEEN")
	# The diary: the side panel's tab pops the book up, full size.
	await _click(runner, runner.find_child("PanelTab_DIARY", true, false))
	assert_object(runner.find_child("DiaryBook", true, false)).is_not_null()
	# The transcript's text at the side panel's size (it scrolled by too fast).
	assert_int((runner.find_child("Transcript") as RichTextLabel).get_theme_font_size("normal_font_size")).is_equal(15)
