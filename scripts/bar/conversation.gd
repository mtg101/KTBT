extends RefCounted
## The conversations' situations: what each line is given to work with, as a direction for the
## AI (never the words): the opener (just served, or a quick hello on a busy night), the topic,
## nearly leaving, and the moments that come up (something stunning just said, a PD's plant
## card happening to them, the PD's camera turning to them, food just arrived, the cat), each
## used once. And for a customers' chat: meeting again, "can I call you eonni?", something to
## share, a table game late on, the stunned moment, the cat, a plant, the camera. How
## someone's known to strangers (as they look, until a name's been said), and who spoke last.
## The tent's scene asks the AI, shows the lines and keeps the stats; this decides what each
## line is given. The dice: the game's (randf) where the night's rolls always were, the
## scenery's for the table games.
## (Part 10 of splitting visit.gd, the second half: see DEVLOG.md, 16 November 2026.)

const Talk = preload("res://scripts/rules/talk.gd")
const Looks = preload("res://scripts/rules/looks.gd")
const Night = preload("res://scripts/bar/night.gd")


## What the owner's (or a customer's) next line to the other is given: {"direction", "hint"
## (what kind of moment, for the stats: "" if none), "opener" (an opening situation given)}.
## line: which line of their conversation (even: the owner's); late, wet: tonight.
## The moments it uses are used up (the guest's, or the night's for the owner).
static func owner_line(night: Night, guest: Variant, line: int, late: bool, wet: bool) -> Dictionary:
	var owner_speaks := line % 2 == 0
	var direction := ""
	var opener := false
	if line == 0 and guest.quick_greeting:
		direction = "It's been busy: this is the owner's first proper word with them since taking their order."
	elif line == 0:
		direction = "They've just been served: what's ready is on the table, and anything else is still cooking."
		var known: Dictionary = guest.customer.get("regular", {})
		var moment := Talk.opener_moment(not known.is_empty(), known.is_empty(), late, wet, randf(), randf())
		if moment != "" and owner_speaks:
			direction += " " + moment
			opener = true
	elif guest.stay_left < 10.0:
		direction = "The customer is nearly ready to leave."
	elif guest.pd_topic_lines > 0:  # (the PD's cue card, for a few lines)
		direction = Talk.cue_hint(guest.pd_topic)
		guest.pd_topic_lines -= 1
	elif guest.topic != "":
		direction = Talk.topic_hint(guest.topic)
	var hint := ""
	var stunned: String = night.owner_stunned if owner_speaks else guest.stunned
	if stunned != "":  # (first: they've just heard something they can't believe)
		direction = (stunned + " " + direction).strip_edges()
		hint = "stunned"
		if owner_speaks:
			night.owner_stunned = ""
		else:
			guest.stunned = ""
	elif line > 0 and not owner_speaks and guest.plant_moment != "":  # (a PD's plant card: it's happened to them)
		direction = (guest.plant_moment + " " + direction).strip_edges()
		hint = "plant_" + guest.plant_card
		guest.plant_moment = ""  # once
	elif line > 0 and not owner_speaks and guest.camera_moment != "":  # (the PD's camera has just turned to them)
		direction = (guest.camera_moment + " " + direction).strip_edges()
		hint = "camera"
		guest.camera_moment = ""  # once
	elif line > 0 and guest.food_moment != "":
		direction = (guest.food_moment + " " + direction).strip_edges()
		hint = Talk.moment_kind(guest.food_moment)
		guest.food_moment = ""  # once
	elif line > 0 and (night.owner_cat_moment if owner_speaks else guest.cat_moment) != "":
		direction = ((night.owner_cat_moment if owner_speaks else guest.cat_moment) + " " + direction).strip_edges()
		hint = "cat"
		if owner_speaks:
			night.owner_cat_moment = ""
		else:
			guest.cat_moment = ""
	return {"direction": direction, "hint": hint, "opener": opener}


## What a line of a customers' chat is given: {"direction", "hint", "moment_term" (the
## "can I call you eonni?" term being asked, or ""), "game" (a table game offered, or "")}.
## speaking: the speaker's guest (null: the owner, joining in); close: the two are close (or
## about to be); moment_term: from Friendliness.friendly_moment; met_before: they've chatted here
## before; food and drink: {speaker's food, listener's food, both drinking}; fewest_drinks:
## the fewest anyone in it has had; late_enough: past the table games' hour.
static func chat_line(night: Night, chat: Variant, speaker: String, addressee: String, first: bool, speaking: Variant, owner_speaks: bool,
		close: bool, moment_term: String, met_before: bool, food: Array, fewest_drinks: int, late_enough: bool, dice: RandomNumberGenerator) -> Dictionary:
	var direction := "This is the first thing they've ever said to each other." if first else Talk.topic_hint(chat.topic, true)
	if not first and chat.pd_topic_lines > 0:  # (the PD's cue card, for a few lines)
		direction = Talk.cue_hint(chat.pd_topic)
		chat.pd_topic_lines -= 1
	if first and met_before:
		direction = "They've met here before: they pick up where they left off."
	if moment_term != "":
		direction = "%s has got to know %s over their chats here, and asks if they can drop the formalities: can they call them %s?" % [speaker, addressee, moment_term.capitalize()]
	var hint := ""
	var game := ""
	# Now and then, once a chat: something to share (a bite, a refill).
	if not first and moment_term == "" and not chat.shared and speaking != null and int(food[0]) > 0:
		var sharing := Talk.sharing_moment(speaker, addressee, close, int(food[0]) > int(food[1]), bool(food[2]), randf(), randf())
		if sharing != "":
			direction = sharing + " " + direction
			hint = Talk.moment_kind(sharing)
			chat.shared = true
	# Late on, a few drinks in: a table game now and then, once a chat (the AI takes it up, or
	# doesn't). It's what's going on at the table for a few lines, not one passing remark, and it
	# takes the place of the chat's topic: the 8B model ignored it next to a topic (0 of 4 taken up).
	if hint == "" and not first and chat.game == "" and speaking != null:
		game = Talk.table_game(chat.people.size(), fewest_drinks, close, late_enough, dice.randf(), dice.randf())
		if game != "":
			chat.game = game
			chat.game_lines = Talk.TABLE_GAME_LINES
	if hint == "" and not first and chat.game != "" and not chat.game_on and chat.game_lines > 0:
		direction = str(Talk.TABLE_GAMES[chat.game]["situation"]) + " " + Talk.TABLE_GAME_NOW
		hint = "game_" + chat.game
		chat.game_lines -= 1
	# Something just said has stunned them.
	var heard: String = night.owner_stunned if owner_speaks else (speaking.stunned if speaking != null else "")
	if heard != "" and not first:
		direction = heard + " " + direction
		hint = "stunned"
		if owner_speaks:
			night.owner_stunned = ""
		else:
			speaking.stunned = ""
	# The cat's come to the speaker (or it's up to something the owner has to deal with).
	if hint == "" and not first:
		var with_cat: String = night.owner_cat_moment if owner_speaks else (speaking.cat_moment if speaking != null else "")
		if with_cat != "":
			direction = with_cat + " " + direction
			hint = "cat"
			if owner_speaks:
				night.owner_cat_moment = ""
			else:
				speaking.cat_moment = ""
	# A PD's plant card has just happened to the speaker.
	if hint == "" and not first and speaking != null and speaking.plant_moment != "":
		direction = speaking.plant_moment + " " + direction
		hint = "plant_" + speaking.plant_card
		speaking.plant_moment = ""
	# The PD's camera has just turned to the speaker.
	if hint == "" and not first and speaking != null and speaking.camera_moment != "":
		direction = speaking.camera_moment + " " + direction
		hint = "camera"
		speaking.camera_moment = ""
	return {"direction": direction, "hint": hint, "moment_term": moment_term, "game": game}


## How someone in a chat is known to the others: by name if it's been said there (their full
## name or their given name), otherwise as anyone can see them ("the woman in the beige
## trench coat"), since nobody knows a stranger's name. (Founding regulars have known each
## other for years.)
static func known_as(guest: Variant, chat: Variant) -> String:
	var full := str(guest.customer["name"])
	if chat != null and bool(guest.customer.get("regular", {}).get("founding", false)):
		for other in chat.people:
			if other != guest and bool(other.customer.get("regular", {}).get("founding", false)):
				return full
	var parts := full.split(" ", false)
	var given := " ".join(parts.slice(1)) if parts.size() > 1 else full
	if chat != null:
		for entry in chat.transcript:
			var text := str(entry.get("text", "")).to_lower()
			if text.contains(full.to_lower()) or text.contains(given.to_lower()):
				return full
	return Looks.seen_as(guest.customer)


## Who spoke last in a transcript ("" if nobody has).
static func last_speaker(transcript: Array) -> String:
	for i in range(transcript.size() - 1, -1, -1):
		if transcript[i].has("text"):
			return str(transcript[i]["speaker"])
	return ""
