extends RefCounted
## Lines of dialogue: the checks every line passes, what conversations turn to, speech bubble
## pages, made-up Korean, and food moments.
## (Part of the game's rules: pure functions and the tables they use, with any dice rolls
## passed in, so they can be tested on their own. See ARCHITECTURE.md.)

const Address = preload("res://scripts/rules/address.gd")
const CatRules = preload("res://scripts/rules/cat_rules.gd")
const Menu = preload("res://scripts/rules/menu.gd")
const Orders = preload("res://scripts/rules/orders.gd")
const Text = preload("res://scripts/rules/text.gd")
const Names = preload("res://scripts/rules/names.gd")
const Catalogue = preload("res://scripts/rules/catalogue.gd")
const Glossary = preload("res://scripts/rules/glossary.gd")


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


## The PD's cue card, as a conversation's topic for a few lines (text: what the PD wrote).
static func cue_hint(text: String) -> String:
	return "The PD's cue card is still up behind the camera: «%s». Let the conversation turn to it, if it does (naturally, following on from what was just said)." % text


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
	var brand := real_brand(line)
	if brand != "":
		return "the line names a real brand (%s): describe it instead (\"mix coffee\", \"the green bottle\", \"the convenience store\")" % brand
	var dark := dark_idiom(line)
	if dark != "":
		return "the line says \"%s\": too dark a turn of phrase for a cosy tent bar, even said lightly: say it another way" % dark
	var given := freebie(line)
	if given != "":
		return "the line gives something away (\"%s\"): nothing here is free but the banchan, and the bill is the game's: leave prices and paying out of it" % given
	var elsewhere := off_menu_here(line)
	if elsewhere != "":
		return "the line talks about %s as if it's served here, but it isn't on the menu: talk about it only as somewhere else's, or someone's cooking at home" % elsewhere
	# No asides in brackets: a small model adds "(translations)" or stage directions there.
	if line.contains("(") or line.contains(")"):
		return "the line has something in brackets: write only what's said, in English, with no translations or stage directions"
	var invented := made_up_korean(line, names + [speaker])
	if invented != "":
		return invented
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


## Brands people might name, which the game never shows (see CONCEPT.md, "Real people, brands
## and shows"): soju, beer, coffee and snack makers, shops and big companies. Real people can't
## be listed reliably, so they're kept out by the style guide. Lower case, whole words.
## (Not ones with digits, "GS25" or "7-Eleven": words lose their digits here, so they'd match
## "eleven". Not ones that are ordinary words or names too: Orion, Kia.)
const REAL_BRANDS := ["chamisul", "jinro", "chum churum", "cheoeum cheoreom", "good day soju", "hite", "cass", "terra",
	"kloud", "maxim", "kanu", "starbucks", "ediya", "mega coffee", "paik's", "emart", "e-mart", "lotte", "olive young",
	"daiso", "samsung", "hyundai", "lg", "kakao", "kakaotalk", "naver", "coupang", "baemin", "binggrae", "nongshim",
	"shin ramyun", "choco pie", "pepero", "bacchus", "chilsung", "milkis", "melona", "honey butter chip",
	# Apps, sites and shops anyone would know (and the biggest pop acts: real people).
	"instagram", "insta", "facebook", "youtube", "tiktok", "netflix", "twitter", "whatsapp", "google", "iphone",
	"uber", "spotify", "amazon", "discord", "mcdonald's", "kfc", "gs25", "seven eleven", "tving",
	"disney", "bts", "blackpink"]


## Turns of phrase too dark for a cosy tent bar, even said lightly ("a job that doesn't make you
## want to jump off a bridge"). Real sadness is fine; these images aren't.
const DARK_IDIOMS := ["jump off a bridge", "jump off the bridge", "jump off a roof", "jump off the roof",
	"kill myself", "kill yourself", "end it all", "want to die", "wanna die", "slit my wrists", "hang myself",
	"shoot myself", "off myself"]


## A dark turn of phrase the text uses, or "" (see DARK_IDIOMS).
static func dark_idiom(text: String) -> String:
	var lower := " " + " ".join(Text.words(text.replace("'", ""))) + " "
	for idiom in DARK_IDIOMS:
		if lower.contains(" " + " ".join(Text.words(str(idiom))) + " "):
			return str(idiom)
	return ""


## Giving something away: only the bill decides what's paid for, and the owner doesn't give
## the tent's food and drink away (and a customer certainly can't).
const FREEBIE_PHRASES := ["on the house", "free of charge", "no charge", "free for first-timers", "free for first timers"]


static func freebie(text: String) -> String:
	var lower := " " + " ".join(Text.words(text)) + " "
	for phrase in FREEBIE_PHRASES:
		if lower.contains(" " + " ".join(Text.words(str(phrase))) + " "):
			return str(phrase)
	return ""


## A brand the text names, or "" (see REAL_BRANDS).
static func real_brand(text: String) -> String:
	var lower := " " + " ".join(Text.words(text.replace("'", "").replace("-", " "))) + " "
	for brand in REAL_BRANDS:
		var wanted := " " + " ".join(Text.words(str(brand).replace("'", "").replace("-", " "))) + " "
		if lower.contains(wanted):
			return str(brand)
	return ""


## Korean dishes that aren't on the menu (yet: menus will differ by bar). People may talk
## about them (their mum's kimchi jjigae, lunch at work), but not as if they're served here.
## (Not mandu or hotteok: they're favourite names for cats.)
const OFF_MENU_DISHES := ["bibimbap", "bulgogi", "samgyeopsal", "galbi", "kalbi", "kimbap", "gimbap", "japchae", "jjigae",
	"naengmyeon", "jjajangmyeon", "jajangmyeon", "jjamppong", "chimaek", "budae", "samgyetang",
	"gopchang", "makchang", "jokbal", "bossam", "sundubu", "haejangguk", "gukbap", "tangsuyuk", "dakbal"]
## Words that put a dish here: ordering it, the menu, serving it, or "the"/"your" one.
const SERVED_HERE_WORDS := ["order", "ordered", "ordering", "orders", "menu", "serve", "serves", "served", "special"]
const HERE_BEFORE_DISH := ["the", "your", "this", "that", "another", "more"]


## A dish that isn't on the menu, talked about as if it's served here ("My friend ordered
## the bibimbap"), or "".
static func off_menu_here(line: String) -> String:
	var said := Text.words(line)
	var served_here := SERVED_HERE_WORDS.any(func(word): return word in said)
	# Not this bar's: the list above, and any catalogue dish it doesn't serve (another bar's) ...
	var elsewhere: Array = OFF_MENU_DISHES + Catalogue.off_menu_words()
	# ... but never a word of tonight's menu (a bar with kimchi-jjigae serves jjigae).
	var ours := {}
	for item in Menu.items():
		for called in [str(item["name"]), str(item.get("word", ""))] + Array(item.get("aliases", [])):
			for part in Text.words(str(called)):
				ours[part] = true
	for i in said.size():
		if elsewhere.has(said[i]) and not ours.has(said[i]) and (served_here or (i > 0 and HERE_BEFORE_DISH.has(said[i - 1]))):
			return said[i]
	return ""


const MADE_UP_KOREAN_WORDS := 3  # this many romanised-looking words in a line, and it's made-up Korean
## ...or one that ends like a Korean verb, which no English word does ("haetjuseyo", and
## "norahae", a garbled 노래해 "sing", said three times in one night). A real one
## ("annyeonghaseyo", "gomawoyo") is in the glossary, so it's fine.
const KOREAN_ENDINGS := ["seyo", "nida", "haeyo", "jiyo", "eoyo", "deyo", "hae"]


## The romanised-Korean-looking words in a line, if there are enough to be made-up Korean
## (a whole phrase rather than the odd word); [] otherwise. names: people's names, which are fine.
## The problem with a line that has made-up Korean in it, or "" (for the order checks too).
static func made_up_korean(line: String, names: Array = []) -> String:
	var invented := romanised_korean(line, names)
	if invented.is_empty():
		return ""
	return "the line has made-up Korean words in it (%s): everyone speaks fluent English here, with at most the odd Korean word a K-drama fan would know" % ", ".join(PackedStringArray(invented))


static func romanised_korean(line: String, names: Array = []) -> Array:
	var allowed := {}
	for word in KNOWN_KOREAN + ENGLISH_LOOKALIKES:
		allowed[word] = true
	for person in names:
		for part in Text.words(str(person)):
			allowed[part] = true
	for item in Catalogue.all():  # (every pocha dish is real Korean, served here or not)
		for part in Text.words(str(item["name"])):
			allowed[part] = true
	for item in Menu.items():
		for part in Text.words(str(item["name"])):
			allowed[part] = true
	for spelling in Glossary.lookup():  # every Korean word the game knows is real
		for part in Text.words(str(spelling)):
			allowed[part] = true
	var found: Array = []
	var verb_ending := false
	for word in Text.words(line):
		if allowed.has(word) or word.length() < 3:
			continue
		if word.contains("eo") or word.contains("eu") or word.contains("ae") or (word.ends_with("yo") and word.length() > 3):
			found.append(word)
		if word.length() >= 6 and KOREAN_ENDINGS.any(func(ending): return word.ends_with(ending)):
			if not found.has(word):
				found.append(word)
			verb_ending = true
	return found if found.size() >= MADE_UP_KOREAN_WORDS or verb_ending else []


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


## How someone orders, now and then, as a situation (never a line to say): left to itself, a
## small model opened most orders the same way ("Ajumma, I'll have a..." 67 times in 115). Each
## has "when" it can happen, so it's only ever true: "any", "usual" (a regular who has a
## usual), "first" (their first time here), "late" (after midnight).
const ORDER_MOMENTS := [
	{"when": "any", "text": "They know exactly what they want: they've been thinking about it all the way here."},
	{"when": "any", "text": "They're torn between two dishes, and might ask the owner to choose."},
	{"when": "any", "text": "They ask what's good tonight before deciding."},
	{"when": "any", "text": "They're so tired they barely look at the menu."},
	{"when": "any", "text": "They're in a good mood tonight, and it shows in how they order."},
	{"when": "any", "text": "Money's a bit tight this week, so they keep it simple."},
	{"when": "any", "text": "They're still half in their own thoughts as they order."},
	{"when": "usual", "text": "They're a regular with a usual, and the owner may already be reaching for it."},
	{"when": "usual", "text": "They're a regular, and fancy trying something other than their usual tonight."},
	{"when": "first", "text": "It's their first time here: they read the menu properly before ordering."},
	{"when": "late", "text": "It's late, and they just want something hot and quick."},
]
const ORDER_MOMENT_CHANCE := 0.5  # (half the time: the AI's own way of ordering stays in the mix)


## Now and then, a situation for someone's order, or "". usual: they're a regular with a
## usual; first: their first visit; late: after midnight. roll: whether there's one; which:
## which of those that fit.
static func order_moment(usual: bool, first: bool, late: bool, roll: float, which: float) -> String:
	if roll >= ORDER_MOMENT_CHANCE:
		return ""
	var fits := ORDER_MOMENTS.filter(func(m): return m["when"] == "any" or (m["when"] == "usual" and usual) \
		or (m["when"] == "first" and first) or (m["when"] == "late" and late))
	return str(fits[mini(int(which * fits.size()), fits.size() - 1)]["text"])


## A craving, now and then, for someone's order (a K-drama favourite: rain means pajeon, a bad
## day means something fiery). "when": "any", "rough" (a rough night for them), "cold" (a cold
## or snowy night), "rain", "warm" (a muggy or breezy one), "company" (they're up for company).
const CRAVINGS := [
	{"when": "any", "text": "They've been craving something spicy all day."},
	{"when": "any", "text": "They want something that tastes like home cooking."},
	{"when": "any", "text": "They fancy something crispy."},
	{"when": "any", "text": "They only want something small to go with their drink."},
	{"when": "rough", "text": "After the day they've had, they want something fiery enough to sweat it out."},
	{"when": "rough", "text": "Tonight they want comfort food, nothing fancy."},
	{"when": "cold", "text": "They're chilled through and want something hot."},
	{"when": "rain", "text": "Rain like this always makes them crave pajeon and makgeolli."},
	{"when": "warm", "text": "It's too warm for anything heavy."},
	{"when": "company", "text": "They're in the mood for something to share."},
]
const CRAVING_CHANCE := 0.35


## Now and then, a craving for someone's order, or "" (see CRAVINGS). weather: NightRules.weather_kind.
static func craving(weather: String, rough: bool, company: bool, roll: float, which: float) -> String:
	if roll >= CRAVING_CHANCE:
		return ""
	var cold := weather in ["cold", "snow"]
	var rain := weather in ["rain", "drizzle"]
	var warm := weather in ["muggy", "breeze"]
	var fits := CRAVINGS.filter(func(c): return c["when"] == "any" or (c["when"] == "rough" and rough) or (c["when"] == "cold" and cold) \
		or (c["when"] == "rain" and rain) or (c["when"] == "warm" and warm) or (c["when"] == "company" and company))
	return str(fits[mini(int(which * fits.size()), fits.size() - 1)]["text"])


## How the owner opens, now and then, once someone's drinks are down (situations again: the owner
## said "You look like you've been..." 18 times in six nights). "when" as for ORDER_MOMENTS,
## plus "rain" (it's wet out) and "regular" (anyone the owner knows).
const OPENER_MOMENTS := [
	{"when": "any", "text": "The owner sets the banchan down first and lets them settle before saying anything much."},
	{"when": "any", "text": "The owner notices something about them: what they're carrying, what they're wearing, how they sat down."},
	{"when": "any", "text": "The owner's in the middle of something at the stove and talks over their shoulder."},
	{"when": "any", "text": "The owner says something about what they ordered."},
	{"when": "rain", "text": "They've come in out of the wet, and the owner can see it."},
	{"when": "late", "text": "It's late, and the owner wonders out loud what's kept them out."},
	{"when": "regular", "text": "The owner picks up from something they remember about them from before."},
	{"when": "first", "text": "A new face: the owner's curious about them."},
]
const OPENER_MOMENT_CHANCE := 0.6


## Now and then, a situation for the owner's first proper word with someone, or "".
static func opener_moment(regular: bool, first: bool, late: bool, wet: bool, roll: float, which: float) -> String:
	if roll >= OPENER_MOMENT_CHANCE:
		return ""
	var fits := OPENER_MOMENTS.filter(func(m): return m["when"] == "any" or (m["when"] == "regular" and regular) \
		or (m["when"] == "first" and first) or (m["when"] == "late" and late) or (m["when"] == "rain" and wet))
	return str(fits[mini(int(which * fits.size()), fits.size() - 1)]["text"])


## Things that go with a particular dish or drink, as situations: never a line to say
## (asked to say "make ssam" outright, a small model says it in every line). They hand the
## AI the table customs (pouring for each other, mixing somaek, wrapping ssam) and leave
## whether anyone mentions them up to the conversation.
const SERVED_MOMENTS := {
	"soju": [
		"Here nobody pours their own glass: you fill other people's, and they fill yours.",
		"The soju's ice cold: the first glass of the night always goes down well.",
	],
	"somaek": [
		"Somaek gets mixed at the table: a shot of soju dropped into the beer, and some people make a little show of it.",
		"Everyone has their own idea of the perfect soju-to-beer ratio for somaek.",
	],
	"beer": ["The beer's cold enough to fog the glass."],
	"makgeolli": [
		"Makgeolli settles in the bottle, so it gets a gentle swirl before it's poured.",
		"Makgeolli and pajeon go together, especially when it's raining.",
	],
	"dakgalbi": ["The dakgalbi comes with lettuce leaves on the side, for wrapping each bite into ssam."],
	"sundae": ["The sundae comes with a little dish of salt to dip it in."],
	"ramyeon": ["The ramyeon comes in the pot it was cooked in: people here eat it off the pot lid."],
	"pajeon": ["The pajeon gets torn apart with chopsticks and shared: the crispy edges go first."],
	"tteokbokki": ["The tteokbokki is properly spicy, and the sauce is good for dipping other things in."],
	"odeng": ["The odeng broth gets topped up for free, and it warms you right through."],
}


## Now and then (FOOD_MOMENT_CHANCE), a situation for the line after something's served:
## mostly one about what just arrived, otherwise (for food) a general one. roll decides
## whether there is one, which decides which.
static func served_moment(ids: Array, roll: float, which: float) -> String:
	if roll >= FOOD_MOMENT_CHANCE:
		return ""
	var specific: Array = []
	var any_food := false
	for id in ids:
		specific.append_array(SERVED_MOMENTS.get(id, []))
		any_food = any_food or Menu.find(id).get("kind", "") == "food"
	var general: Array = FOOD_MOMENTS if any_food else []
	var pool: Array = specific if not specific.is_empty() and (which < 0.65 or general.is_empty()) else general
	if pool.is_empty():
		return ""
	return str(pool[mini(int(which * pool.size()), pool.size() - 1)])


## What kind of hint a served or sharing moment is, for the stats: the menu id it's about,
## "food" (a general food moment), "more_food", "pour" or "close"; "" if it's neither.
static func moment_kind(moment: String) -> String:
	for id in SERVED_MOMENTS:
		if SERVED_MOMENTS[id].has(moment):
			return id
	if FOOD_MOMENTS.has(moment):
		return "food"
	for kind in SHARING_KINDS:
		if _matches_template(moment, SHARING_KINDS[kind]):
			return kind
	return ""


## Words that show a line took a hint up (rough: for the stats, not a check). A kind with
## none (the general food moments) is never counted as taken or not.
const HINT_TELLS := {
	"soju": ["pour", "glass", "cold"], "somaek": ["somaek", "mix", "ratio", "drop"], "beer": ["cold", "fog"],
	"makgeolli": ["swirl", "shake", "pajeon", "rain"], "dakgalbi": ["ssam", "lettuce", "wrap"],
	"sundae": ["salt"], "ramyeon": ["lid"], "pajeon": ["crisp", "edge", "tear"], "tteokbokki": ["spicy", "sauce", "dip"],
	"odeng": ["broth", "warm"], "more_food": ["share", "have some", "try", "take some", "help yourself"],
	"pour": ["pour", "top up", "top you up", "fill", "glass"], "close": ["bite", "feed", "try this", "say ah", "aah", "open"],
	"cat": ["kitty", "puss", "good girl", "good boy", "get down", "get off", "little one", "you little", "naughty", "meow"],  # (and its name)
	"stunned": ["mwo", "heol", "what", "jinjja", "really", "seriously", "wait", "no way"],
	"camera": ["camera", "film", "on tv", "episode", "crew", "broadcast"],
	"plant_regular_in": ["rang", "phoned", "called me", "invited", "producer", "pd", "on tv", "camera", "episode"],
	"plant_rain": ["rain", "pour", "umbrella", "wet", "soaked", "downpour", "drumming", "tarp"],
	"plant_phone": ["phone", "call", "ring", "answer", "text", "message", "mum", "mom", "boss", "eomma", "brother", "number", "ignore"],
	"plant_first_snow": ["snow", "first snow", "wish", "winter", "snowflake"],
	"plant_text": ["text", "message", "read", "says", "wrote", "phone", "who was that"],
	"plant_ex_walks_past": ["ex", "was that", "saw", "outside", "used to", "go after", "my heart", "with someone", "flowers", "wedding", "dog"],
	"plant_round_on": ["thank", "thanks", "on me", "round", "generous", "jjan", "geonbae", "cheers", "kind of you", "congratulations", "promoted", "birthday", "quit", "celebrate"],
	"plant_small_world": ["small world", "same", "no way", "remember", "school", "classmate", "sunbae", "hoobae", "teacher", "company", "jeju", "busan", "bathhouse", "boss", "goshiwon", "neighbour", "neighbor"],
	"plant_noraebang": ["song", "sing", "ballad", "noraebang", "karaoke", "music", "voice", "this song", "trot", "duet", "theme", "off-key", "tune"],
	"plant_ppl": ["sponsor", "plug", "label", "advert", "ad", "haejang", "glow up", "mist", "ginseng", "kkul", "banjjak", "dalbit", "taxi", "phone"],
	"plant_cue_card": ["cue card"],  # (and the words the PD wrote: see Plants.written_tells)
	"plant_interview": ["honestly", "to be honest", "camera", "truth", "if i'm honest"],
	"plant_text_from": ["text", "message", "phone", "read", "says"],
	"plant_power_goes": ["lights", "light", "dark", "power", "bulb", "cable", "lead", "plug", "trip", "fuse", "battery", "blackout"],
	"game_spoon_mic": ["sing", "song", "microphone", "mic"], "game_apartment": ["apateu", "floor", "stack"],
	"game_titanic": ["titanic", "sink", "sank"], "game_nunchi": ["nunchi", "stand up", "on your feet", "count to", "count us"],
	"game_369": ["369", "three six nine", "clap"], "game_love_shot": ["love shot", "loveshot", "link arms", "arms linked", "linked arms"],
}


## Drinking games, late on and a few drinks in: the situation for a line in a customers' chat,
## never the words (the AI takes it up, or doesn't). "scene": what happens at the counter when
## it's offered (shown, and in the chat's transcript as something that happened): someone
## else getting it going, for the two talking to join in or not. (A situation in the direction
## alone was ignored 9 times in 11; bare props, 3 in 4.) "close": only between two who've got
## close (the love shot). What shows a line took it up is in HINT_TELLS: playing it, not
## just mentioning what's there.
const TABLE_GAMES := {
	"spoon_mic": {"situation": "It's the stage of the night when someone sticks a spoon in an empty soju bottle and uses it as a microphone.",
		"scene": "Someone further along has stuck a spoon in an empty soju bottle and is holding it out to the table like they're on stage, waiting for someone to take a turn."},
	"apartment": {"situation": "Someone's in the mood for the apartment game: everyone stacks their hands, someone calls a floor, and whoever's hand lands on it drinks.",
		"scene": "That end of the counter has gone loud and giggly, everyone a few drinks in."},
	"titanic": {"situation": "There's a shot glass floating in someone's beer: the Titanic game, where everyone pours a little soju in and whoever sinks it drinks it.",
		"scene": "Someone's floated an empty shot glass in a glass of beer between them, and is pouring soju into it a little at a time, then passing the bottle on."},
	"nunchi": {"situation": "It's the kind of table where someone starts the nunchi game: stand up and count, and anyone who stands at the same time as someone else drinks.",
		"scene": "Someone at that end of the counter shouts \"One!\" and jumps to their feet, looking round to see who'll go next."},
	"369": {"situation": "Someone suggests 369: count round the table, clapping instead of any number with a 3, 6 or 9 in it.",
		"scene": "Someone says \"One, two...\" and slaps the counter instead of saying three, then looks at the next person to carry on."},
	"love_shot": {"situation": "The two of them are close enough now for a love shot: arms linked, drinking at the same time.", "close": true,
		"scene": "Both their glasses have just been filled, at the same moment."},
}
const TABLE_GAME_LINES := 3  # lines of the chat it's in the air for, unless taken up first
const TABLE_GAME_NOW := "Whatever they were talking about, that's what's going on at the table now."
const TABLE_GAME_CHANCE := 0.35  # for a chat line, once it can be (and once a chat)
const TABLE_GAME_FROM := 21 * 60  # 9pm: not straight after work
const TABLE_GAME_DRINKS := 1  # everyone in the chat has a drink (most order one bottle and nurse it: 2 was hardly ever)


## A table game for a customers' chat line, or "": people in the chat, the fewest drinks any of
## them has had, whether the two talking are close, and whether it's late enough. roll: whether
## (TABLE_GAME_CHANCE); which: which of those that fit.
static func table_game(people: int, fewest_drinks: int, close: bool, late: bool, roll: float, which: float) -> String:
	if people < 2 or fewest_drinks < TABLE_GAME_DRINKS or not late or roll >= TABLE_GAME_CHANCE:
		return ""
	var fits: Array = TABLE_GAMES.keys().filter(func(id): return close or not bool(TABLE_GAMES[id].get("close", false)))
	return str(fits[clampi(floori(which * fits.size()), 0, fits.size() - 1)])


## Turning away to drink in front of someone this many years older (as manners say).
const ELDER_YEARS := 10
const TURN_AWAY_CHANCE := 0.25  # for a younger customer's chat line, once a night each
const KYA_CHANCE := 0.5  # "Kya~!" after the first drink of someone's night


## The door: what the owner calls out as someone ducks in, by how close they are (a
## Regulars.closeness_mark): polite for a stranger, casual for an old friend. Romanised, like
## any Korean said (it explains itself on hover: see the glossary).
const DOOR_WELCOME := {"": "Eoseo oseyo!", "☆": "Tto osyeonneyo!", "★": "Tto osyeonneyo!", "★★": "Wasseo?"}

## And on the way out: the customer's thanks (now and then), and the owner's goodbye.
const DOOR_THANKS := "Jal meogeosseumnida!"
const DOOR_GOODBYE := {"": "Annyeonghi gaseyo!", "☆": "Annyeonghi gaseyo!", "★": "Josimhi gaseyo!", "★★": "Josimhi ga!"}
const DOOR_THANKS_CHANCE := 0.6

## How often a stranger's welcome goes in the transcript (the bubble's every time; a
## regular's always does, since how they're greeted says how close they are).
const DOOR_WELCOME_WRITTEN := 0.3


static func door_welcome(mark: String) -> String:
	return str(DOOR_WELCOME.get(mark, DOOR_WELCOME[""]))


static func door_goodbye(mark: String) -> String:
	return str(DOOR_GOODBYE.get(mark, DOOR_GOODBYE[""]))


## Someone said hwaiting (go for it!): the counter joins in. At most this many others.
const CHORUS_MOST := 3
const CHORUS := "Hwaiting!"


static func says_hwaiting(line: String, names: Array = []) -> bool:
	return Glossary.words_in(line, names).has("Hwaiting")


## A big shock just now (a TV reaction rated it so): whoever else heard it is stunned, for their
## next line. The situation, never the words: the AI finds its own "Mwo?!".
## The PD's camera turns to someone for the first time tonight: everyone knows they're on a
## show, so they notice (and play up to it, hide from it, or carry on: theirs to choose).
const CAMERA_MOMENT := "The show's camera crew have just turned their camera on {who}, and they've noticed."


static func camera_moment(who: String) -> String:
	return CAMERA_MOMENT.replace("{who}", Names.given_name(who))


## ...and what happened, as it goes in the conversation they speak in next (who: full name):
## as with the plant cards, a moment in the direction alone was ignored (0 of 3).
const CAMERA_HAPPENED := "The show's crew turn their camera on {who}."


static func camera_happened(who: String) -> String:
	return CAMERA_HAPPENED.replace("{who}", who)


const STUNNED_MOMENT := "What {who} just said has stunned them: they can hardly believe their ears."


static func stunned_moment(who: String) -> String:
	return STUNNED_MOMENT.replace("{who}", Names.given_name(who))


## Whether a line seems to have taken up a hint of this kind (see HINT_TELLS). extra: more
## words that count (the cat's name, say).
## (Whole words, with their usual endings: "sinks" and "singing" count, but "count" isn't
## in "countryside".)
static func hint_taken(kind: String, line: String, extra: Array = []) -> bool:
	var lower := line.to_lower()
	for tell in HINT_TELLS.get(kind, []) + extra:
		var word := RegEx.create_from_string("\\b" + _regex_escape(str(tell).to_lower()) + "(s|es|d|ed|ing|y|er|ers|est)?\\b")
		if word.search(lower) != null:
			return true
	return false


## A word as a regex pattern, its special characters escaped (Godot's RegEx has no escape()).
static func _regex_escape(word: String) -> String:
	var escaped := ""
	for c in word:
		escaped += ("\\" + c) if "\\^$.|?*+()[]{}".contains(c) else c
	return escaped


static func _matches_template(moment: String, template: String) -> bool:
	var pattern := "^" + template.replace(".", "\\.").replace("{giver}", ".+").replace("{other}", ".+") + "$"
	return RegEx.create_from_string(pattern).search(moment) != null


## Sharing between customers chatting at the counter, as situations ({giver} and {other}
## are filled with names). Each is only offered when the game knows it's true.
const SHARING_MORE_FOOD := "{giver} has more food on the table than {other} has."
const SHARING_POUR := "Here people fill each other's glasses rather than their own: {giver} could top up {other}'s."
const SHARING_CLOSE := "{giver} and {other} are close now: close friends here feed each other a bite, or pick out the best piece for the other."
const SHARING_CHANCE := 0.25
const SHARING_KINDS := {"more_food": SHARING_MORE_FOOD, "pour": SHARING_POUR, "close": SHARING_CLOSE}


## Now and then, a sharing situation for a chat line, or "". giver: the speaker (who has food
## on their table); other: who they're talking to. more_food: the giver has more food served
## than the other; both_drinking: both have a drink on the table.
static func sharing_moment(giver: String, other: String, close: bool, more_food: bool, both_drinking: bool, roll: float, which: float) -> String:
	if roll >= SHARING_CHANCE:
		return ""
	var pool: Array = []
	if more_food:
		pool.append(SHARING_MORE_FOOD)
	if both_drinking:
		pool.append(SHARING_POUR)
	if close:
		pool.append(SHARING_CLOSE)
	if pool.is_empty():
		return ""
	var moment := str(pool[mini(int(which * pool.size()), pool.size() - 1)])
	return moment.replace("{giver}", giver).replace("{other}", other)
