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
const Talk = preload("res://scripts/rules/talk.gd")
const Text = preload("res://scripts/rules/text.gd")

## How many cards the PD's dealt each night: three events, one write-in and, always, a word
## from our sponsor (the PPL card).
const EVENTS := 3
const HAND := EVENTS + 2
const ALWAYS := "ppl"

## The show's sponsors, for the PPL card (a word from our sponsor): our own, made up, never a
## real brand or a near-copy (see CONCEPT.md). what: as it's put on someone's table; spellings:
## how lines might say it (so it's known, not made-up Korean, and explains itself on hover).
const SPONSORS := {
	"haejang_hero": {"name": "Haejang Hero", "hangul": "해장 히어로", "colour": "a0522d", "spellings": ["haejang hero", "haejang"],
		"means": "the show's sponsor: a hangover drink (해장, haejang: curing a hangover)",
		"what": "a little brown bottle of Haejang Hero, the hangover drink"},
	"glow_up": {"name": "Glow Up Mist", "hangul": "글로우업 미스트", "colour": "ff9ec7", "spellings": ["glow up mist", "glow up"],
		"means": "the show's sponsor: a face mist, \"for that 2am skin\"",
		"what": "a can of Glow Up Mist face spray"},
	"kkul_ginseng": {"name": "Kkul Ginseng Sticks", "hangul": "꿀 인삼 스틱", "colour": "c0392b", "spellings": ["kkul ginseng sticks", "kkul ginseng", "kkul"],
		"means": "the show's sponsor: honey red-ginseng sticks, for stamina (꿀, kkul: honey)",
		"what": "a box of Kkul Ginseng Sticks"},
	"banjjak": {"name": "Banjjak 9", "hangul": "반짝 9", "colour": "7fd8ff", "spellings": ["banjjak 9", "banjjak"],
		"means": "the show's sponsor: a phone (반짝, banjjak: sparkle)",
		"what": "a shiny new Banjjak 9 phone, still in its box"},
	"dalbit_taxi": {"name": "Dalbit Taxi", "hangul": "달빛 택시", "colour": "ffd23f", "spellings": ["dalbit taxi", "dalbit"],
		"means": "the show's sponsor: a taxi app (달빛, dalbit: moonlight)",
		"what": "a Dalbit Taxi keyring and a voucher for a ride home"},
}


## How many lines after a card's moment it stays on their minds ("lingers": the ex walking
## past is still there a few lines on, 17 Nov), so the talk can come back to it; 0 for most.
static func lingers(card: String) -> int:
	return int(CARDS.get(card, {}).get("lingers", 0))


## The sponsor's name for what was put on the table ("a little brown bottle of Haejang Hero…"
## is "Haejang Hero"), or "" if it isn't a sponsor's.
static func sponsor_name(what: String) -> String:
	for id in SPONSORS:
		if str(SPONSORS[id]["what"]) == what:
			return str(SPONSORS[id]["name"])
	return ""


## Write-in cards ("write"): the PD types what happens. label: what the box asks; hint: an
## example in the empty box; max: how long; steers: lines it stays the conversation's topic
## after the first (a cue card); from: what the PD's told before typing, for a card with
## variants ("a text from {what}": who it's from, picked before you write it, not after); {text}: what was typed, in the moment and what happened;
## shown: what the screen says, if not what happened (a text's words are only for its reader).

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
	"rain": {"title": "Make it rain", "for": "tent", "lingers": 2, "fact": "weather", "weather": "a sudden downpour",
		"about": "Out of nowhere, a downpour: everyone at the counter's staying put for a while.",
		"moment": "Out of nowhere it's started pouring down outside: the rain's drumming on the tarp.",
		"happened": "Out of nowhere, it's started pouring down outside."},
	"first_snow": {"title": "The first snow", "for": "tent", "lingers": 3, "fact": "first_snow", "winter": true,
		"about": "The first snow of winter starts to fall: they say if you're with someone when it does, it's meant to be.",
		"moment": "It's just started to snow outside: the first snow of winter.",
		"happened": "It's started to snow outside: the first snow of winter."},
	"phone": {"title": "A phone rings", "for": "someone", "lingers": 2,
		"about": "Someone's phone rings at the counter: their mum, an unknown number, the boss at this hour…",
		"variants": ["their mum", "an unknown number", "a number they deleted months ago", "their boss, at this hour",
			"an old friend they haven't heard from in years", "their ex", "their little brother, who only calls when he needs money"],
		"moment": "{who}'s phone has just started ringing: it's {what}.",
		"happened": "{who}'s phone starts ringing: it's {what}."},
	"text": {"title": "A text that changes everything", "for": "someone", "lingers": 3,
		"about": "Someone gets a text: just a few words, and their face changes. What it said is theirs to tell.",
		"variants": ["their ex", "their sister", "the bank", "their landlord", "a group chat that's suddenly going wild", "their mum", "a number they don't know"],
		"moment": "{who} has just read a text from {what}: only a few words, and their face has changed.",
		"happened": "{who}'s phone buzzes: a text from {what}. Only a few words, and their face changes."},
	"ex_walks_past": {"title": "The ex walks past", "for": "someone", "lingers": 3,
		"about": "Someone sees their ex walk past outside the tarp.",
		"variants": ["arm in arm with someone new", "alone, and looking thinner", "carrying a bunch of flowers", "laughing into their phone",
			"dressed for a wedding", "walking a dog they always said they'd never get"],
		"moment": "{who} has just seen their ex walk past outside the tarp, {what}.",
		"happened": "Someone walks past outside the tarp, and {who} freezes: it's their ex, {what}."},
	"round_on": {"title": "A round on them", "for": "someone", "lingers": 1, "fact": "round",
		"about": "Someone buys a bottle of soju for the whole counter (it goes on their bill).",
		"variants": ["they've just been promoted", "it's their birthday", "they've just quit their job", "they've won on a scratch card", "the night just feels right"],
		"moment": "{who} has just bought a bottle of soju for the whole counter, because {what}.",
		"others": "{who} has just bought a bottle of soju for the whole counter, everyone here included: it's only polite to thank them.",
		"happened": "{who} buys a bottle of soju for the whole counter: {what}."},
	"small_world": {"title": "Small world", "for": "pair", "lingers": 3,
		"about": "Two people at the counter work out they're connected: the same school, the same old job, the same street growing up…",
		"variants": ["went to the same school", "worked at the same company years ago", "grew up three streets apart in Jeju",
			"grew up in the same apartment block in Busan", "had the same terrifying maths teacher", "go to the same bathhouse every Sunday",
			"were in the same cram school as kids", "had the same first boss", "lived in the same goshiwon when they first came to Seoul",
			"both nearly married the same person"],
		"moment": "{who} and {other} have just worked out that they {what}.",
		"happened": "{who} and {other} have just worked out that they {what}."},
	"noraebang": {"title": "A song from across the street", "for": "tent", "lingers": 2,
		"about": "A song drifts over from the noraebang across the street.",
		"variants": ["An old trot song", "A 90s ballad", "A K-drama theme everyone knows", "Someone murdering a love song", "A duet nobody can stop listening to"],
		"moment": "{what} has started drifting over from the noraebang across the street.",
		"happened": "{what} starts drifting over from the noraebang across the street."},
	"ppl": {"title": "A word from our sponsor", "for": "someone", "fact": "sponsor", "sponsors": true,
		"about": "The show's sponsor needs a mention: someone's suddenly got the sponsor's product on their table, label to the camera (free: the sponsor's paying).",
		"moment": "The show's sponsor needs a mention: {who} has suddenly got {what} on their table, label turned to the camera, and the crew are waiting. They can gush about it, plug it badly, or refuse with a look at the crew: theirs to choose.",
		"happened": "A crew member slips {what} onto {who}'s table, label turned to the camera."},
	"cue_card": {"title": "Cue card", "for": "someone",
		"write": {"label": "The conversation turns to…", "hint": "her first love", "max": 80, "steers": 3},
		"about": "Hold up a cue card behind the camera: the conversation turns to whatever you write (theirs to take up, or not).",
		"moment": "Behind the camera, the show's PD is holding up a cue card for {who}: «{text}». It's theirs to take up, or not.",
		"happened": "Behind the camera, the PD holds up a cue card for {who}: «{text}»."},
	"interview": {"title": "Interview cut", "for": "someone",
		"write": {"label": "The PD asks…", "hint": "Who do you wish was sitting next to you tonight?", "max": 120, "steers": 0},
		"about": "Ask someone a question from behind the camera: they answer it straight to camera, like a variety show's interview cut.",
		"moment": "The show's PD has just asked {who} a question, off camera: «{text}». {who} answers it straight to the camera, the way people do in a variety show's interview cut, knowing everyone at the counter can hear.",
		"happened": "Off camera, the PD asks {who}: «{text}»."},
	"text_from": {"title": "A text from…", "for": "someone", "lingers": 2,
		"write": {"label": "The text says…", "hint": "we need to talk", "max": 80, "steers": 0, "from": "a text from {what}"},
		"variants": ["their ex", "their sister", "the bank", "their landlord", "their mum", "a number they don't know", "their boss"],
		"about": "Someone gets a text, and you write what it says (who it's from is the card's).",
		"moment": "{who}'s phone has just buzzed: a text from {what}. It says: «{text}». Their next line reacts to what it says (out loud, or to themselves).",
		"happened": "{who}'s phone buzzes: a text from {what}.",
		"shown": "{who}'s phone buzzes: a text from {what}. «{text}»"},
	"power_goes": {"title": "The power goes", "for": "tent", "lingers": 2, "fact": "lights",
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


## Tonight's hand: three events, one write-in (the PD's own words, every night) and the
## sponsor's card, all different and able to happen tonight, not last night's (unless there
## aren't enough without them), in the dice's order.
static func deal(dice: RandomNumberGenerator, tonight: Dictionary = {}, last: Array = []) -> Array:
	var possible: Array = CARDS.keys().filter(func(card): return dealable(card, tonight) and card != ALWAYS)
	var events := _pick(possible.filter(func(card): return not is_write(card)), last, dice, EVENTS)
	return events + _pick(possible.filter(func(card): return is_write(card)), last, dice, 1) + [ALWAYS]


static func _pick(cards: Array, last: Array, dice: RandomNumberGenerator, count: int) -> Array:
	var fresh: Array = _shuffled(cards.filter(func(card): return not last.has(card)), dice)
	var again: Array = _shuffled(cards.filter(func(card): return last.has(card)), dice)
	return (fresh + again).slice(0, count)


## What kind of card it is, as the desk shows it: "event" (something happens), "write" (the
## PD writes what happens) or "sponsor" (a word from our sponsor, every night).
static func kind_of(card: String) -> String:
	if bool(CARDS.get(card, {}).get("sponsors", false)):
		return "sponsor"
	return "write" if is_write(card) else "event"


## Each kind's tag on the desk, and the first line of its hover.
const KINDS := {
	"event": {"tag": "EVENT", "about": "An event: something happens, and whoever it happens to takes it up, or doesn't."},
	"write": {"tag": "WRITE-IN", "about": "A write-in: you write what happens, and the AI answers your words."},
	"sponsor": {"tag": "SPONSOR", "about": "The sponsor's card, every night: a word from our sponsor."},
}


## Whether the PD writes this card (see "write").
static func is_write(card: String) -> bool:
	return CARDS.has(card) and CARDS[card].has("write")


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
	if data.has("write") and not bool(now.get("online", true)):
		return "Needs the AI: offline, the pre-written lines can't answer what you write."
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


## What a card is this time (one of its variants, or for the PPL card, a sponsor's product),
## or "" for a card without them.
static func variant(card: String, dice: RandomNumberGenerator) -> String:
	var variants: Array = CARDS[card].get("variants", [])
	if bool(CARDS[card].get("sponsors", false)):
		variants = SPONSORS.values().map(func(s): return str(s["what"]))
	return str(variants[dice.randi_range(0, variants.size() - 1)]) if not variants.is_empty() else ""


## The moment for whoever a card happens to (who: their full name; other: the other of a pair;
## what: this time's variant; gender: theirs, for a card about one person, so it's "her ex",
## not "their ex").
static func moment(card: String, who: String = "", other: String = "", what: String = "", gender: String = "", text: String = "") -> String:
	return gendered(str(CARDS[card]["moment"]).replace("{who}", Names.given_name(who)).replace("{other}", Names.given_name(other)).replace("{what}", what), gender).replace("{text}", text)


## What everyone else at the counter's told, for a card that happens to one person (who: theirs).
static func others_moment(card: String, who: String) -> String:
	return str(CARDS[card].get("others", "")).replace("{who}", Names.given_name(who))


## What happened, for the conversation they speak in next, and the screen (full names).
static func happened(card: String, who: String = "", other: String = "", what: String = "", gender: String = "", text: String = "") -> String:
	return gendered(str(CARDS[card]["happened"]).replace("{who}", who).replace("{other}", other).replace("{what}", what), gender).replace("{text}", text)


## What the screen says a card did (for a text, its words too: only its reader sees them).
static func shown(card: String, who: String = "", what: String = "", gender: String = "", text: String = "") -> String:
	return gendered(str(CARDS[card].get("shown", CARDS[card]["happened"])).replace("{who}", who).replace("{what}", what), gender).replace("{text}", text)


## The sponsor whose product a PPL card put on the table (what: Plants.variant's), or {}.
static func sponsor_of(what: String) -> Dictionary:
	for id in SPONSORS:
		if str(SPONSORS[id]["what"]) == what:
			return SPONSORS[id]
	return {}


## What the PD's typed, tidied and checked: {"text", "problem"} ("" if it's fine). The game's
## own checks; the tent adds the real-brands one (Talk.real_brand). Never instructions to the
## AI: it goes into the scene as what happened, and every line written back is checked as ever.
static func check_written(card: String, typed: String) -> Dictionary:
	var text := " ".join(typed.replace("\n", " ").split(" ", false)).strip_edges()
	while text.length() > 0 and "\"'«»“”‘’()[]{}".contains(text.left(1)):
		text = text.substr(1)
	while text.length() > 0 and "\"'«»“”‘’()[]{}".contains(text.right(1)):
		text = text.left(text.length() - 1)
	text = text.replace("«", "").replace("»", "").replace("{", "(").replace("}", ")").strip_edges()
	var most := int(CARDS[card].get("write", {}).get("max", 80))
	if text.length() < 3:
		return {"text": text, "problem": "Write a few words first."}
	if text.length() > most:
		return {"text": text, "problem": "Too long: %d characters at most." % most}
	if Text.find_phrase(text, HARD_LIMITS) != "":
		return {"text": text, "problem": "That's not something the show can put on air."}
	if Talk.crosses_line(text) != "":
		return {"text": text, "problem": "Teasing's fine, but not about looks, bodies or anything crude."}
	return {"text": text, "problem": ""}


## Hard limits on what the PD can write, until the content setting (see PLAN.md, "Content
## boundaries"), which is the proper answer before anyone else plays: nothing sexual, and
## nothing about self-harm or suicide (the night isn't set up to treat those with the care
## they need).
const HARD_LIMITS := ["sex", "sexual", "naked", "nude", "porn", "orgasm", "rape", "suicide", "suicidal", "kill myself", "kill yourself",
	"kill themselves", "self-harm", "self harm", "cut myself"]

## Words too common to show a written card was taken up.
const COMMON_WORDS := ["the", "and", "about", "their", "they", "them", "that", "this", "with", "your", "what", "when", "where", "which",
	"would", "could", "should", "have", "from", "just", "like", "been", "were", "there", "here", "into", "some", "tonight", "really"]


## The words that show a line took up something the PD wrote: its longer words, not the
## commonest ("her first love": first, love).
static func written_tells(text: String) -> Array:
	var found: Array = []
	for word in text.to_lower().split(" ", false):
		var bare := ""
		for c in word:
			if (c >= "a" and c <= "z") or c == "'" or (c.unicode_at(0) >= 0xAC00 and c.unicode_at(0) <= 0xD7A3):  # (Hangul too, if that's what the PD wrote)
				bare += c
		if bare.length() >= 4 and not COMMON_WORDS.has(bare) and not found.has(bare):
			found.append(bare)
	return found


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
