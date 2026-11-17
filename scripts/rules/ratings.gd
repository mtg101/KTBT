extends RefCounted
## The show's ratings (시청률, sicheongnyul): every night is an episode, and at 3am it gets a
## Korean TV rating, the share of Korea's TV homes said to be watching (as Nielsen Korea
## measures real shows). Ours is a late-night show on a cable channel, where a few percent is
## an ordinary night, double digits is a hit and 20% is the stuff of legend. It's worked out
## from what happened (tonight's events, NightEvents.timeline): the big moments that got a
## reaction (each worth a little less than the last), a mix of moods (as aired, so the PD's
## spin counts), last time's cliffhanger coming true, regulars' stories carrying on, the
## night's happenings, the PD's cards taken up, and a little luck. Then the last few nights'
## ratings nudge how busy the bar is, a little: it's still mostly about the cosy.
## (Part of the game's rules: pure functions and the tables they use, with any dice rolls
## passed in, so they can be tested on their own. See ARCHITECTURE.md.)

const NightRules = preload("res://scripts/rules/night_rules.gd")

const BASE := 1.5  # every episode airs to someone
const LOWEST := 0.8  # and never quite nobody

## Each big moment (a TV reaction shown) is worth a little less than the one before.
const MOMENT := 1.2
const MOMENT_FADE := 0.8
## Each mood beyond the first among them (a laugh and a tear beat three tears), up to a point.
const MOOD_MIX := 0.8
const MOOD_MIX_MOST := 2.4
const CLIFFHANGER := 2.5  # last time's teaser came true: the audience was waiting for that
const REGULAR_IN := 0.3  # each regular back tonight (people follow their stories)
const REGULARS_MOST := 1.5
const NEW_REGULAR := 0.8  # someone looks like becoming a regular
const NEW_REGULARS_MOST := 1.6
const FRIENDLIER := 0.6  # two people on closer terms
const FRIENDLIER_MOST := 1.2
const CARD_TAKEN_UP := 0.5  # a PD's card the people it happened to took up
const CARDS_MOST := 1.5
## The night's happenings, once each a night.
const HAPPENINGS := {"full_house": 0.6, "table_game": 0.5, "cat_stole": 0.4, "first_snow": 1.0, "cheered_on": 0.4}
const LUCK := 1.6  # from -0.8 to +0.8: some nights the other channels have the football

## Where a rating sits: [below this, its words]. 20% and over is legendary.
const BANDS := [[4.5, "a quiet night for the show"], [8.0, "a good episode"], [10.0, "nearly double digits"], [20.0, "double digits: a hit!"]]
const LEGENDARY := "over 20%: the stuff of legend"
const HIT := 10.0
const LEGEND := 20.0
const RECORD_AFTER := 2  # a new best only counts as one with a couple of rated nights before it

## The banner on the diary page, as Hangul: what it means is in Hangul.MEANINGS.
const RECORD_HANGUL := "자체 최고 시청률!"
const HIT_HANGUL := "두 자릿수!"
const LEGEND_HANGUL := "시청률 20% 돌파!"
const WORD := "시청률"

## How much the last few nights' ratings change how many customers come by: about ±10% at
## most, from the average of the last NUDGE_NIGHTS rated nights (an ordinary 6% changes nothing).
const NUDGE_NIGHTS := 3
const NUDGE_MIDDLE := 6.0
const NUDGE_PER_POINT := 0.025
const NUDGE_MOST := 0.1


## Tonight's rating, from tonight's events and anything else the game knows (context:
## "cards_taken_up", how many of the PD's cards were taken up). roll: 0 to 1, the luck.
## Returns {"rating" (a percent, one decimal place), "parts": [[what, points]...] (biggest
## first, for the hover and the log), "band" (its words)}.
static func score(events: Array, context: Dictionary = {}, roll: float = 0.5) -> Dictionary:
	var moments := 0
	var moods: Array = []
	var regulars: Array = []
	var new_regulars := 0
	var friendlier := 0
	var cliffhanger := false
	var happened: Array = []
	for event in events:
		var kind := str(event.get("kind", ""))
		match kind:
			"big_moment":
				moments += 1
				var mood := str(event.get("mood", ""))  # (as aired: the PD's spin is what the audience saw)
				if mood != "" and not moods.has(mood):
					moods.append(mood)
			"paid":
				var who := str(event.get("name", ""))
				if str(event.get("regular", "")) != "" and not regulars.has(who):
					regulars.append(who)
			"became_regular":
				new_regulars += 1
			"friendlier":
				friendlier += 1
			"cliffhanger_answered":
				cliffhanger = true
			"sat_down":
				if int(event.get("seated", 0)) >= NightRules.SEATS and not happened.has("full_house"):
					happened.append("full_house")
			_:
				if HAPPENINGS.has(kind) and not happened.has(kind):
					happened.append(kind)
	var parts: Array = []
	var moment_points := 0.0
	for k in moments:
		moment_points += MOMENT * pow(MOMENT_FADE, k)
	_add(parts, "%d big %s" % [moments, "moment" if moments == 1 else "moments"], moment_points)
	_add(parts, "a mix of %d moods" % moods.size(), minf(maxf(moods.size() - 1, 0) * MOOD_MIX, MOOD_MIX_MOST))
	_add(parts, "last time's cliffhanger came true", CLIFFHANGER if cliffhanger else 0.0)
	_add(parts, "%d %s back" % [regulars.size(), "regular" if regulars.size() == 1 else "regulars"], minf(regulars.size() * REGULAR_IN, REGULARS_MOST))
	_add(parts, "%d new %s" % [new_regulars, "regular" if new_regulars == 1 else "regulars"], minf(new_regulars * NEW_REGULAR, NEW_REGULARS_MOST))
	_add(parts, "%d on closer terms" % friendlier, minf(friendlier * FRIENDLIER, FRIENDLIER_MOST))
	var cards := int(context.get("cards_taken_up", 0))
	_add(parts, "%d of the PD's %s taken up" % [cards, "card" if cards == 1 else "cards"], minf(cards * CARD_TAKEN_UP, CARDS_MOST))
	for kind in happened:
		_add(parts, HAPPENING_WORDS[kind], HAPPENINGS[kind])
	parts.sort_custom(func(a, b): return float(a[1]) > float(b[1]))
	var luck := (clampf(roll, 0.0, 1.0) - 0.5) * LUCK
	var total := BASE + luck
	for part in parts:
		total += float(part[1])
	var rating := snappedf(maxf(total, LOWEST), 0.1)
	parts.append(["luck (what else was on)", snappedf(luck, 0.1)])
	return {"rating": rating, "parts": parts, "band": band(rating)}


const HAPPENING_WORDS := {"full_house": "a full house", "table_game": "a drinking game", "cat_stole": "the cat's theft", "first_snow": "the first snow",
	"cheered_on": "the whole counter cheering"}


static func _add(parts: Array, what: String, points: float) -> void:
	if points > 0.0:
		parts.append([what, snappedf(points, 0.1)])


## Its words: "a good episode".
static func band(rating: float) -> String:
	for each in BANDS:
		if rating < float(each[0]):
			return str(each[1])
	return LEGENDARY


## "6.4%"
static func percent_text(rating: float) -> String:
	return "%.1f%%" % rating


## The banner for a night worth shouting about, as Hangul ("" for none): a new best for the
## show beats a hit, which beats nothing. before: the earlier nights' ratings (any order).
static func banner(rating: float, before: Array) -> String:
	if is_record(rating, before):
		return RECORD_HANGUL
	if rating >= LEGEND:
		return LEGEND_HANGUL
	if rating >= HIT:
		return HIT_HANGUL
	return ""


## A new best: higher than every earlier night, with a couple of rated nights before it.
static func is_record(rating: float, before: Array) -> bool:
	if before.size() < RECORD_AFTER:
		return false
	for earlier in before:
		if float(earlier) >= rating:
			return false
	return true


## The rated nights' ratings from the bar's night log (older nights, before ratings, have none).
static func from_log(night_log: Array) -> Array:
	return night_log.filter(func(n): return n.has("ratings")).map(func(n): return float(n["ratings"]))


## How much busier (or quieter) tonight is from the last few nights' ratings: a multiplier for
## how often customers arrive, from 0.9 to 1.1. No rated nights yet: 1.
static func busier(ratings: Array) -> float:
	var recent := ratings.slice(-NUDGE_NIGHTS)
	if recent.is_empty():
		return 1.0
	var total := 0.0
	for each in recent:
		total += float(each)
	var average := total / recent.size()
	return snappedf(clampf(1.0 + (average - NUDGE_MIDDLE) * NUDGE_PER_POINT, 1.0 - NUDGE_MOST, 1.0 + NUDGE_MOST), 0.01)


## The hover for a rating: what ratings are, then where tonight's came from.
static func hover(result: Dictionary) -> String:
	var lines := ["%s (sicheongnyul): TV ratings, the share of Korea's TV homes watching. For a late-night cable show, a few percent is an ordinary night, 10%% is a hit." % WORD,
		"%s: %s" % [percent_text(float(result.get("rating", 0.0))), result.get("band", "")]]
	for part in result.get("parts", []):
		lines.append("%s%.1f  %s" % ["+" if float(part[1]) >= 0.0 else "", float(part[1]), part[0]])
	return "\n".join(PackedStringArray(lines))


## One line for the log and the stats: "6.4% (a good episode): +2.1 2 big moments, +0.8 ..."
static func log_text(result: Dictionary) -> String:
	var parts: Array = result.get("parts", []).map(func(p): return "%s%.1f %s" % ["+" if float(p[1]) >= 0.0 else "", float(p[1]), p[0]])
	return "%s (%s): %s" % [percent_text(float(result.get("rating", 0.0))), result.get("band", ""), ", ".join(PackedStringArray(parts))]
