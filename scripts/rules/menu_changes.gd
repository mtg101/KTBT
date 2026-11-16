extends RefCounted
## Menus that change slowly: every few weeks of nights, a dish of the bar's own that hardly
## anyone orders may come off the board, and something new goes on in its place: a dish from
## the catalogue that's good this season, chosen by the AI from a few the game offers (with a
## line on why), or the game's first pick if it can't. Never a regular's usual while they're
## still coming, never the classics, the staples or the owner's own signature dishes.
## (Part of the game's rules: pure functions and the tables they use, with the dice passed in.
## See ARCHITECTURE.md.)

const Catalogue = preload("res://scripts/rules/catalogue.gd")
const Specials = preload("res://scripts/rules/specials.gd")
const Text = preload("res://scripts/rules/text.gd")

const EVERY := 21  # nights (about three weeks) between changes, at least
const CHANCE := 0.3  # once it's been that long: each night, the chance it's tonight
const LOOK_BACK := 60  # the bar's last this many visits
const HARDLY_ORDERED := 2  # ordered at most this many times in them: hardly anyone wants it
const OFFERED := 4  # dishes the AI chooses between
const MAX_WHY := 160


## Whether tonight's the night the menu changes. since: nights since it last did (or the bar
## opened).
static func due(since: int, roll: float) -> bool:
	return since >= EVERY and roll < CHANCE


## The dish that comes off: the bar's own pick (not a classic, staple or signature) ordered
## least in its last LOOK_BACK visits, if that's at most HARDLY_ORDERED times and it isn't
## anyone's usual (protected: the ids in the usual orders of regulars still coming). "" if none.
static func going(menu: Array, history: Array, protected: Array) -> String:
	var counts := {}
	for visit in history.slice(-LOOK_BACK):
		for id in visit.get("order", []):
			counts[str(id)] = int(counts.get(str(id), 0)) + 1
	var least := ""
	for item in menu:
		var id := str(item["id"])
		if Catalogue.layer(id) != "own" or protected.has(id) or int(counts.get(id, 0)) > HARDLY_ORDERED:
			continue
		if least == "" or int(counts.get(id, 0)) < int(counts.get(least, 0)):
			least = id
	return least


## What could go on in its place: catalogue dishes of the bar's own kind that aren't on the
## menu, of the same kind (food or drink), best this season first (the dice break ties). If
## the one going is the menu's only hearty main, only hearty ones (the house rules).
static func offered(menu: Array, out_id: String, season: String, dice: RandomNumberGenerator) -> Array:
	var out_item := Catalogue.find(out_id)
	var on_menu: Array = menu.map(func(item): return str(item["id"]))
	var hearty_left := menu.any(func(item): return str(item["id"]) != out_id and Catalogue.HEARTY.has(str(Catalogue.find(str(item["id"])).get("category", ""))))
	var scored: Array = []
	for item in Catalogue.all():
		var id := str(item["id"])
		if Catalogue.layer(id) != "own" or on_menu.has(id) or bool(item.get("extra_only", false)) or item["kind"] != out_item.get("kind", "food"):
			continue
		if not hearty_left and not Catalogue.HEARTY.has(str(item.get("category", ""))):
			continue
		scored.append([Specials.weight(item, "", season) + dice.randf(), id])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	return scored.slice(0, OFFERED).map(func(pair): return pair[1])


## Checks the AI's choice: {"dish": one of the offered ids, "why": a line}. On success,
## data["why"] is tidied.
static func validate_change(data: Variant, choices: Array) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return "it wasn't a JSON object"
	var dish := str(data.get("dish", "")).strip_edges()
	if not choices.has(dish):
		return "\"dish\" must be one of: %s" % ", ".join(PackedStringArray(choices))
	var why := Text.tidy_text(data.get("why", ""))
	if why == "" or why.length() > MAX_WHY:
		return "\"why\" should be one short line"
	data["dish"] = dish
	data["why"] = why
	return ""


## The menu with one dish swapped for another, in its place on the list (at its usual price).
static func swapped(menu: Array, out_id: String, in_id: String) -> Array:
	return menu.map(func(item): return Catalogue.find(in_id) if str(item["id"]) == out_id else item)
