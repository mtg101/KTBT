extends RefCounted
## Who calls whom, and friendliness: how the owner and each customer address each other (for
## the prompts and the checks), two regulars' record of each other (how often they've met,
## whether they know each other's names, the last thing said), and the "can I call you
## eonni?" moment, when it's time, and marking them close. Plain functions on the bar, the
## owner and the tent's guests (null: the owner). The tent's scene narrates and saves.
## (Part 10 of splitting visit.gd, the first half: see PLAN.md, "A proper refactor".)

const Address = preload("res://scripts/rules/address.gd")
const RegularsTonight = preload("res://scripts/bar/regulars_tonight.gd")

const FRIENDLY_AFTER := 4  # meetings before two regulars might ask "can I call you eonni?"


## Someone, as far as address goes (see Address.allowed_terms). guest null: the owner.
static func person(owner_data: Dictionary, guest: Variant) -> Dictionary:
	if guest == null:
		return {"gender": str(owner_data.get("gender", "woman")), "age": int(owner_data.get("age", 55)), "owner": true}
	return {"gender": str(guest.customer.get("gender", "")), "age": int(guest.customer.get("age", 30)), "owner": false}


## Their name. guest null: the owner.
static func name_of(owner_data: Dictionary, guest: Variant) -> String:
	return str(owner_data["name"]) if guest == null else str(guest.customer["name"])


## For the checks: who's speaking to whom.
static func address_for(owner_data: Dictionary, speaker: Variant, listener: Variant, close: bool = false) -> Dictionary:
	return {"speaker": person(owner_data, speaker), "listener": person(owner_data, listener), "close": close, "listener_name": name_of(owner_data, listener)}


## For the prompts: how the owner and a customer address each other (and, for a regular the
## owner's got to know, their given name).
static func address_note(owner_data: Dictionary, guest: Variant) -> String:
	var text := "HOW THEY ADDRESS EACH OTHER: %s %s" % [
		Address.address_text(name_of(owner_data, guest), person(owner_data, guest), name_of(owner_data, null), person(owner_data, null), false),
		Address.address_text(name_of(owner_data, null), person(owner_data, null), name_of(owner_data, guest), person(owner_data, guest), false)]
	var known: Dictionary = guest.customer.get("regular", {})
	if bool(known.get("owner_knows_name", false)):
		var parts := str(guest.customer["name"]).split(" ", false)
		var given := " ".join(parts.slice(1)) if parts.size() > 1 else str(guest.customer["name"])
		if bool(known.get("founding", false)) or int(known.get("warmth", 0)) >= 2 or int(known.get("visits", 0)) >= 6:
			text += " The owner knows them well, and calls them by their given name, %s." % given
		else:
			text += " The owner knows their name, %s." % guest.customer["name"]
	return text


## Two regulars' record of each other (from the first one's side), or {}.
static func friend_record(bar: Dictionary, a: Variant, b: Variant) -> Dictionary:
	var mine := RegularsTonight.find(bar, str(a.customer.get("regular_id", "")))
	if mine.is_empty() or str(b.customer.get("regular_id", "")) == "":
		return {}
	return mine.get("friends", {}).get(str(b.customer["regular_id"]), {})


## Whether two regulars are close (on "eonni" terms, say).
static func are_close(bar: Dictionary, a: Variant, b: Variant) -> bool:
	return bool(friend_record(bar, a, b).get("close", false))


## After a spell of chat: regulars who chatted remember it (once a night per pair): how many
## times they've met, whether they know each other's names, and the last thing said.
## people: the chat's guests; transcript: what was said in it.
static func remember_chat(bar: Dictionary, people: Array, transcript: Array, last: String, night: int) -> void:
	var said := " ".join(PackedStringArray(transcript.filter(func(e): return e.has("text")).map(func(e): return str(e["text"])))).to_lower()
	for a in people:
		for b in people:
			if a == b:
				continue
			var mine := RegularsTonight.find(bar, str(a.customer.get("regular_id", "")))
			var their_id := str(b.customer.get("regular_id", ""))
			if mine.is_empty() or their_id == "":
				continue
			var friends: Dictionary = mine.get("friends", {})
			var known: Dictionary = friends.get(their_id, {"meetings": 0, "names": false, "close": false, "night": -1})
			if int(known.get("night", -1)) != night:
				known["meetings"] = int(known.get("meetings", 0)) + 1
				known["night"] = night
			if RegularsTonight.name_said(str(b.customer["name"]), said):
				known["names"] = true
			known["name"] = str(b.customer["name"])
			known["last"] = last
			friends[their_id] = known
			mine["friends"] = friends


## The "can I call you eonni?" moment, if it's time: the younger of two regulars who've met
## enough asks the older (the term they'd ask to use); "" if not.
static func friendly_moment(bar: Dictionary, owner_data: Dictionary, speaker: Variant, listener: Variant) -> String:
	if speaker == null or listener == null:
		return ""
	var known := friend_record(bar, speaker, listener)
	if known.is_empty() or bool(known.get("close", false)) or int(known.get("meetings", 0)) < FRIENDLY_AFTER:
		return ""
	return Address.sibling_term(person(owner_data, speaker), person(owner_data, listener))


## Two regulars are close now (the game's call, once asked): both their records say so.
static func make_close(bar: Dictionary, a: Variant, b: Variant) -> void:
	for pair in [[a, b], [b, a]]:
		var mine := RegularsTonight.find(bar, str(pair[0].customer.get("regular_id", "")))
		if mine.is_empty():
			continue
		var friends: Dictionary = mine.get("friends", {})
		var known: Dictionary = friends.get(str(pair[1].customer["regular_id"]), {})
		known["close"] = true
		friends[str(pair[1].customer["regular_id"])] = known
		mine["friends"] = friends


## The term a line actually used for its listener, for the bubble's header ("" if none).
static func term_used(bar: Dictionary, owner_data: Dictionary, line: String, speaker: Variant, listener: Variant) -> String:
	var allowed := Address.allowed_terms(person(owner_data, speaker), person(owner_data, listener), speaker != null and listener != null and are_close(bar, speaker, listener))
	for term in Address.terms_in(line, [name_of(owner_data, speaker), name_of(owner_data, listener)]):
		if allowed.has(term):
			return term
	return ""
