extends RefCounted
## The ladder, simulated: many shows played through many seasons in a moment, with no scene and
## no AI, to see how the ladder's paced (rules/ladder.gd, rules/show_seasons.gd). Each night's
## score is drawn from a model of a PD (a mean and a spread, fitted to real nights: the autopilot
## PD's 31 nights by 20 Nov averaged 9.8, spread 2.0), and everything else is the game's own
## rules: the episodes, the subscribers won and lost, the verdicts and the moves. As the regulars
## have their simulation (regulars.gd), so the ladder can be tuned without hours of autoplay.
## (Part of the game's rules: pure functions, the dice passed in. See ARCHITECTURE.md.)

const Ladder = preload("res://scripts/rules/ladder.gd")
const ShowSeasons = preload("res://scripts/rules/show_seasons.gd")

## Kinds of PD: [mean, spread] of a night's score. The autopilot's from its real nights.
const PDS := {"quiet": [5.0, 2.5], "steady": [7.5, 2.5], "autopilot": [9.8, 2.0], "great": [12.0, 2.0]}
const LOWEST := 0.8  # (Ratings.LOWEST: never quite nobody)


## Plays shows through seasons from the phone stream. Returns {"shows", "seasons", "reached"
## (rung -> [the season each show first got there, or -1]), "drops" (moves down, all shows),
## "final" (rung -> how many shows ended there), "paths" (each show's rung each season)}.
static func run(dice: RandomNumberGenerator, mean: float, spread: float, seasons: int, shows: int) -> Dictionary:
	var reached := {}
	var final := {}
	for rung in Ladder.RUNGS:
		reached[str(rung["id"])] = []
		final[str(rung["id"])] = 0
	var drops := 0
	var paths: Array = []
	for s in shows:
		var show := ShowSeasons.fresh(Ladder.FIRST)
		var before: Array = []
		var first := {Ladder.FIRST: 1}
		var path: Array = []
		var night := 0
		for season in range(1, seasons + 1):
			var rung := ShowSeasons.rung_of(show)
			path.append(rung)
			if not first.has(rung):
				first[rung] = season
			for k in ShowSeasons.EPISODES:
				night += 1
				var rating := snappedf(maxf(dice.randfn(mean, spread), LOWEST), 0.1)
				if Ladder.counts_subscribers(rung):
					show["subscribers"] = Ladder.subscribers_after(int(show.get("subscribers", 0)), rating, rung)
				ShowSeasons.record(show, night, rating)
			var judged := ShowSeasons.verdict(season, show["ratings"], before, show["seasons"], rung, int(show.get("subscribers", 0)))
			before.append_array(show["ratings"])
			if str(judged["outcome"]) == "down":
				drops += 1
			ShowSeasons.end_season(show, judged)
		for rung in Ladder.RUNGS:
			reached[str(rung["id"])].append(int(first.get(str(rung["id"]), -1)))
		final[ShowSeasons.rung_of(show)] += 1
		paths.append(path)
	return {"shows": shows, "seasons": seasons, "reached": reached, "drops": drops, "final": final, "paths": paths}


## Of the shows that got to a rung, the middle season they got there in (-1: none did).
static func median_season(result: Dictionary, rung: String) -> int:
	var got: Array = result["reached"][rung].filter(func(s): return int(s) > 0)
	if got.is_empty():
		return -1
	got.sort()
	return int(got[got.size() / 2])


## How many of the shows got to a rung within so many seasons (0 to 1).
static func share_by(result: Dictionary, rung: String, seasons: int) -> float:
	var got: Array = result["reached"][rung].filter(func(s): return int(s) > 0 and int(s) <= seasons)
	return float(got.size()) / maxi(int(result["shows"]), 1)


## How many seasons the shows that climbed a rung spent on the one below it, the middle of them
## (-1: none climbed it). "network": seasons on the channel before TV.
static func median_climb(result: Dictionary, rung: String) -> int:
	var below := Ladder.below(rung)
	var spent: Array = []
	for k in int(result["shows"]):
		var start := int(result["reached"][below][k])
		var got := int(result["reached"][rung][k])
		if start > 0 and got > 0:
			spent.append(got - start)
	if spent.is_empty():
		return -1
	spent.sort()
	return int(spent[spent.size() / 2])


## The report, a line a rung: "online video channel: 98% got there · seasons on the rung below
## to climb it: 1 (median) · after 1 season 60%, 2: 95%, 3: 98%".
static func report(result: Dictionary, label: String = "") -> String:
	var lines := PackedStringArray(["%s%d shows, %d seasons each:" % [(label + ": ") if label != "" else "", int(result["shows"]), int(result["seasons"])]])
	for rung in Ladder.RUNGS.slice(1):
		var id := str(rung["id"])
		var median := median_season(result, id)
		var climb := median_climb(result, id)
		lines.append("  %s: %d%% got there%s%s · after 1 season %d%%, 2: %d%%, 3: %d%%, 4: %d%%" % [rung["short"],
			roundi(share_by(result, id, int(result["seasons"])) * 100.0), (", after %d seasons (median)" % (median - 1)) if median > 0 else "",
			(" · %d on the rung below to climb it (median)" % climb) if climb > 0 else "",
			roundi(share_by(result, id, 2) * 100.0), roundi(share_by(result, id, 3) * 100.0), roundi(share_by(result, id, 4) * 100.0), roundi(share_by(result, id, 5) * 100.0)])
	var ends := PackedStringArray()
	for rung in Ladder.RUNGS:
		ends.append("%s %d" % [rung["short"], int(result["final"][str(rung["id"])])])
	lines.append("  moves down: %d · ended on: %s" % [int(result["drops"]), ", ".join(ends)])
	return "\n".join(lines)
