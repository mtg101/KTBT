extends RefCounted
## Tonight's menu. The game owns these facts: the AI can only order what's listed here,
## and the bill is always worked out from these prices.
## Food has a portion: "main" (a proper dish; most people order one) or "side" (a small plate).
## Optional: "aliases" (other names the AI might use) and "extra_only" (only ordered later in a
## visit, e.g. fried rice made in the leftover sauce of a main dish).

const ITEMS := [
	{"id": "soju", "name": "Soju", "desc": "the classic green bottle", "price": 5000, "kind": "drink", "color": "3fae6a"},
	{"id": "makgeolli", "name": "Makgeolli", "desc": "milky rice wine", "price": 6000, "kind": "drink", "color": "e9e4d4"},
	{"id": "beer", "name": "Beer", "desc": "a cold lager", "price": 5000, "kind": "drink", "color": "e0b23c"},
	{"id": "somaek", "name": "Somaek", "desc": "a shot of soju dropped into beer", "price": 9000, "kind": "drink", "color": "c9d86a"},
	{"id": "tteokbokki", "name": "Tteokbokki", "desc": "spicy rice cakes", "price": 12000, "kind": "food", "portion": "main", "color": "d8452f"},
	{"id": "odeng", "name": "Odeng", "desc": "fish cake skewers in hot broth", "price": 8000, "kind": "food", "portion": "side", "color": "c9a26b"},
	{"id": "sundae", "name": "Sundae", "desc": "Korean blood sausage", "price": 13000, "kind": "food", "portion": "main", "color": "6b3a3a"},
	{"id": "dakgalbi", "name": "Dakgalbi", "desc": "spicy stir-fried chicken", "price": 18000, "kind": "food", "portion": "main", "color": "c4572e"},
	{"id": "pajeon", "name": "Pajeon", "desc": "spring onion pancake", "price": 15000, "kind": "food", "portion": "main", "color": "d9b44a"},
	{"id": "ramyeon", "name": "Ramyeon", "desc": "instant noodles, made to order", "price": 5000, "kind": "food", "portion": "main", "color": "e07a3a"},
	{"id": "gyeran_mari", "name": "Gyeran-mari", "desc": "rolled omelette", "price": 9000, "kind": "food", "portion": "side", "color": "f2d36b"},
	{"id": "gonggibap", "name": "Gonggibap", "desc": "a bowl of steamed rice", "price": 1000, "kind": "food", "portion": "side", "color": "f4f1e8", "aliases": ["rice", "steamed rice", "bowl of rice"]},
	{"id": "bokkeumbap", "name": "Bokkeumbap", "desc": "fried rice made in the leftover sauce of a main dish; only ordered later, once a main is on the table", "price": 3000, "kind": "food", "portion": "side", "color": "c98a3a", "aliases": ["fried rice"], "extra_only": true},
]


## The item with this id, or {} if there isn't one.
static func find(id: String) -> Dictionary:
	for item in ITEMS:
		if item["id"] == id:
			return item
	return {}


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
static func prompt_list() -> String:
	var lines := PackedStringArray()
	for item in ITEMS:
		var kind := str(item["kind"])
		if item.has("portion"):
			kind += ", " + str(item["portion"])
		lines.append("- %s: %s (%s), %s, %s" % [item["id"], item["name"], item["desc"], format_won(item["price"]), kind])
	return "\n".join(lines)


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
