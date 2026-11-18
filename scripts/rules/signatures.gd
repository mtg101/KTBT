extends RefCounted
## A bar's signature dishes: one or two of the owner's own, invented by the AI from their story
## when the bar opens ("her grandmother's knife-cut noodles"). The AI names the dish (romanised,
## in Hangul, and what the name means), says what it is, picks its kind from the catalogue's
## categories and how it looks from the game's drawing lists. The game sets the rest: its price
## and cooking time (from the catalogue's dishes of that kind), and its id. The meaning's kept
## with it, so the hover never needs translating live.
## (Part of the game's rules: pure functions and the tables they use. See ARCHITECTURE.md.)

const Catalogue = preload("res://scripts/rules/catalogue.gd")
const DishArt = preload("res://scripts/rules/dish_art.gd")
const Names = preload("res://scripts/rules/names.gd")
const Talk = preload("res://scripts/rules/talk.gd")
const Text = preload("res://scripts/rules/text.gd")

## How many a bar has (the catalogue leaves room for SIGNATURES on its menu).
const COUNT := Vector2i(1, Catalogue.SIGNATURES)

## What a signature dish can be (the catalogue's food categories).
const CATEGORIES := ["stew", "pancake", "noodles", "seafood", "grill", "fried", "side", "rice"]

## A signature costs a little more than the usual for its kind: it's the house's own.
const PREMIUM := 1000

const MAX_NAME := 32  # characters, romanised
const MAX_HANGUL := 10  # syllables
const MAX_MEANING := 60
const MAX_DESC := 110
const ID_PREFIX := "own_"

## The game's own, when the AI can't (or it's offline): a home cook's dishes, each with its
## Hangul and meaning. One per bar, picked by its own dice.
const FALLBACKS := [
	{"name": "Halmeoni Kalguksu", "hangul": "할머니 칼국수", "meaning": "grandma's knife-cut noodles", "desc": "hand-cut noodles in an anchovy broth, the way the owner's grandmother made them",
		"category": "noodles", "vessel": "bowl", "bits": "noodles", "garnish": "seaweed", "colour": "e9dcc0"},
	{"name": "Eomma Son-mat Jjigae", "hangul": "엄마 손맛 찌개", "meaning": "a stew with mum's touch", "desc": "kimchi and pork stew from the owner's mother's recipe, simmered all evening",
		"category": "stew", "vessel": "stone_pot", "bits": "chunks", "garnish": "spring_onion", "colour": "c8452f"},
	{"name": "Jip Dubu-kimchi", "hangul": "집 두부김치", "meaning": "home-style tofu and kimchi", "desc": "warm tofu with kimchi stir-fried in pork fat, as it's made at home",
		"category": "side", "vessel": "plate", "bits": "tofu", "garnish": "sesame", "colour": "c4572e"},
	{"name": "Imo Kimchi-jeon", "hangul": "이모 김치전", "meaning": "Imo's kimchi pancake", "desc": "a crisp kimchi pancake, thin at the edges, the owner's own",
		"category": "pancake", "vessel": "plate", "bits": "pancake", "garnish": "spring_onion", "colour": "d96a3a"},
]


## Checks the AI's signature dishes: {"dishes": [{"name", "hangul", "meaning", "desc",
## "category", "vessel", "bits" (optional), "garnish" (optional), "colour"}]}. menu: the bar's
## menu so far (a signature can't share a name with anything on it). On success, data["items"]
## is them as menu items, in full.
static func validate_signatures(data: Variant, menu: Array = []) -> String:
	var problem := _signatures_problem(data, menu)
	return ("the signature dish: " + problem) if problem != "" else ""


static func _signatures_problem(data: Variant, menu: Array) -> String:
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("dishes", null)) != TYPE_ARRAY:
		return "\"dishes\" wasn't a list"
	var dishes: Array = data["dishes"]
	if dishes.size() < COUNT.x or dishes.size() > COUNT.y:
		return "a tent has %d or %d signature dishes" % [COUNT.x, COUNT.y]
	var items: Array = []
	var taken: Array = menu.map(func(item): return _key(str(item.get("name", ""))))
	for dish in dishes:
		if typeof(dish) != TYPE_DICTIONARY:
			return "each dish should be an object"
		var problem := check_dish(dish)
		if problem != "":
			return problem
		var item := item_from(dish)
		if taken.has(_key(str(item["name"]))) or not Catalogue.find(str(item["name"]).to_lower().replace("-", "_").replace(" ", "_")).is_empty():
			return "%s is already a dish: something of the owner's own" % item["name"]
		taken.append(_key(str(item["name"])))
		items.append(item)
	data["items"] = items
	return ""


## What's wrong with one signature dish, or "".
static func check_dish(dish: Dictionary) -> String:
	var dish_name := Text.tidy_text(str(dish.get("name", "")))
	if dish_name == "" or dish_name.length() > MAX_NAME:
		return "the name should be a few words, at most %d letters" % MAX_NAME
	for c in dish_name:
		if not (c.to_lower() in "abcdefghijklmnopqrstuvwxyz -'"):
			return "the name must be Korean written in English letters (no Hangul, numbers or symbols like \"%s\")" % c
	var hangul := Text.tidy_text(str(dish.get("hangul", "")))
	var problem := hangul_problem(dish_name, hangul)
	if problem != "":
		return problem
	var meaning := Text.tidy_text(str(dish.get("meaning", "")))
	if meaning.length() < 3 or meaning.length() > MAX_MEANING:
		return "\"meaning\" should say what the name means in English, in a few words"
	var desc := Text.tidy_text(str(dish.get("desc", "")))
	if desc.length() < 10 or desc.length() > MAX_DESC:
		return "\"desc\" should say what the dish is, in one short line"
	for text in [meaning, desc]:
		for c in text:
			if c.unicode_at(0) >= 0x1100:
				return "\"meaning\" and \"desc\" are in English (the Hangul goes in \"hangul\")"
	for text in [dish_name, meaning, desc]:
		var brand := Talk.real_brand(text)
		if brand != "":
			return "no real brands (%s)" % brand
	if not CATEGORIES.has(str(dish.get("category", ""))):
		return "\"category\" must be one of: %s" % ", ".join(PackedStringArray(CATEGORIES))
	if not DishArt.VESSELS.has(str(dish.get("vessel", ""))) or ["bottle", "glass", "kettle"].has(str(dish.get("vessel", ""))):
		return "\"vessel\" must be one of the dishes it can come in: %s" % ", ".join(PackedStringArray(food_vessels()))
	if str(dish.get("bits", "")) != "" and not DishArt.BITS.has(str(dish["bits"])):
		return "\"bits\" must be one of: %s (or empty)" % ", ".join(PackedStringArray(DishArt.BITS))
	if str(dish.get("garnish", "")) != "" and not DishArt.GARNISHES.has(str(dish["garnish"])):
		return "\"garnish\" must be one of: %s (or empty)" % ", ".join(PackedStringArray(DishArt.GARNISHES))
	if not Color.html_is_valid(str(dish.get("colour", "")).trim_prefix("#")) or str(dish.get("colour", "")).trim_prefix("#").length() != 6:
		return "\"colour\" must be a hex colour like \"c8452f\""
	return ""


## Whether the Hangul fits the romanised name: Hangul only, a sensible length, and each word
## starting with the right sound (each syllable, when they line up). The Hangul may run the
## words together, as Korean often does (아빠짬뽕 for "Appa Jjamppong"): then it just has to start right.
static func hangul_problem(roman: String, hangul: String) -> String:
	var syllables := hangul.replace(" ", "")
	if syllables.length() < 2 or syllables.length() > MAX_HANGUL:
		return "\"hangul\" should be the name in Hangul, %d to %d syllables" % [2, MAX_HANGUL]
	for c in syllables:
		if c.unicode_at(0) < 0xAC00 or c.unicode_at(0) > 0xD7A3:
			return "\"hangul\" must be Hangul syllables only"
	var roman_words := roman.to_lower().replace("'", "").split(" ", false)
	var hangul_words := hangul.split(" ", false)
	if hangul_words.size() < roman_words.size() and Names._starts_alike(roman_words[0].split("-", false)[0] if not roman_words[0].split("-", false).is_empty() else roman_words[0], syllables[0]):
		return ""  # (Korean runs a name together: "Appa Jjamppong" is 아빠짬뽕, 18 Nov)
	if roman_words.size() != hangul_words.size():
		return "\"hangul\" doesn't match the name (%d words, and the name has %d)" % [hangul_words.size(), roman_words.size()]
	for i in roman_words.size():
		var pieces := roman_words[i].split("-", false)
		var word := hangul_words[i]
		if pieces.size() == word.length():
			for k in pieces.size():
				if not Names._starts_alike(pieces[k], word[k]):
					return "\"hangul\" doesn't match the name (%s isn't %s)" % [word, roman_words[i]]
		elif pieces.is_empty() or not Names._starts_alike(pieces[0], word[0]):
			return "\"hangul\" doesn't match the name (%s isn't %s)" % [word, roman_words[i]]
	return ""


## A signature dish as a menu item: the AI's words and look, the game's price and cooking time.
static func item_from(dish: Dictionary) -> Dictionary:
	var dish_name := Text.tidy_text(str(dish["name"]))
	var category := str(dish["category"])
	var colour := str(dish["colour"]).trim_prefix("#").to_lower()
	var art := {"vessel": str(dish["vessel"])}
	if not ["cup"].has(art["vessel"]):
		art["fill"] = colour
	if str(dish.get("bits", "")) != "":
		art["bits"] = str(dish["bits"])
		art["bits_colour"] = Color(colour).lightened(0.45).to_html(false)
	if str(dish.get("garnish", "")) != "":
		art["garnish"] = str(dish["garnish"])
	var meaning := Text.tidy_text(str(dish["meaning"]))
	return {"id": ID_PREFIX + _key(dish_name), "hangul": Text.tidy_text(str(dish["hangul"])), "name": dish_name,
		"meaning": meaning, "desc": Text.tidy_text(str(dish["desc"])), "price": price_for(category), "kind": "food",
		"portion": "side" if ["side", "rice"].has(category) else "main", "category": category, "color": colour,
		"cook": cook_for(category), "tags": ["signature"], "signature": true, "aliases": [meaning.to_lower()], "art": art}


## The usual price of the catalogue's dishes of this kind (the middle one), and the house's premium.
static func price_for(category: String) -> int:
	var prices: Array = _of(category).map(func(item): return int(item["price"]))
	prices.sort()
	var usual: int = prices[floori(prices.size() / 2.0)] if not prices.is_empty() else 12000
	return usual + PREMIUM


## The usual cooking time for its kind (the middle one), at least a few minutes: it's made fresh.
static func cook_for(category: String) -> int:
	var times: Array = _of(category).map(func(item): return int(item.get("cook", 0)))
	times.sort()
	return maxi(4, int(times[floori(times.size() / 2.0)]) if not times.is_empty() else 8)


## The game's own signature dish, when the AI can't: one of FALLBACKS (by the bar's own dice),
## unless the menu already has something by that name.
static func fallback(dice: RandomNumberGenerator, menu: Array = []) -> Array:
	var dishes: Array = FALLBACKS.duplicate()
	var start := dice.randi_range(0, dishes.size() - 1)
	for k in dishes.size():
		var data := {"dishes": [dishes[(start + k) % dishes.size()]]}
		if validate_signatures(data, menu) == "":
			return data["items"]
	return []


## Whether a menu item is a bar's signature dish.
static func is_signature(item: Dictionary) -> bool:
	return bool(item.get("signature", false)) or str(item.get("id", "")).begins_with(ID_PREFIX)


## The vessels a dish of food can come in.
static func food_vessels() -> Array:
	return DishArt.VESSELS.keys().filter(func(v): return not ["bottle", "glass", "kettle"].has(v))


static func _of(category: String) -> Array:
	return Catalogue.all().filter(func(item): return str(item.get("category", "")) == category and item["kind"] == "food" and not bool(item.get("extra_only", false)))


static func _key(text: String) -> String:
	var out := ""
	for c in text.to_lower():
		if c in "abcdefghijklmnopqrstuvwxyz":
			out += c
		elif out != "" and not out.ends_with("_"):
			out += "_"
	return out.trim_suffix("_")
