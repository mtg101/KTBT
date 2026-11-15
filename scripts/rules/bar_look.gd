extends RefCounted
## Each bar's name and look: the AI's choices, checked against the options the game offers, and
## the fallbacks.
## (Part of the game's rules: pure functions and the tables they use, with any dice rolls
## passed in, so they can be tested on their own. See ARCHITECTURE.md.)

const Text = preload("res://scripts/rules/text.gd")


const MAX_BAR_NAME_LENGTH := 40


const MAX_BAR_MEANING_LENGTH := 80


## A bar name is {"name": romanised Korean, "meaning": what it means in English}.
## The name must be in English letters (spaces, hyphens and apostrophes allowed), short,
## and not just the English meaning again.
static func validate_bar_name(data: Variant) -> String:
	var problem := Text.check_fields(data, ["name", "meaning"])
	if problem != "":
		return problem
	var bar_name := Text.unquote(str(data["name"]))
	var meaning := Text.unquote(str(data["meaning"]))
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


## Every bar has its own look, saved with it: the AI chooses from these (to suit the owner
## and the name), and the game draws it. Tarps: main colour, and stripe colour ("" for none).
const BAR_TARPS := {
	"orange": ["e8833a", ""],
	"red": ["c8443a", ""],
	"blue": ["3a6ec8", ""],
	"green": ["3f9e5a", ""],
	"yellow": ["e8c03a", ""],
	"teal": ["2f9e9a", ""],
	"maroon": ["8a2c3e", ""],
	"striped": ["e8833a", "f2ead8"],
	"red_stripes": ["c8443a", "f5f2ea"],
	"blue_stripes": ["3a6ec8", "f5f2ea"],
}


## The tent cover's shape, with how the prompt puts it.
const TENT_SHAPES := {
	"classic": "the classic sloped tarp",
	"peaked": "a peaked roof, high in the middle",
	"scalloped": "a sloped tarp with a scalloped front edge",
	"awning": "a flat awning with a zigzag valance",
	"rounded": "a rounded, arched cover",
}


## Sign styles: board colour, text colour.
const SIGN_STYLES := {
	"wood": ["7a5230", "f2e3c4"],
	"neon": ["141224", "ff5fa8"],
	"banner": ["f2d24a", "b8281f"],
	"lightbox": ["f5f2ea", "2a52a0"],
}


## Little touches around the tent (the AI picks one or two), with how the prompt puts them.
const BAR_TOUCHES := {
	"string_lights": "string lights along the tarp's edge",
	"lanterns": "red paper lanterns",
	"radio": "an old radio on the counter",
	"plants": "potted plants by the poles",
	"calendar": "a paper calendar pinned to a pole",
	"lucky_cat": "a waving lucky-cat figurine",
	"photos": "old photos taped to a pole",
	"fishing_net": "a fishing net hung in a corner",
	"knife_rack": "a neat rack of kitchen knives",
}


## Without the AI's choice (an older bar, or the AI couldn't manage it).
const DEFAULT_HANGUL := "포장마차"


const MAX_HANGUL_LENGTH := 12


## A bar's look: {"hangul": its name in Hangul for the sign, "tarp", "sign", and "touches":
## one or two of BAR_TOUCHES}.
## A new bar's choice of colours and shapes: a few of each, picked by the game, so bars
## differ (left to itself the AI paints nearly every tent the classic orange).
const OFFERED_TARPS := 4


const OFFERED_SHAPES := 3


static func look_offer() -> Dictionary:
	var tarps: Array = BAR_TARPS.keys()
	var shapes: Array = TENT_SHAPES.keys()
	tarps.shuffle()
	shapes.shuffle()
	return {"tarp": tarps.slice(0, OFFERED_TARPS), "shape": shapes.slice(0, OFFERED_SHAPES)}


## offered: the colours and shapes this bar was offered (from look_offer); empty for all of them.
static func validate_bar_look(data: Variant, offered: Dictionary = {}) -> String:
	var problem := Text.check_fields(data, ["hangul", "tarp", "sign"])
	if problem != "":
		return problem
	var hangul := Text.tidy_text(data["hangul"])
	var letters := 0
	for c in hangul:
		if c.unicode_at(0) >= 0xAC00 and c.unicode_at(0) <= 0xD7A3:
			letters += 1
		elif c != " ":
			return "\"hangul\" must be the name in Korean letters (Hangul) only"
	if letters < 2:
		return "\"hangul\" must be the name in Korean letters (Hangul)"
	if hangul.length() > MAX_HANGUL_LENGTH:
		return "\"hangul\" is too long for the sign"
	var tarp := Text.tidy_text(data["tarp"]).to_lower()
	var sign_style := Text.tidy_text(data["sign"]).to_lower()
	var shape := Text.tidy_text(data.get("shape", "classic")).to_lower()  # older looks have none
	var shapes: Array = offered.get("shape", TENT_SHAPES.keys())
	var tarps: Array = offered.get("tarp", BAR_TARPS.keys())
	if not TENT_SHAPES.has(shape) or (data.has("shape") and not shapes.has(shape)):
		return "\"shape\" must be one of: %s" % ", ".join(PackedStringArray(shapes))
	if not BAR_TARPS.has(tarp) or not tarps.has(tarp):
		return "\"tarp\" must be one of: %s" % ", ".join(PackedStringArray(tarps))
	if not SIGN_STYLES.has(sign_style):
		return "\"sign\" must be one of: %s" % ", ".join(PackedStringArray(SIGN_STYLES.keys()))
	var touches: Array = []
	var raw = data.get("touches", [])
	if typeof(raw) != TYPE_ARRAY or raw.is_empty() or raw.size() > 2:
		return "\"touches\" must be a list of one or two of: %s" % ", ".join(PackedStringArray(BAR_TOUCHES.keys()))
	for entry in raw:
		var touch := str(entry).strip_edges().to_lower()
		if not BAR_TOUCHES.has(touch):
			return "\"%s\" isn't one of the touches (%s)" % [touch, ", ".join(PackedStringArray(BAR_TOUCHES.keys()))]
		if not touches.has(touch):
			touches.append(touch)
	data["hangul"] = hangul
	data["tarp"] = tarp
	data["sign"] = sign_style
	data["shape"] = shape
	data["touches"] = touches
	return ""


## A plain look, for when there isn't one chosen.
static func default_bar_look() -> Dictionary:
	return {"hangul": DEFAULT_HANGUL, "tarp": "orange", "sign": "wood", "shape": "classic", "touches": []}
