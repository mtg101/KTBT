extends RefCounted
## Who calls whom what: the terms of address (oppa, imo, sajangnim...), who may use which, and
## their colours on screen.
## (Part of the game's rules: pure functions and the tables they use, with any dice rolls
## passed in, so they can be tested on their own. See ARCHITECTURE.md.)

const Text = preload("res://scripts/rules/text.gd")


## Every term: its spellings, its Hangul, how warm it is (for the colours), and what it means.
const TERMS := {
	"oppa": {"spellings": ["oppa", "orabeoni", "obba"], "hangul": "오빠", "warmth": "close",
		"means": "big brother, said by a woman. Close: a friend, family, or romance.",
		"rule": "only a woman calls an older man she's close to oppa"},
	"hyung": {"spellings": ["hyung", "hyeong"], "hangul": "형", "warmth": "close",
		"means": "big brother, said by a man. Close: a friend, or family.",
		"rule": "only a man calls an older man he's close to hyung"},
	"eonni": {"spellings": ["eonni", "unni", "onni"], "hangul": "언니", "warmth": "close",
		"means": "big sister, said by a woman. Close: a friend, or family.",
		"rule": "only a woman calls an older woman she's close to eonni"},
	"nuna": {"spellings": ["nuna", "noona"], "hangul": "누나", "warmth": "close",
		"means": "big sister, said by a man. Close: a friend, family, or romance.",
		"rule": "only a man calls an older woman he's close to nuna"},
	"imo": {"spellings": ["imo"], "hangul": "이모", "warmth": "family",
		"means": "auntie. A warm way to address a woman running a restaurant.",
		"rule": "imo is for a woman owner, from someone younger"},
	"eomeoni": {"spellings": ["eomeoni", "omoni"], "hangul": "어머니", "warmth": "family",
		"means": "mother. A warm, respectful way to address an older woman running a restaurant.",
		"rule": "eomeoni is for a woman owner, from someone younger"},
	"samchon": {"spellings": ["samchon", "samcheon"], "hangul": "삼촌", "warmth": "family",
		"means": "uncle. A warm way to address a man running a restaurant.",
		"rule": "samchon is for a man owner, from someone younger"},
	"ajumma": {"spellings": ["ajumma", "ajumeoni", "ahjumma"], "hangul": "아줌마", "warmth": "polite",
		"means": "ma'am: a middle-aged woman. Everyday, a little blunt.",
		"rule": "ajumma is for a woman of forty or more (to a young woman it's an insult)"},
	"ajusshi": {"spellings": ["ajusshi", "ajeossi", "ajussi", "ahjussi", "ajosshi"], "hangul": "아저씨", "warmth": "polite",
		"means": "mister: a middle-aged man.",
		"rule": "ajusshi is for a man of forty or more"},
	"sajangnim": {"spellings": ["sajangnim"], "hangul": "사장님", "warmth": "polite",
		"means": "boss: the owner of a business. Respectful.",
		"rule": "sajangnim is for the owner"},
	"seonsaengnim": {"spellings": ["seonsaengnim", "sonsaengnim"], "hangul": "선생님", "warmth": "polite",
		"means": "teacher, or a respectful sir or ma'am for someone older.",
		"rule": "seonsaengnim is for someone older"},
	"haksaeng": {"spellings": ["haksaeng"], "hangul": "학생", "warmth": "polite",
		"means": "student: how an older person addresses someone young.",
		"rule": "haksaeng is for someone young, from someone older"},
}


const MIDDLE_AGED := 40


const YOUNG := 26  # under this, "haksaeng"


## A person, as far as address goes: {"gender", "age", "owner": bool}.
## close: the two of them are close (a pair that's had the "can I call you eonni?" moment).
static func allowed_terms(speaker: Dictionary, listener: Dictionary, close: bool) -> Array:
	var allowed: Array = []
	var older := int(listener.get("age", 0)) > int(speaker.get("age", 0))
	var to_owner := bool(listener.get("owner", false))
	var customers := not to_owner and not bool(speaker.get("owner", false))
	var she := str(speaker.get("gender", "")) == "woman"
	var he := str(speaker.get("gender", "")) == "man"
	var to_her := str(listener.get("gender", "")) == "woman"
	var to_him := str(listener.get("gender", "")) == "man"
	if customers and close and older:
		if she and to_him:
			allowed.append("oppa")
		if he and to_him:
			allowed.append("hyung")
		if she and to_her:
			allowed.append("eonni")
		if he and to_her:
			allowed.append("nuna")
	if to_owner and older:
		if to_her:
			allowed.append_array(["imo", "eomeoni"])
		if to_him:
			allowed.append("samchon")
	if int(listener.get("age", 0)) >= MIDDLE_AGED:
		if to_her:
			allowed.append("ajumma")
		if to_him:
			allowed.append("ajusshi")
	if to_owner:
		allowed.append("sajangnim")
	if older:
		allowed.append("seonsaengnim")
	if int(listener.get("age", 0)) < YOUNG and not older:
		allowed.append("haksaeng")
	return allowed


## The term a younger person would use for an older one they've got close to ("" if none:
## same age, younger, the owner, or someone non-binary).
static func sibling_term(speaker: Dictionary, listener: Dictionary) -> String:
	var allowed := allowed_terms(speaker, listener, true)
	for term in ["oppa", "hyung", "eonni", "nuna"]:
		if allowed.has(term):
			return term
	return ""


## The terms of address in a line (ids from TERMS), first to last. names: people in the
## conversation, removed first (so Lee Hyung-jun isn't "hyung").
static func terms_in(line: String, names: Array = []) -> Array:
	var text := line
	for person in names:
		var full := str(person)
		text = text.replacen(full, " ")
		for part in full.split(" ", false):
			if part.contains("-"):
				text = text.replacen(part, " ")
	var said := Text.words(text)
	var found: Array = []
	for word in said:
		for id in TERMS:
			if TERMS[id]["spellings"].has(word) and not found.has(id):
				found.append(id)
	return found


## What's wrong with how a line addresses someone ("" if nothing). address: {"speaker",
## "listener", "close"} (see allowed_terms); "listener_name" for the reason.
static func address_problem(line: String, address: Dictionary, names: Array = []) -> String:
	var allowed := allowed_terms(address.get("speaker", {}), address.get("listener", {}), bool(address.get("close", false)))
	for term in terms_in(line, names):
		if not allowed.has(term):
			var close_note := " (and only once they've talked about it)" if TERMS[term]["warmth"] == "close" else ""
			return "the line calls %s \"%s\", but %s%s" % [address.get("listener_name", "them"), term, TERMS[term]["rule"], close_note]
	return ""


## How two people may address each other, for a prompt.
static func address_text(speaker_name: String, speaker: Dictionary, listener_name: String, listener: Dictionary, close: bool) -> String:
	var terms := allowed_terms(speaker, listener, close)
	if terms.is_empty():
		return "%s has no particular term for %s: just talk, or use their name if it's known." % [speaker_name, listener_name]
	var named := PackedStringArray(terms.map(func(t): return str(t).capitalize()))
	# (Told just "may call", a small model used one in nearly every line: "Thanks, Imo"...)
	return "%s may call %s %s (only these terms of address), but most lines need none at all: just now and then." % [speaker_name, listener_name, " or ".join(named)]


## Colours for the honorifics in the transcript, by warmth (see Glossary.explain).
const WARMTH_COLOURS := {"polite": "8fb8ff", "family": "ffc46b", "close": "ff8fc0"}
