extends RefCounted
## Regulars: who comes back, how often, and how they fade away. The game owns all of this;
## the AI only ever hears what it decides. Pure functions with their dice rolls passed in,
## so they can be tested exactly (and simulated over months: see simulate). The numbers
## come from a 100-night simulation (see PLAN.md): they settle at about ten regulars, and
## about three of a night's twenty customers.

const Memories = preload("res://scripts/rules/memories.gd")
const NightRules = preload("res://scripts/rules/night_rules.gd")

## How a visit went (from step 2 the AI judges this from the dialogue; for now the game does,
## from what happened: see game_verdict).
const VERDICTS := ["loved", "enjoyed", "fine", "didnt"]
## The chance a newcomer becomes a regular, by verdict (halved after a rushed visit).
const BECOME := {"loved": 0.10, "enjoyed": 0.04, "fine": 0.005, "didnt": 0.0}
const RUSHED_FACTOR := 0.5
## Pull: how strongly someone's drawn back, 0 to 1.
const NEW_PULL := 0.25
const FOUNDING_PULL := 0.8
const PULL_CHANGE := {"loved": 0.15, "enjoyed": 0.05, "fine": 0.0, "didnt": -0.15}
const RUSHED_PULL := -0.05
const FADE := 0.92  # pull kept for each night a regular stays away
const FOUNDING_FADE := 0.99
const DROP_BELOW := 0.1  # below this, they're no longer a regular
## The chance of coming in on a night is their pull, more on their favourite nights.
const FAVOURITE_NIGHT := 1.5
const OTHER_NIGHT := 0.7
const MOST_LIKELY := 0.95
## Someone who's just become a regular is keen: for their first week, until they've been back
## once, twice the chance (someone who's just found the place comes back soon).
const KEEN_NIGHTS := 7
const KEEN := 2.0
const USUAL_HOUR_SPREAD := 45.0  # game minutes either side of their usual hour
const USUAL_AFTER := 3  # the same first order this many times makes it their usual

## Founding regulars' roles in the tent: how the prompt puts it.
const ROLES := {
	"looks_out": "the one who looks out for people: helps a drunk customer into a taxi, tells off anyone bothering someone",
	"fixture": "the fixture on the end stool: quiet or grumpy, always there, and sees everything",
	"family": "like family to the owner, who fusses over them and scolds them like a niece or nephew",
	"knows_past": "the one who knows something of the owner's past, and lets slip the odd hint",
}
## How often a founding regular comes: [how the prompt puts it, favourite nights, visits a week].
const HABITS := [
	["most nights", 5, 4.0], ["a couple of nights a week", 2, 2.0], ["most Fridays", 1, 1.0],
	["most weekends", 2, 1.5], ["after work on weekdays, now and then", 3, 1.5],
]


## A newcomer's visit: do they become a regular? roll: 0 to 1.
static func becomes_regular(verdict: String, was_rushed: bool, roll: float) -> bool:
	var chance: float = BECOME.get(verdict, 0.0) * (RUSHED_FACTOR if was_rushed else 1.0)
	return roll < chance


## A regular's pull after a visit.
static func pull_after_visit(pull: float, verdict: String, was_rushed: bool) -> float:
	return clampf(pull + float(PULL_CHANGE.get(verdict, 0.0)) + (RUSHED_PULL if was_rushed else 0.0), 0.0, 1.0)


## A regular's pull after a night they didn't come.
static func pull_after_absence(pull: float, founding: bool) -> float:
	return pull * (FOUNDING_FADE if founding else FADE)


static func still_regular(pull: float) -> bool:
	return pull >= DROP_BELOW


## Whether a regular's still keen (see KEEN): new, back no more than once, within a week.
static func keen(regular: Dictionary, night: int) -> bool:
	return not bool(regular.get("founding", false)) and int(regular.get("visits", 0)) <= 1 \
		and night - int(regular.get("first_night", 0)) <= KEEN_NIGHTS


## The chance they come in tonight. day: 0 = Monday.
static func visit_chance(pull: float, day: int, favourite_days: Array, is_keen: bool = false) -> float:
	var favourite := false
	for d in favourite_days:  # (whole numbers come back from a save as 4.0)
		favourite = favourite or int(d) == day
	return minf(MOST_LIKELY, pull * (FAVOURITE_NIGHT if favourite else OTHER_NIGHT) * (KEEN if is_keen else 1.0))


## When they turn up, around their usual hour (game minutes), from a roll of 0 to 1.
static func arrival_time(usual_hour: int, roll: float) -> float:
	var when := float(usual_hour) + (clampf(roll, 0.0, 1.0) * 2.0 - 1.0) * USUAL_HOUR_SPREAD
	return clampf(when, float(NightRules.OPEN_MINUTES + 5), float(NightRules.LAST_ARRIVAL_MINUTES - 5))


## The game's own verdict on a visit, from what happened: the fallback when the AI's verdict
## (from the dialogue, with the memory) can't be had. _quick: a quick greeting (not used now:
## rushed visits are handled by Regulars.rushed).
static func game_verdict(owner_lines: int, chatted: bool, _quick: bool, company: String) -> String:
	# (Tuned from a night's stats: with about ten lines each, the first thresholds made most
	# visits "loved", and three new regulars in a night.)
	if owner_lines >= 14 or (company == "owner" and owner_lines >= 10):
		return "loved"
	if owner_lines >= 7 or chatted:
		return "enjoyed"
	if owner_lines >= 3:
		return "fine"
	return "didnt"


## Rushed: greeted in a hurry and hardly spoken to after.
static func rushed(quick: bool, owner_lines: int) -> bool:
	return quick and owner_lines <= 3


## Their usual: a first order they've had USUAL_AFTER times among their last few (or a
## founding regular's, which they've always had). [] if there isn't one yet.
static func usual_of(regular: Dictionary) -> Array:
	if not regular.get("usual", []).is_empty():
		return regular["usual"]
	var counts := {}
	for order in regular.get("orders", []):
		var key := ",".join(PackedStringArray(_sorted(order)))
		counts[key] = int(counts.get(key, 0)) + 1
		if int(counts[key]) >= USUAL_AFTER:
			return _sorted(order)
	return []


static func _sorted(items: Array) -> Array:
	var copy := items.duplicate()
	copy.sort()
	return copy


## How close they are to the owner, as a mark on their name tag.
static func closeness_mark(regular: Dictionary) -> String:
	if regular.is_empty():
		return ""
	var visits := int(regular.get("visits", 0))
	if bool(regular.get("founding", false)) or visits >= 12:
		return "★★"  # an old friend
	if visits >= 4:
		return "★"  # a regular
	return "☆"  # a familiar face


static func closeness_word(regular: Dictionary) -> String:
	return {"★★": "Old friend", "★": "Regular", "☆": "Familiar face"}.get(closeness_mark(regular), "")


## "last night", "3 nights ago", "a week ago", "about 3 weeks ago".
static func nights_ago_text(nights: int) -> String:
	if nights <= 1:
		return "last night"
	if nights < 7:
		return "%d nights ago" % nights
	if nights < 14:
		return "a week ago"
	if nights < 56:
		return "about %d weeks ago" % roundi(nights / 7.0)
	return "months ago"


## "1st", "2nd", "3rd", "4th"... (for "her 4th visit").
static func ordinal(n: int) -> String:
	var suffix := "th"
	if n % 100 < 11 or n % 100 > 13:
		suffix = {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")
	return "%d%s" % [n, suffix]


## A newcomer who's become a regular. night: the night number; day: 0 = Monday.
static func new_regular(customer: Dictionary, look: Dictionary, order: Array, night: int, day: int, arrived_minutes: int, other_day_roll: float) -> Dictionary:
	var other := (day + 1 + floori(clampf(other_day_roll, 0.0, 0.999) * 6.0)) % 7
	var regular := {
		"id": "%s-%d" % [str(customer.get("name", "someone")).to_lower().replace(" ", "-"), night],
		"founding": false, "role": "",
		"visits": 1, "first_night": night, "last_night": night, "pull": NEW_PULL,
		"favourite_days": [day, other], "usual_hour": arrived_minutes,
		"orders": [order.duplicate()], "usual": [],
		"owner_knows_name": false, "knows_owner_name": false,
		"look": look.duplicate(true),
	}
	for key in ["name", "hangul", "gender", "age", "job", "speech_style", "appearance"]:
		regular[key] = customer.get(key, "")
	return regular


## Dressed for tonight: the same person (hair, glasses, colours), but no T-shirt in the snow
## or padded coat on a muggy night.
static func dressed_for(look: Dictionary, weather: String) -> Dictionary:
	var tonight := look.duplicate(true)
	if weather in ["cold", "snow"] and tonight.get("clothes", "") in ["tshirt"]:
		tonight["clothes"] = "padded"
	elif weather == "muggy" and tonight.get("clothes", "") in ["padded", "knit", "trench"]:
		tonight["clothes"] = "tshirt"
	return tonight


## A whole run of nights with made-up verdicts, no scene and no AI: for the runaway test and
## for tuning. Returns {"counts": regulars on the books each night, "shares": their share of
## each night's arrivals (0 to 1), "founding_left": founding regulars still there at the end}.
static func simulate(seed_value: int, nights: int = 100, arrivals: int = 20) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var regulars: Array = []
	for i in 2:
		regulars.append({"pull": FOUNDING_PULL, "founding": true, "favourite_days": [rng.randi() % 7, rng.randi() % 7], "visits": 0, "first_night": 0})
	var counts: Array = []
	var shares: Array = []
	for night in nights:
		var day := night % 7
		var visiting: Array = []
		for regular in regulars:
			if rng.randf() < visit_chance(float(regular["pull"]), day, regular["favourite_days"], keen(regular, night)):
				visiting.append(regular)
		var newcomers := maxi(arrivals - visiting.size(), 8)
		for regular in regulars:
			if visiting.has(regular):
				regular["visits"] = int(regular["visits"]) + 1
				regular["pull"] = pull_after_visit(float(regular["pull"]), _made_up_verdict(rng.randf()), rng.randf() < 0.3)
			else:
				regular["pull"] = pull_after_absence(float(regular["pull"]), bool(regular["founding"]))
		for k in newcomers:
			if becomes_regular(_made_up_verdict(rng.randf()), rng.randf() < 0.3, rng.randf()):
				regulars.append({"pull": NEW_PULL, "founding": false, "favourite_days": [day, rng.randi() % 7], "visits": 1, "first_night": night})
		regulars = regulars.filter(func(r): return still_regular(float(r["pull"])))
		counts.append(regulars.size())
		shares.append(float(visiting.size()) / float(visiting.size() + newcomers))
	return {"counts": counts, "shares": shares, "founding_left": regulars.filter(func(r): return r["founding"]).size()}


## A fifth loved it, two fifths enjoyed it, three tenths thought it was fine, a tenth didn't.
static func _made_up_verdict(roll: float) -> String:
	if roll < 0.2:
		return "loved"
	if roll < 0.6:
		return "enjoyed"
	if roll < 0.9:
		return "fine"
	return "didnt"


# --- Memories ------------------------------------------------------------------------------

const RECENT_MEMORIES := 3  # visits remembered clearly; older ones blur into one impression
const MAX_IMPRESSION := 320


## A visit remembered (from validate_memory): the newest few kept as they are, older ones
## blurring into one overall impression (just their first sentence, and only so much of it),
## and the things that stick replacing what they replace. Changes the regular in place.
static func remember(regular: Dictionary, night: int, memory: Dictionary) -> void:
	var memories: Array = regular.get("memories", [])
	memories.append({"night": night, "owner": str(memory.get("owner_remembers", "")), "them": str(memory.get("they_remember", ""))})
	while memories.size() > RECENT_MEMORIES:
		var oldest: Dictionary = memories.pop_front()
		var gist := str(oldest["owner"]).get_slice(". ", 0).trim_suffix(".") + "."
		var impression := (str(regular.get("impression", "")) + " " + gist).strip_edges()
		while impression.length() > MAX_IMPRESSION and impression.contains(". "):
			impression = impression.substr(impression.find(". ") + 2)  # the oldest bit goes first
		regular["impression"] = impression
	regular["memories"] = memories
	var facts: Dictionary = regular.get("facts", {})
	for key in Memories.STICKING:
		if str(memory.get(key, "")) != "":
			facts[key] = str(memory[key])
	regular["facts"] = facts
