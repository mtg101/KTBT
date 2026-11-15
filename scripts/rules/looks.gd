extends RefCounted
## How people look: the game picks the age range, hair, clothes and colours; and how strangers
## are known by how they look.
## (Part of the game's rules: pure functions and the tables they use, with any dice rolls
## passed in, so they can be tested on their own. See ARCHITECTURE.md.)

const Text = preload("res://scripts/rules/text.gd")


## Age ranges: [lowest, highest, how the prompt puts it].
const AGE_RANGES := {
	"20s": [19, 29, "in their twenties"], "30s": [30, 39, "in their thirties"],
	"40s": [40, 49, "in their forties"], "50s": [50, 59, "in their fifties"],
	"60s": [60, 69, "in their sixties"], "70s": [70, 85, "in their seventies or older"],
}


const CUSTOMER_AGES := {"20s": 30, "30s": 30, "40s": 18, "50s": 12, "60s": 7, "70s": 3}


const OWNER_AGES := {"40s": 20, "50s": 35, "60s": 35, "70s": 10}


## Hairstyles, with how the prompt puts them ({c} is the hair colour).
const HAIR_STYLES := {
	"long": "long straight {c} hair", "bob": "{c} hair in a bob", "ponytail": "{c} hair tied back in a ponytail",
	"bun": "{c} hair up in a bun", "pixie": "short-cropped {c} hair", "perm": "a short, tight {c} perm",
	"short": "short {c} hair", "side_part": "neatly side-parted {c} hair", "buzz": "a {c} buzz cut",
	"two_block": "{c} hair in a two-block cut with a long fringe", "balding": "thinning {c} hair",
}


## Hair colours: [colour, how the prompt puts it].
const HAIR_COLOURS := {
	"black": ["1d1c22", "black"], "dark_brown": ["3e2c22", "dark brown"],
	"ash_brown": ["8a7766", "ash-brown dyed"], "blonde": ["d6bf8c", "bleached blonde"],
	"pink": ["d98fae", "pink-dyed"], "grey": ["9b9ba0", "greying"], "white": ["dcdcdc", "white"],
}


## What people wear, with how the prompt puts it.
const CLOTHES := {
	"suit": "a suit and tie", "blazer": "a blazer over a shirt", "trench": "a trench coat",
	"padded": "a long padded coat", "hoodie": "a hoodie", "cardigan": "a cardigan",
	"scrubs": "hospital scrubs", "work_jacket": "a work jacket", "tshirt": "a T-shirt",
	"knit": "a knitted jumper",
}


## Clothes colours: [colour, how the prompt puts it, how often]. Mostly beige and black (it's
## Seoul), with now and then something brighter.
const CLOTHES_COLOURS := {
	"beige": ["cdb894", "beige", 18], "black": ["26252b", "black", 22], "navy": ["2c3a5c", "navy", 10],
	"charcoal": ["4a4a52", "charcoal", 10], "white": ["e8e6e0", "white", 7], "cream": ["efe6d2", "cream", 8],
	"camel": ["b08a5a", "camel", 8], "khaki": ["8a875a", "khaki", 4], "pastel_pink": ["e8b4c4", "pastel pink", 4],
	"mint": ["a8dcc8", "mint", 3], "sky_blue": ["9cc4e4", "sky-blue", 3], "red": ["b8323a", "red", 2],
}


const SUIT_COLOURS := ["black", "navy", "charcoal"]


const SCRUBS_COLOURS := ["navy", "mint", "sky_blue"]


const BAGS := {"tote": "a tote bag", "briefcase": "a briefcase", "backpack": "a backpack"}


const SKIN_TONES := ["f2d6bd", "e9c7a6", "ddb291", "c99c78"]


## Which age range, from a roll between 0 and 1 (owners are 40 and over).
static func pick_age_range(roll: float, owner: bool = false) -> String:
	return Text.pick_weighted(OWNER_AGES if owner else CUSTOMER_AGES, roll, "")


## The age range an age is in (for owners saved before looks).
static func age_range_of(age: int) -> String:
	for id in AGE_RANGES:
		if age <= int(AGE_RANGES[id][1]):
			return id
	return "70s"


## A whole look, decided by the game: hair (by gender and age), clothes (by the weather, and
## never a suit or scrubs behind the counter), colours (mostly beige and black), glasses, a bag.
## weather: a weather_kind. Uses the game's random numbers.
static func pick_look(gender: String, age_range: String, weather: String, owner: bool = false) -> Dictionary:
	var older := age_range in ["50s", "60s", "70s"]
	var hair := {}
	if gender == "woman":
		hair = {"long": 25, "bob": 25, "ponytail": 15, "bun": 12, "pixie": 10, "perm": 40 if older else 2}
	elif gender == "man":
		hair = {"short": 40, "side_part": 25, "buzz": 12, "two_block": 3 if older else 25, "balding": 25 if older else 0}
	else:
		hair = {"bob": 20, "pixie": 25, "short": 20, "two_block": 20, "ponytail": 10, "long": 10}
	var colours := {}
	match age_range:
		"20s", "30s":
			colours = {"black": 55, "dark_brown": 25, "ash_brown": 10, "blonde": 5, "pink": 5}
		"40s":
			colours = {"black": 60, "dark_brown": 25, "grey": 15}
		"50s":
			colours = {"black": 40, "dark_brown": 15, "grey": 45}
		_:
			colours = {"grey": 60, "white": 25, "black": 15}
	var clothes := {"suit": 14, "blazer": 10, "trench": 10, "padded": 6, "hoodie": 10, "cardigan": 10,
		"scrubs": 5, "work_jacket": 8, "tshirt": 10, "knit": 10}
	match weather:
		"cold", "snow":
			clothes.merge({"padded": 35, "knit": 16, "tshirt": 0, "trench": 8}, true)
		"muggy":
			clothes.merge({"tshirt": 40, "padded": 0, "knit": 0, "trench": 0, "hoodie": 4, "cardigan": 2}, true)
	if older:
		clothes["hoodie"] = 2
	if owner:  # behind the counter: something you can cook in, under an apron
		for formal in ["suit", "blazer", "trench", "scrubs"]:
			clothes[formal] = 0
	var wearing := Text.pick_weighted(clothes, randf(), "")
	var colour_weights := {}
	for id in CLOTHES_COLOURS:
		colour_weights[id] = int(CLOTHES_COLOURS[id][2])
	var colour := Text.pick_weighted(colour_weights, randf(), "")
	if wearing == "suit":
		colour = SUIT_COLOURS.pick_random()
	elif wearing == "scrubs":
		colour = SCRUBS_COLOURS.pick_random()
	var bag := ""
	var bag_roll := randf()
	if not owner and bag_roll < 0.45:
		bag = "briefcase" if wearing in ["suit", "blazer"] and bag_roll < 0.25 else ("backpack" if bag_roll < 0.2 else "tote")
	return {
		"age_range": age_range, "hair": Text.pick_weighted(hair, randf(), ""), "hair_colour": Text.pick_weighted(colours, randf(), ""),
		"clothes": wearing, "colour": colour, "glasses": randf() < 0.25, "bag": bag,
		"skin": randi() % SKIN_TONES.size(), "apron": owner,
	}


## A look in words, for prompts: "in their thirties, with black hair in a bob and glasses,
## wearing a beige trench coat and carrying a tote bag".
static func look_text(look: Dictionary) -> String:
	var hair_colour: String = HAIR_COLOURS.get(look.get("hair_colour", "black"), HAIR_COLOURS["black"])[1]
	var hair_text := str(HAIR_STYLES.get(look.get("hair", "short"), HAIR_STYLES["short"])).format({"c": hair_colour})
	var text := "%s, with %s" % [AGE_RANGES.get(look.get("age_range", "30s"), AGE_RANGES["30s"])[2], hair_text]
	if bool(look.get("glasses", false)):
		text += " and glasses"
	var colour: String = CLOTHES_COLOURS.get(look.get("colour", "black"), CLOTHES_COLOURS["black"])[1]
	var clothes := str(CLOTHES.get(look.get("clothes", "knit"), "a jumper"))
	var article := "an" if colour.substr(0, 1) in ["a", "e", "i", "o", "u"] else "a"
	text += ", wearing %s %s %s" % [article, colour, clothes.trim_prefix("a ").trim_prefix("an ")]
	if clothes == "hospital scrubs":
		text = text.replace("wearing %s %s hospital scrubs" % [article, colour], "wearing %s hospital scrubs" % colour)
	if bool(look.get("apron", false)):
		text += " under an apron"
	var bag := str(look.get("bag", ""))
	if bag != "":
		text += " and carrying %s" % BAGS.get(bag, "a bag")
	return text


## Someone as a stranger sees them: "the woman in the beige trench coat".
static func seen_as(person: Dictionary) -> String:
	var gender := str(person.get("gender", ""))
	var who := "woman" if gender == "woman" else ("man" if gender == "man" else "person")
	var look: Dictionary = person.get("look", {})
	if look.is_empty():
		return "the %s next to them" % who
	var colour: String = CLOTHES_COLOURS.get(look.get("colour", "black"), CLOTHES_COLOURS["black"])[1]
	var clothes := str(CLOTHES.get(look.get("clothes", "knit"), "a jumper")).trim_prefix("a ")
	return "the %s in the %s %s" % [who, colour, clothes]


# --- Names in Hangul ---------------------------------------------------------------------
# Everyone's name is shown in Hangul too, next to the romanised one (like the sign), so the
# player gets used to seeing Korean names. The AI writes it; the game checks it fits the
# romanised name, and drops it rather than showing a wrong one.
