extends RefCounted
## The night on social media (PLAN.md's Social media posts): customers posting about their night
## on 달밤 (Dalbam, "a moonlit night"), the feed app of the game's own, never a real one. The
## game picks the facts (pick: 0 to 3 posts from tonight's events: the big moments, the cat's
## thefts, a new regular, a full house, first snow, a PD's card taken up, a long wait for food;
## a quiet night, a quiet feed), and the words, for now, are the game's own (stitched from
## TEMPLATES; the canned AI answers "socials" with them too); check() is what any words must
## pass: their length, no numbers, no brands, the poster's own handle, hashtags only from
## HASHTAGS, Korean only with its meaning, food only what they were served. Each post is a
## selfie, a food pic, the cat, or text alone; the pictures are real snapshots of the stage when
## it happened (bar/snapshots.gd, wants_snap says when), stuck round the 3am diary page
## (ui/social_feed.gd) and kept with the entry.

const Names = preload("res://scripts/rules/names.gd")
const Talk = preload("res://scripts/rules/talk.gd")
const Text = preload("res://scripts/rules/text.gd")
const Glossary = preload("res://scripts/rules/glossary.gd")
const Menu = preload("res://scripts/rules/menu.gd")
const NightRules = preload("res://scripts/rules/night_rules.gd")

const APP := "달밤"  # (its meaning: rules/hangul.gd MEANINGS)
const APP_ENGLISH := "Dalbam"
const MOST := 3
const MOST_CHARS := 140
const LONG_WAIT := 45  # game minutes from ordering a dish to its coming: a long wait worth posting about
const QUIET_FOOD_CHANCE := 0.6  # a night with nothing to post about: a food pic, this often
const SHOTS := ["selfie", "food", "cat", "text"]
const PICTURED := ["selfie", "food", "cat"]

## How highly each kind of thing is worth posting about (a big moment adds its size).
const WORTH := {"cat_theft": 60, "first_snow": 55, "moment": 50, "new_regular": 45, "long_wait": 40, "full_house": 35, "card": 30, "food": 10}
## What each kind's post is.
const SHOT_OF := {"cat_theft": "cat", "first_snow": "text", "moment": "selfie", "new_regular": "selfie", "long_wait": "food", "full_house": "text", "card": "text", "food": "food"}

## A handle is the poster's given name and one of these (always the same one for the same person).
const HANDLE_ENDS := ["_eats", ".at.night", "_soju", "_seoul", ".late", "_pocha", ".under.tarp", "_mood"]

## Every hashtag a post can have: English, or Korean from this list (each explained on hover).
const HASHTAGS := ["#pojangmacha", "#tentbar", "#latenight", "#포차", "#포장마차", "#tentcat", "#고양이", "#firstsnow", "#첫눈",
	"#단골", "#regular", "#야식", "#latenightfood", "#만석", "#fullhouse", "#nofilter", "#plotTwist", "#soju", "#소주", "#mood", "#whatanight"]
const TAGS_OF := {"cat_theft": ["#tentcat", "#고양이"], "first_snow": ["#firstsnow", "#첫눈"], "new_regular": ["#단골", "#regular"],
	"long_wait": ["#야식", "#latenightfood"], "food": ["#야식", "#latenightfood"], "full_house": ["#만석", "#fullhouse"],
	"card": ["#plotTwist", "#whatanight"], "moment": ["#nofilter", "#mood", "#whatanight"]}
const COMMON_TAGS := ["#pojangmacha", "#tentbar", "#latenight", "#포차"]

## The game's own words, by kind (a moment's by its mood). {dish}, {cat}: tonight's.
const TEMPLATES := {
	"cat_theft": ["{cat} stole my {dish}. right off my plate. robbed and charmed", "the tent's cat, {cat}, owes me a {dish}",
		"{cat} took my {dish} and didn't even look back"],
	"first_snow": ["first snow of the year, watched from under the tarp", "it's snowing!! and i'm warm in a tent bar",
		"first snow. plastic stool. the tarp going white. perfect"],
	"new_regular": ["the owner remembered my order. that's it, i live here now", "think this is my spot now",
		"same stool as last time. it's tradition now"],
	"long_wait": ["waited ages for this {dish}. worth every minute", "the {dish} took its time. so did i",
		"a single cook, a full tent, and my {dish} was worth the wait"],
	"food": ["late {dish} under the tarp. perfect", "nothing beats {dish} at this hour", "{dish} and a plastic stool. that's the night"],
	"full_house": ["every stool taken tonight. got the last one", "packed tent tonight. elbow to elbow at the counter",
		"full house under the tarp tonight"],
	"card": ["tonight at the tent felt like something out of a drama. you had to be there", "the strangest thing happened at the counter tonight. not explaining",
		"is someone filming this tent bar? because tonight was a whole episode"],
	"moment": {
		"shock": ["did NOT see that coming at the counter tonight", "still processing what just got said at the tent bar", "came for a drink, left with a plot twist"],
		"sad": ["some nights hit different under the tarp", "said more than i meant to tonight. the owner just poured another glass", "needed tonight more than i knew"],
		"sweet": ["is it the drink or was that a moment?? asking for me", "my heart did a thing at the counter tonight", "not saying anything. just. tonight."],
		"warm": ["the owner looked after me tonight and i don't know how to say thank you", "this tent bar is a hug with a tarp on it", "people were kind at the counter tonight"],
		"funny": ["laughed so hard at the counter the owner told us to keep it down", "never laughed this much under a tarp", "the counter tonight should have its own show. wait"],
		"awkward": ["said the wrong thing at the tent bar. going to live under this tarp now", "the silence after what i said... you could hear the stove", "new personal record for awkward"],
		"roast": ["got absolutely roasted tonight and honestly fair", "the counter did not hold back on me tonight", "humbled. under a tarp. at this hour"],
	},
}


## Tonight's posts, by when it happened: [{"about", "poster", "handle", "shot", "text", "tags",
## "at", "mood", "dish", "dish_id", "snap" (the snapshot it wants, wants_snap's key), "face"}].
## info: "owner", "cat" (names), "faces" (name -> kept face, visit.gd _keep_faces: a selfie needs
## the poster's), "taken_cards" (the PD's cards taken up tonight), "seats". One post a poster,
## the most worth posting about first; never the owner.
static func pick(events: Array, info: Dictionary, dice: RandomNumberGenerator) -> Array:
	var owner_name := str(info.get("owner", ""))
	var faces: Dictionary = info.get("faces", {})
	var seats := int(info.get("seats", NightRules.SEATS))
	var taken: Array = info.get("taken_cards", [])
	var here := {}  # who's in, at each moment (for first snow)
	var found: Array = []
	var fed := {}  # whose first food's been seen
	for event in events:
		var kind := str(event.get("kind", ""))
		var who := str(event.get("name", ""))
		var at := int(event.get("at", 0))
		match kind:
			"sat_down":
				here[who] = true
				if int(event.get("seated", 0)) >= seats:
					found.append(_candidate("full_house", who, at, event))
			"left":
				here.erase(who)
			"big_moment":
				var said_by := str(event.get("who", ""))
				if said_by != "" and said_by != owner_name and Names.given_name(owner_name) != said_by:
					var moment := _candidate("moment", said_by, at, event)
					moment["worth"] = int(WORTH["moment"]) + 5 * int(event.get("size", 0))
					moment["mood"] = str(event.get("mood", "funny"))
					found.append(moment)
			"cat_stole":
				var stolen := _candidate("cat_theft", who, at, event)
				stolen["dish"] = str(event.get("dish", ""))
				found.append(stolen)
			"became_regular":
				found.append(_candidate("new_regular", who, at, event))
			"first_snow":
				var watchers: Array = here.keys()
				if not watchers.is_empty():
					found.append(_candidate("first_snow", str(watchers[dice.randi() % watchers.size()]), at, event))
			"plant_played":
				if who != "" and who != owner_name and taken.has(str(event.get("card", ""))):
					found.append(_candidate("card", who, at, event))
			"dish_served":
				var dish_id := Menu.resolve(str(event.get("dish", "")))
				if Menu.find(dish_id).get("kind", "") != "food":
					continue
				var about := "long_wait" if float(event.get("wait", 0.0)) >= LONG_WAIT else ("food" if not fed.has(who) else "")
				fed[who] = true
				if about != "":
					var dish := _candidate(about, who, at, event)
					dish["dish"] = str(event.get("dish", ""))
					dish["dish_id"] = dish_id
					found.append(dish)
	for candidate in found:
		candidate["worth"] = float(candidate["worth"]) + dice.randf()  # (ties: a little luck)
	found.sort_custom(func(a, b): return float(a["worth"]) > float(b["worth"]))
	var eventful: Array = found.filter(func(c): return str(c["about"]) != "food")
	var room := mini(MOST, eventful.size())
	if room < MOST and (eventful.is_empty() and dice.randf() < QUIET_FOOD_CHANCE or eventful.size() == 1 and dice.randf() < 0.5):
		room += 1  # (a quiet night: a food pic, maybe)
	var posts: Array = []
	var posting := {}
	for candidate in found:
		if posts.size() >= room:
			break
		var poster := _whose(str(candidate["poster"]), faces)
		if poster == "" or posting.has(poster) or poster == owner_name:
			continue
		if str(candidate["about"]) == "food" and posts.any(func(p): return str(p["shot"]) == "food"):
			continue
		posting[poster] = true
		posts.append(_post(candidate, poster, info, faces, dice))
	posts.sort_custom(func(a, b): return int(a["at"]) < int(b["at"]))
	return posts


static func _candidate(about: String, who: String, at: int, event: Dictionary) -> Dictionary:
	return {"about": about, "poster": who, "at": at, "worth": float(WORTH[about]), "snap": snap_key(event)}


## A kept face's full name for someone (a given name too), or the name as it is if there's no face.
static func _whose(person_name: String, faces: Dictionary) -> String:
	if person_name == "":
		return ""
	if faces.has(person_name):
		return person_name
	for full in faces:
		if Names.given_name(str(full)) == person_name:
			return str(full)
	return person_name


static func _post(candidate: Dictionary, poster: String, info: Dictionary, faces: Dictionary, dice: RandomNumberGenerator) -> Dictionary:
	var about := str(candidate["about"])
	var shot := str(SHOT_OF[about])
	var face: Dictionary = faces.get(poster, {})
	if shot == "selfie" and face.is_empty():
		shot = "text"  # (no face kept for them: words alone)
	var post := {"about": about, "poster": poster, "handle": handle(poster), "shot": shot, "at": int(candidate["at"]),
		"mood": str(candidate.get("mood", "")), "dish": str(candidate.get("dish", "")), "dish_id": str(candidate.get("dish_id", "")),
		"snap": str(candidate["snap"]) if shot != "text" else "", "picture": "",
		"face": {} if face.is_empty() else {"key": str(face.get("key", "")), "look": (face.get("look", {}) as Dictionary).duplicate(true), "mood": str(candidate.get("mood", "calm")) if about == "moment" else "calm"}}
	if post["dish_id"] == "" and post["dish"] != "":
		post["dish_id"] = Menu.resolve(str(post["dish"]))
	post["text"] = stitched_words(post, str(info.get("cat", "")), dice)
	post["tags"] = stitched_tags(about, dice)
	return post


## A post's words, the game's own (TEMPLATES).
static func stitched_words(post: Dictionary, cat_name: String, dice: RandomNumberGenerator) -> String:
	var about := str(post.get("about", "food"))
	var choices: Variant = TEMPLATES.get(about, TEMPLATES["food"])
	if choices is Dictionary:
		choices = choices.get(str(post.get("mood", "")), choices["funny"])
	var words := str(choices[dice.randi() % choices.size()])
	return words.replace("{cat}", cat_name if cat_name != "" else "the cat").replace("{dish}", str(post.get("dish", "food")).to_lower())


## A post's hashtags: one or two of its kind's, and one of the tent's.
static func stitched_tags(about: String, dice: RandomNumberGenerator) -> Array:
	var own: Array = (TAGS_OF.get(about, []) as Array).duplicate()
	var tags: Array = []
	if not own.is_empty():
		tags.append(own.pop_at(dice.randi() % own.size()))
		if not own.is_empty() and dice.randf() < 0.5:
			tags.append(own[dice.randi() % own.size()])
	tags.append(COMMON_TAGS[dice.randi() % COMMON_TAGS.size()])
	return tags


## Someone's handle on the app: their given name and an ending of their own ("jiho.at.night").
static func handle(full_name: String) -> String:
	var given := RegEx.create_from_string("[^a-z0-9]").sub(Names.given_name(full_name).to_lower(), "", true)
	if given == "":
		given = "someone"
	return "@" + given + str(HANDLE_ENDS[absi(hash(full_name)) % HANDLE_ENDS.size()])


## What's wrong with a post, or "" if nothing: facts: "posters" (who was in tonight), "served"
## (name -> the dishes they had), "known" (names it may mention: the owner, the cat, tonight's
## customers). The AI's words will go through this too (PLAN.md's next step).
static func check(post: Dictionary, facts: Dictionary) -> String:
	var text := str(post.get("text", "")).strip_edges()
	if text == "":
		return "empty"
	if text.length() > MOST_CHARS:
		return "too long (%d characters)" % text.length()
	if not SHOTS.has(str(post.get("shot", ""))):
		return "not a kind of post: %s" % post.get("shot", "")
	var poster := str(post.get("poster", ""))
	if not (facts.get("posters", []) as Array).has(poster):
		return "a poster who wasn't here: %s" % poster
	if str(post.get("handle", "")) != handle(poster):
		return "not their handle: %s" % post.get("handle", "")
	if not Text.numbers_in(text).is_empty():
		return "a number not in the facts: %s" % ", ".join(PackedStringArray(Text.numbers_in(text)))
	var brand := Talk.real_brand(text + " " + " ".join(PackedStringArray(post.get("tags", []))))
	if brand != "":
		return "a real brand: %s" % brand
	for tag in post.get("tags", []):
		if not HASHTAGS.has(str(tag)):
			return "a hashtag not on the list: %s" % tag
	var korean := unknown_hangul(text + " " + " ".join(PackedStringArray(post.get("tags", []))))
	if korean != "":
		return "Korean the game doesn't know: %s" % korean
	for mention in RegEx.create_from_string("@[A-Za-z0-9._]+").search_all(text):
		return "a mention of someone: %s" % mention.get_string()
	var dish := str(post.get("dish", ""))
	if dish != "" and not (facts.get("served", {}).get(poster, []) as Array).has(dish):
		return "food they weren't served: %s" % dish
	var known: Array = facts.get("known", [])
	for word in RegEx.create_from_string("\\b[A-Z][a-z]+(-[a-z]+)?\\b").search_all(text):
		var named := word.get_string()
		if named in ["NOT", "I"] or known.any(func(k): return str(k).contains(named)):
			continue
		if not Glossary.words_in(named).is_empty():
			continue
		return "someone not in the facts: %s" % named
	return ""


## The first run of Hangul without a meaning the game knows, or "".
static func unknown_hangul(text: String) -> String:
	for run in RegEx.create_from_string("[\\x{AC00}-\\x{D7A3}]+").search_all(text):
		if Glossary.hangul_tip(run.get_string()) == "":
			return run.get_string()
	return ""


## The snapshot an event wants, as the stage looks when it happens: {"key", "aim" ("person": who
## it's about at their stool; "food": the dish as it's set down; "cat": the cat mid-theft), "name"};
## {} for none. Only what a post could be about (and a big moment the owner's isn't).
static func wants_snap(kind: String, facts: Dictionary, owner_name: String) -> Dictionary:
	var event := facts.duplicate()
	event["kind"] = kind
	match kind:
		"big_moment":
			var who := str(facts.get("who", ""))
			if who == "" or who == owner_name or who == Names.given_name(owner_name):
				return {}
			return {"key": snap_key(event), "aim": "person", "name": who}
		"became_regular":
			return {"key": snap_key(event), "aim": "person", "name": str(facts.get("name", ""))}
		"cat_stole":
			return {"key": snap_key(event), "aim": "cat", "name": str(facts.get("name", ""))}
		"dish_served":
			if Menu.find(Menu.resolve(str(facts.get("dish", "")))).get("kind", "") != "food":
				return {}
			if int(facts.get("food_served", 0)) != 1 and float(facts.get("wait", 0.0)) < LONG_WAIT:
				return {}
			return {"key": snap_key(event), "aim": "food", "name": str(facts.get("name", ""))}
	return {}


## Which snapshot an event's (the same at the moment and at 3am): its kind, minute and who.
static func snap_key(event: Dictionary) -> String:
	var who := str(event.get("who", event.get("name", "")))
	return "%s@%d:%s" % [str(event.get("kind", "")), int(event.get("at", event.get("minutes", 0))), who]


## A post for the log and the transcript: "@jiho.at.night (selfie, moment): words #tags".
static func log_text(post: Dictionary) -> String:
	return "%s (%s, %s%s): %s %s" % [post.get("handle", "?"), post.get("shot", "?"), post.get("about", "?"),
		", a snapshot" if str(post.get("picture", "")) != "" else (", drawn" if PICTURED.has(str(post.get("shot", ""))) else ""),
		post.get("text", ""), " ".join(PackedStringArray(post.get("tags", [])))]
