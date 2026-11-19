extends RefCounted
## Who calls whom, and friendliness: how the owner and each customer address each other (for
## the prompts and the checks), two regulars' bond (bonds.gd: how often they've met, whether
## they know each other's names, the last thing said), and the "can I call you
## eonni?" moment, when it's time, and marking them close. Plain functions on the bar, the
## owner and the tent's guests (null: the owner). The tent's scene narrates and saves.
## (Part 10 of splitting visit.gd, the first half: see DEVLOG.md, 16 November 2026.)

const Address = preload("res://scripts/rules/address.gd")
const RegularsTonight = preload("res://scripts/bar/regulars_tonight.gd")
const Bonds = preload("res://scripts/rules/bonds.gd")

const FRIENDLY_AFTER := Bonds.FRIENDLY  # meetings before two regulars might ask "can I call you eonni?"


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
	return {"speaker": person(owner_data, speaker), "listener": person(owner_data, listener), "close": close, "listener_name": name_of(owner_data, listener),
		"to_camera": speaker != null and "to_camera" in speaker and bool(speaker.to_camera)}


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


## Two regulars' bond (bonds.gd), or {} if they've never chatted here.
static func friend_record(bar: Dictionary, a: Variant, b: Variant) -> Dictionary:
	return Bonds.find(bar, str(a.customer.get("regular_id", "")), str(b.customer.get("regular_id", "")))


## Whether everyone in a chat knows everyone else: close, or regulars who've chatted here
## before (only then can it turn to teasing; strangers never do). people: the chat's guests.
static func know_each_other(bar: Dictionary, people: Array) -> bool:
	for i in people.size():
		for j in range(i + 1, people.size()):
			if friend_record(bar, people[i], people[j]).is_empty():
				return false
	return people.size() > 1


## Whether two regulars are close (on "eonni" terms, say).
static func are_close(bar: Dictionary, a: Variant, b: Variant) -> bool:
	return bool(friend_record(bar, a, b).get("close", false))


## Whether a knows b's name (two regulars).
static func knows_name(bar: Dictionary, a: Variant, b: Variant) -> bool:
	return Bonds.knows_name(friend_record(bar, a, b), str(a.customer.get("regular_id", "")))


## After a spell of chat: regulars who chatted remember it in their bond (a meeting counted once
## a night per pair): each learns the other's name once it's been said, and the last thing said.
## people: the chat's guests; transcript: what was said in it.
static func remember_chat(bar: Dictionary, people: Array, transcript: Array, last: String, night: int) -> void:
	var said := " ".join(PackedStringArray(transcript.filter(func(e): return e.has("text")).map(func(e): return str(e["text"])))).to_lower()
	for i in people.size():
		for j in range(i + 1, people.size()):
			var a_id := str(people[i].customer.get("regular_id", ""))
			var b_id := str(people[j].customer.get("regular_id", ""))
			if a_id == "" or b_id == "":
				continue
			var bond := Bonds.between(bar, a_id, b_id)
			Bonds.meet(bond, night)
			if RegularsTonight.name_said(str(people[j].customer["name"]), said):
				Bonds.learn_name(bond, a_id)
			if RegularsTonight.name_said(str(people[i].customer["name"]), said):
				Bonds.learn_name(bond, b_id)
			bond["last"] = last


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
	var a_id := str(a.customer.get("regular_id", ""))
	var b_id := str(b.customer.get("regular_id", ""))
	if a_id != "" and b_id != "":
		Bonds.between(bar, a_id, b_id)["close"] = true


## The term a line actually used for its listener, for the bubble's header ("" if none).
static func term_used(bar: Dictionary, owner_data: Dictionary, line: String, speaker: Variant, listener: Variant) -> String:
	var allowed := Address.allowed_terms(person(owner_data, speaker), person(owner_data, listener), speaker != null and listener != null and are_close(bar, speaker, listener))
	for term in Address.terms_in(line, [name_of(owner_data, speaker), name_of(owner_data, listener)]):
		if allowed.has(term):
			return term
	return ""
