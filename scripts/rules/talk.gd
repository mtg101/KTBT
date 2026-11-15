extends RefCounted
## Lines of dialogue: the checks every line passes, what conversations turn to, speech bubble
## pages, made-up Korean, and food moments.
## (Part of the game's rules: pure functions and the tables they use, with any dice rolls
## passed in, so they can be tested on their own. See ARCHITECTURE.md.)

const Address = preload("res://scripts/rules/address.gd")
const CatRules = preload("res://scripts/rules/cat_rules.gd")
const Menu = preload("res://scripts/menu.gd")
const Orders = preload("res://scripts/rules/orders.gd")
const Text = preload("res://scripts/rules/text.gd")


const MAX_LINE_LENGTH := 500


## For each spell of the owner's chat with someone, the game picks what it turns to, so a
## small model doesn't fuss over the food line after line (a bit of fussing is in character,
## so food stays one of the topics). Topic -> how the prompt puts it.
const OWNER_TOPICS := {
	"food": "what they're eating and drinking (fuss over them a little, as owners do)",
	"their_day": "how their day has gone",
	"on_their_mind": "what's really on their mind tonight, and why they came",
	"owner_story": "a short story from the owner's own life",
	"the_night": "the weather, the hour, or the street outside",
	"owner_secret": "something that hints at the owner's secret, without giving it away",
	"advice": "a bit of the owner's blunt advice about life",
	"the_cat": "the tent's cat",
	"last_time": "something the owner remembers from their last visit: ask how it turned out",
}


const OWNER_TOPIC_WEIGHTS := {"food": 1.0, "their_day": 2.0, "on_their_mind": 3.0, "owner_story": 1.5, "the_night": 1.0, "owner_secret": 0.5, "advice": 1.5, "the_cat": 1.0, "last_time": 0.0}


## What customers chatting to each other get on to.
const CHAT_TOPICS := {
	"why_here": "why they're each here tonight",
	"work": "work, or the lack of it",
	"the_night": "the weather, the hour, or the city",
	"food_drink": "what's good to eat and drink here",
	"life": "love, family, or where life is heading",
	"small_talk": "small talk: where they live, what they do for fun",
	"the_cat": "the tent's cat",
}


const CHAT_TOPIC_WEIGHTS := {"why_here": 2.0, "work": 1.5, "the_night": 1.0, "food_drink": 1.0, "life": 2.0, "small_talk": 1.5, "the_cat": 1.0}


## The topic for a spell of the owner's chat, from a random roll between 0 and 1. Food's
## likelier when something's just been served or is still cooking; the cat when it's with
## them (and never when there's no cat in the tent). Never the same topic twice running.
## cat: "none" (no cat, or it's out), "tent" (somewhere about) or "with_them".
## remembered: the owner remembers something from this regular's last visits, so it can come up.
static func pick_owner_topic(roll: float, food_news: bool, cat: String, last: String = "", remembered: bool = false) -> String:
	var weights := OWNER_TOPIC_WEIGHTS.duplicate()
	if remembered:
		weights["last_time"] = 3.0
	if food_news:
		weights["food"] = 3.0
	weights["the_cat"] = {"none": 0.0, "tent": 0.7, "with_them": 3.0}.get(cat, 0.0)
	return Text.pick_weighted(weights, roll, last)


static func pick_chat_topic(roll: float, cat: String, last: String = "") -> String:
	var weights := CHAT_TOPIC_WEIGHTS.duplicate()
	weights["the_cat"] = {"none": 0.0, "tent": 0.7, "with_them": 3.0}.get(cat, 0.0)
	return Text.pick_weighted(weights, roll, last)


## The game's steer for a line: "Let the conversation turn to: how their day has gone."
static func topic_hint(topic: String, chat: bool = false) -> String:
	var text: String = (CHAT_TOPICS if chat else OWNER_TOPICS).get(topic, "")
	return "Let the conversation turn to %s (naturally, following on from what was just said)." % text if text != "" else ""


## Terms for someone you're close to (and depending on who's speaking). Strangers at the
## counter, owner included, don't use them. Romanised spellings vary, so all are listed.
const CLOSE_TERMS := ["oppa", "orabeoni", "hyung", "hyeong", "nuna", "noona", "eonni", "unni", "onni"]


## The first close term in a line, or "" if there isn't one. names: the people in the
## conversation, removed first, so a name like Lee Hyung-jun doesn't count as "hyung".
static func close_term(line: String, names: Array = []) -> String:
	var text := line
	for person in names:
		var full := str(person)
		text = text.replacen(full, " ")
		var parts := full.split(" ", false)
		if parts.size() > 1:
			text = text.replacen(parts[parts.size() - 1], " ")
	var said := Text.words(text)
	for term in CLOSE_TERMS:
		if term in said:
			return term
	return ""


## A line of dialogue is {"line": "..."}. Tidies the usual small-model habits: a "Name:"
## prefix, quotes around the line, or carrying on to write the other person's reply.
## If items (what's on the table) is given, the line mustn't mention other menu items.
## A line of dialogue: {"line": "..."}. items: everything ordered by the people talking (a
## line can't mention food nobody ordered). names: the people in the conversation (for the
## check that strangers don't call each other oppa, hyung, nuna or eonni). cat: where the cat
## is, {"name", "spot", "with"} (see check_cat), or {} to skip that check.
## address: who's speaking to whom (see address_problem); empty for the older rule that
## strangers never use close terms.
static func validate_line(data: Variant, speaker: String, alias: String, items: Array = [], names: Array = [], cat: Dictionary = {}, address: Dictionary = {}) -> String:
	if typeof(data) != TYPE_DICTIONARY or not data.has("line"):
		return "it didn't include \"line\""
	var line := Text.tidy_text(data["line"])
	# Small models sometimes carry on and write the other person's reply too: keep the first part.
	var cut := line.find("\n")
	if cut > 0:
		line = line.substr(0, cut).strip_edges()
	# ...or start with "Name:". Strip that off.
	for prefix in [speaker, alias]:
		if prefix != "" and line.to_lower().begins_with(prefix.to_lower() + ":"):
			line = line.substr(prefix.length() + 1).strip_edges()
	line = Text.unquote(line)
	if line == "":
		return "the line was empty"
	if line.length() > MAX_LINE_LENGTH:
		return "the line was far too long"
	if not items.is_empty():
		var mention := Orders.unordered_mention(line, items)
		if mention != "":
			return "the line mentions %s, but that isn't on the table (%s)" % [mention, Orders.item_names(items)]
	# No asides in brackets: a small model adds "(translations)" or stage directions there.
	if line.contains("(") or line.contains(")"):
		return "the line has something in brackets: write only what's said, in English, with no translations or stage directions"
	var invented := romanised_korean(line, names + [speaker])
	if not invented.is_empty():
		return "the line has made-up Korean words in it (%s): everyone speaks fluent English here, with at most the odd Korean word a K-drama fan would know" % ", ".join(PackedStringArray(invented))
	if not address.is_empty():
		var wrong := Address.address_problem(line, address, names + [speaker])
		if wrong != "":
			return wrong
	var term := close_term(line, names + [speaker]) if address.is_empty() else ""
	if term != "":
		return "the line says \"%s\", but these people have only just met: strangers don't use oppa, hyung, nuna or eonni" % term
	if not cat.is_empty():
		var cat_problem := CatRules.check_cat(line, str(cat["name"]), str(cat["spot"]), str(cat["with"]), names + [speaker])
		if cat_problem != "":
			return cat_problem
	data["line"] = line
	return ""


const BUBBLE_PAGE := 190  # most of a line fits in one bubble: only long ones are paged


const BUBBLE_SHORT := 110  # up to this, a narrower bubble


## A line split into bubble-sized pages. Most lines fit in one; a long one is split where it
## overflows, at the last sentence end (or pause) in the page if there's one past halfway,
## never mid-word, with "…" where it carries on. A short leftover joins the page before.
static func bubble_pages(text: String, most: int = BUBBLE_PAGE) -> PackedStringArray:
	var pages := PackedStringArray()
	var page: Array = []  # words
	for word in Text.tidy_text(text).split(" ", false):
		if not page.is_empty() and " ".join(page).length() + 1 + word.length() > most:
			var cut := page.size()
			var length := 0
			for i in page.size():
				length += str(page[i]).length() + 1
				var w := str(page[i])
				if length >= most * 0.5 and (w.ends_with(".") or w.ends_with("?") or w.ends_with("!") or w.ends_with(",") or w.ends_with(";")):
					cut = i + 1
			pages.append(" ".join(page.slice(0, cut)))
			page = page.slice(cut)
		page.append(word)
	if not page.is_empty():
		pages.append(" ".join(page))
	if pages.size() > 1 and pages[pages.size() - 1].length() < 40 and pages[pages.size() - 2].length() + pages[pages.size() - 1].length() <= most + 40:
		pages[pages.size() - 2] = pages[pages.size() - 2] + " " + pages[pages.size() - 1]
		pages.resize(pages.size() - 1)
	for i in pages.size() - 1:
		pages[i] = pages[i].trim_suffix(",").trim_suffix(";") + "…"
	return pages


## How long a page stays up: long enough to read it.
static func page_seconds(page: String) -> float:
	return clampf(1.0 + page.length() * 0.045, 1.8, 5.5)


## Romanised Korean the dialogue may use: the odd word a K-drama fan would know, names of
## food and places, and how people address each other.
const KNOWN_KOREAN := ["ajumma", "ajusshi", "ajeossi", "imo", "samchon", "sajangnim", "seonsaengnim", "oppa", "hyung", "hyeong",
	"nuna", "noona", "eonni", "unni", "sunbae", "seonbae", "haksaeng", "agassi", "jeogiyo", "geonbae", "aigoo", "aigo",
	"daebak", "hwaiting", "gamsahamnida", "gomawo", "mianhae", "saranghae", "jinjja", "eomma", "appa", "omo", "aish",
	"seoul", "busan", "gangnam", "hongdae", "itaewon", "myeongdong", "jongno", "mapo", "euljiro", "pocha", "pojangmacha",
	"hoesik", "maknae", "satoori", "eomuk", "banchan", "kimchi", "chuseok", "seollal", "won"]


## English words that happen to look like romanised Korean (with "eo", "eu" or "ae" in them,
## or ending in "yo").
const ENGLISH_LOOKALIKES := ["people", "someone", "anyone", "everyone", "video", "theory", "neon", "leopard", "george",
	"geography", "meteor", "pigeon", "surgeon", "dungeon", "luncheon", "chameleon", "rodeo", "stereo", "neutral",
	"europe", "european", "queue", "feud", "pseudo", "amateur", "chauffeur", "entrepreneur", "liqueur", "milieu",
	"adieu", "lieu", "deuce", "sleuth", "euphoria", "eulogy", "michael", "israel", "aerial", "aesthetic", "maestro",
	"reggae", "theology", "geometry", "leon", "napoleon", "creole", "yeoman", "deodorant", "galleon", "peony", "eon", "eons"]


const MADE_UP_KOREAN_WORDS := 3  # this many romanised-looking words in a line, and it's made-up Korean


## The romanised-Korean-looking words in a line, if there are enough to be made-up Korean
## (a whole phrase rather than the odd word); [] otherwise. names: people's names, which are fine.
static func romanised_korean(line: String, names: Array = []) -> Array:
	var allowed := {}
	for word in KNOWN_KOREAN + ENGLISH_LOOKALIKES:
		allowed[word] = true
	for person in names:
		for part in Text.words(str(person)):
			allowed[part] = true
	for item in Menu.ITEMS:
		for part in Text.words(str(item["name"])):
			allowed[part] = true
	var found: Array = []
	for word in Text.words(line):
		if allowed.has(word) or word.length() < 3:
			continue
		if word.contains("eo") or word.contains("eu") or word.contains("ae") or (word.ends_with("yo") and word.length() > 3):
			found.append(word)
	return found if found.size() >= MADE_UP_KOREAN_WORDS else []


## Food is love: now and then, when a dish has just arrived, the next line of the owner's
## conversation gets one of these as a direction (the situation, never a phrase to say, so the
## AI finds its own words: "Look at you, eating properly for once!").
const FOOD_MOMENTS := [
	"The owner's watching them take the first bite.",
	"They're clearly enjoying the food, and it shows.",
	"They're eating like they haven't eaten all day.",
	"The owner can tell from their face how the food is.",
	"Feeding people is how the owner shows they care.",
]


const FOOD_MOMENT_CHANCE := 0.33
