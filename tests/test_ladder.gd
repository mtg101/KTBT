extends GdUnitTestSuite
## Tests for scripts/rules/ladder.gd: the three rungs (a phone stream, an online video channel,
## network TV), each showing the night's score in its own units and words, and judging a season
## against its own targets.

const Ladder = preload("res://scripts/rules/ladder.gd")
const Ratings = preload("res://scripts/rules/ratings.gd")
const Hangul = preload("res://scripts/rules/hangul.gd")


func test_three_rungs_from_a_phone_stream_to_network_tv() -> void:
	assert_array(Ladder.RUNGS.map(func(r): return str(r["id"]))).is_equal(["phone", "video", "network"])
	assert_array(Ladder.RUNGS.map(func(r): return str(r["short"]))).is_equal(["phone stream", "online video channel", "network TV"])
	assert_str(Ladder.FIRST).is_equal("phone")  # (a new bar's show)
	assert_str(Ladder.OLDER).is_equal("network")  # (a bar from before the ladder: on TV, where its show always was)
	assert_str(str(Ladder.rung("cable")["id"])).is_equal("network")  # (a rung retired the same day it came)
	assert_str(Ladder.above("phone")).is_equal("video")
	assert_str(Ladder.above("video")).is_equal("network")
	assert_str(Ladder.below("video")).is_equal("phone")
	assert_str(Ladder.below("phone")).is_equal("phone")  # (never off air)
	assert_str(Ladder.above("network")).is_equal("network")
	assert_bool(Ladder.is_floor("phone")).is_true()
	assert_bool(Ladder.is_top("network")).is_true()
	# Each rung's rule for moving on, in its own units: absolute targets, as platforms work.
	assert_int(int(Ladder.rung("phone")["up_views"])).is_equal(1000)
	assert_int(int(Ladder.rung("video")["up_subscribers"])).is_equal(10000)
	for rung in Ladder.RUNGS:  # (no real platform, channel or show named)
		for word in ["YouTube", "TikTok", "KBS", "MBC", "SBS", "tvN", "JTBC"]:
			assert_str(str(rung["name"]) + str(rung["about"])).not_contains(word)


func test_each_rung_shows_the_score_in_its_own_units() -> void:
	assert_str(Ladder.text(9.5, "network")).is_equal("9.5%")
	assert_str(Ladder.label(9.5, "network")).is_equal("시청률 ratings 9.5%")  # (the Korean, and the English beside it)
	assert_str(Ladder.headline(9.5, "network")).is_equal("TV ratings 9.5%")
	assert_str(Ladder.card_text(9.5, "network")).is_equal("RATINGS 9.5%")
	assert_str(Ladder.text(9.5, "phone")).contains(" views · ").ends_with(" likes")
	assert_str(Ladder.label(9.5, "phone")).starts_with("조회수 views ").ends_with("K")
	assert_str(Ladder.card_text(9.5, "phone")).ends_with("K VIEWS")
	# The online video channel's main number is its total subscribers, with what the episode brought.
	var subs := Ladder.subscribers(9.5, "video")
	assert_int(subs).is_greater(0)
	assert_bool(Ladder.counts_subscribers("video")).is_true()
	assert_bool(Ladder.counts_subscribers("phone")).is_false()
	var change := Ladder.subscriber_change(9.5, "video")
	assert_int(change).is_equal(subs - 300)  # (won, less the ones who unsubscribed)
	assert_str(Ladder.text(9.5, "video", 12400)).is_equal("12,400 subscribers (+%s) · %s views" % [Ladder.commas(change), Ladder.commas(Ladder.views(9.5, "video"))])
	# Subscribers go down as well as up: a thin episode loses more than it wins, never below none.
	assert_int(Ladder.subscriber_change(1.5, "video")).is_less(0)
	assert_str(Ladder.text(1.5, "video", 900)).contains("subscribers (−")
	assert_int(Ladder.subscribers_after(900, 1.5, "video")).is_equal(900 + Ladder.subscriber_change(1.5, "video"))
	assert_int(Ladder.subscribers_after(50, 0.5, "video")).is_equal(0)
	assert_str(Ladder.short(1.5, "video")).starts_with("−")  # (an episode's change, without a total: the season page's rows)
	assert_str(Ladder.label(9.5, "video", 12400)).is_equal("구독자 subscribers 12.4K")
	assert_str(Ladder.card_text(9.5, "video", 12400)).is_equal("12.4K SUBSCRIBERS")
	assert_str(Ladder.headline(9.5, "video", 12400)).starts_with("12,400 subscribers (+")
	assert_str(Ladder.short(9.5, "video")).is_equal("+%s" % Ladder.short_number(change))
	assert_str(Ladder.hover({"rating": 9.5, "parts": [], "subscribers": 12400}, "video")).contains("12,400 subscribers (+")
	# The rules in each rung's own units, never the bare score (10 is a great rating, and a handful of views).
	assert_str(Ladder.rule("phone")).is_equal("Average 1,000+ views a night over a season and the show gets its own online video channel.")  # (the bottom rung: no need to say it can't drop)
	assert_str(Ladder.rule("video")).is_equal("Reach 10,000 subscribers by the end of a season and network TV picks the show up; end two seasons under 1,000 and it's back to a phone stream.")
	assert_str(Ladder.rule("network")).is_equal("The top. A season averaging 10% or more is a hit; two seasons averaging under 5% and the show's back on an online video channel.")
	assert_str(Ladder.describe("phone")).is_equal("Views and likes (조회수). " + Ladder.rule("phone"))
	assert_str(Ladder.describe("video")).starts_with("Total subscribers (구독자), and views.")
	assert_str(Ladder.describe("network")).starts_with("TV ratings")
	# A good night's numbers are in scale with the targets: about a thousand views on the stream, nearly a thousand new subscribers on the channel.
	assert_int(Ladder.views(9.0, "phone")).is_between(1000, 1200)
	assert_int(Ladder.subscriber_change(9.0, "video")).is_between(900, 1200)
	assert_int(Ladder.average_views([6.0, 8.0], "phone")).is_equal(roundi((Ladder.views(6.0, "phone") + Ladder.views(8.0, "phone")) / 2.0))
	assert_str(Ladder.progress("phone", [6.0, 8.0], 0)).is_equal("This season so far: %s views a night (1,000 to move on)." % Ladder.commas(Ladder.average_views([6.0, 8.0], "phone")))
	assert_str(Ladder.progress("video", [6.0], 8240)).is_equal("8,240 of 10,000 subscribers (ending a season under 1,000 is a quiet one).")
	assert_str(Ladder.progress("network", [6.0, 7.0], 0)).is_equal("This season so far: averaging 6.5%.")
	assert_str(Ladder.progress("phone", [], 0)).is_equal("Nothing aired this season yet.")
	# More score, more views; the same score, the same numbers every time; a little spread.
	assert_int(Ladder.views(9.5, "phone")).is_greater(Ladder.views(5.0, "phone"))
	assert_int(Ladder.views(9.5, "video")).is_greater(Ladder.views(9.5, "phone"))
	assert_str(Ladder.text(7.3, "phone")).is_equal(Ladder.text(7.3, "phone"))
	assert_int(Ladder.views(6.0, "phone")).is_between(int(6.0 * 120 * 0.93), int(6.0 * 120 * 1.07))
	assert_str(Ladder.commas(1234567)).is_equal("1,234,567")
	assert_str(Ladder.commas(640)).is_equal("640")
	assert_str(Ladder.short_number(11400)).is_equal("11.4K")
	assert_str(Ladder.short_number(86000)).is_equal("86K")
	assert_str(Ladder.short_number(123000)).is_equal("123K")
	assert_str(Ladder.short_number(640)).is_equal("640")


func test_each_rung_has_its_own_words_and_banners() -> void:
	assert_str(Ladder.band(3.0, "phone")).is_equal("a quiet night on the stream")
	assert_str(Ladder.band(12.0, "phone")).is_equal("going viral!")
	assert_str(Ladder.band(12.0, "video")).is_equal("trending!")
	assert_str(Ladder.band(12.0, "network")).is_equal(Ratings.band(12.0))
	assert_str(Ladder.banner(12.0, [5.0, 6.0], "network")).is_equal(Ratings.RECORD_HANGUL)
	assert_str(Ladder.banner(12.0, [5.0, 6.0], "phone")).is_equal(Ladder.VIEWS_RECORD_HANGUL)
	assert_str(Ladder.banner(11.0, [12.0, 5.0], "video")).is_equal(Ladder.VIEWS_HIT_HANGUL)
	assert_str(Ladder.banner(7.0, [8.0, 5.0], "phone")).is_empty()
	for banner in [Ratings.RECORD_HANGUL, Ratings.HIT_HANGUL, Ratings.LEGEND_HANGUL, Ladder.VIEWS_RECORD_HANGUL, Ladder.VIEWS_HIT_HANGUL]:
		assert_str(Ladder.banner_english(banner)).is_not_empty()  # (English to read beside each)
	for hangul in [Ladder.VIEWS_RECORD_HANGUL, Ladder.VIEWS_HIT_HANGUL, "조회수", "구독자"]:
		assert_bool(Hangul.MEANINGS.has(hangul)).override_failure_message("no meaning for %s" % hangul).is_true()
	var result := {"rating": 7.0, "parts": [["2 big moments", 2.2]]}
	assert_str(Ladder.hover(result, "phone")).contains("johoesu").contains("phone stream").contains("+2.2  2 big moments")
	assert_str(Ladder.hover(result, "video")).contains("Moving on: " + Ladder.rule("video"))  # (how to go up or down from here)
	assert_str(Ladder.hover(result, "video")).contains("gudokja").contains("online video channel")
	assert_str(Ladder.hover(result, "network")).contains("sicheongnyul").contains("network TV")


func test_a_great_season_moves_the_show_up_in_one_and_a_good_one_in_two() -> void:
	var great := [12.0, 12.0, 12.0, 12.0, 12.0, 12.0, 12.0, 12.0]
	var good := [9.0, 9.0, 9.0, 9.0, 9.0, 9.0, 9.0, 9.0]  # (the autopilot PD's average night)
	var so_so := [7.0, 7.0, 7.0, 7.0, 7.0, 7.0, 7.0, 7.0]
	# The stream: a good season just makes 1,000 views a night; a so-so one doesn't.
	assert_str(str(Ladder.judge(9.0, "phone", "", good)["outcome"])).is_equal("up")
	assert_str(str(Ladder.judge(7.0, "phone", "", so_so)["outcome"])).is_equal("stay")
	# The channel, from nothing: a great season reaches 10,000; a good one takes two.
	var total := 0
	for rating in great:
		total = Ladder.subscribers_after(total, rating, "video")
	assert_int(total).is_greater_equal(10000)
	total = 0
	for rating in good:
		total = Ladder.subscribers_after(total, rating, "video")
	assert_int(total).is_less(10000)
	for rating in good:
		total = Ladder.subscribers_after(total, rating, "video")
	assert_int(total).is_greater_equal(10000)


func test_each_rung_judges_a_season_by_its_own_rule() -> void:
	var good := [9.0, 9.0, 9.0, 9.0, 9.0, 9.0, 9.0, 9.0]  # (about 1,350 views a night)
	var quiet := [3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0, 3.0]  # (about 450)
	assert_dict(Ladder.judge(9.0, "phone", "", good)).is_equal({"outcome": "up", "to": "video"})
	assert_dict(Ladder.judge(3.0, "phone", "warned", quiet)).is_equal({"outcome": "stay", "to": "phone"})  # (the floor: never down)
	assert_dict(Ladder.judge(9.0, "video", "", good, 10000)).is_equal({"outcome": "up", "to": "network"})  # (10,000 subscribers: TV)
	assert_dict(Ladder.judge(12.0, "video", "", good, 9999)).is_equal({"outcome": "stay", "to": "video"})  # (however good the season, it's the total that moves it up)
	assert_dict(Ladder.judge(3.0, "video", "", quiet, 900)).is_equal({"outcome": "warned", "to": "video"})  # (under 1,000 at the season's end: a warning)
	assert_dict(Ladder.judge(3.0, "video", "warned", quiet, 900)).is_equal({"outcome": "down", "to": "phone"})  # (two in a row: back to the stream)
	assert_dict(Ladder.judge(3.0, "video", "warned", quiet, 1000)).is_equal({"outcome": "stay", "to": "video"})
	assert_dict(Ladder.judge(3.0, "video", "", quiet, 10000)).is_equal({"outcome": "up", "to": "network"})  # (10,000 subscribers: TV)
	assert_dict(Ladder.judge(10.0, "network", "")).is_equal({"outcome": "top", "to": "network"})  # (the top: as big as it gets)
	assert_dict(Ladder.judge(9.0, "network", "")).is_equal({"outcome": "stay", "to": "network"})
	assert_dict(Ladder.judge(4.0, "network", "")).is_equal({"outcome": "warned", "to": "network"})
	assert_dict(Ladder.judge(4.0, "network", "warned")).is_equal({"outcome": "down", "to": "video"})
