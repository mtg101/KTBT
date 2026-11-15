extends RefCounted
## Prompt text sent to the local LLM.
## This is creative writing rather than code: CC BY-SA 4.0 (see LICENSE-ASSETS.md).

const Rules = preload("res://scripts/rules.gd")
const Regulars = preload("res://scripts/regulars.gd")

const STYLE_GUIDE := """You are the writers' room for KTBT (Korean Tent Bar Tropes), a cosy simulation set in a pojangmacha: a street tent bar under a Seoul overpass. Plastic stools, green bottles on every table, steam rising off the pots, bare bulbs swinging in the wind.

Everyone you invent belongs in a K-drama. Lean into the familiar tropes, but make each character feel like a real person rather than a cliche.

Owner types that fit (riff on these, don't copy them):
- the gruff-but-soft ajumma who scolds customers for not eating properly
- the quiet ajusshi with a mysterious past who gives one line of perfect advice
- the ex-something (gangster, chef, idol trainee) who left it all behind

Customer types that fit (riff on these, don't copy them):
- salarymen escaping a hoesik (company dinner)
- a newly dumped office worker drinking alone
- exhausted nurses after a night shift
- a chaebol heir in disguise
- students celebrating the end of exams
- a taxi driver on his break
- old friends reuniting after years apart
- someone working up the courage to confess their feelings

Who turns up should suit the hour: the after-work crowd early in the evening, night-shift workers and lonely stragglers in the small hours.

Tone: warm, melodramatic, a little melancholy, with humour mixed in. Late-night honesty, unspoken feelings, "just one more bottle"."""

const DIALOGUE_RULES := """You write one line of dialogue at a time for a scene at the tent. Stay in character. Show feelings through what people say and small actions, not by explaining them. Keep it natural: people at a tent bar talk in short, plain sentences.

They're speaking Korean, which we show in English: everyone speaks fluent, natural English in their own voice (blunt, rambling, slangy, whatever suits them), never broken English.

Write in English. People can drop in the odd Korean word or exclamation that Western fans of K-dramas would know, but never whole sentences in Korean or romanised Korean, and never translations in brackets."""


## How customers address the owner. The game fixes the owner's title by gender (it's a
## game fact, not something the AI chooses). Customers may use the title or one of the
## alternatives, all of which work for any customer speaking to an older stranger.
## Terms like oppa, hyung, nuna and eonni depend on who's speaking, so they're ruled out.
const OWNER_ADDRESS := {
	"woman": {"title": "Ajumma", "also": "Imo, Sajangnim or Eomeoni"},
	"man": {"title": "Ajusshi", "also": "Samchon or Sajangnim"},
}


## Messages asking the AI to invent the tent's owner.
## The game decides whether the owner is a woman or a man (and so their title);
## the AI invents the rest.
## look: how the game has decided the owner looks (Rules.pick_look), including their age range.
static func owner_messages(gender: String, look: Dictionary = {}) -> Array:
	var title: String = OWNER_ADDRESS[gender]["title"]
	var ages := "a whole number, 40 or older"
	var seen := ""
	if not look.is_empty():
		var band: Array = Rules.AGE_RANGES[look["age_range"]]
		ages = "a whole number from %d to %d" % [maxi(40, int(band[0])), int(band[1])]
		seen = "\n\nHow they look (the game has decided this, so keep to it): %s. Let it shape who they are." % look_text_for(look)
	var request := """Invent the owner of this pojangmacha. The owner is a %s, and customers call them "%s". They've run the tent for years, and every regular knows them. Everything about them (archetype, appearance) must fit a %s.%s

Reply with ONLY a JSON object with exactly these keys:
- "name": their Korean name in English letters, family name first
- "hangul": the same name in Korean letters (Hangul), e.g. "박미숙" for Park Mi-sook
- "age": %s
- "archetype": the K-drama type they are, in a few words
- "appearance": what they look like behind the counter, in one sentence%s
- "personality": two or three traits
- "speech_style": how they talk, in a few words
- "secret": something about their past they rarely talk about, in one sentence""" % [gender, title, gender, seen, ages,
		": keep to how they look, in your own words, and add how they seem (their expression, or how they carry themselves)" if not look.is_empty() else ""]
	return [
		{"role": "system", "content": STYLE_GUIDE},
		{"role": "user", "content": request},
	]


## Messages asking the AI to name the owner's tent. The name is Korean, written in English
## letters, like a real pojangmacha's.
static func bar_name_messages(owner: Dictionary) -> Array:
	var request := """%s

Name this pojangmacha. Real tents have short, warm Korean names, written here in English letters (romanised), often ending in "Pocha" or "Pojangmacha". They might be named after the owner (for example with "-ne", meaning "so-and-so's family's"), a feeling, the weather, the night sky, or the street it's on. The name must be Korean, not English words.

Reply with ONLY a JSON object with exactly these keys:
- "name": the tent's name in romanised Korean
- "meaning": what the name means in English, in a few words""" % describe_owner(owner)
	return [
		{"role": "system", "content": STYLE_GUIDE},
		{"role": "user", "content": request},
	]


## Messages asking the AI how the tent looks, to suit its owner and name: the sign's Hangul,
## and choices from the game's lists (so the game can draw it).
## offered: the colours and shapes the game offers this bar (Rules.look_offer); empty for all.
static func bar_look_messages(owner: Dictionary, bar_name: String, meaning: String, offered: Dictionary = {}) -> Array:
	var shapes := PackedStringArray()
	for id in offered.get("shape", Rules.TENT_SHAPES.keys()):
		shapes.append("%s (%s)" % [id, Rules.TENT_SHAPES[id]])
	var tarps := PackedStringArray(offered.get("tarp", Rules.BAR_TARPS.keys()))
	var touches := PackedStringArray()
	for id in Rules.BAR_TOUCHES:
		touches.append("%s (%s)" % [id, Rules.BAR_TOUCHES[id]])
	var request := """%s

The tent is called %s (%s). Choose how it looks, to suit the owner and the name.

Reply with ONLY a JSON object with exactly these keys:
- "hangul": the tent's name written in Korean letters (Hangul), for the sign, e.g. "별빛 포차" for Byeolbit Pocha
- "shape": the shape of the tent's cover, one of: %s
- "tarp": the tarp's colour, one of: %s
- "sign": the sign's style, one of: %s
- "touches": a list of one or two little touches around the tent, from: %s""" % [
		describe_owner(owner), bar_name, meaning, ", ".join(shapes), ", ".join(tarps),
		", ".join(PackedStringArray(Rules.SIGN_STYLES.keys())), ", ".join(touches)]
	return [
		{"role": "system", "content": STYLE_GUIDE},
		{"role": "user", "content": request},
	]


## Messages asking the AI to invent one customer for the given moment.
## The game picks day, time and weather; the AI only invents the person.
## include_opening_line: stage 1 shows an opening line on the profile card. In a visit,
## the customer's first words come with their order instead, so the two always match.
## The first of two steps in inventing a customer: just a name and gender, which is quick.
## taken: names of people at the counter, which the new customer mustn't share; used_tonight:
## names from earlier tonight, best avoided for variety.
## gender: one the game has already decided (non-binary), so only the name is asked for.
static func customer_name_messages(day: String, time_text: String, weather: String, taken: Array = [], used_tonight: Array = [], gender: String = "") -> Array:
	var request := """It's %s, %s, with %s. Someone is about to duck under the tarp.

Who are they? Give only their name and gender. Pick a name that real Koreans have, and not always the most common ones.""" % [day, time_text, weather]
	if gender != "":
		request = """It's %s, %s, with %s. Someone is about to duck under the tarp. They're %s.

What's their name? Pick a name that real Koreans have, and not always the most common ones.""" % [day, time_text, weather, gender_phrase(gender)]
	if not taken.is_empty():
		request += "\n\nThese people are already here, so the new customer must have a different name: %s." % ", ".join(PackedStringArray(taken))
	if not used_tonight.is_empty():
		request += "\nThese names have come up tonight already, so avoid them too: %s." % ", ".join(PackedStringArray(used_tonight))
	if gender != "":
		request += """

Reply with ONLY a JSON object with exactly these keys:
- "name": their Korean name in English letters, family name first, then the given name
- "hangul": the same name in Korean letters (Hangul), e.g. "김지호" for Kim Ji-ho"""
	else:
		request += """

Reply with ONLY a JSON object with exactly these keys:
- "name": their Korean name in English letters, family name first, then the given name
- "hangul": the same name in Korean letters (Hangul), e.g. "김지호" for Kim Ji-ho
- "gender": either woman or man"""
	return [
		{"role": "system", "content": STYLE_GUIDE},
		{"role": "user", "content": request},
	]


## Inventing a customer. With a name and gender (the second step, once the game has them),
## the AI fills in the rest of that person; without, it invents a whole customer.
## used_jobs and used_looks: tonight's customers so far, so this one's different (small models
## otherwise send in four nurses with dark circles under their eyes).
## look: how the game has decided the customer looks (Rules.pick_look), including their age
## range; the AI invents someone who'd look like that.
static func customer_messages(day: String, time_text: String, weather: String, include_opening_line: bool = true, customer_name: String = "", gender: String = "", used_jobs: Array = [], used_looks: Array = [], look: Dictionary = {}) -> Array:
	if customer_name != "":
		var ages := "a whole number, 19 or older"
		var seen := ""
		var appearance := "what they look like as they arrive, in one sentence"
		if not look.is_empty():
			var band: Array = Rules.AGE_RANGES[look["age_range"]]
			ages = "a whole number from %d to %d" % [maxi(19, int(band[0])), int(band[1])]
			seen = "\n\nHow they look (the game has decided this, so keep to it): %s. Invent someone who'd look like that." % look_text_for(look)
			appearance += ": keep to how they look, in your own words, and add how they seem (their expression, or how they carry themselves), not an object"
		var details := """It's %s, %s, with %s.

A customer has just ducked under the tarp: %s (%s). Fill in who they are, so they'd plausibly turn up right now.%s

Reply with ONLY a JSON object with exactly these keys:
- "age": %s
- "job": their job, or what they do
- "mood": a few words
- "reason": why they're here tonight, in one sentence
- "speech_style": how they talk, in a few words
- "appearance": %s""" % [day, time_text, weather, customer_name, gender_phrase(gender), seen, ages, appearance]
		if not used_jobs.is_empty():
			details += "\n\nMake them different from tonight's other customers. Jobs they've had: %s. Pick a different job." % ", ".join(PackedStringArray(used_jobs))
		if not used_looks.is_empty() and look.is_empty():  # with a game-decided look, not needed (and the AI copied them)
			details += "\nHow they looked (don't describe this one the same way, e.g. no more dark circles or messy buns if those have come up): %s" % " / ".join(PackedStringArray(used_looks))
		return [
			{"role": "system", "content": STYLE_GUIDE},
			{"role": "user", "content": details},
		]
	var request := """It's %s, %s, with %s.

Invent ONE customer who would plausibly duck under the tarp right now.

Reply with ONLY a JSON object with exactly these keys:
- "name": their Korean name in English letters, family name first
- "age": a whole number, 19 or older
- "job": their job, or what they do
- "mood": a few words
- "reason": why they're here tonight, in one sentence
- "speech_style": how they talk, in a few words
- "appearance": what they look like as they arrive, in one sentence""" % [day, time_text, weather]
	if include_opening_line:
		request += """
- "opening_line": the first thing they say to the owner as they sit down"""
	return [
		{"role": "system", "content": STYLE_GUIDE},
		{"role": "user", "content": request},
	]


## Messages asking the AI what the customer orders, from the game's menu.
## hungry and rough_night are decided by the game: a hungry customer may order two main
## dishes, and one having a rough night may order two drinks.
static func order_messages(owner: Dictionary, customer: Dictionary, moment: Dictionary, menu_text: String, transcript: Array, hungry: bool = false, rough_night: bool = false) -> Array:
	var appetite := "%s is starving tonight, so they may order up to two main dishes." % customer["name"] if hungry else "%s isn't especially hungry: at most one main dish." % customer["name"]
	var thirst := "It's a rough night for them, so they may order two drinks." if rough_night else "They'll order just one drink."
	var request := """%s

%s

%s

%s

What's been said so far:
%s

TONIGHT'S MENU (use these exact ids):
%s

What does %s order? Think about who they are and why they're here tonight. Order between 2 and 4 items. Repeat an id to order more than one of something.

HOW PEOPLE ORDER HERE: everyone orders at least one drink and at least one food, because nobody drinks on an empty stomach. Most people order ONE main dish (marked "main" on the menu), maybe with a side (marked "side"), and ONE drink (one bottle goes a long way). Ordering two of the same main dish, or two drinks, is unusual. %s %s

They've just sat down and haven't said anything yet. Their line is the very first thing they say: greet the owner in their own way (using what they call the owner) and ask for their order, in their own voice. The line must match "items" exactly: don't mention any food or drink that isn't in "items", and don't say things like "one of everything".

Reply with ONLY a JSON object with exactly these keys:
- "items": an array of menu ids
- "line": what they say as they sit down and order: one or two short sentences""" % [
		describe_moment(moment), describe_owner(owner), describe_customer(customer),
		describe_relationship(owner, customer), transcript_text(transcript), menu_text, customer["name"], appetite, thirst]
	return [
		{"role": "system", "content": STYLE_GUIDE},
		{"role": "user", "content": request},
	]


## Messages asking the AI for a later order, partway through the conversation: one more bottle,
## a side, or rice to finish the sauce. The game decides when this happens.
static func extra_order_messages(owner: Dictionary, customer: Dictionary, moment: Dictionary, menu_text: String, transcript: Array, table: String) -> Array:
	var request := """%s

%s

%s

%s

On the table: %s

The conversation so far:
%s

TONIGHT'S MENU (use these exact ids):
%s

%s

Partway through the conversation, %s orders something more, the way people do at a pojangmacha: one more bottle, a side, or rice to finish the sauce (fried rice is made in the leftover sauce of a main dish, so only if there's a main on the table). Order ONE or TWO items: at most one drink, and no main dishes. This is NOT their first order: their line must make clear they're adding to what they already have ("one more bottle", "can I get some rice too?", "another one of these"). It follows on from the conversation, in their own voice. Everything they ask for must be in "items": if they say "another tteokbokki", tteokbokki goes in "items". They can mention something already on the table without ordering more by calling it "this" or "the" ("this sauce needs rice").

Reply with ONLY a JSON object with exactly these keys:
- "items": an array of menu ids
- "line": what they say as they order: one or two short sentences""" % [
		describe_moment(moment), describe_owner(owner), describe_customer(customer),
		describe_relationship(owner, customer), table, transcript_text(transcript), menu_text,
		what_just_happened(transcript), customer["name"]]
	return [
		{"role": "system", "content": STYLE_GUIDE + "\n\n" + DIALOGUE_RULES},
		{"role": "user", "content": request},
	]


## "a woman", "a man", or "non-binary, they/them": how prompts describe someone's gender.
## A look in words (Rules.look_text), here so prompts and their tests can share it.
static func look_text_for(look: Dictionary) -> String:
	return Rules.look_text(look)


static func gender_phrase(gender: String) -> String:
	if gender == "non-binary":
		return "non-binary, they/them"
	return "a %s" % gender


## The bar's cat and where it is right now, for dialogue prompts.
static func describe_cat(cat: Dictionary, now: String) -> String:
	var sex := ""
	if cat.has("sex"):
		sex = " (a %s: call the cat \"%s\")" % ["female" if cat["sex"] == "she" else "male", cat["sex"]]
	return "THE CAT: %s, the tent's %s cat%s, %s. Right now: %s Only mention the cat as it really is right now: nobody strokes it, or talks of it on a lap, unless it's on their lap." % [
		cat["name"], cat["coat"], sex, Rules.CAT_PERSONALITIES.get(cat["personality"], cat["personality"]), now]


## Messages asking the AI to name the bar's cat. The game has decided its coat and personality.
## taken: names other bars' cats have, which this one mustn't share.
## Messages asking the AI to write a name in Hangul (for bars saved before names had it).
static func hangul_messages(person_name: String) -> Array:
	var request := """Write this Korean name in Korean letters (Hangul): %s

Reply with ONLY a JSON object with exactly one key:
- "hangul": the name in Hangul, e.g. "김지호" for Kim Ji-ho, or "나비" for Nabi""" % person_name
	return [
		{"role": "system", "content": STYLE_GUIDE},
		{"role": "user", "content": request},
	]


static func cat_name_messages(owner: Dictionary, bar_name: String, coat: String, personality: String, sex: String = "she", taken: Array = []) -> Array:
	var request := """%s, the owner of %s, has a cat that lives at the tent: a %s %s cat, %s.

What's the cat called? A short Korean pet name in English letters, the kind Koreans give their cats.""" % [owner["name"], bar_name, coat, "female" if sex == "she" else "male", Rules.CAT_PERSONALITIES.get(personality, personality)]
	if not taken.is_empty():
		request += " Other tents' cats are called %s, so pick something else." % ", ".join(PackedStringArray(taken))
	request += """

Reply with ONLY a JSON object with exactly these keys:
- "name": the cat's name, in English letters
- "hangul": the same name in Korean letters (Hangul), e.g. "나비" for Nabi"""
	return [
		{"role": "system", "content": STYLE_GUIDE},
		{"role": "user", "content": request},
	]


## How strangers at the counter talk to each other: the game checks this too (Rules.close_term).
const STRANGERS_RULES := "Everyone's already sitting on a stool at the counter (nobody asks if a seat's free). Unless it says above that two of them know each other, they're strangers who've only just met tonight. They don't know each other's names unless someone has said theirs in the conversation below. They talk politely, as strangers do in Korea: never oppa, hyung, nuna or eonni (those are for people who are close). To get someone's attention they might say \"jeogiyo\" (excuse me)."


## Messages asking the AI for the next line of a chat between customers at the counter
## (sometimes with the owner joining in). people: the customers in the chat; tables: what's
## on each one's table, in the same order. speaker and addressee are names (the owner's
## name when they speak or are spoken to).
static func counter_chat_messages(owner: Dictionary, owner_in: bool, people: Array, tables: Array, moment: Dictionary, transcript: Array, speaker: String, addressee: String, direction: String, cat: String = "") -> Array:
	var who := PackedStringArray()
	for i in people.size():
		who.append("- %s %s Their table: %s." % [describe_person(people[i]), standing(people[i], owner), tables[i]])
	# Founding regulars have been coming for years: they know each other.
	var old_hands: Array = people.filter(func(p): return bool(p.get("regular", {}).get("founding", false)))
	if old_hands.size() >= 2:
		who.append("- %s know each other: long-time fellow regulars, on first-name terms." % " and ".join(PackedStringArray(old_hands.map(func(p): return str(p["name"])))))
	var owner_gender := str(owner.get("gender", "woman"))
	var owner_part := "The owner, %s (customers call %s \"%s\"), is busy elsewhere and isn't part of this conversation." % [
		owner["name"], "her" if owner_gender == "woman" else "him", owner.get("title", "Ajumma")]
	if owner_in:
		owner_part = describe_owner(owner) + "\nThe owner has joined in."
	var request := """%s

AT THE COUNTER, talking to each other:
%s

%s

%s%s

The conversation between them so far:
%s

%s

Write the next line, spoken by %s to %s. %s
One to three sentences. Speak only as %s: don't write anyone else's reply or any narration.

Reply with ONLY a JSON object with one key:
- "line": what %s says""" % [
		describe_moment(moment), "\n".join(who), owner_part, STRANGERS_RULES, ("\n\n" + cat) if cat != "" else "",
		transcript_text(transcript), what_just_happened(transcript), speaker, addressee, direction, speaker, speaker]
	return [
		{"role": "system", "content": STYLE_GUIDE + "\n\n" + DIALOGUE_RULES},
		{"role": "user", "content": request},
	]


## Messages asking the AI for the next line of the conversation.
## direction is an optional hint from the game about where the scene is (e.g. "they're about to leave").
## cat: where the bar's cat is right now (describe_cat), or "".
static func dialogue_messages(owner: Dictionary, customer: Dictionary, moment: Dictionary, served: String, transcript: Array, owner_speaks: bool, direction: String, cat: String = "") -> Array:
	var speaker := str(owner["name"]) if owner_speaks else str(customer["name"])
	var role := "the owner" if owner_speaks else "the customer"
	var request := """%s

%s

%s

%s

On the table: %s%s

The conversation so far:
%s

%s

Write the next line, spoken by %s (%s). %s
One to three sentences. Speak only as %s: don't write the other person's reply or any narration.

Reply with ONLY a JSON object with one key:
- "line": what %s says""" % [
		describe_moment(moment), describe_owner(owner), describe_customer(customer),
		describe_relationship(owner, customer), served, ("\n\n" + cat) if cat != "" else "",
		transcript_text(transcript), what_just_happened(transcript), speaker, role, direction, speaker, speaker]
	return [
		{"role": "system", "content": STYLE_GUIDE + "\n\n" + DIALOGUE_RULES},
		{"role": "user", "content": request},
	]


static func describe_moment(moment: Dictionary) -> String:
	return "TONIGHT: %s, %s, with %s." % [moment["day"], moment["time"], moment["weather"]]


static func describe_owner(owner: Dictionary) -> String:
	var gender := str(owner.get("gender", "woman"))
	var address: Dictionary = OWNER_ADDRESS.get(gender, OWNER_ADDRESS["woman"])
	return "THE OWNER: %s, a %s-year-old %s. Customers call them \"%s\" (or sometimes %s; never oppa, hyung, nuna or eonni). %s. %s Personality: %s. Talks: %s. A secret they rarely share, and only ever hint at: %s (Customers don't know the owner's past or secret: only what they can see, and what the owner has told them.)" % [
		owner["name"], owner["age"], gender, owner["title"], address["also"], owner["archetype"], owner["appearance"],
		owner["personality"], owner["speech_style"], owner["secret"]]


static func describe_customer(customer: Dictionary) -> String:
	return "THE CUSTOMER: " + describe_person(customer)


## One customer, for any prompt: who they are, their mood, and (once the game has decided
## it) their mood for company.
static func describe_person(customer: Dictionary) -> String:
	var who := str(customer["name"])
	if customer.has("gender"):
		who += " (%s)" % gender_phrase(str(customer["gender"]))
	var text := "%s, %s, %s. Mood: %s. Why they're here tonight: %s Talks: %s." % [
		who, customer["age"], customer["job"], customer["mood"],
		customer["reason"], customer["speech_style"]]
	if customer.has("company"):
		text += " With other customers: %s." % Rules.COMPANY_TEXT.get(customer["company"], "")
	if customer.has("appearance"):
		text += " What anyone can see: %s" % Rules.as_sentence(str(customer["appearance"]))
	text += " (Nobody else knows their name, age, job or why they're here unless they've said it in the conversation: only what they can see.)"
	return text


## What the owner and customer know about each other: only what the game has tracked. A
## regular's facts are in customer["regular"] (see Regulars and the visit scene).
static func describe_relationship(owner: Dictionary, customer: Dictionary) -> String:
	var known: Dictionary = customer.get("regular", {})
	if not known.is_empty():
		return describe_regular(owner, customer, known)
	return "WHO KNOWS WHOM: this is %s's first visit. The owner has never met them and doesn't know their name unless they say it in the conversation. They aren't a regular, so nobody asks for \"the usual\" or acts like old friends. %s knows the owner only as \"%s\"." % [
		customer["name"], customer["name"], owner["title"]]


## The transcript holds two kinds of entry: things said ({"speaker", "text"}) and things
## that happen ({"action"}, e.g. the owner serving the order), shown as stage directions.
static func transcript_text(transcript: Array) -> String:
	if transcript.is_empty():
		return "(nothing yet)"
	var lines := PackedStringArray()
	for entry in transcript:
		lines.append(transcript_entry(entry))
	return "\n".join(lines)


static func transcript_entry(entry: Dictionary) -> String:
	if entry.has("action"):
		return "(%s)" % entry["action"]
	return "%s: \"%s\"" % [entry["speaker"], entry["text"]]


## Repeats the most recent moment at the end of a dialogue prompt, where small models pay
## most attention: the last thing said, plus anything that happened after it.
static func what_just_happened(transcript: Array) -> String:
	if transcript.is_empty():
		return "WHAT JUST HAPPENED: nothing yet. This is the first line of the conversation."
	var last_said := -1
	for i in range(transcript.size() - 1, -1, -1):
		if not transcript[i].has("action"):
			last_said = i
			break
	var parts := PackedStringArray()
	if last_said >= 0:
		var entry: Dictionary = transcript[last_said]
		parts.append("%s just said: \"%s\"" % [entry["speaker"], entry["text"]])
	for i in range(last_said + 1, transcript.size()):
		parts.append("Then: %s" % transcript_entry(transcript[i]))
	return "WHAT JUST HAPPENED: %s\nReply directly to that, and stay consistent with it (for example, don't ask whether they'll eat when food is already on the table)." % " ".join(parts)


## A regular, as the game knows them: their visits, how long they've been coming, their
## usual, whose names are known, and what each knows about the other.
static func describe_regular(owner: Dictionary, customer: Dictionary, known: Dictionary) -> String:
	var who := str(customer["name"])
	var visits := int(known.get("visits", 1))
	var text := "WHO KNOWS WHOM: %s is a regular here (%s)" % [who, Regulars.closeness_word(known).to_lower()]
	if str(known.get("since", "")) != "":
		text += ": they've been coming %s, %s." % [known["since"], known.get("habit", "now and then")]
	else:
		text += ": this is their %s visit" % Regulars.ordinal(visits + 1)
		if known.has("nights_ago"):
			text += ", and they were last in %s" % Regulars.nights_ago_text(int(known["nights_ago"]))
		text += "."
	if str(known.get("history", "")) != "":
		text += " " + Rules.as_sentence(str(known["history"]))
	if str(known.get("role", "")) != "":
		text += " In the tent, they're %s." % Regulars.ROLES.get(known["role"], known["role"])
	if bool(known.get("owner_knows_name", false)):
		text += " The owner knows their name, %s." % who
	else:
		text += " The owner knows their face but not their name (unless they say it)."
	if bool(known.get("knows_owner_name", false)):
		text += " They know the owner as \"%s\", and by name, %s." % [owner["title"], owner["name"]]
	else:
		text += " They know the owner only as \"%s\"." % owner["title"]
	if str(known.get("owner_knows", "")) != "":
		text += " What the owner knows about them: %s" % Rules.as_sentence(str(known["owner_knows"]))
	if str(known.get("knows_of_owner", "")) != "":
		text += " What they know about the owner: %s" % Rules.as_sentence(str(known["knows_of_owner"]))
	var remembered: Array = known.get("memories", [])
	if str(known.get("impression", "")) != "":
		text += " The owner's overall impression of them: %s" % Rules.as_sentence(str(known["impression"]))
	if not remembered.is_empty():
		text += " What the owner remembers from their last visits (oldest first): %s" % " / ".join(PackedStringArray(remembered.map(func(m): return str(m["owner"]))))
		text += " What they remember about the owner: %s" % " / ".join(PackedStringArray(remembered.map(func(m): return str(m["them"]))))
	var facts: Dictionary = known.get("facts", {})
	var stuck := PackedStringArray()
	for key in Rules.STICKING:
		if str(facts.get(key, "")) != "":
			stuck.append("%s: %s" % [{"job": "job", "family": "family", "home": "from", "other": "and"}[key], facts[key]])
	if not stuck.is_empty():
		text += " Things the owner knows about them: %s." % "; ".join(stuck)
	var usual: Array = known.get("usual", [])
	if not usual.is_empty():
		text += " Their usual is %s: they might just ask for \"the usual\"." % Rules.item_names(usual)
	else:
		text += " They don't have a usual yet, so nobody mentions \"the usual\"."
	text += " They talk like people who've met before, but only about what's above: nothing else has been said between them."
	return text


## Messages asking the AI to invent one of a new bar's two founding regulars: someone who's
## been coming for years. The game has decided their gender, look, role, how long and how
## often, and their usual; the AI invents who they are.
static func founding_regular_messages(owner: Dictionary, bar_name: String, gender: String, look: Dictionary, role: String, since: String, habit: String, usual: Array, taken: Array) -> Array:
	var band: Array = Rules.AGE_RANGES[look["age_range"]]
	var request := """%s

The tent is %s. One of its regulars has been coming %s, %s. They're %s, %s. In the tent, they're %s. Their usual is %s.

Invent them. Their name must be different from these: %s.

Reply with ONLY a JSON object with exactly these keys:
- "name": their Korean name in English letters, family name first, then the given name
- "hangul": the same name in Korean letters (Hangul)
- "age": a whole number from %d to %d
- "job": their job, or what they do
- "speech_style": how they talk, in a few words
- "appearance": what they look like at the counter, in one sentence: keep to how they look, in your own words
- "history": how they first started coming, and what the tent means to them, in one sentence
- "owner_knows": what the owner knows about them after all these years, in one sentence
- "knows_of_owner": what they know about the owner, in one sentence (never the owner's secret itself)""" % [
		describe_owner(owner), bar_name, since, habit, gender_phrase(gender), Rules.look_text(look),
		Regulars.ROLES.get(role, role), Rules.item_names(usual), ", ".join(PackedStringArray(taken)),
		maxi(19, int(band[0])), int(band[1])]
	return [
		{"role": "system", "content": STYLE_GUIDE},
		{"role": "user", "content": request},
	]


## Messages asking the AI what brings a regular in tonight: just a mood and a reason, since
## the game already knows who they are.
static func regular_tonight_messages(day: String, time_text: String, weather: String, customer: Dictionary) -> Array:
	var request := """It's %s, %s, with %s. A regular has just ducked under the tarp: %s (%s), %s, %s. Talks: %s.

What sort of night are they having, and what brings them in tonight?

Reply with ONLY a JSON object with exactly these keys:
- "mood": a few words
- "reason": why they're here tonight, in one sentence""" % [day, time_text, weather, customer["name"], gender_phrase(str(customer.get("gender", ""))),
		customer.get("age", ""), customer.get("job", ""), customer.get("speech_style", "")]
	return [
		{"role": "system", "content": STYLE_GUIDE},
		{"role": "user", "content": request},
	]


## Messages asking the AI what the owner and a customer would each take away from tonight's
## visit, the few things about the customer that would stick, and how the night went for
## them. transcript: their conversation with the owner; chat: their lines at the counter
## with other customers ({"speaker", "text"}).
static func memory_messages(owner: Dictionary, customer: Dictionary, transcript: Array, chat: Array) -> Array:
	var sticking := PackedStringArray()
	for key in Rules.STICKING:
		sticking.append("- \"%s\": %s, if they said it tonight; otherwise \"\"" % [key, Rules.STICKING[key]])
	var request := """%s

%s

Tonight's visit has just ended. Their conversation with the owner:
%s

What they said chatting with other customers at the counter:
%s

People remember a night at a bar roughly: the gist, a detail or two, how it felt. Not every word.

Reply with ONLY a JSON object with exactly these keys:
- "owner_remembers": what the owner would remember about them from tonight, in a sentence or two
- "they_remember": what they'd remember about the owner and the night, in a sentence or two
%s
- "night": how the night went for them: one of "loved it" (they opened up, laughed, or felt looked after), "enjoyed it" (an ordinary good night: a proper chat, good food: most visits with a real conversation), "it was fine" (nothing much happened: hardly a word with anyone), "didn't enjoy it" (rare: they were ignored, kept waiting, or upset)
- "towards_owner": how they feel about the owner now, compared with before tonight: one of "warmer", "the same", "cooler"

Only what was actually said or happened tonight: nothing invented.""" % [
		describe_owner(owner), describe_customer(customer), transcript_text(transcript),
		transcript_text(chat) if not chat.is_empty() else "(they didn't chat with anyone)", "\n".join(sticking)]
	return [
		{"role": "system", "content": STYLE_GUIDE},
		{"role": "user", "content": request},
	]


## Where someone stands at this tent, for a chat prompt: a first-timer, a regular, or someone
## who's been coming for years (and how well they know the owner).
static func standing(person: Dictionary, owner: Dictionary) -> String:
	var known: Dictionary = person.get("regular", {})
	if known.is_empty():
		return "It's their first time at this tent: they don't know the owner, and they've never been before."
	var owner_name := (", and by name, %s" % owner["name"]) if bool(known.get("knows_owner_name", false)) else ""
	if str(known.get("since", "")) != "":
		return "They're a long-time regular (coming %s), and know the owner well, as \"%s\"%s." % [known["since"], owner["title"], owner_name]
	return "They're a regular here (this is their %s visit), and know the owner as \"%s\"%s." % [Regulars.ordinal(int(known.get("visits", 1)) + 1), owner["title"], owner_name]
