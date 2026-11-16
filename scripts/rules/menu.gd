extends RefCounted
## Tonight's menu: the open bar's own (see use), or the classic menu below. The game owns these
## facts: the AI can only order what's listed here, and the bill is always worked out from
## these prices.
## Food has a portion: "main" (a proper dish; most people order one) or "side" (a small plate).
## "hangul" is its name in Hangul (for the hover hints and, later, the menu board).
## Optional: "aliases" (other names the AI might use) and "extra_only" (only ordered later in a
## visit, e.g. fried rice made in the leftover sauce of a main dish).
## "mixed": made at the table, not ordered off the menu (somaek: a soju and a beer), so it's never
## on the board, and every bar with soju and beer has it.
## A bar's signature dishes (rules/signatures.gd) also have "signature": true and "meaning" (what
## their Korean name means), and ids starting "own_".
## "art" is how it looks on the table: what it comes in and what's in it (see rules/dish_art.gd).
## "cook" is how many game minutes a dish takes on the stove. There's one cook, so cooked
## dishes queue; anything without it (drinks, odeng from the simmering pot, a bowl of rice)
## comes straight away.

## The classic menu: every bar's until it has its own (and the tests').
const ITEMS := [
	{"id": "soju", "hangul": "소주", "name": "Soju", "desc": "the classic green bottle", "price": 5000, "kind": "drink", "color": "3fae6a", "art": {"vessel": "bottle"}},
	{"id": "makgeolli", "hangul": "막걸리", "name": "Makgeolli", "desc": "milky rice wine", "price": 6000, "kind": "drink", "color": "e9e4d4", "aliases": ["makkeolli", "makgeoli", "milky rice wine", "rice wine"], "art": {"vessel": "kettle"}},
	{"id": "beer", "hangul": "맥주", "name": "Beer", "desc": "a cold lager", "price": 5000, "kind": "drink", "color": "e0b23c", "aliases": ["lager", "maekju"], "art": {"vessel": "glass", "foam": true}},
	{"id": "somaek", "hangul": "소맥", "name": "Somaek", "desc": "a shot of soju dropped into beer, mixed at the table from a soju and a beer (never on the menu: you just ask)", "price": 9000, "kind": "drink", "mixed": true, "color": "c9d86a", "aliases": ["somaeck", "somac", "so maek"], "art": {"vessel": "glass", "foam": true}},
	{"id": "tteokbokki", "hangul": "떡볶이", "name": "Tteokbokki", "desc": "spicy rice cakes", "price": 12000, "kind": "food", "portion": "main", "color": "d8452f", "cook": 6, "aliases": ["rice cakes", "rice cake", "spicy rice cakes"], "art": {"vessel": "plate", "fill": "d8452f", "bits": "cylinders", "bits_colour": "f3e3cf", "garnish": "spring_onion"}},
	{"id": "odeng", "hangul": "오뎅", "name": "Odeng", "desc": "fish cake skewers in hot broth", "price": 8000, "kind": "food", "portion": "side", "color": "c9a26b", "aliases": ["fish cake", "fish cakes", "fishcake", "fishcakes", "eomuk"], "art": {"vessel": "cup", "bits": "skewers"}},
	{"id": "sundae", "hangul": "순대", "name": "Sundae", "desc": "Korean blood sausage", "price": 13000, "kind": "food", "portion": "main", "color": "6b3a3a", "cook": 4, "aliases": ["blood sausage", "soondae"], "art": {"vessel": "plate", "bits": "slices", "garnish": "sesame"}},
	{"id": "dakgalbi", "hangul": "닭갈비", "name": "Dakgalbi", "desc": "spicy stir-fried chicken, with lettuce leaves to wrap it in", "price": 18000, "kind": "food", "portion": "main", "color": "c4572e", "cook": 12, "aliases": ["spicy stir-fried chicken", "stir-fried chicken", "chicken", "dak galbi"], "art": {"vessel": "pan", "fill": "c4572e", "bits": "chunks", "bits_colour": "eab07a", "garnish": "lettuce"}},
	{"id": "pajeon", "hangul": "파전", "name": "Pajeon", "desc": "spring onion pancake, with a soy dipping sauce", "price": 15000, "kind": "food", "portion": "main", "color": "d9b44a", "cook": 9, "aliases": ["spring onion pancake", "green onion pancake", "pancake", "pa jeon"], "art": {"vessel": "plate", "bits": "pancake", "garnish": "spring_onion"}},
	{"id": "ramyeon", "hangul": "라면", "name": "Ramyeon", "desc": "instant noodles, made to order", "price": 5000, "kind": "food", "portion": "main", "color": "e07a3a", "cook": 5, "aliases": ["ramen", "ramyun", "instant noodles", "noodles"], "art": {"vessel": "pot", "fill": "e07a3a", "bits": "noodles", "bits_colour": "f2d38a"}},
	{"id": "gyeran_mari", "hangul": "계란말이", "name": "Gyeran-mari", "desc": "rolled omelette", "price": 9000, "kind": "food", "portion": "side", "color": "f2d36b", "cook": 6, "aliases": ["rolled omelette", "omelette", "egg roll", "gyeranmari"], "art": {"vessel": "plate", "bits": "rolls"}},
	{"id": "gonggibap", "hangul": "공기밥", "name": "Gonggibap", "desc": "a bowl of steamed rice", "price": 1000, "kind": "food", "portion": "side", "color": "f4f1e8", "aliases": ["rice", "steamed rice", "bowl of rice"], "art": {"vessel": "steel_bowl", "bits": "mound"}},
	{"id": "bokkeumbap", "hangul": "볶음밥", "name": "Bokkeumbap", "desc": "fried rice made in the leftover sauce of a main dish; only ordered later, once a main is on the table", "price": 3000, "kind": "food", "portion": "side", "color": "c98a3a", "aliases": ["fried rice"], "extra_only": true, "cook": 6, "art": {"vessel": "pan", "bits": "mound", "garnish": "seaweed"}},
]


static var _items: Array = []  # the open bar's menu ([]: the classic one)

## What's run out tonight (ids, from rules/specials.gd): still on the board, struck through, and
## can't be ordered. Cleared whenever a menu's put up. (A stopgap, like _items.)
static var sold_out: Array = []

## Goes up whenever the menu changes, so anything built from it (the glossary's tables) knows
## to build itself again.
static var version := 0


## Tonight's menu: the open bar's, or the classic one.
static func items() -> Array:
	return ITEMS if _items.is_empty() else _items


## A bar opens with its own menu (its dishes in full, as saved: see for_bar); [] for the
## classic one. Whole numbers come back from a save as decimals, so they're put back.
## (A stopgap: the refactor's Night object will own the open bar's menu.)
static func use(menu: Array) -> void:
	var tidied: Array = []
	for item in menu:
		if typeof(item) != TYPE_DICTIONARY or str(item.get("id", "")) == "":
			continue
		var copy: Dictionary = item.duplicate(true)
		for key in ["price", "cook"]:
			if copy.has(key):
				copy[key] = int(copy[key])
		tidied.append(copy)
	_items = tidied
	sold_out = []
	version += 1


## A bar's menu, as saved with it ("menu": its dishes in full), or [] for the classic one.
static func for_bar(bar: Dictionary) -> Array:
	var saved: Variant = bar.get("menu", [])
	return saved if saved is Array else []


## The item with this id, or {} if there isn't one.
static func find(id: String) -> Dictionary:
	for item in items():
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
	for item in items():
		if key == item["id"] or key == _normalise(item["name"]):
			return item["id"]
		for alias in item.get("aliases", []):
			if key == _normalise(alias):
				return item["id"]
	return ""


## The menu as a list for the AI to read.
## order: the ids in the order to list them (shuffled for each order, so whatever's first on
## the list doesn't get ordered most: small models lean that way); [] for the menu's own order.
## specials: tonight's specials (rules/specials.gd), marked; anything sold out says so.
static func prompt_list(order: Array = [], specials: Array = []) -> String:
	var lines := PackedStringArray()
	var ids: Array = order if not order.is_empty() else items().map(func(item): return str(item["id"]))
	for id in ids:
		var item := find(str(id))
		if item.is_empty():
			continue
		var kind := str(item["kind"])
		if item.has("portion"):
			kind += ", " + str(item["portion"])
		var about := str(item["desc"]) if str(item.get("meaning", "")) == "" else "\"%s\": %s" % [item["meaning"], item["desc"]]
		if sold_out.has(item["id"]):
			lines.append("- %s: %s: SOLD OUT TONIGHT (it's run out: can't be ordered)" % [item["id"], item["name"]])
			continue
		lines.append("- %s: %s (%s), %s, %s%s%s" % [item["id"], item["name"], about, format_won(item["price"]), kind,
			" (TONIGHT'S SPECIAL)" if specials.has(item["id"]) else "", " (THE OWNER'S OWN DISH)" if bool(item.get("signature", false)) else ""])
	return "\n".join(lines)


## Every id, in a new order each time (see prompt_list).
static func shuffled_ids() -> Array:
	var ids: Array = items().map(func(item): return str(item["id"]))
	ids.shuffle()
	return ids


## The menu in board order, the way a pocha writes it up: tonight's specials first, then the
## food (mains, then sides and rice), then the drinks. Fried rice made in the leftover sauce
## isn't on the board (you ask for it), and nor is somaek (you mix it at the table).
static func board_order(specials: Array = []) -> Array:
	var shown: Array = items().filter(func(item): return not bool(item.get("extra_only", false)) and not bool(item.get("mixed", false)))
	var rank := func(item: Dictionary) -> int:
		if specials.has(item["id"]):
			return 0
		if item["kind"] == "drink":
			return 3
		return 1 if item.get("portion", "") == "main" else 2
	var ordered: Array = []
	for wanted in 4:
		for item in shown:
			if rank.call(item) == wanted:
				ordered.append(item)
	return ordered


## The house favourite: the food ordered most in the bar's recent visits (its history), if
## anything's been ordered at least FAVOURITE_AT_LEAST times and is still on the menu; "".
const FAVOURITE_AT_LEAST := 3


static func favourite(history: Array) -> String:
	var counts := {}
	for visit in history:
		for id in visit.get("order", []):
			if find(str(id)).get("kind", "") == "food":
				counts[str(id)] = int(counts.get(str(id), 0)) + 1
	var best := ""
	for id in counts:
		if int(counts[id]) >= FAVOURITE_AT_LEAST and (best == "" or int(counts[id]) > int(counts[best])):
			best = str(id)
	return best


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
