extends RefCounted
## Customers coming in together: the game decides it (now and then a new customer comes in with
## someone; two close regulars come in as a pair), what they are to each other, and how they'll
## pay (one for both, a fight over the bill settled by kawi-bawi-bo, or split). The AI only
## invents who they are, told how they know each other. Pairs for now; threes and fours later.
## (Part of the game's rules: pure functions with any dice rolls passed in, so they can be
## tested on their own. See ARCHITECTURE.md.)

const PAIR_CHANCE := 0.2  # a new customer comes in with someone

## What two people coming in together can be to each other: how likely, whether they're close
## (friendly terms, teasing, talking casually), how the prompt and the transcript put it, what
## the second one is to the first, and how they pay (the chance of each).
const KINDS := {
	"couple": {"chance": 0.3, "close": true, "text": "a couple out together", "is": "partner",
		"pay": {"one_pays": 0.6, "fight": 0.15, "split": 0.25}},
	"colleagues": {"chance": 0.25, "close": false, "text": "two colleagues who've slipped away from a hoesik (a work dinner) for a quieter drink", "is": "colleague",
		"pay": {"one_pays": 0.2, "fight": 0.45, "split": 0.35}},
	"school_friends": {"chance": 0.25, "close": true, "text": "old school friends catching up", "is": "old school friend",
		"pay": {"one_pays": 0.2, "fight": 0.6, "split": 0.2}},
	"sunbae": {"chance": 0.2, "close": false, "text": "a sunbae (a senior from work or school) taking their hoobae (junior) out", "is": "hoobae (junior)",
		"pay": {"one_pays": 0.85, "fight": 0.15, "split": 0.0}},
}
## Two close regulars coming in together (not decided here: they're friends already).
const REGULARS := {"close": true, "text": "two regulars who are friends, coming in together", "is": "friend from the counter",
	"pay": {"one_pays": 0.3, "fight": 0.5, "split": 0.2}}
const SAME_SEX_COUPLE := 0.1
const AGE_ORDER := ["20s", "30s", "40s", "50s", "60s", "70s"]


## What a pair is, by the dice.
static func pick(roll: float) -> String:
	var total := 0.0
	for kind in KINDS:
		total += float(KINDS[kind]["chance"])
		if roll < total:
			return kind
	return KINDS.keys()[-1]


## A pair's facts ({} for a kind there isn't): KINDS's, or REGULARS's.
static func info(kind: String) -> Dictionary:
	return REGULARS if kind == "regulars" else KINDS.get(kind, {})


## How they'll pay: "one_pays", "fight" or "split".
static func pay_style(kind: String, roll: float) -> String:
	var total := 0.0
	var pay: Dictionary = info(kind).get("pay", {"split": 1.0})
	for style in pay:
		total += float(pay[style])
		if roll < total:
			return style
	return "split"


## The second one's gender: a couple's usually the other one's opposite; otherwise either.
static func second_gender(kind: String, first: String, roll: float, any_roll: float) -> String:
	if kind == "couple" and first in ["woman", "man"]:
		var other := "man" if first == "woman" else "woman"
		return first if roll < SAME_SEX_COUPLE else other
	return "woman" if any_roll < 0.5 else "man"


## The second one's age range: a hoobae a range younger than their sunbae (if there is one);
## a couple, colleagues and school friends about the same.
static func second_age_range(kind: String, first: String, roll: float) -> String:
	var at := AGE_ORDER.find(first)
	if at < 0:
		return first
	if kind == "sunbae":
		return AGE_ORDER[maxi(0, at - 1)]
	if kind == "colleagues" and roll < 0.4:  # (a colleague can be a little older or younger)
		return AGE_ORDER[clampi(at + (1 if roll < 0.2 else -1), 0, AGE_ORDER.size() - 1)]
	return first


## For the second one's prompt: who they came in with, and what they are to each other.
static func note(kind: String, with_name: String) -> String:
	return "They've come in with %s: %s, and they know each other well (by name)." % [with_name, info(kind).get("text", "together")]


## For the transcript: what the second one is to the first.
static func is_to(kind: String) -> String:
	return str(info(kind).get("is", "companion"))


## Who pays when one pays for both: the sunbae (the first one), or for anyone else, by the dice.
static func payer(kind: String, roll: float) -> int:
	if kind == "sunbae":
		return 0
	return 0 if roll < 0.5 else 1


## Kawi-bawi-bo (rock, paper, scissors): who loses, and pays for both.
static func bill_fight_loser(roll: float) -> int:
	return 0 if roll < 0.5 else 1
