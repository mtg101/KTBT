extends GdUnitTestSuite
## Tests for the internet in "Previously on…" and the edit suite: last night's posts and viewers'
## comments as the PD's scenes (scripts/rules/story.gd scene_options, post_scene, comment_scene),
## the writers' cut ending on one (online_pick, the recap's check and the game's own recap), the
## recap prompt (scripts/ai/prompts.gd), the cards on the recap screen (scripts/ui/recap_screen.gd)
## and the suite's list (scripts/ui/edit_suite.gd).

const Story = preload("res://scripts/rules/story.gd")
const Socials = preload("res://scripts/rules/socials.gd")
const Prompts = preload("res://scripts/ai/prompts.gd")
const RecapScreen = preload("res://scripts/ui/recap_screen.gd")
const EditSuite = preload("res://scripts/ui/edit_suite.gd")
const Glossary = preload("res://scripts/rules/glossary.gd")

const POST := {"about": "cat_theft", "poster": "Kim Ji-ho", "handle": "ji-ho_eats", "shot": "cat", "text": "The tent cat just stole my odeng. Respect.",
	"tags": ["#tentcat", "#고양이"], "at": 1350, "mood": "funny", "dish": "Odeng", "dish_id": "", "snap": "", "face": {}}
const BOARD := {"rung": "phone", "place": "live", "crowd": "130 watching", "figure": "11.4K",
	"comments": [{"viewer": "night_owl", "about": "ratings", "who": "", "mood": "", "dish": "", "said": "", "likes": 12, "text": "11.4K for a tent bar?! ㅋㅋㅋ", "by": "game"},
		{"viewer": "soju_mom", "about": "new_regular", "who": "Da-eun", "mood": "", "dish": "", "said": "", "likes": 7, "text": "Da-eun's a regular now, I called it", "by": "game"}]}
const FACTS := {"owner": "Park Mi-sook", "people": [{"name": "Kim Ji-ho"}, {"name": "Lee Da-eun"}],
	"pinned": [{"speaker": "Kim Ji-ho", "text": "I quit today, and I'm glad.", "at": 1260}],
	"happenings": [{"at": 1300, "text": "Lee Da-eun looks like becoming a regular.", "who": ["Lee Da-eun"]}], "missing": ["Hwang Tae-oh"]}


func _entry() -> Dictionary:
	return {"night": 4, "facts": FACTS.duplicate(true), "socials": [POST.duplicate(true)], "viewers": BOARD.duplicate(true)}


func test_posts_and_comments_are_scenes_in_the_order_they_happened() -> void:
	var scenes := Story.scene_options(FACTS, [POST], BOARD)
	assert_array(scenes.map(func(s): return s["kind"])).is_equal(["pin", "happened", "post", "comment", "comment", "happened"])  # (comments at 3am, then who didn't come)
	var post: Dictionary = scenes[2]
	assert_int(int(post["at"])).is_equal(1350)
	assert_array(post["who"]).is_equal(["Kim Ji-ho"])
	assert_str(str(post["text"])).is_equal("ji-ho_eats on 달밤 Dalbam (a photo of the cat): «The tent cat just stole my odeng. Respect.» #tentcat #고양이")
	var comment: Dictionary = scenes[3]
	assert_str(str(comment["when"])).is_equal("3am")
	assert_str(str(comment["text"])).is_equal("night_owl in the 실시간 채팅 live chat (♥ 12): «11.4K for a tent bar?! ㅋㅋㅋ»")
	assert_array(scenes[4]["who"]).is_equal(["Da-eun"])
	assert_array(Story.board_of(comment)["comments"].map(func(c): return c["viewer"])).is_equal(["night_owl"])  # (on its own)
	assert_str(Story.online_counts(scenes)).is_equal("post 1, comment 2")
	# An entry from before the posts: just the night.
	assert_array(Story.scene_options(FACTS).map(func(s): return s["kind"])).is_equal(["pin", "happened", "happened"])


func test_the_writers_end_on_a_post_or_comment_now_and_then() -> void:
	var entry := _entry()
	assert_str(str(Story.online_pick(entry, 0.0, 0)["kind"])).is_equal("post")
	assert_str(str(Story.online_pick(entry, 0.0, 2)["comment"]["viewer"])).is_equal("soju_mom")
	assert_dict(Story.online_pick(entry, Story.ONLINE_CHANCE, 0)).is_empty()  # (not every night)
	assert_dict(Story.online_pick({"facts": FACTS}, 0.0, 0)).is_empty()  # (nothing went online)
	entry["facts"]["pinned"] = [{"speaker": "A", "text": "a"}, {"speaker": "B", "text": "b"}, {"speaker": "C", "text": "c"}]
	assert_dict(Story.online_pick(entry, 0.0, 0)).is_empty()  # (three pins: the beats are those)


func test_the_recap_checks_its_last_beat_cuts_to_it() -> void:
	var post := Story.post_scene(POST)
	var comment := Story.comment_scene(BOARD, BOARD["comments"][0])
	var facts := {"episode": 5, "owner": "Park Mi-sook", "names": ["Park Mi-sook", "Kim Ji-ho", "Lee Da-eun", "Hwang Tae-oh"], "last": FACTS, "online": post}
	assert_str(Story.validate_recap({"beats": ["Ji-ho quits.", "Da-eun stays."], "teaser": "Will she?"}, facts)).contains("cut to what went online")
	assert_str(Story.validate_recap({"beats": ["Ji-ho quits.", "Then Ji-ho told the internet."], "teaser": "Will she?"}, facts)).is_empty()
	facts["online"] = comment
	assert_str(Story.validate_recap({"beats": ["Ji-ho quits.", "And the internet had opinions…"], "teaser": "Will she?"}, facts)).is_empty()
	assert_str(Story.validate_recap({"beats": ["Ji-ho quits.", "Da-eun stays."], "teaser": "Will she?"}, facts)).contains("cut to what went online")
	# The game's own recap ends on it, and passes.
	var stitched := Story.stitched_recap(facts)
	assert_str(str(stitched["beats"][-1])).is_equal("And the internet had opinions…")
	assert_str(Story.validate_recap(stitched, facts)).is_empty()
	facts["online"] = post
	assert_str(str(Story.stitched_recap(facts)["beats"][-1])).is_equal("And then Ji-ho posted it for the internet to see…")
	# Each beat's card: the writers' last, or the PD's that are posts or comments.
	assert_array(Story.online_beats(["a", "b", "c"], [], post).map(func(o): return str(o.get("kind", "")))).is_equal(["", "", "post"])
	assert_array(Story.online_beats(["a", "b"], [Story.scene_options(FACTS)[0], comment], {}).map(func(o): return str(o.get("kind", "")))).is_equal(["", "comment"])
	assert_array(Story.online_beats(["a", "b"], [], {}).map(func(o): return str(o.get("kind", "")))).is_equal(["", ""])


func test_the_pds_post_and_comment_scenes_keep_to_their_beats() -> void:
	var chosen := [Story.post_scene(POST), Story.comment_scene(BOARD, BOARD["comments"][1])]
	assert_str(Story.scenes_problem(["Ji-ho's odeng went viral.", "Viewers saw Da-eun coming."], chosen)).is_empty()
	assert_str(Story.scenes_problem(["The rain falls.", "Viewers saw it coming."], chosen)).contains("beat 1")
	assert_array(Story.scene_beats(chosen)).is_equal(["And then Ji-ho posted it for the internet to see…", "And the internet had opinions…"])
	assert_str(Story.scenes_problem(Story.scene_beats(chosen), chosen)).is_empty()
	assert_str(Story.scene_text(chosen[0])).contains("ji-ho_eats on 달밤 Dalbam")


func test_the_recap_prompt_asks_for_the_cut_to_the_internet() -> void:
	var facts := {"episode": 5, "bar": "Golmok Pocha", "owner": "Park Mi-sook", "last": {"owner": "Park Mi-sook"}, "online": Story.comment_scene(BOARD, BOARD["comments"][0])}
	var request := str(Prompts.recap_messages(facts)[1]["content"])
	assert_str(request).contains("end on what the internet said").contains("night_owl in the 실시간 채팅 live chat")
	facts["last"] = FACTS
	assert_str(str(Prompts.recap_messages(facts)[1]["content"])).contains("make the beats those moments, one each, in order. Then, as K-TV does")
	facts.erase("online")
	assert_str(str(Prompts.recap_messages(facts)[1]["content"])).not_contains("the internet")


func test_previously_on_slams_on_the_post_and_the_comment_beside_their_beats() -> void:
	var screen := RecapScreen.new()
	screen.time_scale = 0.05
	add_child(screen)
	var online := [{}, Story.post_scene(POST), Story.comment_scene(BOARD, BOARD["comments"][0])]
	screen.play(["Ji-ho quits.", "And then Ji-ho posted it for the internet to see…", "And the internet had opinions, a very long beat to make sure it wraps beside the card…"],
		"Will she come back?", 5, "Golmok Pocha", false,
		{"people": {"Kim Ji-ho": "김지호"}, "faces": {}, "online": online, "bar_id": "test", "place": {"season": 1, "episode": 5}})
	assert_bool(await _wait(func(): return screen.find_child("RecapOnlineTitle", true, false) != null)).is_true()
	var title := screen.find_child("RecapOnlineTitle", true, false) as Label
	assert_str(title.tooltip_text).contains("netizens react")  # (its Korean on hover)
	await screen.finished
	assert_array(screen.online_shown).is_equal(["post ji-ho_eats", "comment night_owl"])
	assert_int(screen.online_rects.size()).is_equal(2)
	for pair in screen.online_rects:  # each card on screen, clear of its beat
		var card: Rect2 = pair[0]
		var beat: Rect2 = pair[1]
		assert_bool(Rect2(0, 0, 1920, 1080).encloses(card)).override_failure_message("a card off screen: %s" % card).is_true()
		assert_bool(card.intersects(beat)).override_failure_message("a card %s over its beat %s" % [card, beat]).is_false()
		assert_float(card.position.y).is_greater(title.position.y)


func test_the_suite_lists_posts_and_comments_with_their_korean_on_hover() -> void:
	var suite := EditSuite.new()
	add_child(suite)
	var cuts: Array = []
	suite.finished.connect(func(cut): cuts.append(cut))
	suite.open("season 1, episode 4", [{"hangul": "", "english": "Salt and Overtime"}], "Will she?", [], Story.scene_options(FACTS, [POST], BOARD), {})
	var post := suite.find_child("Scene2", true, false) as CheckBox
	var comment := suite.find_child("Scene3", true, false) as CheckBox
	assert_str(post.text).starts_with("10:30pm · 📱 ji-ho_eats on 달밤 Dalbam")
	assert_str(comment.text).starts_with("3am · 💬 night_owl")
	assert_str(post.tooltip_text).contains("달밤").contains("고양이")
	assert_str(comment.tooltip_text).contains("실시간 채팅").contains("ㅋㅋㅋ")
	suite.tick_scene(0, false)
	suite.tick_scene(3)
	assert_array(suite.ticked_scenes().map(func(s): return s["kind"])).is_equal(["comment"])
	suite.cut()
	assert_array(cuts[0]["scenes"].map(func(s): return s["comment"]["viewer"])).is_equal(["night_owl"])
	suite.queue_free()


func _wait(condition: Callable, timeout_ms := 3000) -> bool:
	var start := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec() - start > timeout_ms:
			return false
		await get_tree().process_frame
	return true
