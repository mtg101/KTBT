extends RefCounted
## Tonight's menu. The game owns these facts: the AI can only order what's listed here,
## and the bill is always worked out from these prices.
## Food has a portion: "main" (a proper dish; most people order one) or "side" (a small plate).
## "hangul" is its name in Hangul (for the hover hints and, later, the menu board).
## Optional: "aliases" (other names the AI might use) and "extra_only" (only ordered later in a
## visit, e.g. fried rice made in the leftover sauce of a main dish).
## "cook" is how many game minutes a dish takes on the stove. There's one cook, so cooked
## dishes queue; anything without it (drinks, odeng from the simmering pot, a bowl of rice)
## comes straight away.

const ITEMS := [
	{"id": "soju", "hangul": "소주", "name": "Soju", "desc": "the classic green bottle", "price": 5000, "kind": "drink", "color": "3fae6a"},
	{"id": "makgeolli", "hangul": "막걸리", "name": "Makgeolli", "desc": "milky rice wine", "price": 6000, "kind": "drink", "color": "e9e4d4"},
	{"id": "beer", "hangul": "맥주", "name": "Beer", "desc": "a cold lager", "price": 5000, "kind": "drink", "color": "e0b23c"},
	{"id": "somaek", "hangul": "소맥", "name": "Somaek", "desc": "a shot of soju dropped into beer", "price": 9000, "kind": "drink", "color": "c9d86a", "aliases": ["somaeck", "somac", "so maek"]},
	{"id": "tteokbokki", "hangul": "떡볶이", "name": "Tteokbokki", "desc": "spicy rice cakes", "price": 12000, "kind": "food", "portion": "main", "color": "d8452f", "cook": 6, "aliases": ["rice cakes", "rice cake", "spicy rice cakes"]},
	{"id": "odeng", "hangul": "오뎅", "name": "Odeng", "desc": "fish cake skewers in hot broth", "price": 8000, "kind": "food", "portion": "side", "color": "c9a26b"},
	{"id": "sundae", "hangul": "순대", "name": "Sundae", "desc": "Korean blood sausage", "price": 13000, "kind": "food", "portion": "main", "color": "6b3a3a", "cook": 4},
	{"id": "dakgalbi", "hangul": "닭갈비", "name": "Dakgalbi", "desc": "spicy stir-fried chicken, with lettuce leaves to wrap it in", "price": 18000, "kind": "food", "portion": "main", "color": "c4572e", "cook": 12},
	{"id": "pajeon", "hangul": "파전", "name": "Pajeon", "desc": "spring onion pancake", "price": 15000, "kind": "food", "portion": "main", "color": "d9b44a", "cook": 9},
	{"id": "ramyeon", "hangul": "라면", "name": "Ramyeon", "desc": "instant noodles, made to order", "price": 5000, "kind": "food", "portion": "main", "color": "e07a3a", "cook": 5},
	{"id": "gyeran_mari", "hangul": "계란말이", "name": "Gyeran-mari", "desc": "rolled omelette", "price": 9000, "kind": "food", "portion": "side", "color": "f2d36b", "cook": 6},
	{"id": "gonggibap", "hangul": "공기밥", "name": "Gonggibap", "desc": "a bowl of steamed rice", "price": 1000, "kind": "food", "portion": "side", "color": "f4f1e8", "aliases": ["rice", "steamed rice", "bowl of rice"]},
	{"id": "bokkeumbap", "hangul": "볶음밥", "name": "Bokkeumbap", "desc": "fried rice made in the leftover sauce of a main dish; only ordered later, once a main is on the table", "price": 3000, "kind": "food", "portion": "side", "color": "c98a3a", "aliases": ["fried rice"], "extra_only": true, "cook": 6},
]


## The item with this id, or {} if there isn't one.
static func find(id: String) -> Dictionary:
	for item in ITEMS:
		if item["id"] == id:
			return item
	return {}


## Game minutes on the stove (0: served straight away).
static func cook_minutes(id: String) -> int:
	return int(find(id).get("cook", 0))


## Matches whatever the AI wrote ("soju", "Gyeran-mari", " Tteokbokki ") to a menu id.
## Returns "" if it isn't on the menu.
static func resolve(text: String) -> String:
	var key := _normalise(text)
	for item in ITEMS:
		if key == item["id"] or key == _normalise(item["name"]):
			return item["id"]
		for alias in item.get("aliases", []):
			if key == _normalise(alias):
				return item["id"]
	return ""


## The menu as a list for the AI to read.
## order: the ids in the order to list them (shuffled for each order, so whatever's first on
## the list doesn't get ordered most: small models lean that way); [] for the menu's own order.
## specials: tonight's specials (Orders.pick_specials), marked.
static func prompt_list(order: Array = [], specials: Array = []) -> String:
	var lines := PackedStringArray()
	var ids: Array = order if not order.is_empty() else ITEMS.map(func(item): return str(item["id"]))
	for id in ids:
		var item := find(str(id))
		if item.is_empty():
			continue
		var kind := str(item["kind"])
		if item.has("portion"):
			kind += ", " + str(item["portion"])
		lines.append("- %s: %s (%s), %s, %s%s" % [item["id"], item["name"], item["desc"], format_won(item["price"]), kind,
			" (TONIGHT'S SPECIAL)" if specials.has(item["id"]) else ""])
	return "\n".join(lines)


## Every id, in a new order each time (see prompt_list).
static func shuffled_ids() -> Array:
	var ids: Array = ITEMS.map(func(item): return str(item["id"]))
	ids.shuffle()
	return ids


## 12000 -> "₩12,000"
static func format_won(amount: int) -> String:
	var digits := str(amount)
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return "₩" + out


static func _normalise(text: String) -> String:
	return text.strip_edges().to_lower().replace("-", "_").replace(" ", "_")
