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


## About one customer in a hundred is non-binary. The game decides (the AI wouldn't hit 1%
## reliably); otherwise the AI chooses woman or man along with the name.
const NON_BINARY_CHANCE := 0.01


## The gender the game has decided for a new customer, from a random roll between 0 and 1:
## "non-binary", or "" to let the AI choose.
static func game_gender(roll: float) -> String:
	return "non-binary" if roll < NON_BINARY_CHANCE else ""


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
## check that strangers don't call each other oppa, hyung, nuna or eonni).
static func validate_line(data: Variant, speaker: String, alias: String, items: Array = [], names: Array = []) -> String:
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
	var term := close_term(line, names + [speaker])
	if term != "":
		return "the line says \"%s\", but these people have only just met: strangers don't use oppa, hyung, nuna or eonni" % term
	data["line"] = line
	return ""


## What kind of problem a validator found, for the stats: the AI's rejected replies,
## grouped so the most common mistakes stand out.
static func problem_kind(problem: String) -> String:
	var p := problem.to_lower()
	if p.contains("already at the counter"):
		return "same name"
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
