extends GdUnitTestSuite
## Tests for the customers' posts: scripts/rules/socials.gd (which posts a night gets, their
## words, the check), scripts/bar/snapshots.gd (the crop, and no screen to take it from), the
## pictures kept beside the save (scripts/save/save_store.gd), and the posts on screen
## (scripts/ui/social_post.gd, scripts/ui/social_feed.gd, the diary book's).

const Socials = preload("res://scripts/rules/socials.gd")
const Snapshots = preload("res://scripts/bar/snapshots.gd")
const SaveStore = preload("res://scripts/save/save_store.gd")
const SocialPost = preload("res://scripts/ui/social_post.gd")
const SocialFeed = preload("res://scripts/ui/social_feed.gd")
const DiaryBook = preload("res://scripts/ui/diary_book.gd")
const NightStats = preload("res://scripts/bar/night_stats.gd")
const CannedAi = preload("res://scripts/ai/canned_ai.gd")
const Glossary = preload("res://scripts/rules/glossary.gd")
const Prompts = preload("res://scripts/ai/prompts.gd")

const TEST_FOLDER := "user://test_saves_socials/"
const STUDENT := {"age_range": "20s", "hair": "long", "hair_colour": "black", "clothes": "hoodie", "colour": "charcoal", "glasses": true, "skin": 2}
const FACE := {"key": "w_20s_long_glasses", "look": STUDENT}
const OWNER := "Park Mi-sook"
const CAT := "Nabi"

var _real_folder := ""


func before_test() -> void:
	_real_folder = SaveStore.folder
	SaveStore.folder = TEST_FOLDER
	SaveStore.delete_bar("bar1")


func after_test() -> void:
	SaveStore.delete_bar("bar1")
	SaveStore.folder = _real_folder


func _dice(seed_value := 7) -> RandomNumberGenerator:
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	return dice


func _faces(names: Array) -> Dictionary:
	var faces := {OWNER: FACE}
	for person in names:
		faces[person] = FACE
	return faces


func _info(names: Array, taken: Array = []) -> Dictionary:
	return {"owner": OWNER, "cat": CAT, "faces": _faces(names), "taken_cards": taken, "seats": 5}


func _sat(who: String, at: int, seated := 1) -> Dictionary:
	return {"kind": "sat_down", "at": at, "name": who, "seated": seated}


func _served(who: String, at: int, dish := "Tteokbokki", wait := 10.0, food_served := 1) -> Dictionary:
	return {"kind": "dish_served", "at": at, "name": who, "dish": dish, "wait": wait, "food_served": food_served}


func _facts(posts: Array, served: Dictionary = {}) -> Dictionary:
	var posters: Array = posts.map(func(p): return str(p["poster"]))
	return {"posters": posters, "served": served, "known": posters + [OWNER, CAT]}


# --- Which posts a night gets ------------------------------------------------------------------

func test_a_night_with_things_happening_gets_three_posts_one_a_poster_in_order() -> void:
	var events := [_sat("Kim Ji-ho", 1100), _sat("Lee Do-yun", 1110), _sat("Choi Ha-eun", 1120),
		{"kind": "big_moment", "at": 1200, "who": "Ji-ho", "mood": "shock", "size": 5},
		{"kind": "big_moment", "at": 1210, "who": OWNER, "mood": "warm", "size": 5},  # (never the owner's)
		{"kind": "cat_stole", "at": 1300, "name": "Lee Do-yun", "cat": CAT, "dish": "Odeng"},
		{"kind": "became_regular", "at": 1400, "name": "Choi Ha-eun"},
		{"kind": "cat_stole", "at": 1500, "name": "Lee Do-yun", "cat": CAT, "dish": "Odeng"}]  # (one post a poster)
	var posts := Socials.pick(events, _info(["Kim Ji-ho", "Lee Do-yun", "Choi Ha-eun"]), _dice())
	assert_array(posts.map(func(p): return p["about"])).is_equal(["moment", "cat_theft", "new_regular"])  # (by when it happened)
	assert_array(posts.map(func(p): return p["poster"])).is_equal(["Kim Ji-ho", "Lee Do-yun", "Choi Ha-eun"])  # (a given name: their full one)
	assert_array(posts.map(func(p): return p["shot"])).is_equal(["selfie", "cat", "selfie"])
	assert_str(str(posts[0]["face"]["mood"])).is_equal("shock")  # (a moment's selfie: in its mood)
	assert_str(str(posts[2]["face"]["mood"])).is_equal("calm")
	assert_str(str(posts[1]["text"])).contains(CAT)
	assert_str(str(posts[1]["snap"])).is_equal("cat_stole@1300:Lee Do-yun")
	for post in posts:
		assert_str(Socials.check(post, _facts(posts, {"Lee Do-yun": ["Odeng"]}))).is_empty()


func test_a_quiet_night_gets_a_quiet_feed() -> void:
	assert_array(Socials.pick([], _info([]), _dice())).is_empty()
	var quiet := [_sat("Kim Ji-ho", 1100), _served("Kim Ji-ho", 1130), _sat("Lee Do-yun", 1200), _served("Lee Do-yun", 1230, "Ramyeon")]
	var seen := {}
	for k in 20:
		var posts := Socials.pick(quiet, _info(["Kim Ji-ho", "Lee Do-yun"]), _dice(k))
		assert_int(posts.size()).is_less_equal(1)  # (a food pic at most)
		seen[posts.size()] = true
		for post in posts:
			assert_str(str(post["about"])).is_equal("food")
			assert_str(str(post["dish_id"])).is_not_empty()
	assert_bool(seen.has(0) and seen.has(1)).is_true()  # (some quiet nights none, some a food pic)


func test_snow_full_house_long_waits_and_cards_taken_up() -> void:
	var events := [_sat("Kim Ji-ho", 1100, 1), {"kind": "left", "at": 1150, "name": "Kim Ji-ho"}, _sat("Lee Do-yun", 1160, 4),
		_sat("Choi Ha-eun", 1170, 5), {"kind": "first_snow", "at": 1180},
		_served("Han Seo-yeon", 1190, "Tteokbokki", 60.0),
		{"kind": "plant_played", "at": 1195, "card": "ppl", "name": "Kim Ji-ho"}]
	var posts := Socials.pick(events, _info(["Kim Ji-ho", "Lee Do-yun", "Choi Ha-eun", "Han Seo-yeon"], ["ppl"]), _dice(3))
	var about := {}
	for post in posts:
		about[post["about"]] = post
	assert_int(posts.size()).is_equal(3)
	assert_bool(about.has("first_snow") and about.has("long_wait")).is_true()  # (worth more than the full house and the card)
	assert_array(["Lee Do-yun", "Choi Ha-eun"]).contains([about["first_snow"]["poster"]])  # (someone in when it snowed: not who'd gone)
	assert_str(str(about["first_snow"]["shot"])).is_equal("text")
	assert_str(str(about["long_wait"]["shot"])).is_equal("food")
	assert_str(str(about["long_wait"]["text"])).contains("tteokbokki")
	# A card nobody took up is nothing to post about.
	var untaken := Socials.pick([_sat("Kim Ji-ho", 1100), {"kind": "plant_played", "at": 1195, "card": "ppl", "name": "Kim Ji-ho"}], _info(["Kim Ji-ho"]), _dice())
	assert_bool(untaken.any(func(p): return p["about"] == "card")).is_false()
	var taken := Socials.pick([_sat("Kim Ji-ho", 1100), {"kind": "plant_played", "at": 1195, "card": "ppl", "name": "Kim Ji-ho"}], _info(["Kim Ji-ho"], ["ppl"]), _dice())
	assert_str(str(taken[0]["about"])).is_equal("card")


func test_a_selfie_without_their_face_is_words_alone() -> void:
	var posts := Socials.pick([_sat("Kim Ji-ho", 1100), {"kind": "became_regular", "at": 1400, "name": "Kim Ji-ho"}],
		{"owner": OWNER, "cat": CAT, "faces": {}, "seats": 5}, _dice())
	assert_str(str(posts[0]["shot"])).is_equal("text")
	assert_str(str(posts[0]["snap"])).is_empty()


# --- Handles, hashtags and the check ---------------------------------------------------------------

func test_handles_are_their_own_name_and_always_the_same() -> void:
	assert_str(Socials.handle("Kim Ji-ho")).is_equal(Socials.handle("Kim Ji-ho"))
	assert_str(Socials.handle("Kim Ji-ho")).starts_with("@jiho")
	for person in ["Kim Ji-ho", "O Seo", "Park Min-seo", "Do"]:
		assert_bool(RegEx.create_from_string("^@[a-z0-9._]{3,30}$").search(Socials.handle(person)) != null).is_true()


func test_every_korean_hashtag_and_the_app_explain_themselves() -> void:
	for tag in Socials.HASHTAGS:
		assert_str(Socials.unknown_hangul(str(tag))).override_failure_message("no meaning for %s" % tag).is_empty()
	assert_str(Glossary.hangul_tip(Socials.APP)).contains("moonlit")
	for about in Socials.TAGS_OF:
		for tag in Socials.TAGS_OF[about]:
			assert_array(Socials.HASHTAGS).contains([tag])


func test_every_template_passes_the_check() -> void:
	var dice := _dice()
	for about in Socials.TEMPLATES:
		var moods: Array = Socials.TEMPLATES[about].keys() if Socials.TEMPLATES[about] is Dictionary else [""]
		for mood in moods:
			var choices: Array = Socials.TEMPLATES[about][mood] if mood != "" else Socials.TEMPLATES[about]
			for words in choices:
				var post := {"about": about, "poster": "Kim Ji-ho", "handle": Socials.handle("Kim Ji-ho"), "shot": "text",
					"text": str(words).replace("{cat}", CAT).replace("{dish}", "tteokbokki"), "tags": Socials.stitched_tags(about, dice)}
				assert_str(Socials.check(post, _facts([post], {"Kim Ji-ho": ["Tteokbokki"]}))).override_failure_message("%s: %s" % [about, words]).is_empty()


func test_the_check_turns_down_what_a_post_mustnt_say() -> void:
	var good := {"about": "food", "poster": "Kim Ji-ho", "handle": Socials.handle("Kim Ji-ho"), "shot": "food", "dish": "Tteokbokki",
		"text": "late tteokbokki under the tarp. perfect", "tags": ["#야식", "#pojangmacha"]}
	var facts := _facts([good], {"Kim Ji-ho": ["Tteokbokki"]})
	assert_str(Socials.check(good, facts)).is_empty()
	var bad := {
		"text": ["", "x".repeat(Socials.MOST_CHARS + 1), "had 3 bottles tonight", "a cold cass at the tent", "hi @minseo_eats", "Min-seo was there too", "오늘 대박사건",
			"the pajeon was even better", "late night. Choi said hi", "so tired. Do-yun kept talking"],
		"tags": [["#ad"], ["#포차", "#꿀잼"]],
		"handle": ["@someone_else"], "poster": ["Han Seo-yeon"], "dish": ["Ramyeon"], "shot": ["video"],
	}
	for field in bad:
		for value in bad[field]:
			var post := good.duplicate(true)
			post[field] = value
			assert_str(Socials.check(post, facts)).override_failure_message("%s = %s got through" % [field, value]).is_not_empty()


func test_a_sentence_starting_with_a_capital_isnt_someone_new() -> void:
	var post := {"about": "food", "poster": "Kim Ji-ho", "handle": Socials.handle("Kim Ji-ho"), "shot": "food", "dish": "Tteokbokki",
		"text": "Best tteokbokki of my life. Honestly? Worth the cold. Ji-ho out", "tags": ["#야식"]}
	assert_str(Socials.check(post, _facts([post], {"Kim Ji-ho": ["Tteokbokki"]}))).is_empty()


# --- The AI writes the posts -------------------------------------------------------------------

func _night_posts() -> Array:
	var events := [_sat("Kim Ji-ho", 1100), _sat("Lee Do-yun", 1110),
		{"kind": "big_moment", "at": 1200, "who": "Ji-ho", "mood": "shock", "size": 5, "said": "I quit my job today"},
		{"kind": "cat_stole", "at": 1300, "name": "Lee Do-yun", "cat": CAT, "dish": "Odeng"}]
	return Socials.pick(events, _info(["Kim Ji-ho", "Lee Do-yun"]), _dice())


func test_the_ai_is_told_who_posts_about_what_in_whose_voice() -> void:
	var posts := _night_posts()
	var voice := Socials.voice({"age": "late 20s", "job": "junior accountant", "mood": "giddy", "reason": "quit her job today", "speech_style": "fast, lots of exclamation"})
	assert_str(voice).contains("junior accountant").contains("giddy").contains("quit her job today").contains("fast, lots of exclamation")
	var facts := Socials.ai_facts(posts, {"owner": OWNER, "cat": CAT, "weather": "drizzle", "voices": {"Kim Ji-ho": voice}})
	assert_int(facts["posts"].size()).is_equal(2)
	var moment: Dictionary = facts["posts"][0]
	assert_str(str(moment["happened"])).contains("I quit my job today").contains("shock")
	assert_str(str(moment["voice"])).is_equal(voice)
	assert_str(str(facts["posts"][1]["happened"])).contains(CAT).contains("odeng")
	assert_str(str(facts["posts"][1]["shows"])).contains(CAT)
	var prompt: String = Prompts.socials_messages(facts)[-1]["content"]
	for post in posts:
		assert_str(prompt).contains(str(post["handle"]))
	assert_str(prompt).contains(voice.trim_suffix(".")).contains("#포차").contains(str(Socials.MOST_CHARS)).contains(OWNER).contains("Ji-ho")
	assert_str(prompt).contains("No numbers")


func test_the_ais_posts_are_checked_one_by_one() -> void:
	var posts := _night_posts()
	var facts := _facts(posts, {"Lee Do-yun": ["Odeng"]})
	var good := {"posts": [
		{"handle": posts[0]["handle"], "text": "\"%s: quit my job. told a tent bar first. no regrets\"" % posts[0]["handle"], "tags": ["nofilter", "#plotTwist", "#notalist"]},
		{"handle": posts[1]["handle"], "text": "%s took my odeng and i said thank you" % CAT, "tags": ["#tentcat"]}]}
	assert_str(Socials.validate_reply(good, posts, facts)).is_empty()
	var words: Dictionary = good["words"]
	assert_str(str(words[posts[0]["handle"]]["text"])).is_equal("quit my job. told a tent bar first. no regrets")  # (their handle and quotes off the front)
	assert_array(words[posts[0]["handle"]]["tags"]).is_equal(["#nofilter", "#plotTwist"])  # (a # put on; one not on the list left off)
	assert_array(good["turned_down"]).is_empty()
	# One post's words fail the check: the rest are kept, that one gets the game's.
	var one_bad := {"posts": [{"handle": posts[0]["handle"], "text": "quit after 7 years", "tags": []},
		{"handle": posts[1]["handle"], "text": "robbed by a cat. %s, you thief" % CAT, "tags": []}]}
	assert_str(Socials.validate_reply(one_bad, posts, facts)).is_empty()
	assert_array(one_bad["words"].keys()).is_equal([posts[1]["handle"]])
	assert_array(one_bad["words"][posts[1]["handle"]]["tags"]).is_equal([Socials.COMMON_TAGS[0]])  # (none on the list: the tent's)
	assert_str(str(one_bad["turned_down"][0])).contains("a number")
	# Not posts at all, or none usable: turned down (and asked again).
	assert_str(Socials.validate_reply({"text": "hi"}, posts, facts)).is_not_empty()
	assert_str(Socials.validate_reply({"posts": [{"handle": "@nobody", "text": "hi"}]}, posts, facts)).contains("none of the posts")


func test_the_canned_ai_writes_posts_from_the_same_words() -> void:
	var ai := CannedAi.new()
	var reply: Dictionary = ai.reply({"purpose": "socials", "facts": {"cat": CAT, "posts": [{"handle": "@jiho_eats", "about": "cat_theft", "dish": "Odeng"}]}})
	assert_int(reply["posts"].size()).is_equal(1)
	assert_str(str(reply["posts"][0]["text"])).contains(CAT)
	assert_array(reply["posts"][0]["tags"]).is_not_empty()


# --- Snapshots ---------------------------------------------------------------------------------------

func test_a_snapshot_is_wanted_for_what_a_post_could_show_and_found_again_at_three() -> void:
	var stole := {"name": "Lee Do-yun", "cat": CAT, "dish": "Odeng", "at": 1300}
	var wanted := Socials.wants_snap("cat_stole", stole, OWNER)
	assert_str(str(wanted["aim"])).is_equal("cat")
	var at_three := Socials.pick([_sat("Lee Do-yun", 1100), {"kind": "cat_stole", "at": 1300, "name": "Lee Do-yun", "cat": CAT, "dish": "Odeng"}], _info(["Lee Do-yun"]), _dice())
	assert_str(str(at_three[0]["snap"])).is_equal(str(wanted["key"]))  # (the same key both times)
	assert_str(str(Socials.wants_snap("big_moment", {"who": "Ji-ho", "at": 1200}, OWNER)["aim"])).is_equal("person")
	assert_dict(Socials.wants_snap("big_moment", {"who": "Mi-sook", "at": 1200}, OWNER)).is_empty()  # (not the owner's)
	assert_str(str(Socials.wants_snap("dish_served", {"name": "Kim Ji-ho", "dish": "Tteokbokki", "food_served": 1, "at": 1130}, OWNER)["aim"])).is_equal("food")
	assert_dict(Socials.wants_snap("dish_served", {"name": "Kim Ji-ho", "dish": "Tteokbokki", "food_served": 2, "wait": 5.0, "at": 1130}, OWNER)).is_empty()
	assert_dict(Socials.wants_snap("dish_served", {"name": "Kim Ji-ho", "dish": "Soju", "food_served": 1, "at": 1130}, OWNER)).is_empty()  # (a drink)
	assert_dict(Socials.wants_snap("arrived", {"name": "Kim Ji-ho"}, OWNER)).is_empty()


func test_a_snapshot_crop_stays_inside_the_stage_on_whole_pixels() -> void:
	var stage := Rect2(24, 141, 1872, 380)
	assert_that(Snapshots.region(Vector2(500.4, 300.2), stage)).is_equal(Rect2(350, 200, 300, 200))
	assert_that(Snapshots.region(Vector2(30, 150), stage)).is_equal(Rect2(24, 141, 300, 200))  # (pushed in at the corner)
	assert_that(Snapshots.region(Vector2(1890, 520), stage)).is_equal(Rect2(1596, 321, 300, 200))


func test_no_screen_means_no_snapshot_and_its_counted() -> void:
	var snaps := Snapshots.new()
	if Snapshots.can_render():
		return  # (a test for the headless runs: with a screen, it'd take one)
	await snaps.take("cat_stole@1300:Lee Do-yun", func(): return Vector2(100, 100))
	assert_dict(snaps.shots).is_empty()
	assert_int(int(snaps.counts["asked"])).is_equal(1)
	assert_int(int(snaps.counts["no_screen"])).is_equal(1)
	snaps.take("", func(): return Vector2.ZERO)  # (nothing to file it under: not asked)
	assert_int(int(snaps.counts["asked"])).is_equal(1)


func test_whats_never_in_a_shot_is_kept_out_to_its_last_child() -> void:
	var layer: Control = auto_free(Control.new())
	var bubble := Control.new()
	layer.add_child(bubble)
	var words := Label.new()
	bubble.add_child(words)
	Snapshots._keep_out_of_shots(layer)
	for item in [layer, bubble, words]:
		assert_int(item.visibility_layer).is_equal(Snapshots.KEEP_OUT)
	assert_int(Snapshots.IN_SHOT & Snapshots.KEEP_OUT).is_equal(0)
	assert_int(Snapshots.IN_SHOT & 1).is_equal(1)  # (everything else is in)


# --- Kept beside the save, and on screen ---------------------------------------------------------

func _image() -> Image:
	var image := Image.create(300, 200, false, Image.FORMAT_RGBA8)
	image.fill(Color("e8833a"))
	return image


func test_a_picture_is_kept_beside_the_save_and_goes_with_the_bar() -> void:
	assert_int(SaveStore.save_picture("bar1", "night3_0.png", _image())).is_equal(OK)
	var picture := SaveStore.load_picture("bar1", "night3_0.png")
	assert_object(picture).is_not_null()
	assert_that(picture.get_size()).is_equal(Vector2(300, 200))
	assert_object(SaveStore.load_picture("bar1", "gone.png")).is_null()
	assert_object(SaveStore.load_picture("bar1", "")).is_null()
	assert_int(SaveStore.save_picture("bar1", "x.png", null)).is_not_equal(OK)
	SaveStore.delete_bar("bar1")
	assert_bool(DirAccess.dir_exists_absolute(SaveStore.pictures_folder("bar1"))).is_false()


func _post(shot: String, picture := "") -> Dictionary:
	return {"about": "food", "poster": "Kim Ji-ho", "handle": Socials.handle("Kim Ji-ho"), "shot": shot, "at": 1290, "dish": "Tteokbokki",
		"dish_id": "tteokbokki", "picture": picture, "face": {"key": FACE["key"], "look": STUDENT, "mood": "calm"},
		"text": "late tteokbokki under the tarp. perfect", "tags": ["#야식", "#pojangmacha"]}


func test_a_post_shows_its_snapshot_or_draws_one_and_explains_its_korean() -> void:
	SaveStore.save_picture("bar1", "night3_0.png", _image())
	var card: SocialPost = auto_free(SocialPost.new())
	card.setup(_post("food", "night3_0.png"), "bar1", 0.04)
	add_child(card)
	assert_str(card.how).is_equal("snapshot")
	assert_object(card.find_child("Snapshot", true, false)).is_not_null()
	assert_int(card.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_str((card.find_child("Handle", true, false) as Label).text).is_equal(Socials.handle("Kim Ji-ho"))
	var app := card.find_child("App", true, false) as Label
	assert_str(app.text).starts_with("달밤 Dalbam · 9:30pm")
	assert_str(app.tooltip_text).contains("moonlit")  # (Korean on screen explains itself)
	var words := card.find_child("Words", true, false) as RichTextLabel
	assert_str(words.get_parsed_text()).contains("#야식")
	assert_str(words.text).contains("late-night snack")  # (the hashtag's hover)
	# Its picture gone (or never taken): drawn, the dish on a food pic, their face on a selfie.
	var drawn: SocialPost = auto_free(SocialPost.new())
	drawn.setup(_post("food", "gone.png"), "bar1", 0.0)
	assert_str(drawn.how).is_equal("drawn")
	assert_object(drawn.find_child("Dish", true, false)).is_not_null()
	var selfie: SocialPost = auto_free(SocialPost.new())
	selfie.setup(_post("selfie"), "bar1", 0.0)
	assert_object(selfie.find_child("Selfie", true, false)).is_not_null()
	var words_alone: SocialPost = auto_free(SocialPost.new())
	words_alone.setup(_post("text"), "bar1", 0.0)
	assert_str(words_alone.how).is_equal("words")
	assert_object(words_alone.find_child("Photo", true, false)).is_null()


func test_the_feed_puts_up_to_three_round_the_page_and_the_diary_book_shows_them() -> void:
	var feed: SocialFeed = auto_free(SocialFeed.new())
	add_child(feed)
	var four := [_post("text"), _post("food"), _post("selfie"), _post("text")]
	four[1]["poster"] = "Lee Do-yun"
	four[2]["poster"] = "Choi Ha-eun"
	feed.show_posts(four, "bar1")
	assert_array(feed.posters()).is_equal(["Kim Ji-ho", "Lee Do-yun", "Choi Ha-eun"])
	assert_array(feed.pictures()).is_equal(["words", "drawn", "drawn"])
	assert_that(feed.get_child(0).position).is_equal(SocialFeed.SPOTS[0])
	assert_float(feed.get_child(1).position.x).is_greater(1400.0)  # (the page's other side)
	assert_int(feed.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	feed.show_posts([], "")
	await get_tree().process_frame
	assert_array(feed.posters()).is_empty()
	# The diary book: each entry's posts round its page; one from before them, none.
	var book: DiaryBook = auto_free(DiaryBook.new())
	add_child(book)
	book.open([{"night": 1, "text": "Quiet.", "stamp": "soju"}, {"night": 2, "text": "The cat!", "stamp": "soju", "socials": [_post("food")]}], "Mi-sook's diary", -1, "bar1")
	assert_array(book.posters()).is_equal(["Kim Ji-ho"])
	book._flip(-1)
	await get_tree().process_frame
	assert_array(book.posters()).is_empty()


func test_the_night_stats_count_the_posts() -> void:
	var stats := NightStats.new()
	stats.socials = {"posts": 2, "pictures": 1, "drawn": 1, "text": 0, "dropped": 1, "viewer_comments": 0, "snapshots": {"asked": 4, "taken": 3, "no_screen": 1},
		"words_ai": 2, "words_game": 1, "ai_turned_down": 1}
	assert_str(stats.socials_text()).is_equal("Socials: posts 2 (words: AI 2, game 1, AI's TURNED DOWN 1) · pictures 1 (drawn 1, words alone 0) · viewer comments 0 · snapshots 3 of 4 (no screen 1) · NOT POSTED 1")
	assert_str(stats.panel_text(0, 0)).contains("Socials: posts 2")
