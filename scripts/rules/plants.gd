extends RefCounted
## The PD's plant cards: three a night, dealt from a pack, each one a thing that happens at the
## tent, never the words. A **situation** card is something that happens to someone (or two
## people, or the whole tent): they're told it in whichever conversation they speak in next,
## as what just happened, and as a moment for their line; whether anything comes of it is the
## AI's. A **fact** card also changes something the game owns (the weather, an arrival, a
## bottle on someone's bill), made true when it's played (see the tent's _on_plant_pressed).
## The stats count whether they're taken up (see Talk.HINT_TELLS, "plant_<card>"). Cards are
## data, so more can be added (and, later, written by players: see PLAN.md).

const Names = preload("res://scripts/rules/names.gd")

## How many cards the PD's dealt each night.
const HAND := 3

## title: on the card; about: its hover; for: who it happens to ("someone": whoever the
## camera's on, or someone picked; "pair": them and who they're chatting with; "tent":
## everyone; "nobody": a fact with nobody in particular); fact: what the tent's code makes true
## (none: a situation); moment: the situation given to whoever it happens to, for their next
## line ({who}: their given name; {other}: the other of a pair); happened: what happened, as
## it goes in the conversation they say it in, and on screen ({who}, {other}: full names);
## others: for "someone" cards, what everyone else at the counter's told ({who}: theirs);
## weather: what tonight becomes; winter: dealt only in winter, before its first snow;
## variants: what it is this time ({what}), one picked as it's played, so a card isn't the
## same every time (later, perhaps, the PD's to write: see PLAN.md).
## (A moment in the direction alone was ignored, as the table games' was: what happened, in
## the conversation, is what gets a reply.)
const CARDS := {
	"regular_in": {"title": "Send in a regular", "for": "nobody", "fact": "regular_in",
		"about": "Ring one of the bar's regulars who isn't here tonight, and ask them to come down.",
		"moment": "{who} is only here tonight because the show's PD rang them this evening and asked them to come down to the tent.",
		"happened": "{who} got a call from the show's PD this evening, asking them to come down to the tent tonight."},
	"rain": {"title": "Make it rain", "for": "tent", "fact": "weather", "weather": "a sudden downpour",
		"about": "Out of nowhere, a downpour: everyone at the counter's staying put for a while.",
		"moment": "Out of nowhere it's started pouring down outside: the rain's drumming on the tarp.",
		"happened": "Out of nowhere, it's started pouring down outside."},
	"first_snow": {"title": "The first snow", "for": "tent", "fact": "first_snow", "winter": true,
		"about": "The first snow of winter starts to fall: they say if you're with someone when it does, it's meant to be.",
		"moment": "It's just started to snow outside: the first snow of winter.",
		"happened": "It's started to snow outside: the first snow of winter."},
	"phone": {"title": "A phone rings", "for": "someone",
		"about": "Someone's phone rings at the counter: their mum, an unknown number, the boss at this hour…",
		"variants": ["their mum", "an unknown number", "a number they deleted months ago", "their boss, at this hour",
			"an old friend they haven't heard from in years", "their ex", "their little brother, who only calls when he needs money"],
		"moment": "{who}'s phone has just started ringing: it's {what}.",
		"happened": "{who}'s phone starts ringing: it's {what}."},
	"text": {"title": "A text that changes everything", "for": "someone",
		"about": "Someone gets a text: just a few words, and their face changes. What it said is theirs to tell.",
		"variants": ["their ex", "their sister", "the bank", "their landlord", "a group chat that's suddenly going wild", "their mum", "a number they don't know"],
		"moment": "{who} has just read a text from {what}: only a few words, and their face has changed.",
		"happened": "{who}'s phone buzzes: a text from {what}. Only a few words, and their face changes."},
	"ex_walks_past": {"title": "The ex walks past", "for": "someone",
		"about": "Someone sees their ex walk past outside the tarp.",
		"variants": ["arm in arm with someone new", "alone, and looking thinner", "carrying a bunch of flowers", "laughing into their phone",
			"dressed for a wedding", "walking a dog they always said they'd never get"],
		"moment": "{who} has just seen their ex walk past outside the tarp, {what}.",
		"happened": "Someone walks past outside the tarp, and {who} freezes: it's their ex, {what}."},
	"round_on": {"title": "A round on them", "for": "someone", "fact": "round",
		"about": "Someone buys a bottle of soju for the whole counter (it goes on their bill).",
		"variants": ["they've just been promoted", "it's their birthday", "they've just quit their job", "they've won on a scratch card", "the night just feels right"],
		"moment": "{who} has just bought a bottle of soju for the whole counter, because {what}.",
		"others": "{who} has just bought a bottle of soju for the whole counter, everyone here included: it's only polite to thank them.",
		"happened": "{who} buys a bottle of soju for the whole counter: {what}."},
	"small_world": {"title": "Small world", "for": "pair",
		"about": "Two people at the counter work out they're connected: the same school, the same old job, the same street growing up…",
		"variants": ["went to the same school", "worked at the same company years ago", "grew up three streets apart in Jeju",
			"grew up in the same apartment block in Busan", "had the same terrifying maths teacher", "go to the same bathhouse every Sunday",
			"were in the same cram school as kids", "had the same first boss", "lived in the same goshiwon when they first came to Seoul",
			"both nearly married the same person"],
		"moment": "{who} and {other} have just worked out that they {what}.",
		"happened": "{who} and {other} have just worked out that they {what}."},
	"noraebang": {"title": "A song from across the street", "for": "tent",
		"about": "A song drifts over from the noraebang across the street.",
		"variants": ["An old trot song", "A 90s ballad", "A K-drama theme everyone knows", "Someone murdering a love song", "A duet nobody can stop listening to"],
		"moment": "{what} has started drifting over from the noraebang across the street.",
		"happened": "{what} starts drifting over from the noraebang across the street."},
	"power_goes": {"title": "The power goes", "for": "tent", "fact": "lights",
		"about": "The tent's lights run off a long extension lead from the shop next door: for a moment, they go out.",
		"variants": ["someone's tripped over the extension lead", "the fryer and the heater were on at once", "the shop next door's closing up and unplugged them",
			"the battery's run flat, and the owner's swapping it"],
		"moment": "The tent's power has just cut out for a moment ({what}), then come back on.",
		"happened": "The tent's lights go out: {what}. A moment later, they're back on."},
}


## Whether a card could happen tonight at all (tonight: {"winter", "snowed" (this winter's
## first snow's been), "wet" (tonight's raining or snowing already)}). One that can't happen
## *yet* is dealt anyway (see why_not).
static func dealable(card: String, tonight: Dictionary) -> bool:
	var data: Dictionary = CARDS[card]
	if bool(data.get("winter", false)) and (not bool(tonight.get("winter", false)) or bool(tonight.get("snowed", false)) or bool(tonight.get("wet", false))):
		return false
	if str(data.get("fact", "")) == "weather" and bool(tonight.get("wet", false)):
		return false
	return true


## Tonight's hand: HAND different cards that could happen tonight, not last night's (unless
## there aren't enough without them), in the dice's order.
static func deal(dice: RandomNumberGenerator, tonight: Dictionary = {}, last: Array = []) -> Array:
	var possible: Array = CARDS.keys().filter(func(card): return dealable(card, tonight))
	var fresh: Array = _shuffled(possible.filter(func(card): return not last.has(card)), dice)
	var again: Array = _shuffled(possible.filter(func(card): return last.has(card)), dice)
	return (fresh + again).slice(0, HAND)


static func _shuffled(cards: Array, dice: RandomNumberGenerator) -> Array:
	var out := cards.duplicate()
	for i in range(out.size() - 1, 0, -1):
		var j := dice.randi_range(0, i)
		var swap: Variant = out[i]
		out[i] = out[j]
		out[j] = swap
	return out


## Why a card can't be played right now ("" if it can). now: {"open" (the night's on and
## nobody's closing up), "seated" (people at the counter), "pairable" (two who could chat:
## already, or getting talking),
## "regulars_away" (regulars who aren't here or on their way), "weather_kind" (tonight's)}.
static func why_not(card: String, now: Dictionary) -> String:
	if not bool(now.get("open", false)):
		return "Not now: the tent's not open for the night."
	var data: Dictionary = CARDS[card]
	if card == "regular_in" and int(now.get("regulars_away", 0)) == 0:
		return "No regulars to ring: they're all here, or on their way."
	if str(data.get("fact", "")) == "weather" and ["rain", "drizzle", "snow"].has(str(now.get("weather_kind", ""))):
		return "It's already wet out."
	if card == "first_snow" and str(now.get("weather_kind", "")) == "snow":
		return "It's already snowing."
	match str(data["for"]):
		"someone":
			if int(now.get("seated", 0)) < (2 if str(data.get("fact", "")) == "round" else 1):
				return "Nobody at the counter." if int(now.get("seated", 0)) == 0 else "Nobody else at the counter to buy for."
		"pair":
			if not bool(now.get("pairable", false)):
				return "Not two at the counter who'd chat (with time left for it)."
		"tent":
			if int(now.get("seated", 0)) == 0 and str(data.get("fact", "")) == "":
				return "Nobody at the counter."
	return ""


## What a card is this time (one of its variants), or "" for a card without them.
static func variant(card: String, dice: RandomNumberGenerator) -> String:
	var variants: Array = CARDS[card].get("variants", [])
	return str(variants[dice.randi_range(0, variants.size() - 1)]) if not variants.is_empty() else ""


## The moment for whoever a card happens to (who: their full name; other: the other of a pair;
## what: this time's variant; gender: theirs, for a card about one person, so it's "her ex",
## not "their ex").
static func moment(card: String, who: String = "", other: String = "", what: String = "", gender: String = "") -> String:
	return gendered(str(CARDS[card]["moment"]).replace("{who}", Names.given_name(who)).replace("{other}", Names.given_name(other)).replace("{what}", what), gender)


## What everyone else at the counter's told, for a card that happens to one person (who: theirs).
static func others_moment(card: String, who: String) -> String:
	return str(CARDS[card].get("others", "")).replace("{who}", Names.given_name(who))


## What happened, for the conversation they speak in next, and the screen (full names).
static func happened(card: String, who: String = "", other: String = "", what: String = "", gender: String = "") -> String:
	return gendered(str(CARDS[card]["happened"]).replace("{who}", who).replace("{other}", other).replace("{what}", what), gender)


## "their" and "they" made "her" and "she" (or "his", "he"), for something about one woman
## (or man); anyone else, or "", keeps "they".
static func gendered(text: String, gender: String) -> String:
	if gender != "woman" and gender != "man":
		return text
	var she := gender == "woman"
	var words := {"they've": "she's" if she else "he's", "they're": "she's" if she else "he's", "they'd": "she'd" if she else "he'd",
		"they": "she" if she else "he", "their": "her" if she else "his", "them": "her" if she else "him", "themselves": "herself" if she else "himself"}
	var out := text
	for word in words:
		out = RegEx.create_from_string("\\b%s\\b" % word).sub(out, str(words[word]), true)
		var capital := str(word).capitalize()
		out = RegEx.create_from_string("\\b%s\\b" % capital).sub(out, str(words[word]).capitalize(), true)
	return out
