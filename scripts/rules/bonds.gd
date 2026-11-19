extends RefCounted
## Bonds: what two people at the tent are to each other, one record for every pair that matters
## (the owner and a regular, two regulars; later, people who came in together), saved with the
## bar under "bonds", keyed by the pair. The game owns all of it: how they know each other, how
## often they've met and when, whose name each knows, how warm it's got, how close they are
## (a level, from those), and each side's last few memories of the other, older ones blurring
## into an impression. What the AI says only ever reaches it through the checked after-visit
## memory. The facts about a person (and who knows them) are the person's: memories.gd.
## (Part of the game's rules: pure functions on the bar's data, so they can be tested on their
## own. See ARCHITECTURE.md.)

const Memories = preload("res://scripts/rules/memories.gd")

const OWNER := "owner"  # the owner's id in a bond
const LEVELS := ["stranger", "acquaintance", "friendly", "close", "old friend"]
const RECENT_MEMORIES := 3  # visits remembered clearly; older ones blur into one impression
const MAX_IMPRESSION := 320
## The owner and a regular: friendly after this many visits, close after this many (or warmth),
## old friends after this many (or a founding regular).
const OWNER_FRIENDLY := 4
const OWNER_CLOSE := 6
const OWNER_CLOSE_WARMTH := 2
const OLD_FRIENDS := 12
## Two regulars: friendly after this many meetings (when the younger might ask for a friendlier
## term: friendliness.gd), old friends once close and this many.
const FRIENDLY := 4
const OLD_FRIENDS_CLOSE := 20
## The fields a regular had before bonds (moved into them by upgrade).
const OLD_FIELDS := ["memories", "impression", "warmth", "owner_knows_name", "knows_owner_name", "friends"]


## A pair's key: the same whichever way round.
static func key(a: String, b: String) -> String:
	return "%s|%s" % ([a, b] if a < b else [b, a])


## All the bar's bonds (saved with it).
static func all(bar: Dictionary) -> Dictionary:
	if not bar.has("bonds"):
		bar["bonds"] = {}
	return bar["bonds"]


## The bond between two people, or {} if they've never met.
static func find(bar: Dictionary, a: String, b: String) -> Dictionary:
	if a == "" or b == "":
		return {}
	return all(bar).get(key(a, b), {})


## The bond between two people, made if they've never met (how: how they know each other).
static func between(bar: Dictionary, a: String, b: String, how: String = "met at the counter") -> Dictionary:
	var bonds := all(bar)
	var k := key(a, b)
	if not bonds.has(k):
		bonds[k] = {"a": a, "b": b, "how": how, "meetings": 0, "first_night": -1, "last_night": -1,
			"names": {a: false, b: false}, "warmth": 0, "close": false, "memories": [], "impression": {}, "last": ""}
	return bonds[k]


## The owner and a regular.
static func with_owner(bar: Dictionary, regular_id: String) -> Dictionary:
	return find(bar, OWNER, regular_id)


## They've met tonight (counted once a night). True if it's the first time tonight.
static func meet(bond: Dictionary, night: int) -> bool:
	if int(bond.get("last_night", -1)) == night:
		return false
	bond["meetings"] = int(bond.get("meetings", 0)) + 1
	bond["last_night"] = night
	if int(bond.get("first_night", -1)) < 0:
		bond["first_night"] = night
	return true


## Whether who knows the other one's name.
static func knows_name(bond: Dictionary, who: String) -> bool:
	return bool(bond.get("names", {}).get(who, false))


static func learn_name(bond: Dictionary, who: String) -> void:
	var names: Dictionary = bond.get("names", {})
	names[who] = true
	bond["names"] = names


## The other one in a bond.
static func other(bond: Dictionary, who: String) -> String:
	return str(bond["b"]) if str(bond["a"]) == who else str(bond["a"])


## A meeting remembered: by: {who: what they'll remember of the other}. The newest few are kept
## as they are, older ones blurring into each side's impression (just their first sentence, and
## only so much of it).
static func remember(bond: Dictionary, night: int, by: Dictionary) -> void:
	var memories: Array = bond.get("memories", [])
	memories.append({"night": night, "by": by.duplicate()})
	var impression: Dictionary = bond.get("impression", {})
	while memories.size() > RECENT_MEMORIES:
		var oldest: Dictionary = memories.pop_front()
		for who in oldest["by"]:
			var said := str(oldest["by"][who])
			if said == "":
				continue
			var gist := said.get_slice(". ", 0).trim_suffix(".") + "."
			var blurred := (str(impression.get(who, "")) + " " + gist).strip_edges()
			while blurred.length() > MAX_IMPRESSION and blurred.contains(". "):
				blurred = blurred.substr(blurred.find(". ") + 2)  # the oldest bit goes first
			impression[who] = blurred
	bond["memories"] = memories
	bond["impression"] = impression


## What who remembers of the other, oldest first: [{"night", "text"}].
static func memories_by(bond: Dictionary, who: String) -> Array:
	return bond.get("memories", []).filter(func(m): return str(m["by"].get(who, "")) != "").map(
		func(m): return {"night": int(m["night"]), "text": str(m["by"][who])})


static func impression_of(bond: Dictionary, who: String) -> String:
	return str(bond.get("impression", {}).get(who, ""))


## How close they are (an index into LEVELS), from what the game knows: how often they've met,
## how warm it's got, whether they're close, how they know each other.
static func level(bond: Dictionary) -> int:
	if bond.is_empty() or int(bond.get("meetings", 0)) <= 0:
		return 0
	var meetings := int(bond["meetings"])
	if str(bond["a"]) == OWNER or str(bond["b"]) == OWNER:
		if str(bond.get("how", "")) == "founding" or meetings >= OLD_FRIENDS:
			return 4
		if meetings >= OWNER_CLOSE or int(bond.get("warmth", 0)) >= OWNER_CLOSE_WARMTH:
			return 3
		return 2 if meetings >= OWNER_FRIENDLY or int(bond.get("warmth", 0)) >= 1 else 1
	if bool(bond.get("close", false)):
		return 4 if meetings >= OLD_FRIENDS_CLOSE else 3
	return 2 if meetings >= FRIENDLY else 1


static func level_word(bond: Dictionary) -> String:
	return LEVELS[level(bond)]


## Someone's gone (no longer a regular): their bonds go with them.
static func forget(bar: Dictionary, who: String) -> void:
	var bonds := all(bar)
	for k in bonds.keys():
		if str(bonds[k]["a"]) == who or str(bonds[k]["b"]) == who:
			bonds.erase(k)


## How many bonds there are at each level ({"friendly": 3, ...}: for the night's stats).
static func count_by_level(bar: Dictionary) -> Dictionary:
	var counts := {}
	for bond in all(bar).values():
		var word := level_word(bond)
		counts[word] = int(counts.get(word, 0)) + 1
	return counts


## A bar from before bonds: each regular's memories, impression, warmth and names (with the
## owner) and friends (with other regulars) moved into bonds, and their things that stick into
## facts the owner knows (memories.gd). True if anything moved. Each pair once: the second
## regular's record of a friendship only adds what the first's hadn't.
static func upgrade(bar: Dictionary) -> bool:
	var changed := false
	for regular in bar.get("regulars", []):
		var id := str(regular.get("id", ""))
		if id == "":
			continue
		if Memories.upgrade_facts(regular):
			changed = true
		if not OLD_FIELDS.any(func(k): return regular.has(k)):
			continue
		changed = true
		var founding := bool(regular.get("founding", false))
		var owner_bond := between(bar, OWNER, id, "founding" if founding else "met at the counter")
		owner_bond["meetings"] = maxi(int(owner_bond["meetings"]), int(regular.get("visits", 0)))
		owner_bond["first_night"] = int(regular.get("first_night", -1))
		owner_bond["last_night"] = int(regular.get("last_night", -1))
		if bool(regular.get("owner_knows_name", false)):
			learn_name(owner_bond, OWNER)
		if bool(regular.get("knows_owner_name", false)):
			learn_name(owner_bond, id)
		owner_bond["warmth"] = int(regular.get("warmth", 0))
		owner_bond["memories"] = regular.get("memories", []).map(func(m): return {"night": int(m.get("night", 0)),
			"by": {OWNER: str(m.get("owner", "")), id: str(m.get("them", ""))}})
		if str(regular.get("impression", "")) != "":
			owner_bond["impression"] = {OWNER: str(regular["impression"])}
		var friends: Dictionary = regular.get("friends", {})
		for friend_id in friends:
			var known: Dictionary = friends[friend_id]
			var bond := between(bar, id, str(friend_id), "regulars for years" if founding and int(known.get("meetings", 0)) >= 20 else "met at the counter")
			bond["meetings"] = maxi(int(bond["meetings"]), int(known.get("meetings", 0)))
			bond["last_night"] = maxi(int(bond["last_night"]), int(known.get("night", -1)))
			if bool(known.get("names", false)):
				learn_name(bond, id)
			bond["close"] = bool(bond["close"]) or bool(known.get("close", false))
			if str(known.get("last", "")) != "":
				bond["last"] = str(known["last"])
		for k in OLD_FIELDS:
			regular.erase(k)
	return changed
