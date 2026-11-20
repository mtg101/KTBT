extends RefCounted
## The show's seasons: every night is an episode, and episodes come in seasons of EPISODES. The
## last is the finale; at 3am after it the season's looked back on (an episode a row: its title,
## its ratings and its pinned line, from the diary) and the channel gives its verdict, from the
## season's average ratings with a bonus for a new best or a hit: up a rung, stay, or down one
## (only after two bad seasons in a row, so one unlucky season doesn't decide it). For now
## there's one rung, today's (a late-night show on a small pay-TV channel): the verdict is
## kept and announced, and the ladder (PLAN.md) will act on it. Kept with the bar as "show":
## {"season", "aired" (episodes this season so far), "nights" and "ratings" (this season's),
## "seasons" (the verdicts of the ones before)}.
## (Part of the game's rules: pure functions and the tables they use. See ARCHITECTURE.md.)

const Ratings = preload("res://scripts/rules/ratings.gd")
const Story = preload("res://scripts/rules/story.gd")

const EPISODES := 8
## The verdict, from the season's score (its average ratings, plus the bonuses): today's rung's
## targets. At UP_AT or over, up; under DOWN_BELOW, a bad season (down, if the last one was too).
const UP_AT := 10.0
const DOWN_BELOW := 5.0
const RECORD_BONUS := 0.5  # a new best for the show, some night this season
const HIT_BONUS := 0.5  # a hit (double digits), some night this season

## The verdict's outcomes: what each means, its stamp (Hangul: meanings in Hangul.MEANINGS).
const OUTCOMES := {
	"up": {"stamp": "대박 시즌!", "words": "A hit season! Renewed for season %d, and the bigger channels have noticed."},
	"stay": {"stamp": "재계약!", "words": "Renewed for season %d."},
	"warned": {"stamp": "위기!", "words": "Renewed for season %d, but the channel wants more: another season like that and the show's in trouble."},
	"down": {"stamp": "폐지 위기!", "words": "Two quiet seasons: the channel's lost patience. Season %d's the show's last chance on it."},
}
const FINALE_HANGUL := "최종회"
const LOOKED_BACK_HANGUL := "시즌 결산"
const PILOT_HANGUL := "파일럿"


## A new show: season 1, nothing aired.
static func fresh() -> Dictionary:
	return {"season": 1, "aired": 0, "nights": [], "ratings": [], "seasons": []}


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


## The channel's verdict on a season. ratings: the season's, in order; before: every rated night
## before it (for a new best); past: the verdicts on the seasons before (the last one's outcome
## decides whether a bad season is a warning or down). Returns {"season", "average", "best",
## "record", "hit", "score", "outcome", "stamp", "words"}.
static func verdict(season: int, ratings: Array, before: Array, past: Array) -> Dictionary:
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
	var outcome := "stay"
	if score >= UP_AT:
		outcome = "up"
	elif score < DOWN_BELOW:
		var last := str(past[-1].get("outcome", "")) if not past.is_empty() else ""
		outcome = "down" if last == "warned" else "warned"
	return {"season": season, "average": average, "best": best, "record": new_best, "hit": hit, "score": score, "outcome": outcome,
		"stamp": str(OUTCOMES[outcome]["stamp"]), "words": str(OUTCOMES[outcome]["words"]) % (season + 1)}


## The season's over: its verdict kept (with its nights and ratings), and the next one begins.
static func end_season(show: Dictionary, judged: Dictionary) -> void:
	var kept := judged.duplicate()
	kept["nights"] = show.get("nights", []).duplicate()
	kept["ratings"] = show.get("ratings", []).duplicate()
	var seasons: Array = show.get("seasons", [])
	seasons.append(kept)
	show["seasons"] = seasons
	show["season"] = int(show.get("season", 1)) + 1
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


## How the verdict's decided, for its hover.
static func hover(judged: Dictionary) -> String:
	var lines := ["%s: %s" % [judged.get("stamp", ""), str(judged.get("words", ""))],
		"The season's average ratings %.1f%%%s%s = %.1f." % [float(judged.get("average", 0.0)), (", +%.1f for a new best" % RECORD_BONUS) if bool(judged.get("record", false)) else "",
			(", +%.1f for a hit" % HIT_BONUS) if bool(judged.get("hit", false)) else "", float(judged.get("score", 0.0))],
		"%.0f or more is a hit season; under %.0f, a quiet one (two in a row and the channel loses patience)." % [UP_AT, DOWN_BELOW]]
	return "\n".join(PackedStringArray(lines))


## One line for the log and the stats: "Season 1: average 8.4%, best 11.2% (a new best, a hit) +1.0 = 9.4: stay (재계약!)"
static func log_text(judged: Dictionary) -> String:
	var why := PackedStringArray()
	if bool(judged.get("record", false)):
		why.append("a new best")
	if bool(judged.get("hit", false)):
		why.append("a hit")
	return "Season %d: average %.1f%%, best %.1f%%%s = %.1f: %s (%s)" % [int(judged.get("season", 1)), float(judged.get("average", 0.0)), float(judged.get("best", 0.0)),
		(" (%s)" % ", ".join(why)) if not why.is_empty() else "", float(judged.get("score", 0.0)), judged.get("outcome", ""), judged.get("stamp", "")]
