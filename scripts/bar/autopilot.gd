extends RefCounted
## The autopilot PD: plays the PD's desk in an autoplay batch, so a test night tries the PD's
## parts too (the cards, the camera, pins, the edit, stepping in to cut the episode), not just
## the night itself. It only decides: visit.gd does what it decides through the same calls a
## player's clicks use (so what's tested is what a player gets). From its own dice, seeded from
## the bar and the night, so it never shifts anything else's rolls, and everything it does is
## marked as the autopilot's in the transcript and counted in the night's stats.

const Plants = preload("res://scripts/rules/plants.gd")

const FIRST_CARD := 19 * 60  # 7pm: no card before (the tent needs people in)
const LAST_CARD := 25 * 60  # 1am: every card's been tried by then
const RETRY_MINUTES := 20.0  # a card that can't be played yet (nobody with time left, already raining): again this much later
const GIVE_UP_AT := 27 * 60  # and not after 3am
const CAMERA_EVERY := 40.0  # game minutes between thoughts about the camera
const CAMERA_CHANCE := 0.6  # ... that it does something (follows someone, or stops)
const STOP_CHANCE := 0.3  # ... that it's to stop, if it's following someone
const PIN_CHANCE := 0.05  # each line said: kept for the episode
const MOST_PINS := 5  # (a fourth drops the oldest: a couple of those happen too)
const SPIN_CHANCE := 0.6  # an edit offered: a spin picked (otherwise the AI's goes out)
const STEP_IN_CHANCE := 0.6  # the next day: steps in to cut the episode
const SCENES_CHANCE := 0.5  # ... and chooses the scenes (the recap's rewritten from them)

## The write-ins' words: what a PD might type (checked like a player's, before it's played).
const WRITE_INS := {
	"cue_card": ["her first love", "the worst job they ever had", "what they'd do with a week off", "the last time they cried at a film",
		"a promise they never kept"],
	"interview": ["Who do you wish was sitting next to you tonight?", "What's the best thing that happened to you this week?",
		"What would you never say to their face?", "What are you really celebrating tonight?"],
	"text_from": ["we need to talk", "are you still up?", "I saw you today", "can I call you?", "you left your scarf here"],
	"gossip": ["the owner used to be a famous singer", "the shop next door's closing down", "someone on this street won the lottery last month",
		"the noraebang across the road is haunted"],
	"breaking_news": ["the subway's running all night from tomorrow", "it's going to snow all weekend", "soju's going up by 500 won",
		"a famous actor's opening a pocha down the road"],
	"quiz": ["Name three dramas with a piggyback scene", "What's the spiciest thing you've ever finished?", "Which song do you always sing at noraebang?",
		"Where in Seoul would you take someone on a first date?"],
}

var dice := RandomNumberGenerator.new()
var schedule: Array = []  # tonight's cards and when to play them: [{"card", "at"}], soonest first
var camera_next := 0.0  # game minutes: when it next thinks about the camera
## What it's done tonight, for the stats: how many cards played, camera moves, pins, spins
## picked, and whether it stepped in (and how) the next day.
var counts := {"cards": 0, "camera": 0, "pins": 0, "spins": 0, "stepped_in": "", "cut": {}}


## seed_text: the bar and night ("bar-1 night 3"), for its own dice.
func _init(seed_text: String = "") -> void:
	dice.seed = hash("autopilot " + seed_text)


## The night's opening: when to play each card in the hand, spread over the evening (or, when
## the crew take over part-way through a night, over what's left of it: never in the past).
func plan(hand: Array, now_minutes: float) -> void:
	schedule = []
	var earliest := maxi(FIRST_CARD, ceili(now_minutes) + 5)
	var latest := maxi(LAST_CARD, mini(earliest + 60, GIVE_UP_AT - 1))
	for card in hand:
		schedule.append({"card": str(card), "at": float(dice.randi_range(earliest, latest))})
	schedule.sort_custom(func(a, b): return float(a["at"]) < float(b["at"]))
	camera_next = maxf(now_minutes, FIRST_CARD - 30) + dice.randf_range(0.0, CAMERA_EVERY)


## The card that's due now: {"card", "text"} (the words, for a write-in), or {}.
func card_due(minutes: float) -> Dictionary:
	if schedule.is_empty() or minutes < float(schedule[0]["at"]):
		return {}
	var card := str(schedule[0]["card"])
	var text := ""
	if WRITE_INS.has(card):
		var words: Array = WRITE_INS[card]
		text = str(words[dice.randi_range(0, words.size() - 1)])
	return {"card": card, "text": text}


## A due card was tried: played (it's done), or not (again later, until it's too late).
func card_tried(card: String, played: bool, minutes: float) -> void:
	for item in schedule.duplicate():
		if str(item["card"]) != card:
			continue
		if played or minutes + RETRY_MINUTES > GIVE_UP_AT:
			schedule.erase(item)
		else:
			item["at"] = minutes + RETRY_MINUTES
	schedule.sort_custom(func(a, b): return float(a["at"]) < float(b["at"]))
	if played:
		counts["cards"] = int(counts["cards"]) + 1


## The camera, now and then: {"do": "follow", "who": k (of the people here)}, {"do": "stop"}, or {}.
func camera_due(minutes: float, people: int, following: bool) -> Dictionary:
	if minutes < camera_next:
		return {}
	camera_next = minutes + CAMERA_EVERY
	if dice.randf() >= CAMERA_CHANCE:
		return {}
	if following and dice.randf() < STOP_CHANCE:
		counts["camera"] = int(counts["camera"]) + 1
		return {"do": "stop"}
	if people == 0:
		return {}
	counts["camera"] = int(counts["camera"]) + 1
	return {"do": "follow", "who": dice.randi_range(0, people - 1)}


## A line's just been said: whether to pin it.
func pins_it() -> bool:
	if int(counts["pins"]) >= MOST_PINS or dice.randf() >= PIN_CHANCE:
		return false
	counts["pins"] = int(counts["pins"]) + 1
	return true


## An edit's offered (spins: how many): the spin to air (0 is the AI's own), or -1 to leave it.
func spin_for(spins: int) -> int:
	if spins <= 0 or dice.randf() >= SPIN_CHANCE:
		return -1
	counts["spins"] = int(counts["spins"]) + 1
	return dice.randi_range(0, spins - 1)


## The next day, as the bar opens: whether to step in and cut last night's episode.
func steps_in() -> bool:
	return dice.randf() < STEP_IN_CHANCE


## In the edit suite: what to pick. titles: how many the writers drafted (0: none to pick
## from); options: the cliffhangers the night can answer; scenes: how many could be ticked.
## {"title": k or -1 (leave it), "cliffhanger": k (0: the writers', then the game's), "scenes": [k...]}.
## Never its own words (a player's own title or teaser can't be checked against the night).
func cut_choices(titles: int, options: int, scenes: int) -> Dictionary:
	var chosen := {"title": dice.randi_range(0, titles - 1) if titles > 0 else -1, "cliffhanger": dice.randi_range(0, options), "scenes": []}
	if scenes > 0 and dice.randf() < SCENES_CHANCE:
		var all: Array = range(scenes)
		for _k in mini(dice.randi_range(1, 3), scenes):
			chosen["scenes"].append(all.pop_at(dice.randi_range(0, all.size() - 1)))
	counts["cut"] = {"title": chosen["title"], "cliffhanger": chosen["cliffhanger"], "scenes": chosen["scenes"].size()}
	return chosen
