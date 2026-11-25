extends RefCounted
## Portraits: which of the library's faces (art/portraits, made by tools/art/portraits.py) a
## person gets, from their look. The library is by what a recolour can't change (gender, age
## range, hairstyle, glasses: "w_60s_perm_glasses"); the game repaints it onto their own hair,
## skin and clothes (people_art.gd portrait()). The pick is the same every time for the same
## look, so a regular keeps their face.
## (Part of the game's rules: pure functions and the tables they use, with any dice rolls
## passed in, so they can be tested on their own. See ARCHITECTURE.md.)

const Looks = preload("res://scripts/rules/looks.gd")

## The hairstyles drawn for women (the rest for men): a non-binary customer gets the portrait
## drawn for their hairstyle (looks.gd gives them both kinds).
const WOMENS_HAIR := ["long", "bob", "ponytail", "bun", "pixie", "perm"]
## When there's no portrait with their hairstyle: the nearest, in order.
const NEAREST_HAIR := {
	"long": ["ponytail", "bob"], "bob": ["long", "pixie"], "ponytail": ["long", "bun"], "bun": ["ponytail", "long"],
	"pixie": ["bob", "short"], "perm": ["bob", "pixie"], "short": ["side_part", "buzz"], "side_part": ["short", "two_block"],
	"buzz": ["short", "balding"], "two_block": ["short", "side_part"], "balding": ["short", "buzz"],
}
const AGE_ORDER := ["20s", "30s", "40s", "50s", "60s", "70s"]


## "w" or "m": whose portraits they get.
static func side_of(gender: String, hair: String) -> String:
	if gender == "woman":
		return "w"
	if gender == "man":
		return "m"
	return "w" if hair in WOMENS_HAIR else "m"


## The portrait they'd ideally have ("w_20s_long_glasses"), whether or not it's in the library.
static func ideal(gender: String, look: Dictionary, age: int = 0) -> String:
	var hair := str(look.get("hair", ""))
	var age_range := str(look.get("age_range", ""))
	if not age_range in AGE_ORDER:
		age_range = Looks.age_range_of(age) if age > 0 else "30s"
	return "%s_%s_%s%s" % [side_of(gender, hair), age_range, hair, "_glasses" if bool(look.get("glasses", false)) else ""]


## The portrait for someone: {"key": a portrait id, or "" for none, "how": "matched" (theirs),
## "fallback" (the nearest there is: another hairstyle, without glasses, a neighbouring age),
## or "none"}. have: the portrait ids there are (Art.has). The same answer every time.
static func pick(gender: String, look: Dictionary, have: Array, age: int = 0) -> Dictionary:
	var best := ideal(gender, look, age)
	if best in have:
		return {"key": best, "how": "matched"}
	var parts := best.split("_", true, 2)  # [side, age range, hair (+ "_glasses")]
	var side: String = parts[0]
	var glasses := best.ends_with("_glasses")
	var hair: String = parts[2].trim_suffix("_glasses") if parts.size() > 2 else ""
	var hairs: Array = [hair if hair != "" else ("bob" if side == "w" else "short")]  # (a look from before hairstyles)
	hairs.append_array(NEAREST_HAIR.get(hairs[0], []))
	var ages: Array = [parts[1]]
	var at := AGE_ORDER.find(parts[1])
	for step in range(1, AGE_ORDER.size()):  # (the nearest age ranges, younger first)
		for near in [at - step, at + step]:
			if near >= 0 and near < AGE_ORDER.size():
				ages.append(AGE_ORDER[near])
	for each_age in ages:
		for each_hair in hairs:
			for with_glasses in ([glasses, not glasses] if glasses else [false, true]):
				var key := "%s_%s_%s%s" % [side, each_age, each_hair, "_glasses" if with_glasses else ""]
				if key in have:
					return {"key": key, "how": "fallback"}
	for key in have:  # (anyone of theirs, at least)
		if str(key).begins_with(side + "_"):
			return {"key": str(key), "how": "fallback"}
	return {"key": "", "how": "none"}


# --- Faces of their own (made during the game: ai/portrait_maker.gd) ---------------------------

## The image model's prompt for a face of someone's own, as tools/art/portraits.py's PROMPT
## (the same style, and always black hair and a plain bright red top on flat green, so the
## split finds the parts and the game repaints them onto their own colours), with their look's
## hairstyle, age and glasses, and a line of who they are (about: their appearance, in the AI's
## words) after it. The colours are said again last, as the description may give others (an
## apron from it came out as a dark block the split read as hair; grey at the temples as skin).
const PROMPT := "Head and shoulders portrait of a Korean %s with %s, wearing a plain bright red top, facing the viewer, neutral friendly expression.%s Flat cel-shaded illustration, simple shapes, clean dark outlines, two tones of shading, like a cozy visual novel character portrait. Whatever the description says: black hair with no grey in it, and a plain bright red T-shirt with nothing over it (no apron, jacket, scarf or straps). Plain flat green background, no text."
const HAIR_SHAPES := {
	"long": "long straight black hair falling past the shoulders",
	"bob": "black hair cut in a chin-length bob",
	"ponytail": "black hair pulled back tightly into a ponytail behind the head, forehead showing",
	"bun": "black hair pulled up into a round bun on top of the head, forehead showing",
	"pixie": "very short cropped black hair, a pixie cut with the ears showing",
	"perm": "very curly, tightly permed short black hair in small curls all over",
	"short": "short neat black hair",
	"side_part": "black hair neatly combed with a side parting",
	"buzz": "a very short black buzz cut, close to the scalp",
	"two_block": "black hair in a two-block cut, shaved short at the sides and longer on top, with a long fringe over the forehead",
	"balding": "a bald top with a receding hairline and a little short black hair at the sides",
}
const AGE_WORDS := {"20s": ["twenties", ""], "30s": ["thirties", ""], "40s": ["forties", ""],
	"50s": ["fifties", "a few lines on {p} face"], "60s": ["sixties", "lines and wrinkles on {p} face"],
	"70s": ["seventies", "an old, wrinkled face"]}
const ABOUT_MOST := 220  # (characters of the description: a line, not a paragraph)


static func prompt_for(gender: String, look: Dictionary, age: int = 0, about: String = "") -> String:
	var who: String = {"woman": "woman", "man": "man"}.get(gender, "person")
	var p: String = {"woman": "her", "man": "his"}.get(gender, "their")
	var age_range := str(look.get("age_range", ""))
	if not age_range in AGE_ORDER:
		age_range = Looks.age_range_of(age) if age > 0 else "30s"
	var words: Array = AGE_WORDS[age_range]
	var hair := str(look.get("hair", ""))
	if not HAIR_SHAPES.has(hair):
		hair = "bob" if side_of(gender, hair) == "w" else "short"
	var shape := str(HAIR_SHAPES[hair])
	if str(words[1]) != "":
		shape += ", " + str(words[1]).format({"p": p})
	shape += ", and thin-framed glasses" if bool(look.get("glasses", false)) else ", and no glasses"
	var line := about.strip_edges().replace("\n", " ")
	if line.length() > ABOUT_MOST:
		line = line.left(ABOUT_MOST).rsplit(" ", true, 1)[0] + "..."
	if line != "" and not line.ends_with(".") and not line.ends_with("..."):
		line += "."
	return PROMPT % ["%s in %s %s" % [who, p, words[0]], shape, (" Who they are: " + line) if line != "" else ""]


## A face of their own's portrait id: unique to the bar, the person and the picture (a new one
## is a new id, so nothing drawn from the old one is reused): "own_<bar>_owner_8123".
static func own_key(bar_id: String, person: String, pic_seed: int) -> String:
	return "own_%s_%s_%d" % [bar_id.replace("/", "_"), person, pic_seed]


## The name the split scores a casting photo by (rules/portrait_split.gd score: little hair if
## it's "balding", glasses' frames if it ends "_glasses"), as the library's ids say them.
static func split_name(who: String, look: Dictionary) -> String:
	return who + ("_balding" if str(look.get("hair", "")) == "balding" else "") + ("_glasses" if bool(look.get("glasses", false)) else "")


## A regular's face of their own is the best of their three casting photos only if it split at
## least this cleanly (the split's score: lower is cleaner; the library's picks are about 0 to
## 0.1); worse, and they keep the library's face. (The owner's is the PD's to judge, on the setup.)
const CLEAN_ENOUGH := 0.3


## Whether a portrait id is a face of someone's own (not the library's).
static func is_own(key: String) -> bool:
	return key.begins_with("own_")


# --- Their moods (a face of their own redrawn: ai/portrait_maker.gd redraw) --------------------

## The edit model's prompt for a face of someone's own in a TV mood (rules/captions.gd REACTIONS),
## word for word tools/art/portraits.py's REACT_PROMPT, REACT_GLASSES and MOOD_FACES (the
## library's reaction faces: test_portraits checks they match). Glasses said outright: "same
## glasses if any" put glasses on nearly every face that had none (22 Nov).
const REACT_PROMPT := "Same person, same face, same hair, {glasses}, same red top, same flat green background, same framing and the same flat cel-shaded illustration style. Change only the facial expression: {face}."
const REACT_GLASSES := {true: "same glasses", false: "no glasses (bare eyes, as in the picture)"}
const MOOD_FACES := {
	"shock": "wide-eyed with shock, eyebrows raised high, mouth dropped open",
	"sad": "sad, eyes glistening with tears, a tear on one cheek, mouth turned down",
	"sweet": "shy and flustered, pink blushing cheeks, a small bashful smile, eyes glancing aside",
	"warm": "deeply touched, a soft warm smile, eyes a little teary",
	"funny": "laughing hard, eyes squeezed shut, mouth wide open",
	"awkward": "awkward, a stiff forced smile, eyes glancing sideways, a bead of sweat on the forehead",
	"roast": "caught out and indignant, frowning, cheeks puffed out, pouting",
}


## A mood's prompt for someone with (or without) glasses: "" for a mood there's no face for.
static func react_prompt(mood: String, glasses: bool) -> String:
	if not MOOD_FACES.has(mood):
		return ""
	return REACT_PROMPT.format({"glasses": REACT_GLASSES[glasses], "face": MOOD_FACES[mood]})
