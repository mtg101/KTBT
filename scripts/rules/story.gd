extends RefCounted
## The night as a story: the owner's diary at 3am and "Previously on...".
## (Part of the game's rules: pure functions and the tables they use, with any dice rolls
## passed in, so they can be tested on their own. See ARCHITECTURE.md.)

const Menu = preload("res://scripts/menu.gd")
const Names = preload("res://scripts/rules/names.gd")
const People = preload("res://scripts/rules/people.gd")
const NightRules = preload("res://scripts/rules/night_rules.gd")
const Orders = preload("res://scripts/rules/orders.gd")
const Talk = preload("res://scripts/rules/talk.gd")
const Text = preload("res://scripts/rules/text.gd")


## Each night is an episode; at 3am the owner writes it up in their diary, from facts the game
## picks (see visit.gd _diary_facts): the AI writes the entry, the game checks it keeps to them,
## and stitches one together itself if it can't. Entries are kept with the bar, with the facts
## they were written from, for the diary book and "Previously on…".
const DAY_HANGUL := {"Monday": "월요일", "Tuesday": "화요일", "Wednesday": "수요일", "Thursday": "목요일",
	"Friday": "금요일", "Saturday": "토요일", "Sunday": "일요일"}


const MIN_DIARY := 120  # characters: a few sentences...


const MAX_DIARY := 900  # ...but not a page and a half


## The stamp in the corner of a diary page, from what happened: the teacher's "참 잘했어요"
## (well done!) for a good night, the cat's paw print, a star for a new regular, and so on.
const DIARY_STAMPS := {
	"well_done": {"hangul": "참 잘했어요", "english": "WELL DONE!", "colour": "e8263a"},
	"star": {"hangul": "단골", "english": "A NEW REGULAR", "colour": "e8a33a"},
	"paw": {"hangul": "냥", "english": "THE CAT WAS HERE", "colour": "8a5a33"},
	"heart": {"hangul": "정", "english": "JEONG: WARM HEARTS", "colour": "e85a8a"},
	"full": {"hangul": "만석", "english": "FULL HOUSE", "colour": "e8263a"},
	"snow": {"hangul": "눈", "english": "SNOW", "colour": "5a8ae8"},
	"rain": {"hangul": "비", "english": "RAIN", "colour": "5a8ae8"},
	"soju": {"hangul": "소주", "english": "ANOTHER NIGHT", "colour": "3f9e5a"},
}


## How tonight's takings compare with the bar's last few nights: "" for its first night.
static func takings_word(tonight: int, before: Array) -> String:
	if before.is_empty():
		return ""
	var total := 0
	var best := 0
	for amount in before:
		total += int(amount)
		best = maxi(best, int(amount))
	var usual := float(total) / before.size()
	if tonight > best and before.size() >= 3:
		return "the best night yet"
	if tonight > usual * 1.2:
		return "better than usual"
	if tonight < usual * 0.8:
		return "quieter than usual"
	return "about usual"


## The stamp for a diary page, from the night's facts: the most notable thing, in this order.
static func diary_stamp(facts: Dictionary) -> String:
	if str(facts.get("takings_vs_usual", "")) in ["the best night yet", "better than usual"]:
		return "well_done"
	if not facts.get("new_regulars", []).is_empty():
		return "star"
	if not facts.get("friendlier", []).is_empty() or facts.get("moments", []).any(func(m): return str(m.get("mood", "")) in ["warm", "sweet"]):
		return "heart"
	if int(facts.get("walked_on", 0)) > 0:
		return "full"
	if not facts.get("cat_laps", []).is_empty():
		return "paw"
	var weather := str(facts.get("weather", "")).to_lower()
	if weather.contains("snow"):
		return "snow"
	if weather.contains("rain") or weather.contains("drizzle") or weather.contains("shower"):
		return "rain"
	return "soju"


## Checks the AI's diary entry {"entry"} against the night's facts: the right length, nobody
## named who wasn't there (of the people the game knows: tonight's customers, the regulars, and
## any it says didn't come), no number the facts don't have, no food nobody ordered, no made-up
## Korean. Tidies it.
static func validate_diary(data: Variant, facts: Dictionary) -> String:
	var problem := Text.check_fields(data, ["entry"])
	if problem != "":
		return problem
	var entry := Text.unquote(Text.tidy_text(data["entry"]))
	if entry.length() < MIN_DIARY:
		return "the diary entry is too short: write four to six sentences"
	if entry.length() > MAX_DIARY:
		return "the diary entry is too long: four to six sentences"
	var opening := entry.left(70).to_lower()
	if opening.contains("diary") or opening.contains("entry") or opening.begins_with("wrote") or opening.begins_with("writing"):
		return "the diary entry talks about writing the diary: start straight in with the night itself"
	var here: Array = facts.get("people", []).map(func(p): return str(p["name"])) + facts.get("missing", [])
	here.append(str(facts.get("owner", "")))
	for person in facts.get("not_here", []):
		if _names_person(entry, str(person)) and not here.has(person):
			return "the diary mentions %s, who wasn't at the tent tonight" % person
	var allowed := {}
	for number in Text.numbers_in(JSON.stringify(facts)):
		allowed[number] = true
	for number in Text.numbers_in(entry):
		if not allowed.has(number):
			return "the diary has a number (%s) that isn't in tonight's facts" % number
	if Talk.real_brand(entry) != "":
		return "the diary names a real brand (%s): describe it instead" % Talk.real_brand(entry)
	var mention := Orders.unordered_mention(entry, facts.get("ordered", []) + facts.get("specials", []))  # (specials: on all night)
	if mention != "":
		return "the diary mentions %s, but nobody ordered that tonight" % mention
	var names: Array = here.duplicate()
	names.append(str(facts.get("cat", "")))
	if not Talk.romanised_korean(entry, names).is_empty():
		return "the diary has made-up Korean words in it: write it in English, with at most the odd Korean word"
	data["entry"] = entry
	return ""


## Whether text names someone (their full name, or their given name on its own).
static func _names_person(text: String, full: String) -> bool:
	var lower := text.to_lower()
	if lower.contains(full.to_lower()):
		return true
	var given := Names.given_name(full).to_lower()
	if given == "" or given == full.to_lower():
		return false
	var at := lower.find(given)
	while at != -1:
		var before := lower.substr(at - 1, 1) if at > 0 else " "
		var after := lower.substr(at + given.length(), 1)
		if not (before >= "a" and before <= "z") and before != "-" and not (after >= "a" and after <= "z") and after != "-":
			return true
		at = lower.find(given, at + 1)
	return false


## A diary entry the game writes itself (offline mode, or when the AI's won't do), from the same
## facts: plain, but in the owner's voice and true.
static func stitched_diary(facts: Dictionary) -> String:
	var sentences := PackedStringArray()
	var weather := str(facts.get("weather", "")).strip_edges()
	sentences.append("%s, and %s." % [str(facts.get("day", "Tonight")), weather if weather != "" else "a quiet sky"])
	var people: Array = facts.get("people", [])
	if people.is_empty():
		sentences.append("Nobody came in at all. I cleaned the pots twice.")
	else:
		var busiest := str(facts.get("busiest", ""))
		var count := int(facts.get("customers", people.size()))
		sentences.append("%d %s came in%s." % [count, "customer" if count == 1 else "customers", (", busiest " + busiest) if busiest != "" else ""])
	for moment in facts.get("moments", []).slice(0, 2):
		var said := str(moment.get("said", ""))
		sentences.append("%s%s" % [Names.given_name(str(moment["who"])), (" said \"%s\", and I haven't stopped thinking about it." % said) if said != "" else " gave me something to think about."])
	for pair in facts.get("friendlier", []).slice(0, 1):
		sentences.append("%s. About time." % str(pair))
	for name in facts.get("new_regulars", []).slice(0, 1):
		sentences.append("I think %s will be back." % Names.given_name(str(name)))
	var laps: Array = facts.get("cat_laps", [])
	if not laps.is_empty():
		sentences.append("%s spent a while on %s's lap." % [str(facts.get("cat", "The cat")), Names.given_name(str(laps[0]))])
	if int(facts.get("walked_on", 0)) > 0:
		sentences.append("We were full, and someone had to walk on. I hate that.")
	var word := str(facts.get("takings_vs_usual", ""))
	sentences.append("%s, %s." % [str(facts.get("takings", "")), word] if word != "" else "%s in the tin." % str(facts.get("takings", "")))
	sentences.append("Another night under the overpass. Tomorrow, the same again.")
	return " ".join(sentences)


## Opening a bar from the title screen plays a K-drama recap of last time before the night
## starts: two or three beats and a teaser, in a TV narrator's voice, from the last diary's
## facts and the regulars (see visit.gd _recap_facts); a new bar's first night gets a series
## opener instead. The AI writes it, the game checks it and stitches one if it can't.
const MAX_RECAP_BEAT := 160


const MAX_RECAP_TEASER := 120


## Checks the AI's recap {"beats": [two or three sentences], "teaser": "a question"}: the right
## lengths, nobody named the game doesn't know, no number not in the facts, no made-up Korean.
## Tidies it (a teaser ends with a question mark).
static func validate_recap(data: Variant, facts: Dictionary) -> String:
	if typeof(data) != TYPE_DICTIONARY or typeof(data.get("beats")) != TYPE_ARRAY or not data.has("teaser"):
		return "it didn't include \"beats\" (a list) and \"teaser\""
	var beats: Array = []
	for beat in data["beats"]:
		var text := Text.unquote(Text.tidy_text(beat))
		if text != "":
			beats.append(text)
	if beats.size() < 2 or beats.size() > 3:
		return "the recap needs two or three beats"
	for beat in beats:
		if beat.length() > MAX_RECAP_BEAT:
			return "a beat of the recap is too long: one short sentence each"
	var teaser := Text.unquote(Text.tidy_text(data["teaser"]))
	if teaser == "" or teaser.length() > MAX_RECAP_TEASER:
		return "the teaser should be one short question"
	if not teaser.ends_with("?"):
		teaser = teaser.trim_suffix(".") + "?"
	var all := " ".join(PackedStringArray(beats)) + " " + teaser
	if Talk.real_brand(all) != "":
		return "the recap names a real brand (%s): describe it instead" % Talk.real_brand(all)
	var known: Array = facts.get("names", [])
	var invented := unknown_name(all, known)
	if invented != "":
		return "the recap mentions %s, who isn't in the story: only the people in the facts" % invented
	var allowed := {}
	for number in Text.numbers_in(JSON.stringify(facts)):
		allowed[number] = true
	for number in Text.numbers_in(all):
		if not allowed.has(number):
			return "the recap has a number (%s) that isn't in the facts" % number
	if not Talk.romanised_korean(all, known + [str(facts.get("bar", "")), str(facts.get("cat", ""))]).is_empty():
		return "the recap has made-up Korean words in it: write it in English"
	data["beats"] = beats
	data["teaser"] = teaser
	return ""


## A Korean-looking given name ("Ji-ho", "Tae-oh") in text that isn't part of any of names, or "".
static func unknown_name(text: String, names: Array) -> String:
	var parts := {}
	for person in names:
		for part in str(person).to_lower().split(" ", false):
			parts[part] = true
	var regex := RegEx.new()
	regex.compile("\\b[A-Z][a-z]{1,4}-[A-Za-z]{1,4}\\b")  # (short, like romanised syllables: "Ji-ho", not "Late-night")
	for found in regex.search_all(text):
		var found_name := found.get_string()
		if not parts.has(found_name.to_lower()):
			return found_name
	return ""


## The game's own recap, from the same facts: {"beats", "teaser"}.
static func stitched_recap(facts: Dictionary) -> Dictionary:
	if int(facts.get("episode", 1)) <= 1 or facts.get("last", {}).is_empty():
		return series_opener(facts)
	var last: Dictionary = facts["last"]
	var beats: Array = []
	for moment in last.get("moments", []).slice(0, 2):
		var said := str(moment.get("said", ""))
		beats.append(("%s said it out loud: \"%s\"" % [Names.given_name(str(moment["who"])), said]) if said != "" else "%s had a night to remember." % Names.given_name(str(moment["who"])))
	for pair in last.get("friendlier", []).slice(0, 1):
		beats.append("%s." % str(pair))
	for name in last.get("new_regulars", []).slice(0, 1):
		beats.append("%s found somewhere to belong." % Names.given_name(str(name)))
	var line: Dictionary = last.get("line", {})
	if beats.size() < 2 and not line.is_empty():
		beats.append("\"%s\"" % str(line["text"]).left(MAX_RECAP_BEAT - 2))
	if beats.size() < 2 and int(last.get("walked_on", 0)) > 0:
		beats.append("Every stool was taken, and someone walked on into the night.")
	if beats.size() < 2:
		beats.append("Under the overpass, %s kept the pots on." % Names.given_name(str(facts.get("owner", "the owner"))))
	if beats.size() < 2:
		beats.append("The bulbs swung in the wind, and the soju went round.")
	var teaser := "Who will duck under the tarp tonight?"
	if not last.get("new_regulars", []).is_empty():
		teaser = "Will %s come back?" % Names.given_name(str(last["new_regulars"][0]))
	elif not last.get("missing", []).is_empty():
		teaser = "Will %s be back tonight?" % Names.given_name(str(last["missing"][0]))
	elif not last.get("moments", []).is_empty():
		teaser = "What will %s do now?" % Names.given_name(str(last["moments"][0]["who"]))
	return {"beats": beats.slice(0, 3), "teaser": teaser}


## A new bar's first night: the series opener.
static func series_opener(facts: Dictionary) -> Dictionary:
	var beats: Array = ["Under a Seoul overpass, a tarp goes up and the first pots go on."]
	beats.append("%s, %s, opens %s for the night." % [str(facts.get("owner", "The owner")), str(facts.get("archetype", "who's seen it all")), str(facts.get("bar", "the tent"))])
	var regulars: Array = facts.get("regulars", [])
	if regulars.size() >= 2:
		beats.append("%s and %s have been coming for years." % [Names.given_name(str(regulars[0])), Names.given_name(str(regulars[1]))])
	return {"beats": beats, "teaser": "Who will duck under the tarp tonight?"}


## How a recap's played: a different K-TV style each time, from what happened last time.
## Each: the title card, the colours (sky, rays, title, tags, ribbons), what drifts down, how
## beats come on ("slam", "slide", "typewriter" or "caption"), the last beat ("zoom" for the
## dramatic triple zoom, or as the rest), the stings, the teaser ("heartbeat", "glitch" or
## "bounce") and an overlay ("" or "sepia").
const RECAP_STYLES := {
	"melodrama": {"title": "지난 이야기 · PREVIOUSLY ON…", "sky": ["0d0b24", "2a1a40"], "rays": ["ff7eb6", "b48cff"], "pill": "ff7eb6", "tag": "7ee8c8",
		"teaser_colour": "ffd27f", "ribbons": ["ff7eb6", "ffd27f", "7ee8c8"], "drift": "petals", "beats": "slide", "last": "zoom",
		"sting": "whoosh", "teaser": "heartbeat", "overlay": ""},
	"makjang": {"title": "지난 이야기 · LAST TIME…", "sky": ["050208", "3a0a14"], "rays": ["ff2a3a", "2a0a10"], "pill": "ff2a3a", "tag": "ffffff",
		"teaser_colour": "ff4f4f", "ribbons": ["ff2a3a", "1a1a1a", "ffffff"], "drift": "none", "beats": "slam", "last": "zoom",
		"sting": "dun", "teaser": "glitch", "overlay": ""},
	"variety": {"title": "지난 방송 · LAST TIME ON KTBT!", "sky": ["1a2a6a", "4a2a8a"], "rays": ["ffd23f", "4fd2ff"], "pill": "ffd23f", "tag": "ff7eb6",
		"teaser_colour": "8cf05a", "ribbons": ["ffd23f", "4fd2ff", "ff7eb6"], "drift": "sparks", "beats": "caption", "last": "slam",
		"sting": "pop", "teaser": "bounce", "overlay": ""},
	"nostalgic": {"title": "그날 밤 · THAT NIGHT…", "sky": ["1a140c", "3a2a18"], "rays": ["ffc46b", "8a6a3a"], "pill": "e8c88a", "tag": "e8c88a",
		"teaser_colour": "fff4e0", "ribbons": ["e8c88a", "8a5a33", "fff4e0"], "drift": "dust", "beats": "typewriter", "last": "typewriter",
		"sting": "sad", "teaser": "heartbeat", "overlay": "sepia"},
}


## The style for tonight's recap: from last time's biggest moment (a shock is a makjang
## cliffhanger, a laugh a variety show, something sad or sweet a melodrama, a quiet night
## nostalgic), never the same as the last recap's; a roll picks when nothing decides.
static func pick_recap_style(last: Dictionary, previous: String, roll: float) -> String:
	var moods: Array = last.get("moments", []).map(func(m): return str(m.get("mood", "")))
	var wanted := ""
	if moods.has("shock"):
		wanted = "makjang"
	elif moods.has("funny"):
		wanted = "variety"
	elif moods.has("sad") or moods.has("sweet") or moods.has("warm") or not last.get("friendlier", []).is_empty():
		wanted = "melodrama"
	elif int(last.get("customers", 0)) <= 8 and not last.is_empty():
		wanted = "nostalgic"
	var styles: Array = RECAP_STYLES.keys()
	if wanted == "" or wanted == previous:
		var others: Array = styles.filter(func(s): return s != previous and s != wanted) if wanted == previous else styles.filter(func(s): return s != previous)
		wanted = str(others[clampi(floori(roll * others.size()), 0, others.size() - 1)])
	return wanted


## The facts the owner's diary is written from, from tonight's events (NightEvents.timeline) and
## what else the game knows (context: "episode", "day", "weather", "owner", "customers",
## "takings" (won), "before" (the last nights' takings), "regulars" ({"name", "founding"}),
## "cat", "line"). Kept with the entry, for the diary book and "Previously on…".
static func diary_facts(events: Array, context: Dictionary) -> Dictionary:
	var people: Array = []
	var ordered: Array = []
	var moments: Array = []
	var friendlier: Array = []
	var new_regulars: Array = []
	var laps: Array = []
	var walked_on := 0
	var peak := 0
	var peak_at := -1
	for event in events:
		match str(event["kind"]):
			"paid":
				people.append({"name": str(event.get("name", "")), "hangul": str(event.get("hangul", "")), "job": str(event.get("job", "")),
					"regular": str(event.get("regular", "")), "ordered": str(event.get("ordered", "")), "order_ids": event.get("order_ids", []).duplicate(),
					"pronoun": People.pronoun(str(event.get("gender", "")))})
				for id in event.get("order_ids", []):
					if not ordered.has(id):
						ordered.append(id)
			"big_moment":
				moments.append({"who": str(event.get("who", "")), "mood": str(event.get("mood", "")), "caption": str(event.get("caption", "")), "said": str(event.get("said", ""))})
			"friendlier":
				friendlier.append("%s and %s are on \"%s\" terms now" % [event.get("a", ""), event.get("b", ""), event.get("term", "")])
			"became_regular":
				new_regulars.append(str(event.get("name", "")))
			"cat_moved":
				if str(event.get("spot", "")) == "lap" and bool(event.get("new_lap", false)) and not laps.has(str(event.get("with", ""))):
					laps.append(str(event.get("with", "")))
			"walked_on":
				walked_on += 1
			"sat_down":
				if int(event.get("seated", 0)) > peak:
					peak = int(event["seated"])
					peak_at = int(event.get("at", 0))
	var here: Array = people.map(func(p): return str(p["name"]))
	var missing: Array = []
	var not_here: Array = []
	for regular in context.get("regulars", []):
		var regular_name := str(regular["name"])
		if here.has(regular_name):
			continue
		if bool(regular.get("founding", false)):
			missing.append(regular_name)  # the old regulars are missed when they don't come
		else:
			not_here.append(regular_name)
	var before: Array = context.get("before", [])
	return {
		"episode": int(context.get("episode", 1)), "day": str(context.get("day", "")), "weather": str(context.get("weather", "")), "owner": str(context.get("owner", "")),
		"customers": int(context.get("customers", 0)), "takings": Menu.format_won(int(context.get("takings", 0))),
		"takings_vs_usual": takings_word(int(context.get("takings", 0)), before.slice(-7)),
		"busiest": ("%s, with %d at the counter" % [NightRules.clock_text(peak_at), peak]) if peak_at >= 0 else "",
		"people": people, "missing": missing, "not_here": not_here, "pronouns": _pronouns(context, people),
		"moments": moments, "friendlier": friendlier, "new_regulars": new_regulars,
		"cat": str(context.get("cat", "")), "cat_laps": laps, "walked_on": walked_on,
		"line": context.get("line", {}).duplicate(), "ordered": ordered, "specials": context.get("specials", []).duplicate(),
	}


## Everyone the diary or recap might mention, and how to refer to them: {name: "she"}.
static func _pronouns(context: Dictionary, people: Array) -> Dictionary:
	var found := {}
	if str(context.get("owner", "")) != "":
		found[str(context["owner"])] = People.pronoun(str(context.get("owner_gender", "")))
	for regular in context.get("regulars", []):
		found[str(regular["name"])] = People.pronoun(str(regular.get("gender", "")))
	for person in people:
		found[str(person["name"])] = str(person.get("pronoun", "they"))
	return found
