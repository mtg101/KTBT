extends RefCounted
## The platform ladder: the show climbs or drops three rungs, season by season, and is never off
## air: a phone stream, an online video channel, network TV. The night's score is worked out the
## same on every rung (Ratings.score); each rung shows it in its own units (views on the phone
## stream, the channel's total subscribers, 시청률 ratings on TV) and words. Moving on is to
## targets in those units, as platforms really work, never the score: a season averaging 1,000
## views a night gets the stream its own online video channel; 10,000 subscribers by a season's
## end gets the channel picked up by network TV (subscribers come and go, episode by episode),
## and ending two seasons under 1,000 drops it back to the stream; on TV a season averaging 10% is a hit, and two averaging
## under 5% drop the show back to the channel. Rungs change the numbers, never the
## PD's tools. No real platform, channel or show is ever named.
## (Part of the game's rules: pure functions and the tables they use. See ARCHITECTURE.md.)

const Ratings = preload("res://scripts/rules/ratings.gd")
const Hangul = preload("res://scripts/rules/hangul.gd")

## Paced so a great season moves the show up in one and a good one in two: a good night's score
## is about 9 (the autopilot PD's average), a great one 12. On the stream 120 views a point (a
## good season averages about 1,100 a night: just enough; a so-so one doesn't); on the channel 150
## new subscribers a point, less 300 unsubscribes an episode (a good season nets about 8,400, a
## great one 12,000).
## The rungs, lowest first, with how the score shows in their units (views per point of the
## score, likes and new subscribers as shares of the views) and their targets: up_views (a
## season's average views a night to move up), up_subscribers (the total by a season's end),
## unsubscribes (lost each episode, whatever it's like: subscribers go down as well as up),
## down_subscribers (ending a season under this many is a quiet one: two in a row and the show
## drops a rung), hit_at and down_below (on TV, the season's score: its average ratings with the
## bonuses).
const RUNGS := [
	{"id": "phone", "name": "a phone stream", "short": "phone stream", "the": "the stream", "word": "조회수", "english": "views", "percent": false,
		"views_per_point": 120.0, "likes": 0.08, "subscribers": 0.0, "up_views": 1000,
		"bands": ["a quiet night on the stream", "a good night for views", "the views are climbing", "going viral!", "everyone's sharing it"],
		"about": "The show's a phone stream for now: each night's episode goes up on a short-video app, and its views and likes are how it's doing."},
	{"id": "video", "name": "an online video channel", "short": "online video channel", "the": "the channel", "word": "구독자", "english": "subscribers", "percent": false,
		"views_per_point": 1200.0, "likes": 0.0, "subscribers": 1.0 / 8.0, "unsubscribes": 300, "up_subscribers": 10000, "down_subscribers": 1000,
		"bands": ["a quiet episode for the channel", "a good episode", "lots of new subscribers", "trending!", "the most watched video of the week"],
		"about": "The show has its own online video channel: its subscribers, won and lost with each episode (and each episode's views), are how it's doing."},
	{"id": "network", "name": "network TV", "short": "network TV", "the": "the network", "word": "시청률", "english": "ratings", "percent": true,
		"hit_at": 10.0, "down_below": 5.0,
		"about": "The show's on network TV, a late-night show on one of the big channels: the top. A few percent is an ordinary night, 10% a hit."},
]
const EPISODES := 8  # a season's (ShowSeasons.EPISODES is this)
const FIRST := "phone"  # where a new bar's show starts
const OLDER := "network"  # where a bar from before the ladder is placed: on TV, where its show always was
const RETIRED := ["cable", "entertainment"]  # rungs there were for a day (20 Nov): now network TV

const VIEWS_RECORD_HANGUL := "자체 최고 조회수!"
const VIEWS_HIT_HANGUL := "떡상!"


## A rung's data by id (an unknown id, or one retired: network TV).
static func rung(id: String) -> Dictionary:
	for each in RUNGS:
		if str(each["id"]) == id:
			return each
	return rung(OLDER)


static func index_of(id: String) -> int:
	for k in RUNGS.size():
		if str(RUNGS[k]["id"]) == id:
			return k
	return index_of(OLDER)


## The rung above or below (or the same, at the top or the floor).
static func above(id: String) -> String:
	return str(RUNGS[mini(index_of(id) + 1, RUNGS.size() - 1)]["id"])


static func below(id: String) -> String:
	return str(RUNGS[maxi(index_of(id) - 1, 0)]["id"])


static func is_top(id: String) -> bool:
	return index_of(id) == RUNGS.size() - 1


static func is_floor(id: String) -> bool:
	return index_of(id) == 0


## A little spread, the same every time for the same score (so a night's numbers never change).
static func _spread(score: float) -> float:
	var x := sin(score * 91.7 + 3.1) * 43758.5453
	return 0.94 + 0.12 * (x - floorf(x))


static func views(score: float, id: String) -> int:
	var data := rung(id)
	var raw := maxf(score, 0.0) * float(data.get("views_per_point", 0.0)) * _spread(score)
	return int(roundf(raw / 100.0) * 100.0) if raw >= 10000.0 else int(roundf(raw / 10.0) * 10.0)


## New subscribers an episode brings, on a rung that counts them (the online video channel's).
static func subscribers(score: float, id: String) -> int:
	return int(roundf(views(score, id) * float(rung(id).get("subscribers", 0.0))))


## What an episode does to the channel's subscribers: the new ones, less the ones who
## unsubscribed (a thin episode loses more than it wins). +590, -150.
static func subscriber_change(score: float, id: String) -> int:
	return subscribers(score, id) - int(rung(id).get("unsubscribes", 0))


## The channel's subscribers after an episode: never below none.
static func subscribers_after(total: int, score: float, id: String) -> int:
	return maxi(total + subscriber_change(score, id), 0)


## A change, signed: +590, −150.
static func signed(number: int) -> String:
	return ("+" if number >= 0 else "−") + commas(absi(number))


## A whole number with commas: 11400 -> "11,400".
static func commas(number: int) -> String:
	var digits := str(absi(number))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if number < 0 else "") + digits + out


## Short: 11400 -> "11.4K", 86000 -> "86K", 640 -> "640".
static func short_number(number: int) -> String:
	if number >= 100000:
		return "%dK" % roundi(number / 1000.0)
	if number >= 1000:
		var thousands := snappedf(number / 1000.0, 0.1)
		return ("%dK" % int(thousands)) if is_equal_approx(thousands, roundf(thousands)) else "%.1fK" % thousands
	return str(number)


## A score in the rung's own units, in full: "11,400 views · 680 likes", "9.5%", and on the online
## video channel its total subscribers (total: the channel's, after this episode) with what
## this episode brought: "12,400 subscribers (+390) · 86,000 views" ("+390 subscribers · …"
## without a total).
static func text(score: float, id: String, total: int = -1) -> String:
	var data := rung(id)
	if bool(data["percent"]):
		return Ratings.percent_text(score)
	var seen := views(score, id)
	if counts_subscribers(id):
		if total >= 0:
			return "%s subscribers (%s) · %s views" % [commas(total), signed(subscriber_change(score, id)), commas(seen)]
		return "%s subscribers · %s views" % [signed(subscriber_change(score, id)), commas(seen)]
	return "%s views · %s likes" % [commas(seen), commas(int(roundf(seen * float(data.get("likes", 0.0)) / 10.0) * 10.0))]


## Whether the rung's main number is its total subscribers (the online video channel).
static func counts_subscribers(id: String) -> bool:
	return float(rung(id).get("subscribers", 0.0)) > 0.0


## Short, beside its word: "11.4K" (조회수 views), "12.4K" (구독자 subscribers, the total; "+390"
## without one), "9.5%" (시청률 ratings).
static func short(score: float, id: String, total: int = -1) -> String:
	if bool(rung(id)["percent"]):
		return Ratings.percent_text(score)
	if counts_subscribers(id):
		if total >= 0:
			return short_number(total)
		var change := subscriber_change(score, id)
		return ("+" if change >= 0 else "−") + short_number(absi(change))
	return short_number(views(score, id))


## The rung's word for its measure (Hangul: 시청률, ratings; 조회수, views; 구독자, subscribers).
static func word(id: String) -> String:
	return str(rung(id)["word"])


## "시청률 ratings 9.5%", "조회수 views 11.4K", "구독자 subscribers 12.4K": the Korean, and the
## English beside it, so it reads easily (the hover says more).
static func label(score: float, id: String, total: int = -1) -> String:
	return "%s %s %s" % [word(id), rung(id)["english"], short(score, id, total)]


## What a rung is, in a line, for choosing it (the PD setting up the show): its units, and the
## rule for moving on, in its own units.
static func describe(id: String) -> String:
	var data := rung(id)
	var units := "TV ratings, the share of homes watching (시청률)" if bool(data["percent"]) else \
		("Total subscribers (구독자), and views" if counts_subscribers(id) else "Views and likes (조회수)")
	return "%s. %s" % [units, rule(id)]


## The rule for moving on from a rung, always in its own units, never the score (10 is a
## great rating, and a handful of views).
static func rule(id: String) -> String:
	var data := rung(id)
	if data.has("up_views"):
		return "Average %s+ views a night over a season and the show gets its own %s." % [commas(int(data["up_views"])), rung(above(id))["short"]]
	if data.has("up_subscribers"):
		return "Reach %s subscribers by the end of a season and %s picks the show up; end two seasons under %s and it's back to %s." % [
			commas(int(data["up_subscribers"])), rung(above(id))["name"], commas(int(data["down_subscribers"])), rung(below(id))["name"]]
	return "The top. A season averaging %s or more is a hit; two seasons averaging under %s and the show's back on %s." % [
		Ratings.percent_text(float(data["hit_at"])).replace(".0%", "%"), Ratings.percent_text(float(data["down_below"])).replace(".0%", "%"), rung(below(id))["name"]]


## The average views a night over a season's ratings, on a rung.
static func average_views(ratings: Array, id: String) -> int:
	if ratings.is_empty():
		return 0
	var total := 0
	for each in ratings:
		total += views(float(each), id)
	return int(roundf(float(total) / ratings.size()))


## How the season's going against the rule, in a line: "This season so far: 640 views a night
## (1,000 to move on).", "8,240 of 10,000 subscribers.", "This season so far: averaging 6.4%."
## ratings: this season's so far; total: the channel's subscribers.
static func progress(id: String, ratings: Array, total: int) -> String:
	var data := rung(id)
	if data.has("up_subscribers"):
		return "%s of %s subscribers (ending a season under %s is a quiet one)." % [commas(total), commas(int(data["up_subscribers"])), commas(int(data["down_subscribers"]))]
	if ratings.is_empty():
		return "Nothing aired this season yet."
	if data.has("up_views"):
		return "This season so far: %s views a night (%s to move on)." % [commas(average_views(ratings, id)), commas(int(data["up_views"]))]
	var sum := 0.0
	for each in ratings:
		sum += float(each)
	return "This season so far: averaging %s." % Ratings.percent_text(sum / ratings.size())


## The summary's headline: "TV ratings 9.5%", "11,400 views · 680 likes", "12,400 subscribers (+390) · 86,000 views".
static func headline(score: float, id: String, total: int = -1) -> String:
	return ("TV ratings " + text(score, id)) if bool(rung(id)["percent"]) else text(score, id, total)


## "Previously on…"'s card: "RATINGS 9.5%", "11.4K VIEWS", "12.4K SUBSCRIBERS".
static func card_text(score: float, id: String, total: int = -1) -> String:
	return ("RATINGS " + text(score, id)) if bool(rung(id)["percent"]) else "%s %s" % [short(score, id, total), str(rung(id)["english"]).to_upper()]


## Its words, in the rung's own terms (on TV, Ratings.band's).
static func band(score: float, id: String) -> String:
	var data := rung(id)
	if bool(data["percent"]):
		return Ratings.band(score)
	var k := Ratings.BANDS.size()
	for i in Ratings.BANDS.size():
		if score < float(Ratings.BANDS[i][0]):
			k = i
			break
	return str(data["bands"][k])


## The banner for a night worth shouting about (Ratings.banner), in the rung's own terms: off
## TV, a new best is the show's most views (자체 최고 조회수!), a hit has blown up (떡상!).
static func banner(score: float, before: Array, id: String) -> String:
	var tv := Ratings.banner(score, before)
	if tv == "" or bool(rung(id)["percent"]):
		return tv
	return VIEWS_RECORD_HANGUL if tv == Ratings.RECORD_HANGUL else VIEWS_HIT_HANGUL


## A banner's English, short, to read beside the Hangul ("떡상!" -> "blown up"); "" for none.
const BANNER_ENGLISH := {Ratings.RECORD_HANGUL: "best ever", Ratings.HIT_HANGUL: "double digits", Ratings.LEGEND_HANGUL: "past 20%",
	VIEWS_RECORD_HANGUL: "most views ever", VIEWS_HIT_HANGUL: "blown up"}


static func banner_english(shown: String) -> String:
	return str(BANNER_ENGLISH.get(shown, ""))


## The hover for a night's score on its rung: what its measure is, where the show is, the rule for
## moving up or down, then where tonight's came from (in points of the score).
static func hover(result: Dictionary, id: String) -> String:
	var data := rung(id)
	var score := float(result.get("rating", 0.0))
	var first := "%s (sicheongnyul): TV ratings, the share of Korea's TV homes watching." % Ratings.WORD if bool(data["percent"]) \
		else "%s %s" % [word(id), Hangul.MEANINGS.get(word(id), "")]
	var lines := ["%s %s" % [first, data["about"]], "Moving on: %s" % rule(id), "%s: %s" % [text(score, id, int(result.get("subscribers", -1))), band(score, id)]]
	for part in result.get("parts", []):
		lines.append("%s%.1f  %s" % ["+" if float(part[1]) >= 0.0 else "", float(part[1]), part[0]])
	return "\n".join(PackedStringArray(lines))


## The season's verdict on a rung: where the show goes, by the rung's rule. score: the season's
## (its average ratings with the bonuses, for TV); ratings: the season's nights (for its views);
## total: the channel's subscribers at the season's end; last: the previous season's outcome on
## this rung ("warned": a second quiet season goes down).
## Returns {"outcome" ("up", "top", "stay", "warned", "down"), "to" (the rung next season)}.
static func judge(score: float, id: String, last: String, ratings: Array = [], total: int = 0) -> Dictionary:
	var data := rung(id)
	if data.has("up_views"):
		return {"outcome": "up", "to": above(id)} if average_views(ratings, id) >= int(data["up_views"]) else {"outcome": "stay", "to": id}
	if data.has("up_subscribers"):
		if total >= int(data["up_subscribers"]):
			return {"outcome": "up", "to": above(id)}
		if total < int(data["down_subscribers"]):
			return {"outcome": "down", "to": below(id)} if last == "warned" else {"outcome": "warned", "to": id}
		return {"outcome": "stay", "to": id}
	if score >= float(data["hit_at"]):
		return {"outcome": "top", "to": id}
	if score < float(data["down_below"]):
		return {"outcome": "down", "to": below(id)} if last == "warned" else {"outcome": "warned", "to": id}
	return {"outcome": "stay", "to": id}
