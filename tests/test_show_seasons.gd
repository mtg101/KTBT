extends GdUnitTestSuite
## Tests for scripts/rules/show_seasons.gd: the show's seasons of eight episodes, the finale,
## the season looked back on, and the channel's verdict.

const ShowSeasons = preload("res://scripts/rules/show_seasons.gd")
const Ratings = preload("res://scripts/rules/ratings.gd")
const Hangul = preload("res://scripts/rules/hangul.gd")


func _season(ratings: Array, start_night: int = 1) -> Dictionary:
	var the_show := ShowSeasons.fresh()
	for k in ratings.size():
		ShowSeasons.record(the_show, start_night + k, float(ratings[k]))
	return the_show


func test_a_season_is_eight_episodes_and_the_eighth_is_the_finale() -> void:
	var the_show := ShowSeasons.fresh()
	var first := ShowSeasons.tonight(the_show)
	assert_int(int(first["season"])).is_equal(1)
	assert_int(int(first["episode"])).is_equal(1)
	assert_bool(bool(first["finale"])).is_false()
	assert_str(ShowSeasons.label(first)).is_equal("Season 1, episode 1 of 8")
	assert_str(ShowSeasons.short_label(first)).is_equal("S1 · EP 1/8")
	for night in range(1, ShowSeasons.EPISODES):
		assert_bool(ShowSeasons.record(the_show, night, 6.0)).is_false()
	var last := ShowSeasons.tonight(the_show)
	assert_int(int(last["episode"])).is_equal(8)
	assert_bool(bool(last["finale"])).is_true()
	assert_str(ShowSeasons.label(last)).is_equal("Season 1, episode 8 of 8, the finale")
	assert_str(ShowSeasons.short_label(last)).ends_with("FINALE")
	assert_bool(ShowSeasons.record(the_show, 8, 7.0)).is_true()  # (the finale's aired: the season's over)
	assert_array(the_show["nights"]).is_equal([1, 2, 3, 4, 5, 6, 7, 8])
	var saved := {"aired": 1, "nights": [1.0]}  # (as a save's JSON gives it back)
	ShowSeasons.record(saved, 2, 6.0)
	assert_array(saved["nights"]).is_equal([1, 2])
	assert_str(ShowSeasons.so_far(the_show)).is_equal("average 6.1%, best 7.0% (8 aired)")
	assert_str(ShowSeasons.so_far(ShowSeasons.fresh())).is_equal("")


func test_the_verdict_comes_from_the_average_with_a_bonus_for_a_best_or_a_hit() -> void:
	var ordinary := ShowSeasons.verdict(1, [6.0, 7.0, 6.0, 7.0, 6.0, 7.0, 6.0, 7.0], [8.0, 9.0], [])
	assert_float(float(ordinary["average"])).is_equal_approx(6.5, 0.001)
	assert_bool(bool(ordinary["record"])).is_false()
	assert_bool(bool(ordinary["hit"])).is_false()
	assert_str(str(ordinary["outcome"])).is_equal("stay")
	assert_str(str(ordinary["words"])).is_equal("Renewed for season 2.")
	# A new best some night, and a hit: both count, on top of the average.
	var good := ShowSeasons.verdict(2, [9.0, 9.0, 9.0, 12.0, 9.0, 9.0, 9.0, 9.0], [8.0, 9.0], [ordinary])
	assert_bool(bool(good["record"])).is_true()
	assert_bool(bool(good["hit"])).is_true()
	assert_float(float(good["score"])).is_equal_approx(float(good["average"]) + ShowSeasons.RECORD_BONUS + ShowSeasons.HIT_BONUS, 0.001)
	assert_str(str(good["outcome"])).is_equal("up")
	assert_str(str(good["words"])).contains("season 3")
	# The first season's first nights aren't new bests (a couple of rated nights first, as the banner).
	var first := ShowSeasons.verdict(1, [5.0, 6.0, 9.0], [], [])
	assert_bool(bool(first["record"])).is_true()  # (the third night beat the two before it)
	assert_bool(ShowSeasons.verdict(1, [5.0, 4.0], [], [])["record"]).is_false()


func test_a_bad_season_is_a_warning_and_two_in_a_row_down() -> void:
	var quiet := [3.0, 4.0, 3.5, 4.0, 3.0, 4.5, 3.0, 4.0]
	var first := ShowSeasons.verdict(1, quiet, [], [])
	assert_str(str(first["outcome"])).is_equal("warned")
	var second := ShowSeasons.verdict(2, quiet, quiet, [first])
	assert_str(str(second["outcome"])).is_equal("down")
	# After a good season in between, a bad one's a warning again.
	assert_str(str(ShowSeasons.verdict(3, quiet, quiet, [first, {"outcome": "stay"}])["outcome"])).is_equal("warned")
	# Down, then another bad season: a warning first again (it's a new start).
	assert_str(str(ShowSeasons.verdict(3, quiet, quiet, [first, second])["outcome"])).is_equal("warned")


func test_a_season_ending_keeps_its_verdict_and_starts_the_next() -> void:
	var the_show := _season([6.0, 7.0, 6.0, 7.0, 6.0, 7.0, 6.0, 7.0], 11)
	var judged := ShowSeasons.verdict(1, the_show["ratings"], [], [])
	ShowSeasons.end_season(the_show, judged)
	assert_int(int(the_show["season"])).is_equal(2)
	assert_int(int(the_show["aired"])).is_equal(0)
	assert_array(the_show["nights"]).is_empty()
	assert_array(the_show["seasons"]).has_size(1)
	assert_array(the_show["seasons"][0]["nights"]).is_equal([11, 12, 13, 14, 15, 16, 17, 18])
	assert_str(str(the_show["seasons"][0]["outcome"])).is_equal("stay")
	assert_int(int(ShowSeasons.tonight(the_show)["episode"])).is_equal(1)
	assert_int(int(ShowSeasons.tonight(the_show)["season"])).is_equal(2)


func test_the_season_looked_back_on_from_the_diary() -> void:
	var diary := [
		{"night": 4, "title": {"hangul": "소주 한 잔", "english": "One Glass of Soju"}, "facts": {"pinned": [{"speaker": "Kim Ji-ho", "text": "Just one more."}], "line": {"speaker": "Imo", "text": "Go home."}}},
		{"night": 5, "titles": [{"hangul": "", "english": "Rain on the Tarp"}], "facts": {"line": {"speaker": "Lee Ho-jin", "text": "It never stops."}}},
		{"night": 6, "facts": {}},
	]
	var rows := ShowSeasons.recap_rows([4, 5, 6], [6.2, 8.1, 5.0], diary)
	assert_array(rows).has_size(3)
	assert_int(int(rows[0]["episode"])).is_equal(1)
	assert_str(str(rows[0]["title"])).is_equal("소주 한 잔 · One Glass of Soju")  # (as cut)
	assert_str(str(rows[0]["quote"]["text"])).is_equal("Just one more.")  # (the pinned line beats the night's)
	assert_str(str(rows[1]["title"])).is_equal("Rain on the Tarp")  # (not cut yet: the writers' first draft)
	assert_str(str(rows[1]["quote"]["speaker"])).is_equal("Lee Ho-jin")
	assert_float(float(rows[1]["rating"])).is_equal_approx(8.1, 0.001)
	assert_str(str(rows[2]["title"])).is_equal("")
	assert_dict(rows[2]["quote"]).is_empty()


func test_the_verdicts_hangul_and_hover_explain_themselves() -> void:
	for outcome in ShowSeasons.OUTCOMES:
		assert_bool(Hangul.MEANINGS.has(str(ShowSeasons.OUTCOMES[outcome]["stamp"]))).override_failure_message(outcome).is_true()
	assert_bool(Hangul.MEANINGS.has(ShowSeasons.FINALE_HANGUL)).is_true()
	assert_bool(Hangul.MEANINGS.has(ShowSeasons.LOOKED_BACK_HANGUL)).is_true()
	var judged := ShowSeasons.verdict(1, [9.0, 9.0, 12.0], [8.0, 9.0], [])
	var hover := ShowSeasons.hover(judged)
	assert_str(hover).contains("average ratings 10.0%")
	assert_str(hover).contains("new best")
	assert_str(hover).contains("a hit")
	assert_str(ShowSeasons.log_text(judged)).is_equal("Season 1: average 10.0%, best 12.0% (a new best, a hit) = 11.0: up (대박 시즌!)")


func test_episodes_are_only_ever_numbered_within_their_season() -> void:
	var place := ShowSeasons.of({"night": 22, "episode": 22, "season": 3, "season_episode": 6})
	assert_dict(place).is_equal({"season": 3, "episode": 6})
	assert_str(ShowSeasons.tag(place)).is_equal("S3 · EP 6")
	assert_str(ShowSeasons.words(place)).is_equal("season 3, episode 6")
	assert_str(ShowSeasons.hangul(place)).is_equal("시즌 3 · 제6화")
	# A night from before seasons is a pilot, never a running count.
	var pilot := ShowSeasons.of({"night": 12, "episode": 12})
	assert_dict(pilot).is_empty()
	assert_str(ShowSeasons.tag(pilot)).is_equal("PILOT")
	assert_str(ShowSeasons.words(pilot)).is_equal("a pilot episode")
	assert_str(ShowSeasons.hangul(pilot)).is_equal("파일럿")
	assert_bool(Hangul.MEANINGS.has(ShowSeasons.PILOT_HANGUL)).is_true()
	assert_str(ShowSeasons.tag(ShowSeasons.tonight({"season": 2, "aired": 3}))).is_equal("S2 · EP 4")
