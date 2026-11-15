extends RefCounted
## What's remembered after a visit: the AI's memory and verdict, checked, and the things that
## stick.
## (Part of the game's rules: pure functions and the tables they use, with any dice rolls
## passed in, so they can be tested on their own. See ARCHITECTURE.md.)

const Text = preload("res://scripts/rules/text.gd")


## The verdict on a visit, as the AI may put it -> the game's word for it.
const NIGHT_VERDICTS := {"loved it": "loved", "loved": "loved", "enjoyed it": "enjoyed", "enjoyed": "enjoyed",
	"it was fine": "fine", "fine": "fine", "didn't enjoy it": "didnt", "did not enjoy it": "didnt", "didnt": "didnt"}


const OWNER_FEELINGS := {"warmer": "warmer", "the same": "same", "about the same": "same", "same": "same", "cooler": "cooler"}


## The things that stick, as the prompt asks for them.
const STICKING := {"job": "their job or what they do", "family": "family (married, children, parents...)",
	"home": "where they live or come from", "other": "one other thing about them that would stick"}


const MAX_MEMORY := 260


const SHORT_WORDS := ["that", "this", "with", "from", "they", "their", "have", "about", "just", "been", "were", "what", "when", "some", "into", "really", "very", "much", "only"]


## The after-visit memory. said: everything the customer themselves said tonight (lower
## case), which the things that stick must come from: one that isn't backed by it is dropped
## (left empty), not rejected, so a made-up "she has two kids" never sticks.
static func validate_memory(data: Variant, said: String) -> String:
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
	return ""


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
