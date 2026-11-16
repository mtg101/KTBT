extends RefCounted
## Tonight's specials and what's sold out, from the bar's own menu: the dish the owner's
## pushing tonight (by the weather and the season, now and then their own signature dish),
## now and then a drink worth pushing (never the soju or beer every tent has), never last
## night's again, and now and then something that's run out. Rain is the exception: a pancake
## and makgeolli, every time it rains, as everyone in Korea craves.
## (Part of the game's rules: pure functions and the tables they use, with the dice passed in.
## See ARCHITECTURE.md.)

const Catalogue = preload("res://scripts/rules/catalogue.gd")

## Never a special or sold out: what every tent always has (and a soda for anyone not drinking).
const STAPLES := ["soju", "beer", "gonggibap", "somaek", "saida"]

## What each kind of weather makes people want (NightRules.weather_kind): categories and tags.
const WEATHER_LIKES := {
	"snow": {"categories": ["stew", "noodles"], "tags": ["hearty", "comfort"]},
	"cold": {"categories": ["stew", "grill"], "tags": ["hearty", "comfort", "spicy"]},
	"muggy": {"categories": ["side", "seafood"], "tags": ["light"]},
	"breeze": {"categories": ["grill", "seafood"], "tags": ["light"]},
	"fog": {"categories": ["stew", "noodles"], "tags": ["comfort"]},
}
const WEATHER_WEIGHT := 2.0  # (each match)
const SEASON_WEIGHT := 3.0  # a dish at its best this season
const OUT_OF_SEASON := 0.3  # a winter dish in summer, or the other way round

const SIGNATURE_CHANCE := 0.25  # the owner's own dish as tonight's special
const DRINK_CHANCE := 0.35
const SOLD_OUT_CHANCE := 0.2


## Tonight's specials and sold out: {"specials": [ids], "sold_out": [ids]}. menu: the bar's
## menu (Menu.items()); weather: NightRules.weather_kind; season: Seasons.season ("winter"...);
## last: last night's specials (not again tonight, unless it's raining).
static func tonight(bar_menu: Array, weather: String, season: String, last: Array, dice: RandomNumberGenerator) -> Dictionary:
	var menu: Array = bar_menu.map(func(item): return _full(item))  # (the classic menu's dishes, with their categories and seasons)
	var foods: Array = menu.filter(func(item): return item["kind"] == "food" and _can_be_special(item))
	var drinks: Array = menu.filter(func(item): return item["kind"] == "drink" and _can_be_special(item))
	var specials: Array = []
	if weather in ["rain", "drizzle"]:
		var pancakes: Array = foods.filter(func(item): return str(item.get("category", "")) == "pancake")
		if not pancakes.is_empty():
			specials.append(str(pancakes[dice.randi_range(0, pancakes.size() - 1)]["id"]))
		if menu.any(func(item): return item["id"] == "makgeolli"):
			specials.append("makgeolli")
	if not specials.any(func(id): return foods.any(func(item): return item["id"] == id)):  # (a dish, unless the rain's given one)
		var fresh: Array = foods.filter(func(item): return not last.has(item["id"]))
		var own: Array = fresh.filter(func(item): return bool(item.get("signature", false)))
		var dish := ""
		if not own.is_empty() and dice.randf() < SIGNATURE_CHANCE:
			dish = str(own[dice.randi_range(0, own.size() - 1)]["id"])
		else:
			dish = _weighted(fresh if not fresh.is_empty() else foods, weather, season, dice)
		if dish != "":
			specials.push_front(dish)
	if specials.size() < 2 and not drinks.is_empty() and dice.randf() < DRINK_CHANCE:
		var drink := _weighted(drinks.filter(func(item): return not last.has(item["id"]) and not specials.has(item["id"])), weather, season, dice)
		if drink != "":
			specials.append(drink)
	var sold_out: Array = []
	if dice.randf() < SOLD_OUT_CHANCE:
		var could: Array = foods.filter(func(item): return not specials.has(item["id"]) and not bool(item.get("signature", false)))
		if not could.is_empty():
			sold_out.append(str(could[dice.randi_range(0, could.size() - 1)]["id"]))
	return {"specials": specials, "sold_out": sold_out}


## How much a dish suits tonight: its category and tags for the weather, and its season.
static func weight(item: Dictionary, weather: String, season: String) -> float:
	var likes: Dictionary = WEATHER_LIKES.get(weather, {})
	var w := 1.0
	if likes.get("categories", []).has(str(item.get("category", ""))):
		w += WEATHER_WEIGHT
	for tag in item.get("tags", []):
		if likes.get("tags", []).has(str(tag)):
			w += WEATHER_WEIGHT
	var best := str(item.get("season", ""))
	var now := "summer" if season == "monsoon" else season
	if best != "" and best == now:
		w += SEASON_WEIGHT
	elif best != "" and now in ["summer", "winter"]:
		w *= OUT_OF_SEASON
	return w


static func _weighted(items: Array, weather: String, season: String, dice: RandomNumberGenerator) -> String:
	if items.is_empty():
		return ""
	var weights: Array = items.map(func(item): return weight(item, weather, season))
	var total := 0.0
	for w in weights:
		total += float(w)
	var roll := dice.randf() * total
	for i in items.size():
		roll -= float(weights[i])
		if roll <= 0.0:
			return str(items[i]["id"])
	return str(items[-1]["id"])


## A menu item with the catalogue's facts about it (category, tags, season), where it has none.
static func _full(item: Dictionary) -> Dictionary:
	var full := Catalogue.find(str(item["id"]))
	full.merge(item, true)
	return full


static func _can_be_special(item: Dictionary) -> bool:
	return not STAPLES.has(str(item["id"])) and not bool(item.get("extra_only", false)) and not bool(item.get("mixed", false))
