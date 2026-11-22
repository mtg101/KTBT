extends RefCounted
## The show's seasons: every night is an episode, and episodes come in seasons of EPISODES. The
## last is the finale; at 3am after it the season's looked back on (an episode a row: its title,
## its ratings and its pinned line, from the diary) and the channel gives its verdict, from the
## season's average ratings with a bonus for a new best or a hit, against the rung's own targets
## (rules/ladder.gd): up a rung, stay, or down one (only after two quiet seasons in a row, so
## one unlucky season doesn't decide it), never below the phone stream. Kept with the bar as
## "show": {"season", "rung" (where the show is on the ladder), "subscribers" (the online video
## channel's total, kept if the show moves on and comes back), "aired" (episodes this season
## so far), "nights" and "ratings" (this season's), "seasons" (the verdicts of the ones before)}.
## (Part of the game's rules: pure functions and the tables they use. See ARCHITECTURE.md.)

const Ratings = preload("res://scripts/rules/ratings.gd")
const Story = preload("res://scripts/rules/story.gd")
const Ladder = preload("res://scripts/rules/ladder.gd")
const Channels = preload("res://scripts/rules/channels.gd")

const EPISODES := Ladder.EPISODES
## The season's score: its average ratings, plus these (judged against the rung's targets).
const RECORD_BONUS := 0.5  # a new best for the show, some night this season
const HIT_BONUS := 0.5  # a hit (double digits), some night this season

## The verdict's outcomes (Ladder.judge): their stamps (Hangul: meanings in Hangul.MEANINGS).
## On the phone stream there's no contract to renew: the stream just goes on (계속!).
const OUTCOMES := {
	"up": {"stamp": "대박 시즌!"},
	"top": {"stamp": "대박 시즌!"},
	"stay": {"stamp": "재계약!"},
	"warned": {"stamp": "위기!"},
	"down": {"stamp": "강등!"},
}
const STREAM_GOES_ON_HANGUL := "계속!"
const FINALE_HANGUL := "최종회"
const LOOKED_BACK_HANGUL := "시즌 결산"
const PILOT_HANGUL := "파일럿"


## A new show: season 1, nothing aired, on the rung given (a new bar's on the phone stream).
static func fresh(rung: String = Ladder.FIRST) -> Dictionary:
	return {"season": 1, "rung": rung, "aired": 0, "nights": [], "ratings": [], "seasons": [], "subscribers": 0}


## Where the show is on the ladder (a show from before the ladder: network TV, where it always was).
static func rung_of(show: Dictionary) -> String:
	return str(show.get("rung", Ladder.OLDER))


## Tonight's episode: {"season", "episode" (of this season, from 1), "of", "finale"}.
static func tonight(show: Dictionary) -> Dictionary:
	var episode := int(show.get("aired", 0)) + 1
	return {"season": int(show.get("season", 1)), "episode": episode, "of": EPISODES, "finale": episode >= EPISODES}


## A night's been rated: it's aired. Returns whether that was the season's finale.
static func record(show: Dictionary, night: int, rating: float) -> bool:
	show["aired"] = int(show.get("aired", 0)) + 1
	var nights: Array = show.get("nights", []).map(func(n): return int(n))  # (whole numbers: a save's JSON gives them back as 1.0)
	nights.append(night)
	show["nights"] = nights
	var ratings: Array = show.get("ratings", [])
	ratings.append(snappedf(rating, 0.1))
	show["ratings"] = ratings
	return int(show["aired"]) >= EPISODES


## A new season's first night, in plain words: the show moved up or down a rung ("Your show's
## been picked up by network TV, 달빛TV (Moonlight TV)!"), renewed by its channel, by name
## ("Moonlight TV has renewed the show for season 3."), or its own stream or channel going on;
## "" on any other night, or in the first season. place: tonight's (see tonight).
static func season_news(show: Dictionary, place: Dictionary) -> String:
	var seasons: Array = show.get("seasons", [])
	if int(place.get("episode", 0)) != 1 or seasons.is_empty():
		return ""
	var season := int(place.get("season", 1))
	var last: Dictionary = seasons[-1]
	var from := str(last.get("rung", Ladder.OLDER))
	var to := str(last.get("to", from))
	var channel: Dictionary = show.get("channel", {})
	var booked := str(channel.get("rung", "")) == to  # (the channel it's on now)
	if to != from:
		var named := (", " + Channels.full_name(channel)) if booked else ""
		if Ladder.index_of(to) > Ladder.index_of(from):
			return "Your show's been picked up by %s%s! Season %d starts tonight, with more people watching than ever." % [Ladder.rung(to)["name"], named, season]
		return "The show's dropped to %s%s. Season %d starts tonight: time to win the audience back." % [Ladder.rung(to)["name"], named, season]
	var called := Channels.display_name(channel) if booked else ""
	if bool(Ladder.rung(to)["percent"]):  # (TV: a contract, renewed)
		var who := called if called != "" else str(Ladder.rung(to)["the"]).left(1).to_upper() + str(Ladder.rung(to)["the"]).substr(1)
		match str(last.get("outcome", "")):
			"warned":
				return "%s has renewed the show for season %d, but it wants better ratings this time." % [who, season]
			"top":
				return "After a hit season, %s has renewed the show for season %d." % [who, season]
		return "%s has renewed the show for season %d." % [who, season]
	return "Season %d starts tonight%s: the %s goes on." % [season, (" on " + called) if called != "" else "", "stream" if to == Ladder.FIRST else "channel"]


## The channel's verdict on a season. ratings: the season's, in order; before: every rated night
## before it (for a new best); past: the verdicts on the seasons before (the last one's outcome
## decides whether a bad season is a warning or down); rung: where the show was this season
## (its rule: Ladder.judge); subscribers: the channel's total at the season's end. Returns
## {"season", "rung", "to" (next season's rung), "average", "best", "record", "hit", "score",
## "views" (the average a night), "subscribers", "outcome", "stamp", "words"}.
static func verdict(season: int, ratings: Array, before: Array, past: Array, rung: String = Ladder.OLDER, subscribers: int = 0) -> Dictionary:
	var total := 0.0
	var best := 0.0
	var new_best := false
	var earlier: Array = before.duplicate()
	for each in ratings:
		var rating := float(each)
		total += rating
		best = maxf(best, rating)
		if Ratings.is_record(rating, earlier):
			new_best = true
		earlier.append(rating)
	var average := snappedf(total / ratings.size(), 0.1) if not ratings.is_empty() else 0.0
	var hit := best >= Ratings.HIT
	var score := snappedf(average + (RECORD_BONUS if new_best else 0.0) + (HIT_BONUS if hit else 0.0), 0.1)
	var last := ""  # (a warning only counts on the same rung)
	if not past.is_empty() and str(past[-1].get("rung", Ladder.OLDER)) == rung:
		last = str(past[-1].get("outcome", ""))
	var judged := Ladder.judge(score, rung, last, ratings, subscribers)
	var outcome := str(judged["outcome"])
	var stamp := STREAM_GOES_ON_HANGUL if outcome == "stay" and not bool(Ladder.rung(rung)["percent"]) else str(OUTCOMES[outcome]["stamp"])  # (your own stream or channel: nothing to renew, it goes on)
	var result := {"season": season, "rung": rung, "to": str(judged["to"]), "average": average, "best": best, "record": new_best, "hit": hit, "score": score,
		"views": Ladder.average_views(ratings, rung), "subscribers": subscribers, "outcome": outcome, "stamp": stamp}
	result["words"] = verdict_words(outcome, season + 1, rung, str(judged["to"]), result)
	return result


## The verdict in plain words: where the show's going for its next season, and why. judged: the
## season's numbers (its "views" a night, the channel's "subscribers").
static func verdict_words(outcome: String, next_season: int, from: String, to: String, judged: Dictionary = {}) -> String:
	var here: Dictionary = Ladder.rung(from)
	var there: Dictionary = Ladder.rung(to)
	match outcome:
		"up":
			if here.has("up_subscribers"):
				return "%s subscribers! The show's been picked up by %s: season %d's on it." % [Ladder.commas(int(judged.get("subscribers", 0))), there["name"], next_season]
			if here.has("up_views"):
				return "%s views a night! The show's got its own %s: season %d's on it." % [Ladder.commas(int(judged.get("views", 0))), there["short"], next_season]
			return "A hit season! The show's been picked up by %s: season %d's on it." % [there["name"], next_season]
		"top":
			return "A hit season on %s: as big as a show gets. Renewed for season %d." % [here["name"], next_season]
		"warned":
			if here.has("down_subscribers"):
				return "The channel goes on for season %d, but with only %s subscribers: end another season under %s and the show's back to %s." % [
					next_season, Ladder.commas(int(judged.get("subscribers", 0))), Ladder.commas(int(here["down_subscribers"])), Ladder.rung(Ladder.below(from))["name"]]
			return "Renewed for season %d, but %s wants more: another season like that and the show drops to %s." % [next_season, here["the"], Ladder.rung(Ladder.below(from))["name"]]
		"down":
			if here.has("down_subscribers"):
				return "Two seasons under %s subscribers: the channel's gone quiet, and the show's back to %s for season %d." % [Ladder.commas(int(here["down_subscribers"])), there["name"], next_season]
			return "Two quiet seasons: %s has dropped the show. Season %d's on %s." % [here["the"], next_season, there["name"]]
	if here.has("up_views"):
		return "The stream goes on: season %d, on %s (%s views a night this season). Average %s a night over a season and the show gets its own %s." % [
			next_season, here["name"], Ladder.commas(int(judged.get("views", 0))), Ladder.commas(int(here["up_views"])), Ladder.rung(Ladder.above(from))["short"]]
	if here.has("up_subscribers"):
		return "The channel goes on: season %d, with %s of the %s subscribers it takes for %s." % [next_season, Ladder.commas(int(judged.get("subscribers", 0))),
			Ladder.commas(int(here["up_subscribers"])), Ladder.rung(Ladder.above(from))["name"]]
	return "Renewed for season %d on %s." % [next_season, here["name"]]


## How a season went, in its rung's units: "averaged 640 views a night", "ended on 8,240
## subscribers", "averaged 9.5%".
static func season_done(judged: Dictionary) -> String:
	var rung := str(judged.get("rung", Ladder.OLDER))
	if Ladder.counts_subscribers(rung):
		return "ended on %s subscribers" % Ladder.commas(int(judged.get("subscribers", 0)))
	if not bool(Ladder.rung(rung)["percent"]):
		return "averaged %s views a night" % Ladder.commas(int(judged.get("views", 0)))
	return "averaged " + Ratings.percent_text(float(judged.get("average", 0.0)))


## The season's over: its verdict kept (with its nights and ratings), and the next one begins.
static func end_season(show: Dictionary, judged: Dictionary) -> void:
	var kept := judged.duplicate()
	kept["nights"] = show.get("nights", []).duplicate()
	kept["ratings"] = show.get("ratings", []).duplicate()
	var seasons: Array = show.get("seasons", [])
	seasons.append(kept)
	show["seasons"] = seasons
	show["season"] = int(show.get("season", 1)) + 1
	show["rung"] = str(judged.get("to", rung_of(show)))
	show["aired"] = 0
	show["nights"] = []
	show["ratings"] = []


## "Season 1, episode 3 of 8" (", the finale").
static func label(place: Dictionary) -> String:
	return "Season %d, episode %d of %d%s" % [int(place.get("season", 1)), int(place.get("episode", 1)), int(place.get("of", EPISODES)), ", the finale" if bool(place.get("finale", false)) else ""]


## Which season and episode a night was, from its diary entry or night log ("season",
## "season_episode"): {"season", "episode"}, or {} for one aired before the show had seasons (a
## pilot). Episodes are only ever numbered within their season, never as a running count.
static func of(entry: Dictionary) -> Dictionary:
	if not entry.has("season") or not entry.has("season_episode"):
		return {}
	return {"season": int(entry["season"]), "episode": int(entry["season_episode"])}


## "S2 · EP 3", or "PILOT" for a night from before seasons. place: tonight's or ShowSeasons.of's.
static func tag(place: Dictionary) -> String:
	if place.is_empty():
		return "PILOT"
	return "S%d · EP %d" % [int(place.get("season", 1)), int(place.get("episode", 1))]


## "season 2, episode 3", or "a pilot episode".
static func words(place: Dictionary) -> String:
	if place.is_empty():
		return "a pilot episode"
	return "season %d, episode %d" % [int(place.get("season", 1)), int(place.get("episode", 1))]


## "시즌 2 · 제3화" (as Korean TV numbers them: season 2, episode 3), or "파일럿" (a pilot).
static func hangul(place: Dictionary) -> String:
	if place.is_empty():
		return PILOT_HANGUL
	return "시즌 %d · 제%d화" % [int(place.get("season", 1)), int(place.get("episode", 1))]


## "S1 · EP 3/8" (" · FINALE"), for the top bar.
static func short_label(place: Dictionary) -> String:
	return "S%d · EP %d/%d%s" % [int(place.get("season", 1)), int(place.get("episode", 1)), int(place.get("of", EPISODES)), " · FINALE" if bool(place.get("finale", false)) else ""]


## The season so far, in a line: "average 8.4%, best 11.2% (3 aired)", or "" before any.
static func so_far(show: Dictionary) -> String:
	var ratings: Array = show.get("ratings", [])
	if ratings.is_empty():
		return ""
	var total := 0.0
	var best := 0.0
	for each in ratings:
		total += float(each)
		best = maxf(best, float(each))
	return "average %.1f%%, best %.1f%% (%d aired)" % [total / ratings.size(), best, ratings.size()]


## The season looked back on, an episode a row, from the bar's diary: {"episode" (of the season),
## "night", "title" (as cut, else the writers' first draft, else ""), "rating", "quote" ({"speaker",
## "text"}: the first line pinned, else the night's line, else {})}. nights and ratings: the season's.
static func recap_rows(nights: Array, ratings: Array, diary: Array) -> Array:
	var rows: Array = []
	for k in nights.size():
		var night := int(nights[k])
		var entry: Dictionary = {}
		for each in diary:
			if int(each.get("night", 0)) == night:
				entry = each
		var title := ""
		if not entry.get("title", {}).is_empty():
			title = Story.title_text(entry["title"])
		elif not entry.get("titles", []).is_empty():
			title = Story.title_text(entry["titles"][0])
		var facts: Dictionary = entry.get("facts", {})
		var quote: Dictionary = {}
		if not facts.get("pinned", []).is_empty():
			quote = {"speaker": str(facts["pinned"][0].get("speaker", "")), "text": str(facts["pinned"][0].get("text", ""))}
		elif facts.get("line", {}) is Dictionary and str(facts.get("line", {}).get("text", "")) != "":
			quote = {"speaker": str(facts["line"].get("speaker", "")), "text": str(facts["line"]["text"])}
		rows.append({"episode": k + 1, "night": night, "title": title, "rating": float(ratings[k]) if k < ratings.size() else 0.0, "quote": quote})
	return rows


## How the verdict's decided, for its hover: how the season went, and the rung's rule.
static func hover(judged: Dictionary) -> String:
	var rung := str(judged.get("rung", Ladder.OLDER))
	var data: Dictionary = Ladder.rung(rung)
	var average := float(judged.get("average", 0.0))
	var lines := ["%s: %s" % [judged.get("stamp", ""), str(judged.get("words", ""))]]
	if bool(data["percent"]):
		lines.append("The season's average ratings %.1f%%%s%s = %.1f." % [average, (", +%.1f for a new best" % RECORD_BONUS) if bool(judged.get("record", false)) else "",
			(", +%.1f for a hit" % HIT_BONUS) if bool(judged.get("hit", false)) else "", float(judged.get("score", 0.0))])
	else:  # (in its own units: a score's a great rating but a handful of views)
		lines.append("The season %s." % season_done(judged))
	lines.append("On %s: %s" % [data["name"], Ladder.rule(rung)])
	return "\n".join(PackedStringArray(lines))


## One line for the log and the stats: "Season 1: average 8.4%, best 11.2% (a new best, a hit) +1.0 = 9.4: stay (재계약!)"
static func log_text(judged: Dictionary) -> String:
	var why := PackedStringArray()
	if bool(judged.get("record", false)):
		why.append("a new best")
	if bool(judged.get("hit", false)):
		why.append("a hit")
	var rung := str(judged.get("rung", Ladder.OLDER))
	var to := str(judged.get("to", rung))
	return "Season %d: average %.1f%%, best %.1f%%%s = %.1f: %s (%s)%s" % [int(judged.get("season", 1)), float(judged.get("average", 0.0)), float(judged.get("best", 0.0)),
		(" (%s)" % ", ".join(why)) if not why.is_empty() else "", float(judged.get("score", 0.0)), judged.get("outcome", ""), judged.get("stamp", ""),
		(" · %s → %s" % [rung, to]) if to != rung else (" · on %s" % rung)]
