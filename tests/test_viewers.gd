extends GdUnitTestSuite
## Tests for the viewers' commentary: scripts/rules/viewers.gd (where they comment by rung, which
## comments a night gets and their likes, the words and the check, the AI's comments), the prompt
## (scripts/ai/prompts.gd) and the canned AI's, the comments on screen (scripts/ui/viewer_comments.gd,
## in ui/social_feed.gd and the diary book) and the night stats' line.

const Viewers = preload("res://scripts/rules/viewers.gd")
const Ladder = preload("res://scripts/rules/ladder.gd")
const ViewerComments = preload("res://scripts/ui/viewer_comments.gd")
const SocialFeed = preload("res://scripts/ui/social_feed.gd")
const DiaryBook = preload("res://scripts/ui/diary_book.gd")
const NightStats = preload("res://scripts/bar/night_stats.gd")
const CannedAi = preload("res://scripts/ai/canned_ai.gd")
const Prompts = preload("res://scripts/ai/prompts.gd")
const Glossary = preload("res://scripts/rules/glossary.gd")
const Hangul = preload("res://scripts/rules/hangul.gd")

const OWNER := "Park Mi-sook"
const CAT := "Nabi"


func _dice(seed_value := 7) -> RandomNumberGenerator:
	var dice := RandomNumberGenerator.new()
	dice.seed = seed_value
	return dice


func _info(rung: String, score: float, record := false, taken: Array = []) -> Dictionary:
	return {"rung": rung, "score": score, "record": record, "owner": OWNER, "cat": CAT, "taken_cards": taken}


## A night with something of everything: a big moment, the cat's theft, first snow, a new
## regular, a card taken up, the owner's own moment and a card nobody took up.
func _busy_night() -> Array:
	return [{"kind": "sat_down", "at": 10, "name": "Kim Ji-ho"}, {"kind": "sat_down", "at": 20, "name": "Lee Do-yun"},
		{"kind": "big_moment", "at": 30, "who": "Ji-ho", "mood": "shock", "size": 4, "said": "I quit today."},
		{"kind": "big_moment", "at": 31, "who": "Mi-sook", "mood": "funny", "size": 6},
		{"kind": "cat_stole", "at": 40, "name": "Lee Do-yun", "dish": "Odeng"},
		{"kind": "first_snow", "at": 50},
		{"kind": "became_regular", "at": 60, "name": "Lee Do-yun"},
		{"kind": "plant_played", "at": 70, "name": "Kim Ji-ho", "card": "taken_card"},
		{"kind": "plant_played", "at": 71, "name": "Lee Do-yun", "card": "ignored_card"}]


func _facts(rung: String, score: float) -> Dictionary:
	return Viewers.check_facts(_busy_night(), _info(rung, score), {"Lee Do-yun": ["Odeng"]})


func _comment(text: String, about := "ratings") -> Dictionary:
	return {"viewer": "night_owl", "about": about, "who": "", "mood": "", "dish": "", "likes": 12, "text": text, "by": "game"}


# --- Where, how many, what about ------------------------------------------------------------------

func test_where_viewers_comment_goes_with_the_rung() -> void:
	assert_str(str(Viewers.place_of("phone")["place"])).is_equal("live")
	assert_str(str(Viewers.place_of("video")["place"])).is_equal("comments")
	assert_str(str(Viewers.place_of("network")["place"])).is_equal("board")
	assert_str(str(Viewers.place_of("retired_rung")["place"])).is_equal("board")  # (an unknown rung is network TV's)
	assert_str(Viewers.figure(9.5, "network")).is_equal("9.5%")
	assert_str(Viewers.figure(9.0, "phone")).ends_with(" views")
	assert_str(Viewers.crowd_text(9.0, "phone")).ends_with(" watching")
	assert_str(Viewers.title(Viewers.pick([], _info("network", 9.0), _dice()))).starts_with("시청자 게시판 viewer board · ")
	for rung in Viewers.PLACES:  # (every place's Korean explains itself)
		assert_str(Glossary.hangul_tip(str(Viewers.PLACES[rung]["hangul"]))).is_not_empty()
	assert_str(Glossary.hangul_tip("추천")).contains("recommends")


func test_a_busier_night_gets_more_comments_and_more_likes() -> void:
	var quiet := Viewers.pick(_busy_night(), _info("phone", 3.0), _dice())
	var hit := Viewers.pick(_busy_night(), _info("phone", 12.0), _dice())
	assert_int(quiet["comments"].size()).is_equal(Viewers.FEWEST)
	assert_int(hit["comments"].size()).is_equal(Viewers.MOST)
	assert_str(str(quiet["comments"][0]["about"])).is_equal("ratings")  # (the figure's always first)
	assert_int(int(hit["comments"][0]["likes"])).is_greater(int(quiet["comments"][0]["likes"]))
	assert_int(int(hit["comments"][0]["likes"])).is_greater(int(hit["comments"][-1]["likes"]))  # (fading down the list)
	assert_that(Viewers.pick(_busy_night(), _info("phone", 12.0), _dice())).is_equal(hit)  # (the same dice, the same comments)
	var viewers: Array = hit["comments"].map(func(c): return c["viewer"])
	for viewer in viewers:
		assert_int(viewers.count(viewer)).is_equal(1)
	# The counts come from the rung's own numbers: a hit night on TV has a busier board.
	assert_int(Viewers.audience(12.0, "network")).is_greater(Viewers.audience(3.0, "network"))
	assert_int(Viewers.audience(9.0, "video")).is_equal(Ladder.views(9.0, "video"))


func test_comments_are_about_what_happened_worth_most_first() -> void:
	var board := Viewers.pick(_busy_night(), _info("video", 12.0, false, ["taken_card"]), _dice())
	var about: Array = board["comments"].map(func(c): return c["about"])
	assert_array(about).is_equal(["ratings", "moment", "cat_theft", "first_snow"])
	assert_str(str(board["comments"][1]["who"])).is_equal("Ji-ho")  # (the customer's moment, not the owner's bigger one)
	assert_str(str(board["comments"][1]["mood"])).is_equal("shock")
	assert_str(str(board["comments"][2]["dish"])).is_equal("Odeng")
	# A quiet night: the figure, and the owner.
	var empty := Viewers.pick([], _info("video", 5.0), _dice())
	assert_array(empty["comments"].map(func(c): return c["about"])).is_equal(["ratings", "owner"])
	# A card only once it's been taken up.
	var cards := Viewers.pick([{"kind": "plant_played", "at": 1, "name": "Kim Ji-ho", "card": "ignored_card"}], _info("video", 12.0), _dice())
	assert_bool(cards["comments"].any(func(c): return c["about"] == "card")).is_false()


func test_the_figure_talk_follows_its_band_and_a_new_best() -> void:
	assert_str(Viewers.band_key(3.0, false)).is_equal("quiet")
	assert_str(Viewers.band_key(6.0, false)).is_equal("good")
	assert_str(Viewers.band_key(9.0, false)).is_equal("near")
	assert_str(Viewers.band_key(12.0, false)).is_equal("hit")
	assert_str(Viewers.band_key(25.0, false)).is_equal("legend")
	assert_str(Viewers.band_key(3.0, true)).is_equal("record")
	assert_str(str(Viewers.words_info(_info("network", 12.0))["cheer"])).is_equal("두 자릿수!!")
	assert_str(str(Viewers.words_info(_info("phone", 12.0))["cheer"])).is_equal("떡상!!")
	var words := Viewers.words_info(_info("network", 12.0))
	var said := Viewers.stitched_words({"about": "ratings"}, words, _dice())
	assert_bool(Viewers.TEMPLATES["ratings"]["hit"].any(func(t): return Viewers.fill(str(t), {}, words) == said)).is_true()
	assert_bool(said.contains("12.0%") or said.contains("두 자릿수")).is_true()


# --- The words and the check ----------------------------------------------------------------------

func test_every_template_passes_the_check() -> void:
	for rung in Viewers.PLACES:
		var facts := _facts(rung, 12.0)
		var words := Viewers.words_info(_info(rung, 12.0))
		for about in Viewers.TEMPLATES:
			var sets: Dictionary = Viewers.TEMPLATES[about] if Viewers.TEMPLATES[about] is Dictionary else {"": Viewers.TEMPLATES[about]}
			for key in sets:
				for template in sets[key]:
					var comment := {"viewer": "night_owl", "about": about, "who": "Do-yun", "mood": key, "dish": "Odeng"}
					comment["text"] = Viewers.fill(str(template), comment, words)
					assert_str(Viewers.check(comment, facts)).override_failure_message("%s %s/%s: %s" % [rung, about, key, comment["text"]]).is_empty()


func test_the_check_turns_down_what_a_comment_mustnt_say() -> void:
	var facts := _facts("network", 12.0)
	assert_str(Viewers.check(_comment("12.0%?! a tent bar did that"), facts)).is_empty()
	assert_str(Viewers.check(_comment(""), facts)).is_equal("empty")
	assert_str(Viewers.check(_comment("so good ".repeat(20)), facts)).starts_with("too long")
	assert_str(Viewers.check(_comment("watched it 3 times"), facts)).contains("isn't tonight's figure")
	assert_str(Viewers.check(_comment("@stoolside you were right"), facts)).contains("a mention")
	assert_str(Viewers.check(_comment("대박 진짜 미쳤다"), facts)).contains("Korean the game doesn't know")
	assert_str(Viewers.check(_comment("Mi-sook and Hyun-woo at the counter"), facts)).contains("Hyun-woo")
	assert_str(Viewers.check(_comment("that tteokbokki looked so good"), facts)).contains("food nobody had")
	assert_str(Viewers.check(_comment("that odeng looked so good"), facts)).is_empty()  # (somebody had it)
	var stranger := _comment("lovely")
	stranger["viewer"] = "a_real_person"
	assert_str(Viewers.check(stranger, facts)).contains("not one of the game's viewers")
	assert_str(Viewers.check(_comment("헐 Ji-ho ㅋㅋㅋ 대박"), facts)).is_empty()


# --- The AI's comments ------------------------------------------------------------------------------

func test_the_ai_is_told_what_to_comment_on() -> void:
	var board := Viewers.pick(_busy_night(), _info("network", 12.0), _dice())
	var facts := Viewers.ai_facts(board, _info("network", 12.0))
	var asked := str(Prompts.viewers_messages(facts)[1]["content"])
	for comment in board["comments"]:
		assert_str(asked).contains(str(comment["viewer"]))
	assert_str(asked).contains("12.0%")
	assert_str(asked).contains("network TV")
	assert_str(asked).contains("viewer board")
	assert_str(asked).contains("두 자릿수")
	assert_str(asked).contains("I quit today.")  # (the moment's own words)
	assert_str(asked).contains("Ji-ho")
	assert_str(asked).contains("Nabi")
	assert_str(asked).contains("No other numbers")


func test_the_ais_comments_are_checked_one_by_one() -> void:
	var board := Viewers.pick(_busy_night(), _info("network", 12.0), _dice())
	var comments: Array = board["comments"]
	var facts := _facts("network", 12.0)
	var reply := {"comments": [{"viewer": "@" + str(comments[0]["viewer"]), "text": "%s: 12.0%% for a tent bar?! 대박" % comments[0]["viewer"]},
		{"viewer": str(comments[1]["viewer"]), "text": "watched it 5 times"}]}
	assert_str(Viewers.validate_reply(reply, comments, facts)).is_empty()
	assert_str(str(reply["words"][str(comments[0]["viewer"])])).is_equal("12.0% for a tent bar?! 대박")  # (their handle off the front)
	assert_int(reply["words"].size()).is_equal(1)
	assert_int(reply["turned_down"].size()).is_equal(comments.size() - 1)  # (one failing, the rest missing: the game's words)
	assert_str(Viewers.validate_reply({"comments": [{"viewer": str(comments[1]["viewer"]), "text": "watched it 5 times"}]}, comments, facts)).starts_with("none of the comments")
	assert_str(Viewers.validate_reply({"posts": []}, comments, facts)).contains("\"comments\"")
	assert_str(Viewers.validate_reply("words", comments, facts)).contains("\"comments\"")


func test_the_canned_ai_writes_comments_from_the_same_words() -> void:
	var board := Viewers.pick(_busy_night(), _info("phone", 12.0), _dice())
	var facts := Viewers.ai_facts(board, _info("phone", 12.0))
	var reply: Dictionary = CannedAi.new().reply({"purpose": "viewers", "facts": facts})
	assert_int(reply["comments"].size()).is_equal(board["comments"].size())
	assert_str(Viewers.validate_reply(reply, board["comments"], _facts("phone", 12.0))).is_empty()
	assert_int(reply["words"].size()).is_equal(board["comments"].size())


# --- On screen ----------------------------------------------------------------------------------------

func test_the_comments_look_like_their_place_explain_their_korean_and_never_take_a_click() -> void:
	for rung in ["phone", "video", "network"]:
		var board := Viewers.pick(_busy_night(), _info(rung, 9.0), _dice())
		var shown: ViewerComments = auto_free(ViewerComments.new())
		shown.setup(board, 0.0)
		add_child(shown)
		assert_str(shown.place).is_equal(str(board["place"]))
		assert_int(shown.rows).is_equal(board["comments"].size())
		assert_int(shown.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		var title := shown.find_child("Title", true, false) as RichTextLabel
		assert_str(title.tooltip_text).contains(str(Viewers.place_of(rung)["english"]))
		assert_str(title.text).contains(str(Hangul.MEANINGS[str(Viewers.place_of(rung)["hangul"])]).get_slice(":", 0))  # (its Korean's hover)
		if rung == "phone":
			assert_str(title.get_parsed_text()).contains("LIVE")
		else:
			assert_str(title.get_parsed_text()).not_contains("LIVE")
		var row := shown.find_child("Comment", true, false) as RichTextLabel
		assert_str(row.get_parsed_text()).contains(str(board["comments"][0]["viewer"]))
		if rung == "network":
			assert_str(row.get_parsed_text()).contains("추천")
			assert_str(row.text).contains("recommends")  # (its hover)
		else:
			assert_str(row.get_parsed_text()).contains("♥")


func test_the_feed_puts_the_comments_bottom_right_and_the_diary_book_shows_them() -> void:
	var feed: SocialFeed = auto_free(SocialFeed.new())
	add_child(feed)
	var board := Viewers.pick(_busy_night(), _info("video", 9.0), _dice())
	feed.show_posts([], "bar1", board)
	assert_int(feed.comment_count()).is_equal(board["comments"].size())
	assert_array(feed.posters()).is_empty()  # (the comments aren't posts)
	assert_that(feed.comments.position).is_equal(SocialFeed.COMMENTS_SPOT)
	feed.show_posts([], "")
	await get_tree().process_frame
	assert_int(feed.comment_count()).is_equal(0)
	# The diary book: an entry's comments with its page; one from before them, none.
	var book: DiaryBook = auto_free(DiaryBook.new())
	add_child(book)
	book.open([{"night": 1, "text": "Quiet.", "stamp": "soju"}, {"night": 2, "text": "The cat!", "stamp": "soju", "viewers": board}], "Mi-sook's diary", -1, "bar1")
	assert_int(book._feed.comment_count()).is_equal(board["comments"].size())
	book._flip(-1)
	await get_tree().process_frame
	assert_int(book._feed.comment_count()).is_equal(0)


func test_the_night_stats_count_the_comments() -> void:
	var stats := NightStats.new()
	stats.socials = {"posts": 1, "viewer_comments": 3, "viewer_words_ai": 2, "viewer_words_game": 1, "viewer_ai_turned_down": 1, "viewer_dropped": 1}
	assert_str(stats.socials_text()).contains("viewer comments 3 (words: AI 2, game 1, AI's TURNED DOWN 1, NOT SHOWN 1)")
	stats.socials = {"posts": 0}
	assert_str(stats.socials_text()).contains("viewer comments 0 ·")
