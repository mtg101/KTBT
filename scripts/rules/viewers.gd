extends RefCounted
## Viewers' commentary (PLAN.md's Social media posts): at 3am, a few viewers comment on tonight's
## episode, where the show's rung has them: live comments on the phone stream (실시간 채팅, live
## chat), comments under the episode on the online video channel (댓글), the viewer board on
## network TV (시청자 게시판). The game picks what they're about (pick: the night's figure,
## always first; then the big moment, the cat's theft, first snow, a new regular, a PD's card
## taken up, the owner), how many (a busier night, more), and their hearts, likes or recommends
## and the count at the top, all scaled from the night's score; the AI writes the words (ai_facts,
## Prompts.viewers_messages, validate_reply), and the game checks them (check: tonight's figure
## the only number, names only tonight's, Korean only what the game knows, no brands, mentions or
## food nobody had); offline, or failing the check, they're the game's own (TEMPLATES; the canned
## AI answers "viewers" with them too). The comments show and talk about the ratings, and never
## change them: both come from the same facts.
## (Part of the game's rules: pure functions and the tables they use, with any dice rolls passed
## in, so they can be tested on their own. See ARCHITECTURE.md.)

const Names = preload("res://scripts/rules/names.gd")
const Talk = preload("res://scripts/rules/talk.gd")
const Text = preload("res://scripts/rules/text.gd")
const Glossary = preload("res://scripts/rules/glossary.gd")
const Menu = preload("res://scripts/rules/menu.gd")
const Ladder = preload("res://scripts/rules/ladder.gd")
const Ratings = preload("res://scripts/rules/ratings.gd")
const Socials = preload("res://scripts/rules/socials.gd")

const FEWEST := 2
const MOST := 4
const BUSIER := [4.5, 8.0]  # a comment more at each of these scores: a good night's busier
const MOST_CHARS := 120

## Where the viewers comment, by rung (each place's Korean explained in rules/hangul.gd): what
## the count at the top counts ("crowd": a share of the audience), and what a comment gets
## ("per_like": the top comment's, as a share of the audience).
const PLACES := {
	"phone": {"place": "live", "hangul": "실시간 채팅", "english": "live chat", "likes": "hearts", "crowd": 0.12, "crowd_words": "watching", "per_like": 0.012},
	"video": {"place": "comments", "hangul": "댓글", "english": "comments", "likes": "likes", "crowd": 0.004, "crowd_words": "comments", "per_like": 0.003},
	"network": {"place": "board", "hangul": "시청자 게시판", "english": "viewer board", "likes": "recommends", "crowd": 0.01, "crowd_words": "posts", "per_like": 0.006},
}
const TV_AUDIENCE_PER_POINT := 4000.0  # on TV there are no views: the board's counts come from this many a point of the score
const LIKES_FADE := 0.6  # each comment down gets about this much of the one above's

## How much each thing's worth commenting on (a big moment adds its size); the figure's always first.
const WORTH := {"moment": 50, "cat_theft": 45, "first_snow": 40, "new_regular": 35, "card": 30, "owner": 10}

## The viewers' handles: the game's own, never anyone real.
const HANDLES := ["night_owl", "tarp_watcher", "soju_aunty", "couch_ajusshi", "cat_police", "stoolside", "noodle_critic",
	"midnight_snacker", "pocha_fan", "rain_on_the_tarp", "owner_stan", "late_shift", "sofa_critic", "just_one_more_ep"]

## The Korean a comment may have besides words the game already explains (each explained on
## hover), and the figure's cheer on a big night, by whether the rung counts in percent.
const KOREAN := ["대박", "헐", "ㅋㅋㅋ", "떡상", "두 자릿수"]
const CHEER := {"percent": "두 자릿수!!", "views": "떡상!!"}

## The talk about the figure, by its band (Ratings.BANDS' order), or a new best.
const BAND_KEYS := ["quiet", "good", "near", "hit", "legend"]

## What a comment's about, for the AI ({figure}, {band}, {who}, {cat}, {dish}, {owner}, {mood}).
const HAPPENED := {"ratings": "tonight's episode got {figure} ({band})",
	"moment": "{who} had a big moment at the counter (it felt {mood})",
	"cat_theft": "{cat}, the tent's cat, stole {who}'s {dish} right off the plate",
	"first_snow": "the first snow of the winter fell on the tent's tarp",
	"new_regular": "{who} is becoming a regular: the owner knew them, and their order",
	"card": "something out of a drama happened to {who} at the counter",
	"owner": "{owner}, the owner, running the tent and looking after everyone"}

## The game's own words, by what they're about (the figure's by its band, a moment's by its
## mood). {figure}: the night's, as the rung shows it; {cheer}: the rung's.
const TEMPLATES := {
	"ratings": {
		"quiet": ["only {figure} tonight? more people need to find this tent", "{figure}. small but mine. this is my show", "quiet night, {figure}, still the comfiest thing on"],
		"good": ["{figure} for a tent bar, not bad at all", "{figure} tonight, tell your friends about this owner", "solid {figure}. this is my bedtime show now"],
		"near": ["{figure}!! so close to blowing up", "come on, {figure} is nearly there", "{figure}... one more good night and it's huge"],
		"hit": ["{cheer} {figure} for a tent bar?!", "{figure}?! a tent bar did that", "{cheer} the tarp has fans now"],
		"legend": ["{figure}. a tent bar. i have no words", "{cheer} {figure}, this is history", "{figure}?! everyone was watching the tent tonight"],
		"record": ["best night this show's ever had, {figure}!", "{figure}, a new best. the tent deserves it", "a new best ever, {figure}. i was here for this"],
	},
	"moment": {
		"shock": ["헐. what did {who} just say", "{who}!! i screamed at my screen", "nobody saw that coming from {who}"],
		"sad": ["{who} made me cry on a weeknight", "someone get {who} another glass, gently", "that bit with {who} hurt. in a good way"],
		"sweet": ["{who}!! my heart", "was that a moment?? {who}, i'm rooting for you", "the way {who} smiled. i'm gone"],
		"warm": ["{who} at the counter tonight felt like a hug", "this is why i watch. {who}, be happy", "{owner} looking after {who}. that's the show"],
		"funny": ["ㅋㅋㅋ {who} is a menace", "{who} should have their own show ㅋㅋㅋ", "i was crying laughing at {who}"],
		"awkward": ["the silence after {who} said that ㅋㅋㅋ", "{who}... oh no. oh no no", "second-hand embarrassment for {who}, i'm under my duvet"],
		"roast": ["{who} got destroyed and took it so well", "they roasted {who} and honestly fair ㅋㅋㅋ", "{who} will never live that down"],
	},
	"cat_theft": ["{cat} stealing the {dish} is the real star of this show", "justice for {who}'s {dish}", "{cat} owes {who} a {dish}. no regrets though"],
	"first_snow": ["first snow on the tarp... watching this in bed, perfect", "the snow on the tent tonight 대박", "first snow and a tent bar. cosiest episode yet"],
	"new_regular": ["{who} is a regular now, i'm so proud", "the owner remembered {who}'s order. crying", "{who} has a stool of their own now"],
	"card": ["no way that just happened by chance", "real life at that counter is more drama than a drama", "the producers didn't plan that... right?"],
	"owner": ["{owner} looks after everyone. i want a stool at that counter", "i'd watch {owner} cook all night", "{owner} is the heart of this show"],
}


## Where the viewers comment on a rung (PLACES'; an unknown rung, network TV's).
static func place_of(rung: String) -> Dictionary:
	return PLACES.get(str(Ladder.rung(rung)["id"]), PLACES["network"])


## How many are watching, for the counts: the episode's views, or on TV a crowd from the score.
static func audience(score: float, rung: String) -> int:
	if bool(Ladder.rung(rung)["percent"]):
		return int(roundf(maxf(score, 0.0) * TV_AUDIENCE_PER_POINT))
	return Ladder.views(score, rung)


## The night's figure, the way a viewer would put it: "9.5%" on TV, "1.1K views" off it.
static func figure(score: float, rung: String) -> String:
	if bool(Ladder.rung(rung)["percent"]):
		return Ratings.percent_text(score)
	return "%s views" % Ladder.short_number(Ladder.views(score, rung))


## The count at the top: "130 watching", "44 comments", "360 posts".
static func crowd_text(score: float, rung: String) -> String:
	var data := place_of(rung)
	return "%s %s" % [Ladder.commas(maxi(int(roundf(audience(score, rung) * float(data["crowd"]))), 1)), data["crowd_words"]]


## Which talk the figure gets: a new best's, or its band's (BAND_KEYS).
static func band_key(score: float, record: bool) -> String:
	if record:
		return "record"
	for i in Ratings.BANDS.size():
		if score < float(Ratings.BANDS[i][0]):
			return str(BAND_KEYS[i])
	return str(BAND_KEYS[-1])


## How many comments a night's score gets: FEWEST, and one more at each of BUSIER.
static func how_many(score: float) -> int:
	var count := FEWEST
	for at in BUSIER:
		if score >= float(at):
			count += 1
	return mini(count, MOST)


## Tonight's comments: {"rung", "place", "crowd" (the count at the top), "figure", "comments":
## [{"viewer", "about", "who", "mood", "dish", "said", "likes", "text", "by"}]}. info: "rung",
## "score", "record" (a new best), "owner", "cat", "taken_cards" (the PD's cards taken up). The
## figure's always first, then the most worth commenting on, one each; the likes fade down the list.
static func pick(events: Array, info: Dictionary, dice: RandomNumberGenerator) -> Dictionary:
	var rung := str(Ladder.rung(str(info.get("rung", Ladder.FIRST)))["id"])
	var score := float(info.get("score", 0.0))
	var owner_name := str(info.get("owner", ""))
	var taken: Array = info.get("taken_cards", [])
	var found: Array = []
	var moment := {}
	for event in events:
		var who := Names.given_name(str(event.get("name", "")))
		match str(event.get("kind", "")):
			"big_moment":
				var said_by := str(event.get("who", ""))
				if said_by != "" and said_by != owner_name and said_by != Names.given_name(owner_name) and int(event.get("size", 0)) >= int(moment.get("size", -1)):
					moment = {"about": "moment", "who": Names.given_name(said_by), "mood": str(event.get("mood", "funny")), "size": int(event.get("size", 0)),
						"said": str(event.get("said", ""))}
			"cat_stole":
				found.append({"about": "cat_theft", "who": who, "dish": str(event.get("dish", ""))})
			"first_snow":
				found.append({"about": "first_snow"})
			"became_regular":
				found.append({"about": "new_regular", "who": who})
			"plant_played":
				if who != "" and str(event.get("name", "")) != owner_name and taken.has(str(event.get("card", ""))):
					found.append({"about": "card", "who": who})
	if not moment.is_empty():
		found.append(moment)
	if owner_name != "":
		found.append({"about": "owner"})
	for candidate in found:
		candidate["worth"] = float(WORTH[candidate["about"]]) + 5.0 * int(candidate.get("size", 0)) + dice.randf()  # (ties: a little luck)
	found.sort_custom(func(a, b): return float(a["worth"]) > float(b["worth"]))
	var picked: Array = [{"about": "ratings"}]
	for candidate in found:
		if picked.size() >= how_many(score):
			break
		if not picked.any(func(p): return p["about"] == candidate["about"]):
			picked.append(candidate)
	var data := place_of(rung)
	var crowd := audience(score, rung)
	var words := words_info(info)
	var handles: Array = HANDLES.duplicate()
	var comments: Array = []
	for k in picked.size():
		var candidate: Dictionary = picked[k]
		var comment := {"viewer": str(handles.pop_at(dice.randi() % handles.size())), "about": str(candidate["about"]),
			"who": str(candidate.get("who", "")), "mood": str(candidate.get("mood", "")), "dish": str(candidate.get("dish", "")),
			"said": str(candidate.get("said", "")), "by": "game",
			"likes": maxi(int(roundf(crowd * float(data["per_like"]) * pow(LIKES_FADE, k) * (0.8 + 0.4 * dice.randf()))), 0)}
		comment["text"] = stitched_words(comment, words, dice)
		comments.append(comment)
	return {"rung": rung, "place": str(data["place"]), "crowd": crowd_text(score, rung), "figure": figure(score, rung), "comments": comments}


## What the words are filled in with: "cat", "owner" (their given name), "figure", "cheer", "band"
## (its words on the rung), "key" (band_key's). info: as pick's.
static func words_info(info: Dictionary) -> Dictionary:
	var rung := str(info.get("rung", Ladder.FIRST))
	var score := float(info.get("score", 0.0))
	return {"cat": str(info.get("cat", "")), "owner": Names.given_name(str(info.get("owner", ""))), "figure": figure(score, rung),
		"cheer": CHEER["percent" if bool(Ladder.rung(rung)["percent"]) else "views"], "band": Ladder.band(score, rung),
		"key": band_key(score, bool(info.get("record", false)))}


## A comment's words, the game's own (TEMPLATES). words: words_info's.
static func stitched_words(comment: Dictionary, words: Dictionary, dice: RandomNumberGenerator) -> String:
	var about := str(comment.get("about", "owner"))
	var choices: Variant = TEMPLATES.get(about, TEMPLATES["owner"])
	if about == "ratings":
		choices = choices.get(str(words.get("key", "good")), choices["good"])
	elif choices is Dictionary:
		choices = choices.get(str(comment.get("mood", "")), choices["funny"])
	return fill(str(choices[dice.randi() % choices.size()]), comment, words)


## Some words with tonight's facts put in.
static func fill(text: String, comment: Dictionary, words: Dictionary) -> String:
	var who := str(comment.get("who", ""))
	var cat_name := str(words.get("cat", ""))
	var owner_name := str(words.get("owner", ""))
	var dish := str(comment.get("dish", "")).to_lower()
	return text.replace("{figure}", str(words.get("figure", ""))).replace("{cheer}", str(words.get("cheer", ""))).replace("{band}", str(words.get("band", ""))) \
		.replace("{who}", who if who != "" else "them").replace("{cat}", cat_name if cat_name != "" else "the cat") \
		.replace("{owner}", owner_name if owner_name != "" else "the owner").replace("{dish}", dish if dish != "" else "food") \
		.replace("{mood}", str(comment.get("mood", "")))


## What the check needs: "known" (the names a comment may use: tonight's customers, the owner,
## the cat), "figure" (the only number a comment may have), "served" (every dish anyone had:
## Socials.served_tonight's).
static func check_facts(events: Array, info: Dictionary, served: Dictionary) -> Dictionary:
	var known: Array = []
	for event in events:
		if str(event.get("kind", "")) == "sat_down" and not known.has(str(event.get("name", ""))):
			known.append(str(event.get("name", "")))
	for named in [str(info.get("owner", "")), str(info.get("cat", ""))]:
		if named != "":
			known.append(named)
	var dishes: Array = []
	for who in served:
		for dish in served[who]:
			if not dishes.has(dish):
				dishes.append(dish)
	return {"known": known, "figure": words_info(info)["figure"], "served": dishes}


## What's wrong with a comment, or "" if nothing. facts: check_facts'.
static func check(comment: Dictionary, facts: Dictionary) -> String:
	var text := str(comment.get("text", "")).strip_edges()
	if text == "":
		return "empty"
	if text.length() > MOST_CHARS:
		return "too long (%d characters)" % text.length()
	if not HANDLES.has(str(comment.get("viewer", ""))):
		return "not one of the game's viewers: %s" % comment.get("viewer", "")
	var allowed := Text.numbers_in(str(facts.get("figure", "")))
	var numbers: Array = Text.numbers_in(text).filter(func(n): return not allowed.has(n))
	if not numbers.is_empty():
		return "a number that isn't tonight's figure: %s" % ", ".join(PackedStringArray(numbers))
	var brand := Talk.real_brand(text)
	if brand != "":
		return "a real brand: %s" % brand
	var korean := unknown_korean(text)
	if korean != "":
		return "Korean the game doesn't know: %s" % korean
	for mention in RegEx.create_from_string("@[A-Za-z0-9._]+").search_all(text):
		return "a mention of someone: %s" % mention.get_string()
	var served: Array = facts.get("served", [])
	var lowered := text.to_lower()
	for item in Menu.items():  # (a dish in the words: only one somebody had)
		var named := str(item.get("name", "")).to_lower()
		if named != "" and RegEx.create_from_string("\\b%s\\b" % Socials._regex_escape(named)).search(lowered) != null \
				and not served.any(func(d): return str(d).to_lower() == named or Menu.resolve(str(d)) == str(item.get("id", ""))):
			return "food nobody had tonight: %s" % item["name"]
	var stranger := Socials.someone_new(text, facts.get("known", []))
	if stranger != "":
		return "someone not in the facts: %s" % stranger
	return ""


## The first run of Korean that isn't on KOREAN or explained word by word, or "".
static func unknown_korean(text: String) -> String:
	for run in RegEx.create_from_string("[\\x{AC00}-\\x{D7A3}\\x{3131}-\\x{318E}]+(?: [\\x{AC00}-\\x{D7A3}\\x{3131}-\\x{318E}]+)*").search_all(text):
		var korean := run.get_string()
		if KOREAN.has(korean):
			continue
		for word in korean.split(" ", false):
			if Glossary.hangul_tip(word) == "":
				return korean
	return ""


## What the AI writes the comments from: the game's facts, nothing else. board: pick's; info: as pick's.
static func ai_facts(board: Dictionary, info: Dictionary) -> Dictionary:
	var words := words_info(info)
	var listed: Array = []
	for comment in board.get("comments", []):
		var about := str(comment.get("about", ""))
		var happened := fill(str(HAPPENED.get(about, HAPPENED["owner"])), comment, words)
		if about == "moment" and str(comment.get("said", "")) != "":
			happened += ": they said \"%s\"" % comment["said"]
		listed.append({"viewer": str(comment["viewer"]), "about": about, "who": str(comment.get("who", "")), "mood": str(comment.get("mood", "")),
			"dish": str(comment.get("dish", "")), "happened": happened})
	var rung := str(board.get("rung", info.get("rung", Ladder.FIRST)))
	var facts := words.duplicate()
	facts["show_on"] = str(Ladder.rung(rung)["name"])
	facts["place"] = str(place_of(rung)["english"])
	facts["comments"] = listed
	return facts


## Checks the AI's comments (Prompts.viewers_messages): "" if they'll do. Each comment's words
## are tidied and go through check(); the ones that pass go in data["words"] (viewer -> text),
## the ones that don't in data["turned_down"] ("viewer: why"), and get the game's own. Turned
## down only if it isn't comments at all, or none of them pass.
static func validate_reply(data: Variant, comments: Array, facts: Dictionary) -> String:
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("comments")) != TYPE_ARRAY:
		return "it didn't include \"comments\""
	var by_viewer := {}
	for written in data["comments"]:
		if typeof(written) == TYPE_DICTIONARY:
			by_viewer[str(written.get("viewer", "")).strip_edges().trim_prefix("@")] = written
	var words := {}
	var turned_down: Array = []
	for comment in comments:
		var viewer := str(comment["viewer"])
		if not by_viewer.has(viewer):
			turned_down.append("%s: no comment from them" % viewer)
			continue
		var text := Text.unquote(Text.tidy_text(str(by_viewer[viewer].get("text", ""))))
		for front in ["@" + viewer, viewer]:  # (their own handle on the front: it's shown already)
			if text.begins_with(front):
				text = text.trim_prefix(front).lstrip(": ").strip_edges()
		var trial: Dictionary = comment.duplicate(true)
		trial["text"] = text
		var problem := check(trial, facts)
		if problem != "":
			turned_down.append("%s: %s (\"%s\")" % [viewer, problem, text])
			continue
		words[viewer] = text
	data["words"] = words
	data["turned_down"] = turned_down
	if words.is_empty() and not comments.is_empty():
		return "none of the comments could be used: %s" % "; ".join(PackedStringArray(turned_down))
	return ""


## The title of where they comment, Korean and English: "실시간 채팅 live chat · 130 watching".
static func title(board: Dictionary) -> String:
	var data := place_of(str(board.get("rung", "")))
	return "%s %s · %s" % [data["hangul"], data["english"], board.get("crowd", "")]


## A comment's likes in its place's words: "♥ 12", "♥ 34", "추천 21".
static func likes_text(board: Dictionary, comment: Dictionary) -> String:
	var count := Ladder.short_number(int(comment.get("likes", 0)))
	return ("추천 %s" % count) if str(board.get("place", "")) == "board" else ("♥ %s" % count)


## A comment for the log and the transcript: "night_owl (ratings, ♥ 12): words".
static func log_text(board: Dictionary, comment: Dictionary) -> String:
	return "%s (%s, %s): %s" % [comment.get("viewer", "?"), comment.get("about", "?"), likes_text(board, comment), comment.get("text", "")]
