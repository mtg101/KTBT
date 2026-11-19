extends RefCounted
## The bar's regulars tonight, kept with the bar: finding them, who's coming in tonight (from
## their pull and habits, and a cliffhanger about someone coming back), their facts for the
## prompts, how they're announced as they duck in, the night's end (those who stayed away drift
## further; too far and they're not regulars any more), and what the owner remembers of them.
## The tent's scene asks the AI (founding regulars, tonight's mood, memories after a visit),
## narrates and saves; this works it out. The rules themselves are in scripts/rules/regulars.gd.
## (Part 8 of splitting visit.gd: see DEVLOG.md, 16 November 2026.)

const Regulars = preload("res://scripts/rules/regulars.gd")
const Memories = preload("res://scripts/rules/memories.gd")
const Bonds = preload("res://scripts/rules/bonds.gd")
const Story = preload("res://scripts/rules/story.gd")
const Text = preload("res://scripts/rules/text.gd")


## The bar's regulars (saved with it). Any from before bonds are brought up to date first
## (save_upgrades.gd does it as a bar opens; this catches one that turns up some other way).
static func all(bar: Dictionary) -> Array:
	if not bar.has("regulars"):
		bar["regulars"] = []
	Bonds.upgrade(bar)
	return bar["regulars"]


## The regular with this id, or {}.
static func find(bar: Dictionary, id: String) -> Dictionary:
	if id == "":
		return {}
	for regular in all(bar):
		if str(regular["id"]) == id:
			return regular
	return {}


## Who's coming in tonight, from their pull and habits: each regular at most once, around their
## usual hour, soonest first ({"time", "id"}). A founding regular always comes in the first
## night the bar has them, to meet them. A cliffhanger about someone coming in: TV makes sure it
## pays off, often enough (dice: the scenery's, for that).
static func plan(bar: Dictionary, night: int, day_index: int, cliffhanger: Dictionary, dice: RandomNumberGenerator) -> Array:
	var due: Array = []
	for regular in all(bar):
		var first := bool(regular.get("founding", false)) and not bool(regular.get("introduced", false))
		if first or randf() < Regulars.visit_chance(float(regular["pull"]), day_index, regular.get("favourite_days", []), Regulars.keen(regular, night)):
			due.append({"time": Regulars.arrival_time(int(regular.get("usual_hour", 21 * 60)), randf()), "id": regular["id"]})
	if not cliffhanger.is_empty() and ["comes_back", "meet_again"].has(cliffhanger["kind"]):
		for regular in all(bar):
			var coming := due.any(func(d): return d["id"] == regular["id"])
			if not coming and cliffhanger["who"].has(str(regular["name"])) and dice.randf() < Story.CLIFFHANGER_NUDGE:
				due.append({"time": Regulars.arrival_time(int(regular.get("usual_hour", 21 * 60)), dice.randf()), "id": regular["id"]})
	together(bar, due, dice)
	due.sort_custom(func(a, b): return float(a["time"]) < float(b["time"]))
	return due


const TOGETHER_MINUTES := 20.0  # close friends coming in tonight: the second within this of the first
const TAG_ALONG := 0.3  # the chance a close friend who wasn't coming in turns up anyway, around the same time


## Close friends drift in around the same time (the start of coming in together): of two close
## regulars both coming in, the later one moves to just after the earlier; one who wasn't coming
## might tag along. Marks each moved or added one "with" their friend's id. (Dice: the scenery's.)
static func together(bar: Dictionary, due: Array, dice: RandomNumberGenerator) -> void:
	for first in due.duplicate():
		for regular in all(bar):
			var id := str(regular["id"])
			if id == str(first["id"]) or not bool(Bonds.find(bar, str(first["id"]), id).get("close", false)):
				continue
			var theirs: Array = due.filter(func(d): return str(d["id"]) == id)
			var near := float(first["time"]) + dice.randf_range(2.0, TOGETHER_MINUTES)
			if not theirs.is_empty():
				if float(theirs[0]["time"]) > float(first["time"]) and not theirs[0].has("with"):
					theirs[0]["time"] = near
					theirs[0]["with"] = str(first["id"])
			elif dice.randf() < TAG_ALONG:
				due.append({"time": near, "id": id, "with": str(first["id"])})


## A regular's facts, for the prompts (see Prompts.describe_regular): theirs, and from their bond
## with the owner (names, memories, warmth, how close), the facts the owner knows, and anything
## they mentioned last time that the owner might ask about.
static func facts(bar: Dictionary, regular: Dictionary, night: int) -> Dictionary:
	var id := str(regular.get("id", ""))
	var bond := Bonds.with_owner(bar, id)
	var thread := Memories.open_thread(regular)
	var known := {
		"visits": int(regular.get("visits", 0)), "founding": bool(regular.get("founding", false)),
		"role": regular.get("role", ""), "since": regular.get("since", ""), "habit": regular.get("habit", ""), "history": regular.get("history", ""),
		"owner_knows": regular.get("owner_knows", ""), "knows_of_owner": regular.get("knows_of_owner", ""),
		"usual": Regulars.usual_of(regular), "owner_knows_name": Bonds.knows_name(bond, Bonds.OWNER),
		"knows_owner_name": Bonds.knows_name(bond, id),
		"memories": bond.get("memories", []).map(func(m): return {"night": int(m["night"]), "owner": str(m["by"].get(Bonds.OWNER, "")), "them": str(m["by"].get(id, ""))}),
		"impression": Bonds.impression_of(bond, Bonds.OWNER), "facts": Memories.facts_known_by(regular, Bonds.OWNER),
		"own_facts": Memories.facts_known_by(regular), "warmth": int(bond.get("warmth", 0)), "level": Bonds.level_word(bond) if not bond.is_empty() else "",
		"thread": Memories.thread_note(thread, night) if not thread.is_empty() else "",
	}
	if int(regular.get("last_night", 0)) > 0:
		known["nights_ago"] = night - int(regular["last_night"])
	return known


## "Kim Ji-ho is back, for her 4th visit (last time: 9 nights ago)." or, for a founding
## regular, "Choi Young-ja ducks in and takes her usual stool: she's been coming for six
## years, most Fridays." (and, the first time, who they are to the tent: they're marked
## introduced, so the bar wants saving).
static func back_text(regular: Dictionary, night: int) -> String:
	var her: String = {"woman": "her", "man": "his"}.get(str(regular.get("gender", "")), "their")
	var she: String = {"woman": "she's", "man": "he's"}.get(str(regular.get("gender", "")), "they've")
	if bool(regular.get("founding", false)):
		var arrives := "%s ducks in and takes %s usual stool: %s been coming %s, %s." % [regular["name"], her, she, regular.get("since", ""), regular.get("habit", "")]
		if not bool(regular.get("introduced", false)):
			regular["introduced"] = true
			var who: String = {"woman": "She's", "man": "He's"}.get(str(regular.get("gender", "")), "They're")
			arrives += " %s %s. %s" % [who, str(Regulars.ROLES.get(regular.get("role", ""), "a regular")).get_slice(":", 0), Text.as_sentence(str(regular.get("history", "")))]
		return arrives
	var text := "%s is back, for %s %s visit" % [regular["name"], her, Regulars.ordinal(int(regular.get("visits", 0)) + 1)]
	if int(regular.get("last_night", 0)) > 0:
		text += " (last time: %s)" % Regulars.nights_ago_text(night - int(regular["last_night"]))
	return text + "."


## The night's over: regulars who didn't come drift a little further away; anyone who's
## drifted too far isn't a regular any more. Returns the names of those who've gone.
static func fade(bar: Dictionary, night: int) -> Array:
	var kept: Array = []
	var gone: Array = []
	for regular in all(bar):
		if int(regular.get("last_night", 0)) != night:
			regular["pull"] = Regulars.pull_after_absence(float(regular["pull"]), bool(regular.get("founding", false)))
		if Regulars.still_regular(float(regular["pull"])):
			kept.append(regular)
		else:
			gone.append(str(regular["name"]))
			Bonds.forget(bar, str(regular["id"]))  # (their bonds go with them)
	bar["regulars"] = kept
	return gone


## Each regular's pull ({name: pull}, for the stats), and how many are founding regulars.
static func pulls(bar: Dictionary) -> Dictionary:
	var each := {}
	var founding := 0
	for regular in all(bar):
		each[str(regular["name"])] = snappedf(float(regular["pull"]), 0.01)
		if bool(regular.get("founding", false)):
			founding += 1
	return {"pulls": each, "founding": founding}


## What the owner remembers about a regular, for the hover in who's here now ("" if nothing yet).
static func remembered_text(known: Dictionary) -> String:
	var parts := PackedStringArray()
	if str(known.get("impression", "")) != "":
		parts.append(str(known["impression"]))
	for memory in known.get("memories", []):
		parts.append(str(memory["owner"]))
	var sticking: Dictionary = known.get("facts", {})
	for key in Memories.STICKING:
		if str(sticking.get(key, "")) != "":
			parts.append("%s: %s" % [str(Memories.FACT_LABELS[key]).capitalize(), Memories.fact_text(sticking[key])])
	if str(known.get("owner_knows", "")) != "" and parts.is_empty():
		parts.append(str(known["owner_knows"]))
	return " · ".join(parts)  # (Text.hint makes it safe to go inside the tag.)


## Whether someone's name (the full name, or the given name) has been said.
static func name_said(full: String, said: String) -> bool:
	var parts := full.split(" ", false)
	var given := " ".join(parts.slice(1)) if parts.size() > 1 else full
	return said.contains(full.to_lower()) or said.contains(given.to_lower())


## A visit remembered (from the checked after-visit memory): each side's memory of the other in
## their bond, the things that stick (known by whoever heard them said: heard, see
## Memories.who_heard), and threads (how something they'd mentioned went, closing it; something
## new coming up). Returns what changed: {"facts": [keys learned], "thread_opened", "thread_closed"}.
static func remember(bar: Dictionary, regular: Dictionary, night: int, memory: Dictionary, heard: Array) -> Dictionary:
	var id := str(regular["id"])
	var bond := Bonds.between(bar, Bonds.OWNER, id)
	Bonds.remember(bond, night, {Bonds.OWNER: str(memory.get("owner_remembers", "")), id: str(memory.get("they_remember", ""))})
	var changed := {"facts": [], "thread_opened": false, "thread_closed": false}
	for key in Memories.STICKING:
		var fact := str(memory.get(key, ""))
		if fact != "" and Memories.learn_fact(regular, key, fact, night, Memories.who_heard(fact, heard)):
			changed["facts"].append(key)
	var thread := Memories.open_thread(regular)
	if not thread.is_empty() and str(memory.get("followed_up", "")) != "" and Memories.says_how_it_went(str(memory["followed_up"]), str(thread["text"])):
		Memories.close_thread(thread, str(memory["followed_up"]), night)
		changed["thread_closed"] = true
	if str(memory.get("coming_up", "")) != "":
		Memories.add_thread(regular, str(memory["coming_up"]), night)
		changed["thread_opened"] = true
	return changed


const PAIR_MEMORIES := 4  # pairs of regulars remembered at closing, at most (the most said between them first)


## Tonight's chats, as pairs of people who are regulars now (a newcomer who became one tonight
## included), each with everything said in the chats they were both in ({"a", "b": regulars,
## "lines": [{"speaker", "text"}], "heard": for each line said, who else heard it}). chats: the
## night's ({"names", "lines", "owner_in"}). The most said between them first; at most PAIR_MEMORIES.
static func chat_pairs(bar: Dictionary, chats: Array) -> Array:
	var by_name := {}
	for regular in all(bar):
		by_name[str(regular["name"])] = regular
	var pairs := {}
	for chat in chats:
		var names: Array = chat["names"].filter(func(n): return by_name.has(n))
		for i in names.size():
			for j in range(i + 1, names.size()):
				var a: Dictionary = by_name[names[i]]
				var b: Dictionary = by_name[names[j]]
				var k := Bonds.key(str(a["id"]), str(b["id"]))
				if not pairs.has(k):
					pairs[k] = {"a": a, "b": b, "lines": [], "heard": []}
				for line in chat["lines"]:
					pairs[k]["lines"].append(line)
					var others: Array = chat["names"].filter(func(n): return n != str(line["speaker"]) and by_name.has(n)).map(func(n): return str(by_name[n]["id"]))
					if bool(chat.get("owner_in", false)):
						others.append(Bonds.OWNER)
					pairs[k]["heard"].append({"speaker": str(line["speaker"]), "text": str(line["text"]).to_lower(), "by": others})
	var out: Array = pairs.values()
	out.sort_custom(func(x, y): return x["lines"].size() > y["lines"].size())
	return out.slice(0, PAIR_MEMORIES)


## Everything one of a pair said in their chats (lower case: what their facts must come from).
static func said_by(pair: Dictionary, regular: Dictionary) -> String:
	return " ".join(PackedStringArray(pair["heard"].filter(func(h): return h["speaker"] == str(regular["name"])).map(func(h): return str(h["text"]))))


## Two regulars' closing memory (checked: Memories.validate_pair_memory) kept: in their bond
## (met tonight, each one's memory of the other), a fact each said (known by whoever heard it),
## and anything coming up (a thread the other heard about). Returns the facts learned
## ([[regular, key]]) and threads opened ([[regular, text]]).
static func remember_pair(bar: Dictionary, pair: Dictionary, night: int, memory: Dictionary) -> Dictionary:
	var a: Dictionary = pair["a"]
	var b: Dictionary = pair["b"]
	var bond := Bonds.between(bar, str(a["id"]), str(b["id"]))
	Bonds.meet(bond, night)
	Bonds.remember(bond, night, {str(a["id"]): str(memory["first_remembers"]), str(b["id"]): str(memory["second_remembers"])})
	var changed := {"facts": [], "threads": []}
	for side in [["first", a, b], ["second", b, a]]:
		var person: Dictionary = side[1]
		var heard: Array = pair["heard"].filter(func(h): return h["speaker"] == str(person["name"]))
		var fact := str(memory.get(side[0] + "_fact", ""))
		var kind := str(memory.get(side[0] + "_fact_kind", ""))
		if fact != "" and Memories.learn_fact(person, kind, fact, night, Memories.who_heard(fact, heard)):
			changed["facts"].append([person, kind])
		var coming := str(memory.get(side[0] + "_coming_up", ""))
		if coming != "":
			Memories.add_thread(person, coming, night, Memories.who_heard(coming, heard))
			changed["threads"].append([person, coming])
	return changed


const KNOWN_FACTS := 2  # facts about someone in a "who you know here" note, at most
const KNOWN_MEMORY := 140  # ...and this much of the last memory of them


## What me (the owner, or a regular's id) knows of another regular, for a line's prompt, from
## me's side only: how close (their bond), whether me knows their name, a fact or two me heard,
## me's last memory of them, and anything they'd mentioned to me that's coming up. "" if they've
## never met.
static func known_of(bar: Dictionary, me: String, other: Dictionary) -> String:
	var other_id := str(other.get("id", ""))
	var bond := Bonds.find(bar, me, other_id)
	if bond.is_empty() or int(bond.get("meetings", 0)) <= 0:
		return ""
	var name := str(other["name"]) if Bonds.knows_name(bond, me) else "the %s (name not known)" % str(other.get("job", "regular"))
	var parts := PackedStringArray(["%s: %s" % [name, Bonds.level_word(bond)]])
	if bool(bond.get("casual", false)):
		parts.append("they talk to each other casually now, like friends (no polite speech)")
	var heard := Memories.facts_known_by(other, me)
	var shown := PackedStringArray()
	for key in Memories.STICKING:
		if heard.has(key) and shown.size() < KNOWN_FACTS:
			shown.append("%s: %s" % [Memories.FACT_LABELS[key], heard[key]])
	if not shown.is_empty():
		parts.append("knows " + "; ".join(shown))
	var memories := Bonds.memories_by(bond, me)
	if not memories.is_empty():
		parts.append("remembers \"%s\"" % Text.shorten(str(memories[-1]["text"]), KNOWN_MEMORY))
	var thread := Memories.open_thread(other, me)
	if not thread.is_empty():
		parts.append("they'd mentioned %s (it might come up)" % Text.unquote(str(thread["text"])))
	return ", ".join(parts)


## What someone's said about themselves before (to anyone): for their own lines, so they keep to it.
static func own_facts_text(regular: Dictionary) -> String:
	var said := Memories.facts_known_by(regular)
	var shown := PackedStringArray()
	for key in Memories.STICKING:
		if said.has(key):
			shown.append("%s: %s" % [Memories.FACT_LABELS[key], said[key]])
	return "; ".join(shown)


## What a regular brings in with them tonight (for the log, as they come in): from the owner's
## side and theirs, and the other regulars they know.
static func carried_in(bar: Dictionary, regular: Dictionary) -> String:
	var id := str(regular["id"])
	var owner_bond := Bonds.with_owner(bar, id)
	var parts := PackedStringArray(["with the owner %s (%d memories, %d facts known%s)" % [Bonds.level_word(owner_bond), owner_bond.get("memories", []).size(),
		Memories.facts_known_by(regular, Bonds.OWNER).size(), ", a thread to ask about" if not Memories.open_thread(regular).is_empty() else ""]])
	var friends := PackedStringArray()
	for other in all(bar):
		var bond := Bonds.find(bar, id, str(other["id"]))
		if other != regular and not bond.is_empty():
			friends.append("%s (%s)" % [other["name"], Bonds.level_word(bond)])
	if not friends.is_empty():
		parts.append("knows " + ", ".join(friends))
	var own := Memories.facts_known_by(regular).size()
	if own > 0:
		parts.append("%d things said about themselves" % own)
	return " · ".join(parts)
