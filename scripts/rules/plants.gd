extends RefCounted
## The PD's plant cards: a few a night, each one a thing that happens at the tent (a game fact,
## made true when it's played), never the words. Whether anything comes of it is the AI's:
## the people it happens to are told, as a moment for their next line, and the stats count
## whether they took it up (see Talk.HINT_TELLS, "plant_<card>"). Cards are data, so more can
## be added (and, later, written by players: see PLAN.md).

## How many cards the PD's dealt each night.
const Names = preload("res://scripts/rules/names.gd")

const HAND := 3

## title: on the card; about: its hover; moment: the situation given to whoever it happens to
## ({who}: their given name), for their next line; happened: what happened, as it goes in the
## conversation they say it in (so "reply to what just happened" covers it: a moment in the
## direction alone was ignored, as the table games' was); weather (the rain): what tonight becomes.
const CARDS := {
	"regular_in": {"title": "Send in a regular",
		"about": "Ring one of the bar's regulars who isn't here tonight, and ask them to come down.",
		"moment": "The show's PD rang {who} this evening and asked them to come down to the tent tonight, and here they are.",
		"happened": "{who} got a call from the show's PD this evening, asking them to come down to the tent tonight."},
	"rain": {"title": "Make it rain",
		"about": "Out of nowhere, a downpour: everyone at the counter's staying put for a while.",
		"weather": "a sudden downpour",
		"moment": "Out of nowhere it's started pouring down outside: the rain's drumming on the tarp.",
		"happened": "Out of nowhere, it's started pouring down outside."},
	"phone": {"title": "A phone rings",
		"about": "Someone's phone rings at the counter: whoever the camera's on, if they're here.",
		"moment": "{who}'s phone has just started ringing: they look to see who it is.",
		"happened": "{who}'s phone starts ringing."},
}


## Tonight's hand: HAND different cards, in the dice's order.
static func deal(dice: RandomNumberGenerator) -> Array:
	var cards: Array = CARDS.keys()
	for i in range(cards.size() - 1, 0, -1):
		var j := dice.randi_range(0, i)
		var swap: Variant = cards[i]
		cards[i] = cards[j]
		cards[j] = swap
	return cards.slice(0, HAND)


## Why a card can't be played right now ("" if it can). now: {"open" (the night's on and
## nobody's closing up), "seated" (people at the counter), "regulars_away" (regulars who
## aren't here or on their way), "weather_kind" (tonight's: NightRules.weather_kind)}.
static func why_not(card: String, now: Dictionary) -> String:
	if not bool(now.get("open", false)):
		return "Not now: the tent's not open for the night."
	match card:
		"regular_in":
			if int(now.get("regulars_away", 0)) == 0:
				return "No regulars to ring: they're all here, or on their way."
		"rain":
			if ["rain", "drizzle", "snow"].has(str(now.get("weather_kind", ""))):
				return "It's already wet out."
		"phone":
			if int(now.get("seated", 0)) == 0:
				return "Nobody at the counter."
	return ""


## What happened, for the conversation whoever it happened to speaks in next (who: their full name).
static func happened(card: String, who: String = "") -> String:
	return str(CARDS[card]["happened"]).replace("{who}", who)


## The moment for whoever a card happens to (who: their full name).
static func moment(card: String, who: String = "") -> String:
	return str(CARDS[card]["moment"]).replace("{who}", Names.given_name(who))
