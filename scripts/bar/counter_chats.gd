extends RefCounted
## Customers chatting to each other at the counter: the chats going on, who's in one, who's
## free to start one or join in, and choosing tonight's next spell (carry one on, someone
## joining in, or two strangers getting talking). The tent's scene says each line (asking the
## AI), narrates and announces it; this keeps track of who's talking to whom.
## (Part 9 of splitting visit.gd: see DEVLOG.md, 16 November 2026.)

const People = preload("res://scripts/rules/people.gd")

const JOIN_CHANCE := 0.4  # how often another customer joins an ongoing chat
const CHAT_MIN_STAY_LEFT := 10.0  # game minutes: nobody starts a chat about to leave
const CARRY_ON_CHANCE := 0.6  # with two free to start a new one: how often an ongoing chat carries on instead


## A conversation between customers at the counter.
class Chat:
	extends RefCounted
	var people: Array = []  # the tent's Guests
	var owner_in := false
	var transcript: Array = []  # what's been said in this chat, and what happened
	var last_speaker := ""  # a name
	var topic := ""  # what it's turning to this spell (see Talk.pick_chat_topic)
	var shared := false  # had its sharing moment (see Talk.sharing_moment)
	var game := ""  # the table game it was offered (see Talk.TABLE_GAMES), once a chat
	var game_on := false  # ... and took up
	var game_lines := 0  # lines it's still in the air for (see Talk.TABLE_GAME_LINES)


var chats: Array = []  # Chat: customer conversations going on at the counter


## Someone who can be drawn into a chat right now: not keeping to themselves, settled in
## (served), and not about to leave (nobody starts a chat with ten minutes to go).
func can_chat(guest: Variant) -> bool:
	return People.joins_chats(guest.company) and guest.stay_left >= CHAT_MIN_STAY_LEFT and not guest.order.is_empty()


## The chat someone's in, or null.
func chat_of(guest: Variant) -> Chat:
	for chat in chats:
		if chat.people.has(guest):
			return chat
	return null


## People free to start a new chat, or join one.
func free_to_chat(guests: Array) -> Array:
	return guests.filter(func(guest): return can_chat(guest) and chat_of(guest) == null)


## The customers in a chat who can still take part.
func voices(chat: Chat) -> Array:
	return chat.people.filter(func(guest): return can_chat(guest))


## Whether there could be a chat now (none after last orders).
func possible(guests: Array, last_orders: bool) -> bool:
	if last_orders:
		return false
	for chat in chats:
		if voices(chat).size() >= 2:
			return true
	return free_to_chat(guests).size() >= 2


## Someone's leaving: out of their chats (and a chat with one left is over).
func leave(guest: Variant) -> void:
	for chat in chats.duplicate():
		chat.people.erase(guest)
		if chat.people.size() < 2:
			chats.erase(chat)


## The next spell of chat: an ongoing chat carries on (sometimes someone else joins in), or
## two strangers get talking. {"chat": the Chat (null: nobody to chat), "started": a new one,
## "joiner": who joined (or null)}. camera: the PD's camera (bar/camera.gd), leaning the spell
## towards whoever it's following (the dice are rolled as ever, then it leans).
## prefer: someone something's just happened to (a PD's plant card): their chat carries on.
func choose_spell(guests: Array, camera: Variant = null, prefer: Variant = null) -> Dictionary:
	var ongoing := chats.filter(func(c): return voices(c).size() >= 2)
	var free := free_to_chat(guests)
	if not ongoing.is_empty() and (free.size() < 2 or randf() < CARRY_ON_CHANCE):
		var chat: Chat = ongoing.pick_random()
		if camera != null:
			chat = camera.choose_chat(ongoing, chat)
		if prefer != null:
			for each in ongoing:
				if each.people.has(prefer):
					chat = each
		var joiner: Variant = null
		if not free.is_empty() and randf() < JOIN_CHANCE:
			joiner = free.pick_random()
			chat.people.append(joiner)
		return {"chat": chat, "started": false, "joiner": joiner}
	if free.size() >= 2:
		free.shuffle()
		if camera != null:
			free = camera.put_first(free)
		var chat := Chat.new()
		chat.people = [free[0], free[1]]
		chats.append(chat)
		return {"chat": chat, "started": true, "joiner": null}
	return {"chat": null, "started": false, "joiner": null}


## Changes anyone in a chat can see, added up (see the tent's Guest.version).
func version(chat: Chat) -> int:
	var total := 0
	for person in chat.people:
		total += person.version
	return total
