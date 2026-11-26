extends RefCounted
## Where a PD's card waits to be talked about: someone's moment for their next line (one at a
## time, the rest queued behind it in the order they happened), and what lingers on a person's
## or a chat's mind afterwards (the steer: a cue card, or "a little while ago…"). A new card
## never wipes out one that's still waiting (26 Nov: the interview went unasked because the
## chaebol card came five minutes later, and a song across the street wiped out the ex walking
## past). Someone's own card comes before one for the whole tent; otherwise the newest steer
## goes first and the older one waits. At most MAX_WAITING wait; past that, the one furthest
## back is dropped (a card for the whole tent, if any are waiting), and the notes say so.
##
## Works on anything with the fields: a moment holder has plant_moment, plant_card,
## plant_happened, card_turn and plant_queue; a steer holder has pd_topic, pd_topic_lines,
## pd_topic_card, pd_topic_personal and pd_topic_queue (the tent's Guest and Chat).
## The owner's moment for a card for the whole tent: Night's owner_plant_moment, owner_plant_card
## and owner_plant_queue.

const MAX_WAITING := 3


## A card's moment for someone's next line: now, or queued behind one still to come.
## {"behind": the card it waits behind ("" if it's next), "dropped": a card dropped to make room ("")}.
static func plant(guest: Variant, card: String, moment: String, happened: String) -> Dictionary:
	var entry := {"moment": moment, "card": card, "happened": happened}
	if guest.plant_moment == "":
		_take_plant(guest, entry)
		return {"behind": "", "dropped": ""}
	guest.plant_queue.append(entry)
	var dropped := ""
	if guest.plant_queue.size() > MAX_WAITING:
		dropped = str(guest.plant_queue.pop_front()["card"])
	return {"behind": str(guest.plant_card) if str(guest.plant_card) != "" else "earlier", "dropped": dropped}


## Their moment's been used (a line was given it): the next one waiting, if any, is next.
## Returns its card ("" if none was waiting).
static func use_plant(guest: Variant) -> String:
	guest.plant_moment = ""
	if guest.plant_queue.is_empty():
		return ""
	var next: Dictionary = guest.plant_queue.pop_front()
	_take_plant(guest, next)
	return str(next["card"])


static func _take_plant(guest: Variant, entry: Dictionary) -> void:
	guest.plant_moment = str(entry["moment"])
	guest.plant_card = str(entry["card"])
	guest.plant_happened = str(entry["happened"])
	guest.card_turn = false


## The cards someone still had to come (their moment, and any waiting): for the notes when they leave.
static func unsaid(guest: Variant) -> Array:
	var cards: Array = []
	if guest.plant_moment != "" and guest.plant_card != "":
		cards.append(str(guest.plant_card))
	for entry in guest.plant_queue:
		cards.append(str(entry["card"]))
	return cards


## What's to stay on their minds (or a chat's) for a few lines. personal: someone's own card
## (or a pair's), not one for the whole tent. {"card", "behind": the card it waits behind (""), "ahead_of":
## the card it goes ahead of, still waiting (""), "dropped": a card dropped to make room ("")}.
static func steer(holder: Variant, topic: String, lines: int, card: String, personal: bool) -> Dictionary:
	var result := {"card": card, "behind": "", "ahead_of": "", "dropped": ""}
	if lines <= 0 or topic == "":
		return result
	var entry := {"topic": topic, "lines": lines, "card": card, "personal": personal}
	if holder.pd_topic_lines <= 0:
		_take_steer(holder, entry)
		return result
	var current := {"topic": holder.pd_topic, "lines": holder.pd_topic_lines, "card": holder.pd_topic_card, "personal": holder.pd_topic_personal}
	if bool(current["personal"]) and not personal:  # (the whole tent's card waits behind their own)
		_queue(holder, entry, false)
		result["behind"] = str(current["card"])
	else:  # (the newer one first; what was on their mind waits, next)
		_take_steer(holder, entry)
		_queue(holder, current, true)
		result["ahead_of"] = str(current["card"])
	if holder.pd_topic_queue.size() > MAX_WAITING:
		var last: Dictionary = holder.pd_topic_queue.pop_back()  # (the one furthest back: a card for the whole tent's, if any are waiting)
		result["dropped"] = str(last["card"])
	return result


## The steer's been given to a line: one line fewer, and the next waiting takes over when it's
## done. Returns the card that's taken over ("" if none).
static func use_steer(holder: Variant) -> String:
	holder.pd_topic_lines -= 1
	if holder.pd_topic_lines > 0 or holder.pd_topic_queue.is_empty():
		return ""
	var next: Dictionary = holder.pd_topic_queue.pop_front()
	_take_steer(holder, next)
	return str(next["card"])


## Everything on one's mind (the steer, and what's waiting) goes to another: someone into the
## chat they've started or joined, or a chat that's ended back to whoever's still in it. The
## one it came from is left with none. Returns the steer() results where one of these and
## something already on the other's mind had to take turns (for the notes).
static func hand_over(from: Variant, to: Variant) -> Array:
	var all: Array = []
	if from.pd_topic_lines > 0:
		all.append({"topic": from.pd_topic, "lines": from.pd_topic_lines, "card": from.pd_topic_card, "personal": from.pd_topic_personal})
	all.append_array(from.pd_topic_queue)
	clear_steer(from)
	if all.is_empty():
		return []
	if to.pd_topic_lines <= 0 and to.pd_topic_queue.is_empty():  # (nothing on the other's mind: it all goes over as it was)
		_take_steer(to, all[0])
		to.pd_topic_queue.append_array(all.slice(1))
		return []
	var theirs: Array = all.map(func(e): return str(e["card"]))
	var results: Array = []
	all.reverse()  # (the one most wanted last, so it's the one on top)
	for entry in all:
		var slot := steer(to, str(entry["topic"]), int(entry["lines"]), str(entry["card"]), bool(entry["personal"]))
		var behind := str(slot["behind"])
		var ahead := str(slot["ahead_of"])
		if (behind != "" and not theirs.has(behind)) or (ahead != "" and not theirs.has(ahead)) or str(slot["dropped"]) != "":
			results.append(slot)
	return results


static func clear_steer(holder: Variant) -> void:
	holder.pd_topic = ""
	holder.pd_topic_lines = 0
	holder.pd_topic_card = ""
	holder.pd_topic_personal = false
	holder.pd_topic_queue.clear()


static func _take_steer(holder: Variant, entry: Dictionary) -> void:
	holder.pd_topic = str(entry["topic"])
	holder.pd_topic_lines = int(entry["lines"])
	holder.pd_topic_card = str(entry["card"])
	holder.pd_topic_personal = bool(entry["personal"])


## Into the queue: someone's own before the whole tent's. front: at the front of its kind
## (it was already on their mind), otherwise at the back.
static func _queue(holder: Variant, entry: Dictionary, front: bool) -> void:
	var queue: Array = holder.pd_topic_queue
	var at := queue.size()
	var personal := bool(entry["personal"])
	for i in queue.size():
		var other_personal := bool(queue[i]["personal"])
		if front and other_personal == personal:
			at = i
			break
		if personal and not other_personal:
			at = i
			break
	queue.insert(at, entry)


## A card for the whole tent, for the owner's next line: now, or after one still to come.
## Returns the card it waits behind ("" if it's next).
static func owner_plant(night: Variant, card: String, moment: String) -> String:
	if night.owner_plant_moment == "":
		night.owner_plant_moment = moment
		night.owner_plant_card = card
		return ""
	night.owner_plant_queue.append({"moment": moment, "card": card})
	while night.owner_plant_queue.size() > MAX_WAITING:
		night.owner_plant_queue.pop_front()
	return str(night.owner_plant_card)


## The owner's moment's been used: the next waiting, if any.
static func use_owner_plant(night: Variant) -> void:
	night.owner_plant_moment = ""
	night.owner_plant_card = ""
	if not night.owner_plant_queue.is_empty():
		var next: Dictionary = night.owner_plant_queue.pop_front()
		night.owner_plant_moment = str(next["moment"])
		night.owner_plant_card = str(next["card"])
