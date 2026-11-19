extends RefCounted
## What's remembered after a visit: the AI's memory and verdict, checked; the things that stick
## about a person (and who knows them: the owner, if they said it to the owner; whoever was in
## the chat, if they said it there); lines checked against those (a widower doesn't mention his
## wife's nagging); and threads, something coming up they mentioned, for the owner to ask about
## next time. Who's who to whom (the memories of each other) is bonds.gd.
## (Part of the game's rules: pure functions and the tables they use, with any dice rolls
## passed in, so they can be tested on their own. See ARCHITECTURE.md.)

const Text = preload("res://scripts/rules/text.gd")


## The verdict on a visit, as the AI may put it -> the game's word for it.
const NIGHT_VERDICTS := {"loved it": "loved", "loved": "loved", "enjoyed it": "enjoyed", "enjoyed": "enjoyed",
	"it was fine": "fine", "fine": "fine", "didn't enjoy it": "didnt", "did not enjoy it": "didnt", "didnt": "didnt"}


const OWNER_FEELINGS := {"warmer": "warmer", "the same": "same", "about the same": "same", "same": "same", "cooler": "cooler"}


## The things that stick, as the prompt asks for them.
const STICKING := {"job": "their job or what they do", "family": "family (married, widowed, divorced or single; children, parents...)",
	"home": "where they live or come from", "pet": "a pet of their own at home (not the tent's cat)", "worry": "something in their life worrying them (not just tonight's mood)",
	"hope": "something in their life they're hoping for or working towards (not just tonight)",
	"other": "one other fact about their life that would stick (a hobby, a habit, something they own): not how they seemed tonight"}
## Words that make a "fact" an impression of tonight rather than something about their life
## (19 Nov: "seems friendly", "getting through the rest of the night"): dropped.
const NOT_FACTS := ["tonight", "seem", "chatting", "the rest of the night", "this evening", "other customers"]
## How each is put in a prompt or a hover ("job: nurse").
const FACT_LABELS := {"job": "job", "family": "family", "home": "from", "pet": "pet", "worry": "worried about", "hope": "hoping for", "other": "and"}


const MAX_MEMORY := 260


const SHORT_WORDS := ["that", "this", "with", "from", "they", "their", "have", "about", "just", "been", "were", "what", "when", "some", "into", "really", "very", "much", "only"]


## The after-visit memory. said: everything the customer themselves said tonight (lower
## case), which the things that stick must come from: one that isn't backed by it is dropped
## (left empty), not rejected, so a made-up "she has two kids" never sticks.
static func validate_memory(data: Variant, said: String, not_facts: Array = []) -> String:
	var problem := Text.check_fields(data, ["owner_remembers", "they_remember", "night", "towards_owner"])
	if problem != "":
		return problem
	var night := Text.tidy_text(data["night"]).to_lower()
	if not NIGHT_VERDICTS.has(night):
		return "\"night\" must be one of: loved it, enjoyed it, it was fine, didn't enjoy it"
	var feeling := Text.tidy_text(data["towards_owner"]).to_lower()
	if not OWNER_FEELINGS.has(feeling):
		return "\"towards_owner\" must be one of: warmer, the same, cooler"
	for key in ["owner_remembers", "they_remember"]:
		var text := Text.tidy_text(data[key])
		if text.length() > MAX_MEMORY:
			return "\"%s\" is too long: a sentence or two" % key
		data[key] = text
	data["night"] = NIGHT_VERDICTS[night]
	data["towards_owner"] = OWNER_FEELINGS[feeling]
	for key in STICKING:
		data[key] = sticks(str(data.get(key, "")), said)
		if is_not_a_fact(str(data[key]), not_facts):
			data[key] = ""
	for key in ["coming_up", "followed_up"]:  # (threads: also only from what they said)
		data[key] = sticks(str(data.get(key, "")), said)
		if is_not_a_fact(str(data[key]), not_facts):
			data[key] = ""
	return ""


## Whether a "fact" is really an impression of tonight, or about the show or the tent's cat
## (extra: words for this bar: the PD, its cat's name).
static func is_not_a_fact(text: String, extra: Array = []) -> bool:
	var t := " " + text.to_lower() + " "
	for word in NOT_FACTS + extra:
		if str(word) != "" and t.contains(" " + str(word)):  # (at the start of a word: "seem" is "seems", "seemed")
			return true
	return false


## Whether how it went says something new, not just the thing again ("exam looming" for "exam
## looming": 19 Nov): a word of its own that isn't in the thread.
static func says_how_it_went(outcome: String, thread: String) -> bool:
	var before := Text.words(thread)
	for word in Text.words(outcome):
		if word.length() >= 3 and not before.has(word) and not SHORT_WORDS.has(word):
			return true
	return false


## A thing that sticks, if what was said backs it up (one of its real words was said), or "".
static func sticks(fact: String, said: String) -> String:
	var text := Text.tidy_text(fact)
	if text == "" or text.to_lower() in ["none", "n/a", "unknown", "not mentioned", "nothing"]:
		return ""
	for word in Text.words(text):
		# (the start of a long word is enough: "pharmacist" is backed by "pharmacy")
		var stem := word if word.length() < 7 else word.substr(0, 6)
		if word.length() >= 4 and not SHORT_WORDS.has(word) and said.contains(stem):
			return text
	return ""


# --- Who calls whom what ---------------------------------------------------------------------
# The game decides which terms each pair may use, from what it knows (gender, who's older,
# owner or customer, and whether they're close), tells the AI, and rejects lines that break
# the rules: never "oppa" to someone younger, never "ajumma" to a young woman.


# --- The facts about a person, and who knows them ---------------------------------------------

## A fact learned: kept as {"text", "night", "known_by"} (who knows it: "owner", regulars' ids).
## The same fact heard again adds who's heard it; a new one replaces the old. True if it changed.
static func learn_fact(regular: Dictionary, key: String, text: String, night: int, known_by: Array) -> bool:
	if text == "":
		return false
	var facts: Dictionary = regular.get("facts", {})
	var old: Variant = facts.get(key, null)
	if old is Dictionary and str(old["text"]) == text:
		var heard: Array = old["known_by"]
		var grew := false
		for who in known_by:
			if not heard.has(who):
				heard.append(who)
				grew = true
		return grew
	facts[key] = {"text": text, "night": night, "known_by": known_by.duplicate()}
	regular["facts"] = facts
	return true


## A fact's words (a fact from before who-knows-what is just its words).
static func fact_text(fact: Variant) -> String:
	return str(fact["text"]) if fact is Dictionary else str(fact)


## The facts about someone that who knows ({key: text}); "" for all of them (what they know
## about themselves).
static func facts_known_by(regular: Dictionary, who: String = "") -> Dictionary:
	var known := {}
	var facts: Dictionary = regular.get("facts", {})
	for key in facts:
		var fact: Variant = facts[key]
		if who == "" or not (fact is Dictionary) or fact["known_by"].has(who):
			known[key] = fact_text(fact)
	return known


## Who heard a fact said: everyone in each heard ({"text": what was said there, lower case,
## "by": [who heard it]}) where the fact's words were said.
static func who_heard(fact: String, heard: Array) -> Array:
	var who: Array = []
	for place in heard:
		if sticks(fact, str(place["text"])) != "":
			for person in place["by"]:
				if not who.has(person):
					who.append(person)
	return who


## A regular from before who-knows-what: their facts were all said to the owner. True if any.
static func upgrade_facts(regular: Dictionary) -> bool:
	var facts: Dictionary = regular.get("facts", {})
	var changed := false
	for key in facts:
		if not (facts[key] is Dictionary):
			facts[key] = {"text": str(facts[key]), "night": int(regular.get("last_night", 0)), "known_by": ["owner"]}
			changed = true
	return changed


# --- Lines that contradict what's known ------------------------------------------------------

const WIDOWED := ["widow", "late wife", "late husband", "wife died", "husband died", "wife passed", "husband passed", "lost his wife", "lost her husband", "lost my wife", "lost my husband"]
const DIVORCED := ["divorc", "ex-wife", "ex-husband", "separated"]
const SINGLE := ["never married", "not married", "unmarried", "single"]
const MARRIED := ["married", "wife", "husband"]
const NO_KIDS := ["no kids", "no children", "childless", "never had kids", "never had children"]
const KIDS := ["son", "daughter", "kids", "children", "grandchild", "grandson", "granddaughter"]
## Words that put a spouse in the past ("my wife used to say...": a widower remembering her).
## (Padded with spaces, as the line is: " late " isn't "later".)
const PAST := [" used to", " passed", " died", " miss ", " missed", " was ", " late ", " before ", " back when", " remember", " ex-", " ex ", " would have", " funeral", " grave"]


## Married, widowed, divorced or single, from what's known of someone's family ("" if it doesn't say).
static func family_state(family: String) -> String:
	var t := family.to_lower()
	for kind in [["widowed", WIDOWED], ["divorced", DIVORCED], ["single", SINGLE], ["married", MARRIED]]:
		if kind[1].any(func(w): return t.contains(w)):
			return kind[0]
	return ""


## Whether someone has children: "none", "some" or "" (it doesn't say).
static func kids_state(family: String) -> String:
	var t := family.to_lower()
	if NO_KIDS.any(func(w): return t.contains(w)):
		return "none"
	for word in Text.words(t):
		if KIDS.has(word) or KIDS.has(word.trim_suffix("s")) or word.begins_with("grandchild") or word.begins_with("grandson") or word.begins_with("granddaughter"):
			return "some"
	return ""


## Whether a line someone says about themselves contradicts what's known about their family:
## the problem, or "". who: their name; family: what's known ("" if nothing).
static func contradiction(line: String, who: String, family: String) -> String:
	if family == "":
		return ""
	var t := " " + line.to_lower() + " "
	var state := family_state(family)
	var spouse := ""
	for word in ["wife", "husband"]:
		if t.contains("my " + word + " ") or t.contains("my " + word + "'") or t.contains("my " + word + ",") or t.contains("my " + word + ".") or t.contains("my " + word + "?") or t.contains("my " + word + "!"):
			spouse = word
	if spouse != "" and ["widowed", "divorced", "single"].has(state) and not PAST.any(func(w): return t.contains(w)):
		return "%s is %s (as they've said before: \"%s\"), so the line can't talk about their %s as if they're at home now: keep to what they've said" % [who, state, family, spouse]
	var claims_single := [" i'm single", " i'm not married", " i never married", " never been married"].any(func(w): return t.contains(w))
	if claims_single and state == "married":
		return "%s is married (as they've said before: \"%s\"), so the line can't say they're single: keep to what they've said" % [who, family]
	var kids := kids_state(family)
	var claims_kids := false
	for word in ["son", "daughter", "kids", "children", "grandkids", "grandson", "granddaughter"]:
		if t.contains("my " + word + " ") or t.contains("my " + word + "'") or t.contains("my " + word + ",") or t.contains("my " + word + "."):
			claims_kids = true
	if claims_kids and kids == "none":
		return "%s has no children (as they've said before: \"%s\"), so the line can't mention theirs: keep to what they've said" % [who, family]
	var claims_none := [" i don't have kids", " i don't have children", " i have no kids", " i have no children", " no kids of my own"].any(func(w): return t.contains(w))
	if claims_none and kids == "some":
		return "%s has children (as they've said before: \"%s\"), so the line can't say they haven't: keep to what they've said" % [who, family]
	return ""


# --- Threads: something coming up, for next time ---------------------------------------------

const THREADS_KEPT := 4
const THREAD_STALE := 21  # nights: too long ago to ask about
const THREAD_ASKS := 2  # visits the owner's had it on their mind without hearing how it went


## Something coming up they mentioned (an interview, a date, moving house), for the owner to ask
## about next time.
static func add_thread(regular: Dictionary, text: String, night: int, heard_by: Array = ["owner"]) -> void:
	if text == "":
		return
	var threads: Array = regular.get("threads", [])
	threads.append({"text": text, "night": night, "asked": 0, "open": true, "outcome": "", "heard_by": heard_by.duplicate()})
	regular["threads"] = threads.slice(-THREADS_KEPT)


## The latest thread still open that who heard about (the owner, or a regular's id), or {}.
static func open_thread(regular: Dictionary, who: String = "owner") -> Dictionary:
	for i in range(regular.get("threads", []).size() - 1, -1, -1):
		var thread: Dictionary = regular["threads"][i]
		if bool(thread["open"]) and thread.get("heard_by", ["owner"]).has(who):
			return thread
	return {}


## For the owner's line: what they mentioned last time, to ask about.
static func thread_note(thread: Dictionary, night: int) -> String:
	var ago := night - int(thread["night"])
	var when := "last night" if ago <= 1 else ("%d nights ago" % ago if ago < 7 else "a while ago")
	return "Last time they were in (%s), they mentioned %s. The owner remembers, and asks how it went (or is going)." % [when, Text.unquote(str(thread["text"]))]


## They said how it went: closed, with the outcome.
static func close_thread(thread: Dictionary, outcome: String, night: int) -> void:
	thread["open"] = false
	thread["outcome"] = outcome
	thread["closed_night"] = night


## Threads too old to ask about, or asked about too often without an answer, dropped. How many.
static func drop_stale(regular: Dictionary, night: int) -> int:
	var dropped := 0
	for thread in regular.get("threads", []):
		if bool(thread["open"]) and (night - int(thread["night"]) > THREAD_STALE or int(thread["asked"]) >= THREAD_ASKS):
			thread["open"] = false
			thread["dropped"] = true
			dropped += 1
	return dropped


# --- Two regulars remembering each other (at closing) ----------------------------------------

## What the closing call asks of two regulars who chatted tonight: for each, what they'll
## remember of the other, one thing the other said about their own life that would stick (and
## what kind), and anything coming up the other mentioned.
const PAIR_FIELDS := ["first_remembers", "second_remembers"]


## The closing memory of two regulars' chats, checked: each memory a sentence or two; each fact
## of a kind there is, said by that person (their own lines: first_said, second_said), and not an
## impression of tonight or about the show (not_facts); threads the same. A fact or thread that
## doesn't pass is dropped (left empty), not rejected.
static func validate_pair_memory(data: Variant, first_said: String, second_said: String, not_facts: Array = []) -> String:
	var problem := Text.check_fields(data, PAIR_FIELDS)
	if problem != "":
		return problem
	for key in PAIR_FIELDS:
		var text := Text.tidy_text(data[key])
		if text.length() > MAX_MEMORY:
			return "\"%s\" is too long: a sentence or two" % key
		data[key] = text
	for side in [["first", first_said], ["second", second_said]]:
		var kind := Text.tidy_text(data.get(side[0] + "_fact_kind", "")).to_lower()
		var fact := sticks(str(data.get(side[0] + "_fact", "")), side[1])
		if not STICKING.has(kind) or is_not_a_fact(fact, not_facts):
			fact = ""
		data[side[0] + "_fact_kind"] = kind if fact != "" else ""
		data[side[0] + "_fact"] = fact
		var coming := sticks(str(data.get(side[0] + "_coming_up", "")), side[1])
		data[side[0] + "_coming_up"] = "" if is_not_a_fact(coming, not_facts) else coming
	return ""
