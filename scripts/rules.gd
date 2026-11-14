extends RefCounted
## The game's rules: the facts it owns and the checks it applies to everything the AI writes.
##
## Everything here is a static function with no scene, no AI and no randomness, so it can
## be tested directly (see tests/test_rules.gd). Scenes call these; they don't re-implement them.
##
## Validators take the AI's parsed JSON reply and return "" if it's usable, or a short,
## plain-English description of the problem (which is fed back to the AI on a retry).
## They may tidy the data in place: trimming text, converting ages to whole numbers,
## turning menu names into menu ids.

const Menu = preload("res://scripts/menu.gd")

const MIN_DRINKING_AGE := 19  # Korea's legal drinking age: enforced by the game, not the AI.
const MAX_CUSTOMER_AGE := 90
const MIN_OWNER_AGE := 40  # Owners are called Ajumma or Ajusshi, which suits 40 and over.
const MAX_OWNER_AGE := 85
const MAX_ORDER_ITEMS := 4
const MAX_EXTRA_ITEMS := 2  # A later order: one more bottle, a side, rice...
## How many times a customer orders again after their first order: half never do, most of
## the rest order once more, and a few order a third time. Must add up to 1.
const EXTRA_ORDER_ODDS := [0.5, 0.4, 0.1]
## A later order's line must sound like adding to what they have, using one of these words.
## In a later order, a dish already on the table can be mentioned without ordering more of it
## only when one of these comes just before it ("this tteokbokki needs rice").
const REFERRING_WORDS := ["this", "these", "that", "the", "my", "our"]
const MORE_WORDS := ["more", "another", "also", "too", "again", "extra", "add", "refill", "same", "seconds"]
const MAX_LINE_LENGTH := 500
const MAX_BAR_NAME_LENGTH := 40
const MAX_BAR_MEANING_LENGTH := 80

const OWNER_FIELDS := ["name", "age", "archetype", "appearance", "personality", "speech_style", "secret"]
const CUSTOMER_FIELDS := ["name", "age", "job", "mood", "reason", "speech_style", "appearance"]
const CUSTOMER_DETAIL_FIELDS := ["age", "job", "mood", "reason", "speech_style", "appearance"]
const MAX_NAME_LENGTH := 30

## Korean terms of address that only fit one gender. The game picks the owner's gender
## (and so their title: see Prompts.OWNER_ADDRESS), then rejects an owner whose archetype
## uses a word for the other gender.
const GENDERED_TERMS := {
	"woman": ["ajumma", "ajumeoni", "ajummoni", "imo", "halmeoni", "halmoni", "eomeoni", "eomma", "nuna", "noona", "eonni", "unni"],
	"man": ["ajusshi", "ajeossi", "ajussi", "ajeoshi", "ajeosshi", "samchon", "harabeoji", "abeoji", "appa", "hyung", "hyeong", "oppa"],
}


# --- Validators for the AI's replies -------------------------------------------

static func validate_owner(data: Variant, gender: String) -> String:
	var problem := check_fields(data, OWNER_FIELDS)
	if problem != "":
		return problem
	problem = check_age(data, MIN_OWNER_AGE, MAX_OWNER_AGE)
	if problem != "":
		return problem
	# The owner is a {gender}: their archetype mustn't use a word for the other gender.
	var other := "man" if gender == "woman" else "woman"
	var said := words(str(data["archetype"]))
	for term in GENDERED_TERMS[other]:
		if term in said:
			return "the owner is a %s, but their archetype uses \"%s\", which is for a %s" % [gender, term, other]
	return ""


## A bar name is {"name": romanised Korean, "meaning": what it means in English}.
## The name must be in English letters (spaces, hyphens and apostrophes allowed), short,
## and not just the English meaning again.
static func validate_bar_name(data: Variant) -> String:
	var problem := check_fields(data, ["name", "meaning"])
	if problem != "":
		return problem
	var bar_name := unquote(str(data["name"]))
	var meaning := unquote(str(data["meaning"]))
	if bar_name.length() > MAX_BAR_NAME_LENGTH:
		return "the name is too long (at most %d characters)" % MAX_BAR_NAME_LENGTH
	if meaning.length() > MAX_BAR_MEANING_LENGTH:
		return "the meaning is too long (at most %d characters)" % MAX_BAR_MEANING_LENGTH
	for c in bar_name:
		var ok := (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c in [" ", "-", "'"]
		if not ok:
			return "the name must be Korean written in English letters (no Hangul, numbers or symbols like \"%s\")" % c
	if bar_name.to_lower() == meaning.to_lower():
		return "the name is just the English meaning: the name should be Korean, written in English letters"
	data["name"] = bar_name
	data["meaning"] = meaning
	return ""


## If the AI can't name the bar, the game does: "<given name>-ne Pocha" ("Park Mi-sook" ->
## "Mi-sook-ne Pocha", Mi-sook's family's tent).
static func fallback_bar_name(owner_name: String) -> Dictionary:
	var parts := owner_name.split(" ", false)
	var last := parts[parts.size() - 1] if parts.size() > 0 else ""
	var given := ""
	for c in last:
		if (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "-":
			given += c
	if given == "":
		given = "Imo"
	return {"name": "%s-ne Pocha" % given, "meaning": "%s's family's tent" % given}


## The game decides every customer's gender (left to choose, the AI picked a woman about
## three times in four): about one in a hundred is non-binary, and the rest are split evenly
## between women and men. The AI only names them.
const NON_BINARY_CHANCE := 0.01


## A new customer's gender, from a random roll between 0 and 1.
static func game_gender(roll: float) -> String:
	if roll < NON_BINARY_CHANCE:
		return "non-binary"
	return "woman" if roll < NON_BINARY_CHANCE + (1.0 - NON_BINARY_CHANCE) / 2.0 else "man"


## A new customer's name and gender, the first of two steps (it's quick, so a retry costs
## little): {"name": family name first, in English letters, "gender": "woman" or "man"}.
## taken: the names of everyone already at the counter. Two people there can't share a name
## (it would confuse the transcript, and the AI). gender: one the game has already decided
## (then only the name is needed).
static func validate_customer_name(data: Variant, taken: Array = [], gender: String = "") -> String:
	if gender != "" and typeof(data) == TYPE_DICTIONARY:
		data["gender"] = gender
	var problem := check_fields(data, ["name", "gender"])
	if problem != "":
		return problem
	var customer_name := tidy_text(data["name"])
	if gender == "":
		# The AI's choice: woman or man (non-binary customers are the game's decision).
		gender = tidy_text(data["gender"]).to_lower()
		if gender not in ["woman", "man"]:
			return "\"gender\" must be \"woman\" or \"man\""
	if customer_name.split(" ", false).size() < 2:
		return "the name needs a family name and a given name, family name first"
	if customer_name.length() > MAX_NAME_LENGTH:
		return "the name was far too long"
	for c in customer_name:
		if not ((c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c in [" ", "-", "'"]):
			return "the name must be in English letters"
	for other in taken:
		if customer_name.to_lower() == str(other).to_lower():
			return "someone called %s is already at the counter: pick a different name" % customer_name
	data["name"] = customer_name
	data["gender"] = gender
	return ""


## The rest of a customer, the second step, once the game has their name and gender.
static func validate_customer_details(data: Variant) -> String:
	var problem := check_fields(data, CUSTOMER_DETAIL_FIELDS)
	if problem != "":
		return problem
	return check_age(data, MIN_DRINKING_AGE, MAX_CUSTOMER_AGE)


## A whole customer at once (name included). taken: names already at the counter.
static func validate_customer(data: Variant, taken: Array = []) -> String:
	var problem := check_fields(data, CUSTOMER_FIELDS)
	if problem != "":
		return problem
	var customer_name := tidy_text(data["name"])
	for other in taken:
		if customer_name.to_lower() == str(other).to_lower():
			return "someone called %s is already at the counter: pick a different name" % customer_name
	return check_age(data, MIN_DRINKING_AGE, MAX_CUSTOMER_AGE)


## An order is {"items": [menu ids], "line": what they say as they sit down and order}.
## Names are turned into menu ids, and the line must only mention what was ordered.
## Every order has at least one drink and one food (nobody drinks on an empty stomach),
## at most max_mains main dishes (1 normally, 2 for a customer the game made hungry) and
## at most max_drinks drinks (1 normally, 2 for a customer the game decided is having a rough night).
static func validate_order(data: Variant, max_mains: int = 1, max_drinks: int = 1) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return "it wasn't a JSON object"
	if not data.has("items") or typeof(data["items"]) != TYPE_ARRAY:
		return "\"items\" wasn't a list of menu ids"
	var raw: Array = data["items"]
	if raw.is_empty():
		return "they didn't order anything"
	if raw.size() > MAX_ORDER_ITEMS:
		return "they ordered %d items, and the most is %d" % [raw.size(), MAX_ORDER_ITEMS]
	var ids: Array = []
	for entry in raw:
		var id := Menu.resolve(str(entry))
		if id == "":
			return "\"%s\" isn't on the menu" % str(entry)
		ids.append(id)
	var line := unquote(tidy_text(data.get("line", "")))
	if line == "":
		return "\"line\" was empty"
	var problem := check_order_shape(ids, max_mains, max_drinks)
	if problem != "":
		return problem
	for id in ids:
		if Menu.find(id).get("extra_only", false):
			return "%s is only ordered later, not when you first sit down" % Menu.find(id)["name"]
	# What they say must match what they get: no mentioning dishes they didn't order.
	var mention := unordered_mention(line, ids, true)
	if mention != "":
		return "the line mentions %s, but that isn't in \"items\"" % mention
	data["items"] = ids
	data["line"] = line
	return ""


## A later order, partway through a visit: {"items": [menu ids], "line": "..."}.
## One or two things: one more drink, a side, or rice. No new main dishes, at most one drink,
## and fried rice only once there's a main on the table. table is what's already been ordered.
static func validate_extra_order(data: Variant, table: Array) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return "it wasn't a JSON object"
	if not data.has("items") or typeof(data["items"]) != TYPE_ARRAY:
		return "\"items\" wasn't a list of menu ids"
	var raw: Array = data["items"]
	if raw.is_empty():
		return "they didn't order anything"
	if raw.size() > MAX_EXTRA_ITEMS:
		return "they ordered %d more things, and a later order is at most %d" % [raw.size(), MAX_EXTRA_ITEMS]
	var ids: Array = []
	var drinks := 0
	for entry in raw:
		var id := Menu.resolve(str(entry))
		if id == "":
			return "\"%s\" isn't on the menu" % str(entry)
		var item := Menu.find(id)
		if item.get("portion", "") == "main":
			return "%s is a main dish, and a later order is a drink, a side or rice" % item["name"]
		if item.get("kind", "") == "drink":
			drinks += 1
		ids.append(id)
	if drinks > 1:
		return "they ordered %d more drinks, and a later order has at most one" % drinks
	if ids.has("bokkeumbap") and not has_main(table):
		return "Bokkeumbap is made in the leftover sauce of a main dish, and there isn't one on the table"
	var line := unquote(tidy_text(data.get("line", "")))
	if line == "":
		return "\"line\" was empty"
	# It must sound like ordering more, not like a first order.
	var said := words(line)
	var sounds_like_more := false
	for word in MORE_WORDS:
		if word in said:
			sounds_like_more = true
			break
	if not sounds_like_more:
		return "the line sounds like a first order: make it clear they're adding to what they already have (e.g. \"one more bottle\", \"some rice too\")"
	# Everything they ask for must be in "items". Something already on the table can be
	# mentioned only as "this ..."/"the ...", not asked for again ("another tteokbokki").
	var allowed := with_somaek_parts(ids)
	for found in mentions(line, true):
		var id: String = found["id"]
		if allowed.has(id):
			continue
		var dish := str(Menu.find(id)["name"])
		if table.has(id):
			var before: int = found["start"] - 1
			if before >= 0 and REFERRING_WORDS.has(said[before]):
				continue
			return "the line asks for more %s, but that isn't in \"items\" (to talk about the %s already on the table, say \"this %s\")" % [dish, dish, dish.to_lower()]
		return "the line mentions %s, but that isn't in \"items\"" % dish
	data["items"] = ids
	data["line"] = line
	return ""


## How many later orders a customer makes, from a random roll between 0 and 1 (see EXTRA_ORDER_ODDS).
static func extra_order_count(roll: float) -> int:
	var total := 0.0
	for count in EXTRA_ORDER_ODDS.size():
		total += EXTRA_ORDER_ODDS[count]
		if roll < total:
			return count
	return EXTRA_ORDER_ODDS.size() - 1


## Which of the customer's turns in a conversation become later orders. Lines alternate
## owner (even turns) and customer (odd turns). A later order is never the customer's first
## reply (they settle in first) or their last line (they're leaving), and two later orders
## always have at least one ordinary customer line between them. Returns up to count turns
## (at most 2), in order. Callers should lengthen the conversation by one exchange per
## later order, so ordering doesn't eat into the talking.
static func extra_order_turns(exchanges: int, count: int) -> Array:
	var choices: Array = []
	for turn in range(3, exchanges * 2 - 1, 2):
		choices.append(turn)
	if count <= 0 or choices.is_empty():
		return []
	if count == 1:
		return [choices.pick_random()]
	var pairs: Array = []
	for first in choices:
		for second in choices:
			if second - first >= 4:
				pairs.append([first, second])
	if pairs.is_empty():
		return [choices.pick_random()]
	return pairs.pick_random()


# --- The night ----------------------------------------------------------------------------

## The tent opens at 6pm and closes at 3am. Times are minutes since midnight at the start of
## the night, so 3am is 27 * 60. Nobody new arrives after LAST_ARRIVAL.
const OPEN_MINUTES := 18 * 60
const CLOSE_MINUTES := 27 * 60
const LAST_ARRIVAL_MINUTES := 26 * 60 + 30  # 2:30am
const DAYS := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
## Roughly how many customers arrive in each hour (keyed by the hour it starts; 24 is midnight):
## a steady trickle after work, a rush from 9 to 1am (peaking from 10 to 11, when the tent
## usually fills up), then the stragglers. About twenty a night: enough that strangers are
## often sitting side by side, while leaving time to talk (a real tent might get thirty; a
## setting could change it).
const ARRIVALS_PER_HOUR := {18: 1.4, 19: 1.6, 20: 1.8, 21: 3.4, 22: 4.8, 23: 3.4, 24: 2.2, 25: 1.2, 26: 0.8}


## 1080 -> "6:00pm", 1445 -> "12:05am"
static func clock_text(minutes: int) -> String:
	var m := minutes % (24 * 60)
	var hour := floori(m / 60.0)
	var hour_12 := hour % 12
	if hour_12 == 0:
		hour_12 = 12
	return "%d:%02d%s" % [hour_12, m % 60, "am" if hour < 12 else "pm"]


## How many customers usually arrive per hour at this time of night.
static func arrivals_per_hour(minutes: int) -> float:
	return ARRIVALS_PER_HOUR.get(clampi(floori(minutes / 60.0), 18, 26), 1.0)


## Game minutes until the next customer, from a random roll between 0 and 1: on average
## 60 / arrivals_per_hour, anywhere from half to one and a half times that, and at least 5.
static func next_arrival_gap(minutes: int, roll: float) -> int:
	var average := 60.0 / arrivals_per_hour(minutes)
	return maxi(5, roundi(average * (0.5 + roll)))


## How fast game time runs, by how many people are in (at the counter or waiting to be
## greeted): an empty tent's quiet stretches fly by, one customer goes a bit quicker, and
## from two (when customers can chat) it's normal speed, so there's time to talk.
const TIME_SPEEDS := [6.0, 2.0, 1.0]


static func time_speed(people: int) -> float:
	return TIME_SPEEDS[clampi(people, 0, TIME_SPEEDS.size() - 1)]


## A customer who's been waiting this many game minutes for a free stool gives up.
const GIVE_UP_MINUTES := 30


## Which day night number `night` falls on, for a bar whose first night was first_day (0 = Monday).
static func night_day(first_day: int, night: int) -> String:
	return DAYS[posmod(first_day + night - 1, DAYS.size())]


## The night's most memorable line, for the summary: the longest thing a customer said.
## Lines are {"speaker", "text"}. Returns {} if nobody said anything.
static func memorable_line(lines: Array) -> Dictionary:
	var best := {}
	for line in lines:
		if best.is_empty() or str(line["text"]).length() > str(best["text"]).length():
			best = line
	return best


# --- Seats and the kitchen -----------------------------------------------------------------

## Stools at the counter.
const SEATS := 5


## The items that come straight away (drinks, anything not cooked), in order.
static func instant_items(items: Array) -> Array:
	return items.filter(func(id): return Menu.cook_minutes(str(id)) == 0)


## The items that go on the stove and wait their turn, in order.
static func cooked_items(items: Array) -> Array:
	return items.filter(func(id): return Menu.cook_minutes(str(id)) > 0)


## What's on a customer's table, as the AI is told it, including what's still cooking, so
## nobody eats a dish that hasn't arrived (though they can grumble about waiting for it).
static func table_text(served: Array, cooking: Array, banchan: String) -> String:
	var text := "free banchan (%s)" % banchan
	if not served.is_empty():
		text = "%s, plus free banchan (%s)" % [item_names(served), banchan]
	if not cooking.is_empty():
		text += ". Still cooking, so not on the table yet and nobody can eat it: %s" % item_names(cooking)
	return text


# --- Customers: how long they stay, and their mood for company ------------------------

## The game decides each customer's mood for company when they sit down:
## "chatty" (happy to talk to anyone at the counter), "quiet" (keeps to themselves, so isn't
## drawn into other customers' chats) or "owner" (here to talk to the owner: they stay
## longer and get the owner's attention sooner).
const HERE_TO_TALK_CHANCE := 0.2
const KEEPS_TO_THEMSELVES_CHANCE := 0.25
const COMPANY_TEXT := {
	"chatty": "happy to chat with anyone at the counter",
	"quiet": "keeps to themselves, and would rather not talk to other customers",
	"owner": "here to talk to the owner: they have something on their mind",
}


## The mood for company, from a random roll between 0 and 1.
static func company(roll: float) -> String:
	if roll < HERE_TO_TALK_CHANCE:
		return "owner"
	if roll < HERE_TO_TALK_CHANCE + KEEPS_TO_THEMSELVES_CHANCE:
		return "quiet"
	return "chatty"


## How many game minutes a customer stays, from a random roll between 0 and 1: 30 to 60
## for most, 60 to 90 for someone here to talk. When it's up, they say goodbye and pay,
## whether or not they got much of the owner's time.
static func stay_minutes(company_mood: String, roll: float) -> int:
	var shortest := 60 if company_mood == "owner" else 30
	return shortest + roundi(30.0 * clampf(roll, 0.0, 1.0))


## When it's busy (someone else waiting to be greeted, or this many already at the counter),
## the owner greets a newcomer quickly: takes the order and serves it, and comes back for a
## proper word later. On a quiet night they have a first chat straight away.
const BUSY_COUNTER := 3


## waiting: how many others are still waiting to be greeted; seated: how many are already
## at the counter.
static func quick_greeting(waiting: int, seated: int) -> bool:
	return waiting > 0 or seated >= BUSY_COUNTER


## Whether someone can be drawn into a chat with another customer.
static func joins_chats(company_mood: String) -> bool:
	return company_mood != "quiet"


# --- What conversations turn to ----------------------------------------------------------

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
}
const OWNER_TOPIC_WEIGHTS := {"food": 1.0, "their_day": 2.0, "on_their_mind": 3.0, "owner_story": 1.5, "the_night": 1.0, "owner_secret": 0.5, "advice": 1.5, "the_cat": 1.0}
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
static func pick_owner_topic(roll: float, food_news: bool, cat: String, last: String = "") -> String:
	var weights := OWNER_TOPIC_WEIGHTS.duplicate()
	if food_news:
		weights["food"] = 3.0
	weights["the_cat"] = {"none": 0.0, "tent": 0.7, "with_them": 3.0}.get(cat, 0.0)
	return _pick_weighted(weights, roll, last)


static func pick_chat_topic(roll: float, cat: String, last: String = "") -> String:
	var weights := CHAT_TOPIC_WEIGHTS.duplicate()
	weights["the_cat"] = {"none": 0.0, "tent": 0.7, "with_them": 3.0}.get(cat, 0.0)
	return _pick_weighted(weights, roll, last)


static func _pick_weighted(weights: Dictionary, roll: float, skip: String) -> String:
	var total := 0.0
	for key in weights:
		if key != skip:
			total += float(weights[key])
	var target := clampf(roll, 0.0, 0.9999) * total
	var choice := ""
	for key in weights:
		if key == skip or float(weights[key]) <= 0.0:
			continue
		choice = key
		target -= float(weights[key])
		if target < 0.0:
			return key
	return choice


## The game's steer for a line: "Let the conversation turn to: how their day has gone."
static func topic_hint(topic: String, chat: bool = false) -> String:
	var text: String = (CHAT_TOPICS if chat else OWNER_TOPICS).get(topic, "")
	return "Let the conversation turn to %s (naturally, following on from what was just said)." % text if text != "" else ""


# --- The cat ------------------------------------------------------------------------------

## Every bar has a cat. The game decides its coat and personality (and, all night, where it
## is); the AI only names it. Its personality sets how likely each spot is.
const CAT_COATS := {"ginger": "d9883a", "black": "2b2a33", "white": "eeeae0", "tabby": "9c7a52", "calico": "e8e0d0", "grey": "8a8a96"}
const CAT_PERSONALITIES := {
	"lazy": "lazy: sleeps most of the night",
	"affectionate": "affectionate: always looking for a lap",
	"greedy": "greedy: a shameless beggar for food",
	"grumpy": "grumpy: tolerates people, barely",
	"curious": "curious: into everything, and often off out in the street",
}
## Where the cat can be. "lap", "feet" and "food" are with a customer (food: by the stool of
## someone with food on their table, staring at it).
const CAT_SPOTS := ["stove", "counter", "stools", "street", "lap", "feet", "food"]
const CAT_SPOT_WEIGHTS := {
	"lazy": {"stove": 6.0, "counter": 3.0, "stools": 1.0, "street": 1.0, "lap": 2.0, "feet": 0.5, "food": 0.5},
	"affectionate": {"stove": 1.0, "counter": 1.0, "stools": 1.0, "street": 0.5, "lap": 5.0, "feet": 3.0, "food": 1.0},
	"greedy": {"stove": 1.0, "counter": 2.0, "stools": 2.0, "street": 1.0, "lap": 0.5, "feet": 1.0, "food": 5.0},
	"grumpy": {"stove": 4.0, "counter": 3.0, "stools": 1.0, "street": 2.0, "lap": 0.3, "feet": 0.2, "food": 1.0},
	"curious": {"stove": 1.0, "counter": 2.0, "stools": 4.0, "street": 4.0, "lap": 1.0, "feet": 2.0, "food": 1.0},
}
## Korean pet names, for a bar whose cat the AI couldn't name (or an older bar that had none).
const CAT_NAMES := ["Nabi", "Dubu", "Gamja", "Mandu", "Bori", "Kongi", "Duri", "Hodu", "Nuri", "Dalgi", "Kkami", "Chorong"]
const CAT_WORDS := ["cat", "cats", "kitty", "kitten", "goyangi", "puss", "pussycat", "moggy"]
## Stroking, petting, a lap...: only for a cat that's on the lap of someone in the conversation.
const CAT_TOUCH_WORDS := ["stroke", "strokes", "stroking", "stroked", "pet", "pets", "petting", "petted", "scratch", "scratches", "scratching", "cuddle", "cuddles", "cuddling", "lap", "laps"]
const MAX_CAT_NAME_LENGTH := 16


## Where the cat goes next, from a random roll between 0 and 1, by its personality. It
## always moves somewhere new. Spots with a customer need one (lap and feet: anyone at the
## counter; food: someone with food on their table).
static func pick_cat_spot(personality: String, has_people: bool, has_food: bool, roll: float, current: String = "") -> String:
	var weights: Dictionary = CAT_SPOT_WEIGHTS.get(personality, CAT_SPOT_WEIGHTS["lazy"])
	var choices: Array = []
	var total := 0.0
	for spot in CAT_SPOTS:
		if spot == current or (spot in ["lap", "feet"] and not has_people) or (spot == "food" and not has_food):
			continue
		choices.append(spot)
		total += float(weights[spot])
	var target := clampf(roll, 0.0, 0.9999) * total
	for spot in choices:
		target -= float(weights[spot])
		if target < 0.0:
			return spot
	return choices.back() if not choices.is_empty() else "stove"


## Where the cat is, as a sentence: "Nabi is curled up asleep by the stove."
## with: the customer it's with (for lap, feet and food).
static func cat_text(cat_name: String, spot: String, with: String = "") -> String:
	match spot:
		"stove": return "%s is curled up asleep by the stove." % cat_name
		"counter": return "%s is washing itself on the end of the counter." % cat_name
		"stools": return "%s is prowling about under the stools." % cat_name
		"street": return "%s is out in the street, not in the tent." % cat_name
		"lap": return "%s is curled up on %s's lap." % [cat_name, with]
		"feet": return "%s is winding round %s's ankles." % [cat_name, with]
		"food": return "%s is sitting by %s's stool, staring at their food." % [cat_name, with]
	return "%s is somewhere about." % cat_name


## What it looks like when the cat goes somewhere: "Nabi jumps up onto Kim Ji-ho's lap."
static func cat_move_text(cat_name: String, spot: String, with: String = "") -> String:
	match spot:
		"stove": return "%s curls up by the stove and goes to sleep." % cat_name
		"counter": return "%s hops up onto the end of the counter for a wash." % cat_name
		"stools": return "%s goes prowling under the stools." % cat_name
		"street": return "%s slips out under the tarp into the street." % cat_name
		"lap": return "%s jumps up onto %s's lap and settles in." % [cat_name, with]
		"feet": return "%s winds round %s's ankles." % [cat_name, with]
		"food": return "%s sits down by %s's stool, eyes fixed on their food." % [cat_name, with]
	return "%s wanders off." % cat_name


## The cat must be talked about as it really is: nobody strokes it, or talks of it on a lap,
## unless it's on the lap of someone in this conversation (people: their names). Returns a
## problem, or "".
static func check_cat(line: String, cat_name: String, spot: String, with: String, people: Array) -> String:
	var said := words(line)
	var about_cat := false
	for word in CAT_WORDS + Array(words(cat_name)):
		if word in said:
			about_cat = true
	if not about_cat:
		return ""
	var touching := false
	for word in CAT_TOUCH_WORDS:
		if word in said:
			touching = true
	if not touching or (spot == "lap" and with in people):
		return ""
	return "the line has the cat being stroked or on a lap, but that isn't what's happening: %s" % cat_text(cat_name, spot, with)


## A cat's name, from the AI: {"name": a short Korean pet name in English letters}.
## taken: names other bars' cats already have (so every bar's cat is its own).
static func validate_cat_name(data: Variant, owner_name: String = "", taken: Array = []) -> String:
	var problem := check_fields(data, ["name"])
	if problem != "":
		return problem
	var cat_name := unquote(tidy_text(data["name"]))
	if cat_name.split(" ", false).size() > 2:
		return "a cat's name is one or two words"
	if cat_name.length() > MAX_CAT_NAME_LENGTH:
		return "the name is too long for a cat"
	for c in cat_name:
		if not ((c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c in [" ", "-", "'"]):
			return "the name must be in English letters"
	for part in owner_name.split(" ", false):
		if cat_name.to_lower() == part.to_lower() or cat_name.to_lower() == owner_name.to_lower():
			return "the cat can't have the owner's name"
	for other in taken:
		if cat_name.to_lower() == str(other).to_lower():
			return "another bar's cat is already called %s: pick a different name" % cat_name
	data["name"] = cat_name
	return ""


static func fallback_cat_name(roll: float, taken: Array = []) -> String:
	var free := CAT_NAMES.filter(func(n): return not taken.has(n))
	if free.is_empty():
		free = CAT_NAMES
	return free[clampi(floori(roll * free.size()), 0, free.size() - 1)]


## Every cat is a she or a he (a game fact, so everyone gets it right).
const CAT_SEXES := ["she", "he"]


# --- How strangers talk -------------------------------------------------------------------

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
	var said := words(text)
	for term in CLOSE_TERMS:
		if term in said:
			return term
	return ""


static func has_main(items: Array) -> bool:
	for id in items:
		if Menu.find(id).get("portion", "") == "main":
			return true
	return false


## A line of dialogue is {"line": "..."}. Tidies the usual small-model habits: a "Name:"
## prefix, quotes around the line, or carrying on to write the other person's reply.
## If items (what's on the table) is given, the line mustn't mention other menu items.
## A line of dialogue: {"line": "..."}. items: everything ordered by the people talking (a
## line can't mention food nobody ordered). names: the people in the conversation (for the
## check that strangers don't call each other oppa, hyung, nuna or eonni). cat: where the cat
## is, {"name", "spot", "with"} (see check_cat), or {} to skip that check.
static func validate_line(data: Variant, speaker: String, alias: String, items: Array = [], names: Array = [], cat: Dictionary = {}) -> String:
	if typeof(data) != TYPE_DICTIONARY or not data.has("line"):
		return "it didn't include \"line\""
	var line := tidy_text(data["line"])
	# Small models sometimes carry on and write the other person's reply too: keep the first part.
	var cut := line.find("\n")
	if cut > 0:
		line = line.substr(0, cut).strip_edges()
	# ...or start with "Name:". Strip that off.
	for prefix in [speaker, alias]:
		if prefix != "" and line.to_lower().begins_with(prefix.to_lower() + ":"):
			line = line.substr(prefix.length() + 1).strip_edges()
	line = unquote(line)
	if line == "":
		return "the line was empty"
	if line.length() > MAX_LINE_LENGTH:
		return "the line was far too long"
	if not items.is_empty():
		var mention := unordered_mention(line, items)
		if mention != "":
			return "the line mentions %s, but that isn't on the table (%s)" % [mention, item_names(items)]
	# No asides in brackets: a small model adds "(translations)" or stage directions there.
	if line.contains("(") or line.contains(")"):
		return "the line has something in brackets: write only what's said, in English, with no translations or stage directions"
	var term := close_term(line, names + [speaker])
	if term != "":
		return "the line says \"%s\", but these people have only just met: strangers don't use oppa, hyung, nuna or eonni" % term
	if not cat.is_empty():
		var cat_problem := check_cat(line, str(cat["name"]), str(cat["spot"]), str(cat["with"]), names + [speaker])
		if cat_problem != "":
			return cat_problem
	data["line"] = line
	return ""


## What kind of problem a validator found, for the stats: the AI's rejected replies,
## grouped so the most common mistakes stand out.
static func problem_kind(problem: String) -> String:
	var p := problem.to_lower()
	if p.contains("already at the counter") or p.contains("already called"):
		return "same name"
	if p.contains("the cat"):
		return "the cat"
	if p.contains("in brackets"):
		return "brackets (translations, asides)"
	if p.contains("only just met"):
		return "oppa, hyung, nuna or eonni"
	if p.contains("isn't on the table") or p.contains("isn't in \"items\"") or p.contains("asks for more"):
		return "food that wasn't ordered"
	if p.contains("isn't on the menu"):
		return "not on the menu"
	if p.contains("sounds like a first order"):
		return "later order sounded like a first one"
	if p.contains("json") or p.contains("didn't include") or p.contains("left out") or p.contains("was empty") or p.contains("wasn't a list"):
		return "missing or broken JSON"
	if p.contains("gender"):
		return "name format"
	if p.contains("age"):
		return "age"
	if p.contains("archetype"):
		return "owner's gendered words"
	if p.contains("name"):
		return "name format"
	if p.contains("drink") or p.contains("food") or p.contains("main") or p.contains("order") or p.contains("bokkeumbap"):
		return "order rules"
	if p.contains("too long"):
		return "too long"
	return "other"


## Checks an order has at least one drink, at least one food, and no more main dishes or
## drinks than allowed.
static func check_order_shape(ids: Array, max_mains: int, max_drinks: int = 1) -> String:
	var drinks := 0
	var foods := 0
	var mains := 0
	for id in ids:
		var item := Menu.find(id)
		if item.get("kind", "") == "drink":
			drinks += 1
		else:
			foods += 1
			if item.get("portion", "") == "main":
				mains += 1
	if drinks == 0:
		return "there's no drink: everyone orders at least one drink"
	if foods == 0:
		return "there's no food: nobody drinks on an empty stomach, so order at least one food"
	if mains > max_mains:
		if max_mains == 1:
			return "they ordered %d main dishes, but most people order just one main (add a side instead)" % mains
		return "they ordered %d main dishes, and the most for this customer is %d" % [mains, max_mains]
	if drinks > max_drinks:
		if max_drinks == 1:
			return "they ordered %d drinks, but most people order just one (one bottle goes a long way)" % drinks
		return "they ordered %d drinks, and the most for this customer is %d" % [drinks, max_drinks]
	return ""


## The name of a menu item the line mentions that isn't in items, or "" if there isn't one.
## with_aliases: also look for other names ("rice", "fried rice"). On for order lines; off for
## conversation, where "have you eaten rice?" is just a greeting, not an order.
static func unordered_mention(line: String, items: Array, with_aliases: bool = false) -> String:
	var allowed := with_somaek_parts(items)
	for found in mentions(line, with_aliases):
		if not allowed.has(found["id"]):
			return str(Menu.find(found["id"])["name"])
	return ""


## Somaek is soju dropped in beer, so ordering it lets people mention soju and beer too.
static func with_somaek_parts(items: Array) -> Array:
	var allowed := items.duplicate()
	if items.has("somaek"):
		allowed.append_array(["soju", "beer"])
	return allowed


## Every menu item a line mentions, in order: [{"id", "start"}], where start is the word
## position. Looks for the first word of each name (and, with_aliases, every alias),
## longest phrases first, so "fried rice" counts as fried rice and not also as rice.
static func mentions(line: String, with_aliases: bool) -> Array:
	var said := words(line)
	var phrases: Array = []
	for item in Menu.ITEMS:
		phrases.append({"id": item["id"], "words": [words(str(item["name"]))[0]]})
		if with_aliases:
			for alias in item.get("aliases", []):
				phrases.append({"id": item["id"], "words": Array(words(str(alias)))})
	phrases.sort_custom(func(a, b): return a["words"].size() > b["words"].size())
	var used := []
	used.resize(said.size())
	used.fill(false)
	var found: Array = []
	for phrase in phrases:
		var length: int = phrase["words"].size()
		for start in range(said.size() - length + 1):
			var matches := true
			for k in length:
				if used[start + k] or said[start + k] != phrase["words"][k]:
					matches = false
					break
			if matches:
				for k in length:
					used[start + k] = true
				found.append({"id": phrase["id"], "start": start})
	found.sort_custom(func(a, b): return a["start"] < b["start"])
	return found


## Checks every field is present and that text fields aren't empty. Tidies text in place.
static func check_fields(data: Variant, fields: Array) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return "it wasn't a JSON object"
	for field in fields:
		if not data.has(field):
			return "it left out \"%s\"" % field
		if field == "age":
			continue
		var text := tidy_text(data[field])
		if text == "":
			return "\"%s\" was empty" % field
		data[field] = text
	return ""


## Checks "age" is a whole number in range. Accepts "34" or 34.0 and stores 34.
static func check_age(data: Dictionary, lowest: int, highest: int) -> String:
	var age = data["age"]
	if typeof(age) == TYPE_STRING and age.is_valid_int():
		age = age.to_int()
	if typeof(age) != TYPE_INT and typeof(age) != TYPE_FLOAT:
		return "the age wasn't a number"
	if int(age) < lowest or int(age) > highest:
		return "an age of %d doesn't fit here (it must be %d to %d)" % [int(age), lowest, highest]
	data["age"] = int(age)
	return ""


# --- Orders and bills ------------------------------------------------------------

## The bill for a list of menu ids, worked out from the menu's prices.
static func bill(items: Array) -> int:
	var total := 0
	for id in items:
		total += int(Menu.find(id).get("price", 0))
	return total


## ["soju", "soju", "tteokbokki"] -> "2x Soju, Tteokbokki"
static func item_names(items: Array) -> String:
	var counts := {}
	var order_seen: Array = []
	for id in items:
		if not counts.has(id):
			counts[id] = 0
			order_seen.append(id)
		counts[id] += 1
	var parts := PackedStringArray()
	for id in order_seen:
		var item_name := str(Menu.find(id).get("name", id))
		parts.append(item_name if counts[id] == 1 else "%dx %s" % [counts[id], item_name])
	return ", ".join(parts)


# --- Text helpers ------------------------------------------------------------------

## Text fields sometimes come back as lists: join them up.
static func tidy_text(value: Variant) -> String:
	if typeof(value) == TYPE_ARRAY:
		var parts := PackedStringArray()
		for part in value:
			parts.append(str(part).strip_edges())
		return ", ".join(parts)
	return str(value).strip_edges()


## "\"Hello\"" -> "Hello" (straight, curly or single quotes)
static func unquote(text: String) -> String:
	for pair in [["\"", "\""], ["“", "”"], ["'", "'"]]:
		if text.length() >= 2 and text.begins_with(pair[0]) and text.ends_with(pair[1]):
			return text.substr(1, text.length() - 2).strip_edges()
	return text


## "Gruff-but-soft Ajumma!" -> ["gruff", "but", "soft", "ajumma"]
static func words(text: String) -> PackedStringArray:
	var letters := ""
	for c in text.to_lower():
		letters += c if (c >= "a" and c <= "z") else " "
	return letters.split(" ", false)


## "a messy bob" -> "A messy bob."
static func as_sentence(text: String) -> String:
	var result := sentence_case(text.strip_edges())
	if result != "" and not (result.ends_with(".") or result.ends_with("!") or result.ends_with("?")):
		result += "."
	return result


## "light drizzle" -> "Light drizzle"
static func sentence_case(text: String) -> String:
	if text == "":
		return text
	return text.substr(0, 1).to_upper() + text.substr(1)
