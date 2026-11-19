extends RefCounted
## Orders and the bill: the AI's orders checked against the menu and the ordering rules, which
## food a line mentions, what's served straight away and what's cooked.
## (Part of the game's rules: pure functions and the tables they use, with any dice rolls
## passed in, so they can be tested on their own. See ARCHITECTURE.md.)

const Menu = preload("res://scripts/rules/menu.gd")
const Text = preload("res://scripts/rules/text.gd")
const Address = preload("res://scripts/rules/address.gd")


const MAX_ORDER_ITEMS := 4


const MAX_EXTRA_ITEMS := 2  # A later order: one more bottle, a side, rice...


## How many times a customer orders again after their first order: half never do, most of
## the rest order once more, and a few order a third time. Must add up to 1.
const EXTRA_ORDER_ODDS := [0.5, 0.4, 0.1]


## A later order's line must sound like adding to what they have, using one of these words.
## In a later order, a dish already on the table can be mentioned without ordering more of it
## only when one of these comes just before it ("this tteokbokki needs rice").
const REFERRING_WORDS := ["this", "these", "that", "the", "my", "our"]


## Words in an order's line that leave the choosing to the owner ("what's good tonight?",
## "something crispy", "the usual"), so whatever the AI put in "items" stands, said or not.
const LEAVE_IT_WORDS := ["good", "recommend", "whatever", "usual", "surprise", "something", "anything", "choose", "pick", "special", "specials", "suggest"]

## Words that ask for a drink without naming it ("a bottle", "something to drink").
const ANY_DRINK_WORDS := ["bottle", "drink", "drinks", "glass", "usual"]


const MORE_WORDS := ["more", "another", "also", "too", "again", "extra", "add", "refill", "same", "seconds"]


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
		if Menu.sold_out.has(id):
			return "%s is sold out tonight" % Menu.find(id)["name"]
		ids.append(id)
	var line := Text.unquote(Text.tidy_text(data.get("line", "")))
	if line == "":
		return "\"line\" was empty"
	var problem := check_order_shape(ids, max_mains, max_drinks)
	if problem != "":
		return problem
	for id in ids:
		if Menu.find(id).get("extra_only", false):
			return "%s is only ordered later, not when you first sit down" % Menu.find(id)["name"]
	# What they say must match what they get: no mentioning dishes they didn't order. A side
	# they ask for but left out of "items" ("...and a bowl of rice") is added: the line wins.
	var asked_for := ids.size()
	add_mentioned_sides(line, ids, MAX_ORDER_ITEMS, func(more: Array): return check_order_shape(more, max_mains, max_drinks) == "")
	data["added_sides"] = ids.size() - asked_for  # (for the stats)
	# And what they get must be what they asked for: anything in "items" the line never asks
	# for is taken off, if the order still keeps the rules without it (the line wins, again).
	# Unless the line leaves it to the owner ("what's good tonight?").
	var before_dropping := ids.size()
	drop_unsaid(line, ids, func(fewer: Array): return check_order_shape(fewer, max_mains, max_drinks) == "")
	data["dropped_unsaid"] = before_dropping - ids.size()  # (for the stats)
	var mention := unordered_mention(line, ids, true)
	if mention != "":
		return "the line mentions %s, but that isn't in \"items\"" % mention
	var unsaid := somaek_unsaid(line, ids)
	if unsaid != "":
		return unsaid
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
		if Menu.sold_out.has(id):
			return "%s is sold out tonight" % Menu.find(id)["name"]
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
	var line := Text.unquote(Text.tidy_text(data.get("line", "")))
	if line == "":
		return "\"line\" was empty"
	# It must sound like ordering more, not like a first order.
	var said := Text.words(line)
	var sounds_like_more := false
	for word in MORE_WORDS:
		if word in said:
			sounds_like_more = true
			break
	if not sounds_like_more:
		return "the line sounds like a first order: make it clear they're adding to what they already have (e.g. \"one more bottle\", \"some rice too\")"
	# Everything they ask for must be in "items" (a side left out of it is added, as for a
	# first order). Something already on the table can be mentioned only as "this ..."/"the
	# ...", not asked for again ("another tteokbokki").
	var asked_for := ids.size()
	add_mentioned_sides(line, ids, MAX_EXTRA_ITEMS, func(more: Array): return not more.has("bokkeumbap") or has_main(table), table)
	data["added_sides"] = ids.size() - asked_for  # (for the stats)
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
	var unsaid := somaek_unsaid(line, ids)
	if unsaid != "":
		return unsaid
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


static func has_main(items: Array) -> bool:
	for id in items:
		if Menu.find(id).get("portion", "") == "main":
			return true
	return false


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


## Sides the line asks for that the AI left out of the items ("tteokbokki and a bowl of rice",
## items: just tteokbokki) go into ids, so the order matches what was said, as long as there's
## room (most items) and fits(ids with it added) says the order's still allowed. Drinks and
## mains aren't added: a line naming a different one is a real mix-up. table: what's already
## been ordered (a side on it that's only mentioned isn't asked for again).
static func add_mentioned_sides(line: String, ids: Array, most: int, fits: Callable, table: Array = []) -> void:
	var said := Text.words(line)
	for found in mentions(line, true):
		var id: String = found["id"]
		var item := Menu.find(id)
		if with_somaek_parts(ids).has(id) or item.get("portion", "") != "side" or ids.size() >= most:
			continue
		var before: int = found["start"] - 1
		if table.has(id) and before >= 0 and REFERRING_WORDS.has(said[before]):
			continue  # "this rice": talking about it, not asking for more
		if bool(item.get("extra_only", false)) and table.is_empty():
			continue  # (fried rice: not with a first order)
		var more := ids + [id]
		if fits.call(more):
			ids.append(id)


## Takes out of ids anything the line never asks for (by name or another name: "spicy
## stir-fried chicken" is dakgalbi), last first, as long as fits(ids without it) says the
## order's still allowed. A line that leaves the choosing to the owner keeps everything; one
## asking for "a bottle" or "a drink" keeps its drink.
static func drop_unsaid(line: String, ids: Array, fits: Callable) -> void:
	var said_words := Text.words(line)
	for word in LEAVE_IT_WORDS:
		if word in said_words:
			return
	var said: Array = with_somaek_parts(mentions(line, true).map(func(found): return str(found["id"])))
	var any_drink := false
	for word in ANY_DRINK_WORDS:
		any_drink = any_drink or word in said_words
	for k in range(ids.size() - 1, -1, -1):
		var id := str(ids[k])
		if said.has(id) or (id == "somaek" and said.has("soju") and said.has("beer")):
			continue
		if any_drink and Menu.find(id).get("kind", "") == "drink":
			continue
		var fewer := ids.duplicate()
		fewer.remove_at(k)
		if fits.call(fewer):
			ids.remove_at(k)


## Somaek ordered, but the line doesn't ask for it: "" if it does (or there's no somaek).
## Saying somaek, or soju and beer together ("a soju dropped into this beer"), or "the usual"
## counts. (Somaek lets a line mention soju, so without this "one more soju" or "one more
## bottle" came out as somaek.) "The usual" only stands in for a drink it doesn't name: "the
## usual, soju and sundae" asks for soju.
static func somaek_unsaid(line: String, ids: Array) -> String:
	if not ids.has("somaek"):
		return ""
	var said: Array = mentions(line, true).map(func(found): return str(found["id"]))
	var names_a_drink := said.any(func(id): return Menu.find(str(id)).get("kind", "") == "drink")
	if said.has("somaek") or (said.has("soju") and said.has("beer")) or ("usual" in Text.words(line) and not names_a_drink):
		return ""
	return "they ordered Somaek, but the line doesn't ask for it (say \"somaek\", or order what the line asks for)"


## Somaek is soju dropped in beer, so ordering it lets people mention soju and beer too.
static func with_somaek_parts(items: Array) -> Array:
	var allowed := items.duplicate()
	if items.has("somaek"):
		allowed.append_array(["soju", "beer"])
	return allowed


## The free banchan's words: a dish whose name starts with one (Kimchi-jjigae, Kimchi-jeon) is
## only found by its whole name, since "eat the kimchi first" is about the banchan.
const BANCHAN_WORDS := ["kimchi", "radish", "danmuji"]


## Whether a word is how people call someone (imo, ajumma, halmeoni...): a dish named after one
## ("Imo Jeyuk", a bar's signature) isn't mentioned by calling the owner "Imo" (19 Nov: 18 to 42
## lines a night sent back for it).
static func is_term_of_address(word: String) -> bool:
	for term in Address.TERMS.values():
		if term["spellings"].has(word):
			return true
	return ["halmeoni", "halmoni", "grandma", "granny", "mom", "mum", "auntie", "aunty"].has(word)


## Every menu item a line mentions, in order: [{"id", "start"}], where start is the word
## position. Looks for the first word of each name (and, with_aliases, every alias and the
## menu's description), longest phrases first, so "fried rice" counts as fried rice and not
## also as rice.
static func mentions(line: String, with_aliases: bool) -> Array:
	var said := Text.words(line)
	var phrases: Array = []
	for item in Menu.items():
		var name_words := Text.words(str(item["name"]))
		if not BANCHAN_WORDS.has(name_words[0]) and not (name_words.size() > 1 and is_term_of_address(name_words[0])):  # ("kimchi" alone is the free banchan, not Kimchi-jjigae: 18 Nov; "Imo" alone is the owner, not Imo Jeyuk: 19 Nov)
			phrases.append({"id": item["id"], "words": [name_words[0]]})
		if name_words.size() > 1:  # (the whole name, word by word, and run together as one word: "Dakbokkeumtang")
			phrases.append({"id": item["id"], "words": Array(name_words)})
			phrases.append({"id": item["id"], "words": [Menu.compact(str(item["name"]))]})
		if with_aliases:
			for alias in item.get("aliases", []):
				phrases.append({"id": item["id"], "words": Array(Text.words(str(alias)))})
			# And how the menu describes it, up to the first comma: "sausage and rice cakes on a stick"
			# is sotteok, not tteokbokki's "rice cakes" (18 Nov). (Long, so it's matched first.)
			var described := Array(Text.words(str(item.get("desc", "")).get_slice(",", 0)))
			if described.size() >= 3:
				phrases.append({"id": item["id"], "words": described})
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


## The bill for a list of menu ids, worked out from the menu's prices.
static func bill(items: Array) -> int:
	var total := 0
	for id in items:
		total += int(Menu.find(id).get("price", 0))
	return total


## When the AI can't come up with an order: soju and odeng, the pocha's standby, or (at a tent
## without odeng) soju and its first side, or its first food.
static func fallback_order() -> Array:
	if not Menu.find("odeng").is_empty() and not Menu.sold_out.has("odeng"):
		return ["soju", "odeng"]
	var foods: Array = Menu.items().filter(func(item): return item["kind"] == "food" and not bool(item.get("extra_only", false)) and not Menu.sold_out.has(item["id"]))
	var sides: Array = foods.filter(func(item): return item.get("portion", "") == "side")
	var food: Dictionary = sides[0] if not sides.is_empty() else (foods[0] if not foods.is_empty() else {})
	return ["soju"] if food.is_empty() else ["soju", str(food["id"])]


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
