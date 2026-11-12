extends RefCounted
## Prompt text sent to the local LLM.
## This is creative writing rather than code: CC BY-SA 4.0 (see LICENSE-ASSETS.md).

const STYLE_GUIDE := """You are the writers' room for KTBT (Korean Tent Bar Tropes), a cosy simulation set in a pojangmacha: an orange-tarp street tent bar under a Seoul overpass. Plastic stools, green soju bottles, steam rising off the tteokbokki, a single bulb swinging in the wind.

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

const DIALOGUE_RULES := """You write one line of dialogue at a time for a scene at the tent. Stay in character. Show feelings through what people say and small actions, not by explaining them. Keep it natural: people at a tent bar talk in short, plain sentences."""


## Messages asking the AI to invent the tent's owner.
## The game decides whether the owner is a woman or a man; the AI invents the rest.
static func owner_messages(gender: String) -> Array:
	var request := """Invent the owner of this pojangmacha. The owner is a %s. They've run the tent for years, and every regular knows them. Everything about them (title, archetype, appearance) must fit a %s.

Reply with ONLY a JSON object with exactly these keys:
- "name": their Korean name in English letters, family name first
- "title": what customers call them, a Korean family-style term of address used for a %s
- "age": a whole number
- "archetype": the K-drama type they are, in a few words
- "appearance": what they look like behind the counter, in one sentence
- "personality": two or three traits
- "speech_style": how they talk, in a few words
- "secret": something about their past they rarely talk about, in one sentence""" % [gender, gender, gender]
	return [
		{"role": "system", "content": STYLE_GUIDE},
		{"role": "user", "content": request},
	]


## Messages asking the AI to invent one customer for the given moment.
## The game picks day, time and weather; the AI only invents the person.
## include_opening_line: stage 1 shows an opening line on the profile card. In a visit,
## the customer's first words come with their order instead, so the two always match.
static func customer_messages(day: String, time_text: String, weather: String, include_opening_line: bool = true) -> Array:
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
static func order_messages(owner: Dictionary, customer: Dictionary, moment: Dictionary, menu_text: String, transcript: Array) -> Array:
	var request := """%s

%s

%s

What's been said so far:
%s

TONIGHT'S MENU (use these exact ids):
%s

What does %s order? Think about who they are and why they're here tonight. Order between 1 and 4 items. Repeat an id to order more than one of something.

They've just sat down and haven't said anything yet. Their line is the very first thing they say: greet the owner in their own way (using what they call the owner) and ask for their order, in their own voice. The line must match "items" exactly: don't mention any food or drink that isn't in "items", and don't say things like "one of everything".

Reply with ONLY a JSON object with exactly these keys:
- "items": an array of menu ids
- "line": what they say as they sit down and order: one or two short sentences""" % [
		describe_moment(moment), describe_owner(owner), describe_customer(customer),
		transcript_text(transcript), menu_text, customer["name"]]
	return [
		{"role": "system", "content": STYLE_GUIDE},
		{"role": "user", "content": request},
	]


## Messages asking the AI for the next line of the conversation.
## direction is an optional hint from the game about where the scene is (e.g. "they're about to leave").
static func dialogue_messages(owner: Dictionary, customer: Dictionary, moment: Dictionary, served: String, transcript: Array, owner_speaks: bool, direction: String) -> Array:
	var speaker := str(owner["name"]) if owner_speaks else str(customer["name"])
	var role := "the owner" if owner_speaks else "the customer"
	var request := """%s

%s

%s

On the table: %s

The conversation so far:
%s

Write the next line, spoken by %s (%s). %s
One to three sentences. Speak only as %s: don't write the other person's reply or any narration.

Reply with ONLY a JSON object with one key:
- "line": what %s says""" % [
		describe_moment(moment), describe_owner(owner), describe_customer(customer), served,
		transcript_text(transcript), speaker, role, direction, speaker, speaker]
	return [
		{"role": "system", "content": STYLE_GUIDE + "\n\n" + DIALOGUE_RULES},
		{"role": "user", "content": request},
	]


static func describe_moment(moment: Dictionary) -> String:
	return "TONIGHT: %s, %s, with %s." % [moment["day"], moment["time"], moment["weather"]]


static func describe_owner(owner: Dictionary) -> String:
	return "THE OWNER: %s, a %s-year-old %s, whom customers call \"%s\". %s. %s Personality: %s. Talks: %s. A secret they rarely share, and only ever hint at: %s" % [
		owner["name"], owner["age"], owner.get("gender", "person"), owner["title"], owner["archetype"], owner["appearance"],
		owner["personality"], owner["speech_style"], owner["secret"]]


static func describe_customer(customer: Dictionary) -> String:
	return "THE CUSTOMER: %s, %s, %s. Mood: %s. Why they're here tonight: %s Talks: %s." % [
		customer["name"], customer["age"], customer["job"], customer["mood"],
		customer["reason"], customer["speech_style"]]


static func transcript_text(transcript: Array) -> String:
	if transcript.is_empty():
		return "(nothing yet)"
	var lines := PackedStringArray()
	for entry in transcript:
		lines.append("%s: \"%s\"" % [entry["speaker"], entry["text"]])
	return "\n".join(lines)
