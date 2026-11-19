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
	due.sort_custom(func(a, b): return float(a["time"]) < float(b["time"]))
	return due


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
