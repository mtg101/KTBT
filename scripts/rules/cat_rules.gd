extends RefCounted
## The cat: coats, personalities, where it goes, how it's talked about, and its name.
## (Part of the game's rules: pure functions and the tables they use, with any dice rolls
## passed in, so they can be tested on their own. See ARCHITECTURE.md.)

const Names = preload("res://scripts/rules/names.gd")
const Text = preload("res://scripts/rules/text.gd")


## Every bar has a cat. The game decides its coat and personality (and, all night, where it
## is); the AI only names it. Its personality sets how likely each spot is.
const CAT_COATS := {"ginger": "d9883a", "black": "2b2a33", "white": "eeeae0", "tabby": "9c7a52", "calico": "e8e0d0", "grey": "8a8a96"}


const CAT_PERSONALITIES := {
	"lazy": "lazy: sleeps most of the night",
	"affectionate": "affectionate: always looking for a lap",
	"greedy": "greedy: a shameless beggar for food",
	"grumpy": "grumpy: tolerates people, barely",
	"curious": "curious: into everything, and often off out in the street",
}


## Where the cat can be. "lap", "feet" and "food" are with a customer (food: by the stool of
## someone with food on their table, staring at it).
const CAT_SPOTS := ["stove", "counter", "stools", "street", "lap", "feet", "food"]


const CAT_SPOT_WEIGHTS := {
	"lazy": {"stove": 6.0, "counter": 3.0, "stools": 1.0, "street": 1.0, "lap": 2.0, "feet": 0.5, "food": 0.5},
	"affectionate": {"stove": 1.0, "counter": 1.0, "stools": 1.0, "street": 0.5, "lap": 5.0, "feet": 3.0, "food": 1.0},
	"greedy": {"stove": 1.0, "counter": 2.0, "stools": 2.0, "street": 1.0, "lap": 0.5, "feet": 1.0, "food": 5.0},
	"grumpy": {"stove": 4.0, "counter": 3.0, "stools": 1.0, "street": 2.0, "lap": 0.3, "feet": 0.2, "food": 1.0},
	"curious": {"stove": 1.0, "counter": 2.0, "stools": 4.0, "street": 4.0, "lap": 1.0, "feet": 2.0, "food": 1.0},
}


## Korean pet names, for a bar whose cat the AI couldn't name (or an older bar that had none).
## The tent's cat is a stray that wandered in one night and stayed: it isn't anyone's, so the
## owner and the regulars gave it a nickname, the kind Koreans give street cats. Always one of
## these (never a person's name, which mixed it up with the customers: a cat called Ji-eun,
## and a Park Ji-eun at the counter). coats: the coats it suits ([]: any). Each name's Hangul
## and meaning, for the hover.
const CAT_NICKNAMES := {
	"Nabi": {"hangul": "나비", "means": "butterfly: what Koreans have called street cats for generations", "coats": []},
	"Nyang-i": {"hangul": "냥이", "means": "kitty", "coats": []},
	"Mandu": {"hangul": "만두", "means": "dumpling", "coats": []},
	"Kong-i": {"hangul": "콩이", "means": "little bean", "coats": []},
	"Gamja": {"hangul": "감자", "means": "potato", "coats": []},
	"Bori": {"hangul": "보리", "means": "barley", "coats": ["tabby", "ginger", "grey"]},
	"Chijeu": {"hangul": "치즈", "means": "cheese: what Koreans call a ginger cat", "coats": ["ginger"]},
	"Hotteok": {"hangul": "호떡", "means": "a sweet street pancake: round and golden", "coats": ["ginger"]},
	"Kkami": {"hangul": "까미", "means": "blackie", "coats": ["black"]},
	"Kkamjang-i": {"hangul": "깜장이", "means": "little black one", "coats": ["black"]},
	"Dubu": {"hangul": "두부", "means": "tofu", "coats": ["white"]},
	"Seolgi": {"hangul": "설기", "means": "a white rice cake", "coats": ["white"]},
	"Godeungeo": {"hangul": "고등어", "means": "mackerel: what Koreans call a striped tabby", "coats": ["tabby", "grey"]},
	"Hodu": {"hangul": "호두", "means": "walnut", "coats": ["tabby"]},
	"Samsaek-i": {"hangul": "삼색이", "means": "three colours: what Koreans call a calico", "coats": ["calico"]},
	"Jaetbit": {"hangul": "잿빛", "means": "ash grey", "coats": ["grey"]},
}
const CAT_NAMES := ["Nabi", "Nyang-i", "Mandu", "Kong-i", "Gamja", "Bori", "Chijeu", "Hotteok", "Kkami", "Kkamjang-i", "Dubu", "Seolgi", "Godeungeo", "Hodu", "Samsaek-i", "Jaetbit"]


## The nicknames that suit a cat of this coat (its own first, then the ones for any coat).
static func nicknames_for(coat: String) -> Array:
	var own: Array = CAT_NAMES.filter(func(n): return (CAT_NICKNAMES[n]["coats"] as Array).has(coat))
	return own + CAT_NAMES.filter(func(n): return (CAT_NICKNAMES[n]["coats"] as Array).is_empty())


## Whether a name's one of the nicknames (a bar from before them has a cat with some other name).
static func is_nickname(cat_name: String) -> bool:
	return CAT_NICKNAMES.has(cat_name)


## A nickname for a cat from before nicknames, the game's own pick (no dice: the same every
## time for the same cat): one that suits its coat, not another bar's.
static func nickname_for_old_cat(cat: Dictionary, taken: Array = []) -> String:
	var choices: Array = nicknames_for(str(cat.get("coat", ""))).filter(func(n): return not taken.has(n))
	if choices.is_empty():
		choices = CAT_NAMES
	return str(choices[posmod(hash(str(cat.get("name", ""))), choices.size())])


const CAT_WORDS := ["cat", "cats", "kitty", "kitten", "goyangi", "puss", "pussycat", "moggy"]


## Stroking, petting, a lap...: only for a cat that's on the lap of someone in the conversation.
const CAT_TOUCH_WORDS := ["stroke", "strokes", "stroking", "stroked", "pet", "pets", "petting", "petted", "scratch", "scratches", "scratching", "cuddle", "cuddles", "cuddling", "lap", "laps"]


const MAX_CAT_NAME_LENGTH := 16


## Where the cat goes next, from a random roll between 0 and 1, by its personality. It
## always moves somewhere new. Spots with a customer need one (lap and feet: anyone at the
## counter; food: someone with food on their table).
static func pick_cat_spot(personality: String, has_people: bool, has_food: bool, roll: float, current: String = "") -> String:
	var weights: Dictionary = CAT_SPOT_WEIGHTS.get(personality, CAT_SPOT_WEIGHTS["lazy"])
	var choices: Array = []
	var total := 0.0
	for spot in CAT_SPOTS:
		if spot == current or (spot in ["lap", "feet"] and not has_people) or (spot == "food" and not has_food):
			continue
		choices.append(spot)
		total += float(weights[spot])
	var target := clampf(roll, 0.0, 0.9999) * total
	for spot in choices:
		target -= float(weights[spot])
		if target < 0.0:
			return spot
	return choices.back() if not choices.is_empty() else "stove"


## Where the cat is, as a sentence: "Nabi is curled up asleep by the stove."
## with: the customer it's with (for lap, feet and food).
static func cat_text(cat_name: String, spot: String, with: String = "") -> String:
	match spot:
		"stove": return "%s is curled up asleep by the stove." % cat_name
		"counter": return "%s is washing itself on the end of the counter." % cat_name
		"stools": return "%s is prowling about under the stools." % cat_name
		"street": return "%s is out in the street, not in the tent." % cat_name
		"lap": return "%s is curled up on %s's lap." % [cat_name, with]
		"feet": return "%s is winding round %s's ankles." % [cat_name, with]
		"food": return "%s is sitting by %s's stool, staring at their food." % [cat_name, with]
	return "%s is somewhere about." % cat_name


## What it looks like when the cat goes somewhere: "Nabi jumps up onto Kim Ji-ho's lap."
static func cat_move_text(cat_name: String, spot: String, with: String = "") -> String:
	match spot:
		"stove": return "%s curls up by the stove and goes to sleep." % cat_name
		"counter": return "%s hops up onto the end of the counter for a wash." % cat_name
		"stools": return "%s goes prowling under the stools." % cat_name
		"street": return "%s slips out under the tarp into the street." % cat_name
		"lap": return "%s jumps up onto %s's lap and settles in." % [cat_name, with]
		"feet": return "%s winds round %s's ankles." % [cat_name, with]
		"food": return "%s sits down by %s's stool, eyes fixed on their food." % [cat_name, with]
	return "%s wanders off." % cat_name


## A greedy cat helps itself now and then: when it's sitting by someone's food and there's
## a fish cake skewer on their table, it may grab one and bolt (the skewer's gone; it's still
## on the bill). How likely, by personality: greedy cats mostly, curious ones once in a while.
const THEFT_CHANCE := {"greedy": 0.4, "curious": 0.1}
const STEALABLE := "odeng"  # (a skewer's easy to run off with)


static func steals(personality: String, stealable_on_table: bool, roll: float) -> bool:
	return stealable_on_table and roll < float(THEFT_CHANCE.get(personality, 0.0))


## The moments after (see CAT_MOMENTS): for the owner, and for whoever it robbed.
## Someone whose time's up with the cat asleep on their lap can't get up yet: they stay this
## many game minutes more (once a visit), and the cat moves on before then.
const LAP_KEEPS_MINUTES := 12.0
const LAP_MOMENT := "Your time's up and you'd go now, but {cat} is fast asleep on your lap: you can't get up until {cat} does, and you say so."
const LAP_TEXT := "{name}'s ready to go, but {cat} is fast asleep on their lap."

## Eyeing someone's food and not stealing it: how likely they slip the cat a bit, by its
## personality (a greedy one begs hardest; a grumpy one won't take it from just anyone).
const SHARE_CHANCE := {"greedy": 0.5, "affectionate": 0.35, "curious": 0.3, "lazy": 0.2, "grumpy": 0.1}
const SHARE_MOMENT := "You've just slipped {cat} a bit of your {dish}."
const SHARE_MOMENT_OWNER := "{name} has just slipped {cat} a bit of their {dish} under the counter."
const SHARE_TEXT := "{name} slips {cat} a bit of their {dish}."


static func shares(personality: String, roll: float) -> bool:
	return roll < float(SHARE_CHANCE.get(personality, 0.0))


## Someone says the cat's name: now and then it answers (a Korean cat's meow: 야옹), more often
## it couldn't care less. "answer", "ignore" or "" (nothing to see).
const ANSWER_CHANCE := 0.2
const IGNORE_CHANCE := 0.35
const ANSWER_TEXT := "{cat}: 야옹 (ya-ong)."
const IGNORE_TEXTS := ["{cat} doesn't even look up.", "{cat} flicks an ear, and that's all.", "{cat} yawns.", "{cat} turns its back on them."]


static func hears_its_name(line: String, cat_name: String, roll: float) -> String:
	if cat_name == "" or RegEx.create_from_string("(?i)(?<![\\w-])%s(?![\\w-])" % regex_escape(cat_name)).search(line) == null:
		return ""
	if roll < ANSWER_CHANCE:
		return "answer"
	if roll < ANSWER_CHANCE + IGNORE_CHANCE:
		return "ignore"
	return ""


static func regex_escape(text: String) -> String:
	var out := ""
	for c in text:
		out += ("\\" + c) if "\\^$.|?*+()[]{}".contains(c) else c
	return out


const THEFT_MOMENT_OWNER := "{cat} has just snatched an odeng skewer off {name}'s plate and bolted out into the street with it."
const THEFT_MOMENT_ROBBED := "{cat} has just snatched one of their odeng skewers and bolted out into the street with it."


## People talk to cats. When the cat goes somewhere, now and then the next line from whoever
## it's with gets a moment (a situation, never a line: whether they say anything to it is up
## to them). lap, feet and food: the customer it's with; counter, stove and stools: the
## owner (it's their tent). {cat} is its name.
const CAT_MOMENTS := {
	"lap": "{cat} has just settled on their lap and is looking up at them, the way cats do when they expect to be spoken to.",
	"feet": "{cat} is winding round their ankles, mewing up at them.",
	"food": "{cat} is sitting by their stool, staring at their food as if some of it is owed.",
	"counter": "{cat} is up on the counter again, where the owner has told it a hundred times not to be.",
	"stove": "{cat} is asleep by the stove, right where the owner needs to stand.",
	"stools": "{cat} is weaving between the stools, getting under everyone's feet.",
}
const CAT_MOMENT_CHANCE := 0.5


## Now and then, a moment for whoever the cat's with (see CAT_MOMENTS), or "". Whether it's
## for the owner: owner_spot().
static func cat_moment(cat_name: String, spot: String, roll: float) -> String:
	if roll >= CAT_MOMENT_CHANCE or not CAT_MOMENTS.has(spot):
		return ""
	return str(CAT_MOMENTS[spot]).replace("{cat}", cat_name)


## Whether a cat in this spot is the owner's to deal with, not a customer's.
static func owner_spot(spot: String) -> bool:
	return spot in ["counter", "stove", "stools"]


## The cat must be talked about as it really is: nobody strokes it, or talks of it on a lap,
## unless it's on the lap of someone in this conversation (people: their names). Returns a
## problem, or "".
static func check_cat(line: String, cat_name: String, spot: String, with: String, people: Array) -> String:
	var said := Text.words(line)
	var about_cat := false
	for word in CAT_WORDS + Array(Text.words(cat_name)):
		if word in said:
			about_cat = true
	if not about_cat:
		return ""
	var touching := false
	for word in CAT_TOUCH_WORDS:
		if word in said:
			touching = true
	if not touching or (spot == "lap" and with in people):
		return ""
	return "the line has the cat being stroked or on a lap, but that isn't what's happening: %s" % cat_text(cat_name, spot, with)


## A cat's name, from the AI: {"name": a short Korean pet name in English letters}.
## taken: names other bars' cats already have (so every bar's cat is its own).
static func validate_cat_name(data: Variant, owner_name: String = "", taken: Array = []) -> String:
	var problem := Text.check_fields(data, ["name"])
	if problem != "":
		return problem
	var said := Text.unquote(Text.tidy_text(data["name"]))
	var cat_name := ""
	for nickname in CAT_NAMES:  # (one of the nicknames: spelled as the list has it)
		if said.to_lower().replace(" ", "-") == str(nickname).to_lower():
			cat_name = nickname
	if cat_name == "":
		return "the cat's nickname must be one from the list given: \"%s\" isn't" % said
	for part in owner_name.split(" ", false):
		if cat_name.to_lower() == part.to_lower():
			return "the cat can't have the owner's name"
	for other in taken:
		if cat_name.to_lower() == str(other).to_lower():
			return "another bar's cat is already called %s: pick a different name" % cat_name
	data["name"] = cat_name
	data["hangul"] = str(CAT_NICKNAMES[cat_name]["hangul"])  # (the game's own)
	return ""


## The game's own pick of a nickname (when the AI can't): one that suits the coat ("": any).
static func fallback_cat_name(roll: float, taken: Array = [], coat: String = "") -> String:
	var suits: Array = nicknames_for(coat) if coat != "" else CAT_NAMES
	var free := suits.filter(func(n): return not taken.has(n))
	if free.is_empty():
		free = suits
	return free[clampi(floori(roll * free.size()), 0, free.size() - 1)]


## Every cat is a she or a he (a game fact, so everyone gets it right).
const CAT_SEXES := ["she", "he"]
