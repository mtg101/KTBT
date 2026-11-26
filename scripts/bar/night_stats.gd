extends RefCounted
## Debug stats for one night, for testing and tuning: who came, how much talking there was
## (owner and customer chats), how long people waited, and how the AI did. The visit scene
## counts things as they happen; this shows them in the stats panel and, when the night
## ends (or the bar's closed partway through), writes them to a log file in stats/ in the
## user data folder, one per night, to compare runs.

const Text = preload("res://scripts/rules/text.gd")
const Talk = preload("res://scripts/rules/talk.gd")
const Glossary = preload("res://scripts/rules/glossary.gd")
const NightRules = preload("res://scripts/rules/night_rules.gd")
const Menu = preload("res://scripts/rules/menu.gd")
const Captions = preload("res://scripts/rules/captions.gd")

## Where the logs go: "" for the default (the project's logs/stats/ when playing from the
## editor, beside the transcripts, so a night's log can be read and checked; otherwise stats/
## in the user data folder). Tests point this at their own folder.
static var folder := ""


static func logs_folder() -> String:
	if folder != "":
		return folder
	return "res://logs/stats/" if OS.has_feature("editor") else "user://stats/"

## Every night event, counted by kind (so a new kind of event is always counted, even
## before it has a stat of its own).
var event_counts := {}

# People
var who := {}  # gender ("woman", "man", "non-binary") -> how many came in
var ages := {}  # age range ("20s"...) -> how many
var company_mix := {}  # mood for company ("chatty", "quiet", "owner") -> how many
var tipsy := 0  # customers who had enough to sway
## The night as a story: how it opened (how long the loading screen took, the recap's style
## and who wrote it: "ai" or "game") and the diary (its stamp, and who wrote it).
var story := {}
## The art: which of the game's pieces were drawn from images, which in code, and which images
## wouldn't load (Art.summary(): {"images", "drawn", "broken"}, each a list of keys).
var art := {}
var gestures := {}  # gestures, by kind: customers' "drink" (a glass raised), "eat" (mouthfuls) (visit.gd _gestures); the owner's "pour", "carry", "cook", "wave"
var card_turns := 0  # someone a card had just happened to, turned to first (before a greeting or a chat)
var worn_let_through := 0  # lines let through with a worn-out phrase, rather than a chat given up
var poses := 0  # big moments shown in someone's pose (people_view.gd pose)
## Portraits in people's hovers (visit.gd _give_portrait): "own" (a face made for them, kept with the
## bar: ai/portrait_maker.gd), "matched" (the library's for their look), "fallback" (the
## nearest the library had), "none" (no portrait), one each per person; "seen": hovers opened with one;
## the cat's: "cat_face" (its coat's portrait) or "cat_none", and "cat_seen" (its hover opened with it).
var portraits := {}
## Faces on the captions (captions_on_screen.gd, ui/face_sticker.gd): "beside" (slapped onto a
## caption over the stage) and "zoom" (the caption and its face over the whole window); their
## faces, "mood" (the caption's own face), "calm" (the plain one, asked for), "stood_in" (the
## plain one, the mood's face missing), "cat" (the cat's one face); "none": a caption that wanted a face and had nobody's.
var stings := {}
## The edit's clipart stuck to people on stage (rules/clipart.gd, ui/clipart_sticker.gd): each
## clipart -> how many captions it went on; "missing": one picked whose art wasn't there.
var clipart := {}
## 3am's keepsakes (rules/keepsakes.gd): "end_card" (whose moment, its mood and size, if one
## went up), "end_card_faceless" (a moment, but no face for it), "polaroids" (on the diary
## page), "faces_kept" (everyone's portrait kept with the entry).
var keepsakes := {}
## 3am's posts (rules/socials.gd, visit.gd _post_socials): "posts" (up round the diary page),
## "pictures" (real snapshots kept with them), "drawn" (a picture that wasn't taken, drawn),
## "text" (words alone), "dropped" (failing the check), "picked", "words_ai" / "words_game" (whose
## words: the AI's, or the game's own), "ai_turned_down" (the AI's words for a post failing the
## check, so the game's instead), "tags_from_words" (the AI's posts with hashtags in their words,
## taken out: Socials.validate_reply), "viewer_comments" (the viewers' comments shown: rules/viewers.gd,
## visit.gd _viewers_comment), "viewer_words_ai" / "viewer_words_game", "viewer_ai_turned_down",
## "viewer_dropped" (failing the check, not shown), "snapshots" (bar/snapshots.gd counts: asked, taken, failed, over, no_screen).
var socials := {}
## The ratings so far tonight (Ratings.score, before the luck: that's only known at 3am), kept
## up to date as things happen, and the last nights' ratings, for the panel's RATINGS section.
var ratings_so_far := {}
## The autopilot PD's night, in an autoplay batch (Autopilot.counts): {} when a player's at the desk.
var autopilot := {}
## The crew running it (autoplay: visit.gd, "Let the crew run it"), tonight: {"from" (the menu or
## the command line), "nights", "night" ("night 3 of 10"), "took_over" (a time, if they took over
## part-way through), "stopped" (how, if they were), "handed_back" (when)}; {} when they weren't.
var crew_run := {}
## The transcript's toolbar tonight (transcript_view.gd): {"searches", "jumps", "talk", "events",
## "all" (the filter picked, each time), "catch_ups", "caught" (lines caught up on), "size" and
## "compact" (as it is: set as the night opens, then as it's changed)}.
var transcript_use := {}
var esc_menu := 0  # times the Esc menu was opened tonight
var quit_asked := {}  # quitting with the bar open (the window's ✕ or the menu's Quit game): "asked" and the answer ("close_up_first", "quit_now", "kept_playing") -> times
var ratings_before: Array = []
var arrived := 0
var served := 0  # paid and left
var walked_past := 0  # gave up waiting for a stool
var closing_up := {}  # closing up early: "seated" (at the counter when Close the bar was pressed), "seconds" (real seconds until the tent was empty)
var peak_seated := 0
var prepared := 0  # new customers invented ahead, while the owner was free
var prepared_used := 0  # ...who came in
var prepared_stale := 0  # ...thrown away: too long waiting (another hour), or their name was taken by then
var quick_greetings := 0
var proper_greetings := 0
var greet_waits: Array = []  # game minutes from arriving to the owner coming to greet them
var serve_waits: Array = []  # game minutes from arriving to their first drinks on the table (AI thinking included)
var owner_lines_each: Array = []  # for each customer who paid: lines in their chat with the owner

# Talk
var owner_lines := 0  # lines in owner–customer conversations (either of them speaking)
var chat_lines := 0  # lines in customer chats (owner joining in included)
var chats_started := 0
var chats_drawn_in := 0  # ...of them, a quiet customer drawn in by a chatty one (CounterChats.reserved)
var phrases := {}  # three-word turns of phrase said tonight -> how many lines (Text.phrases_in)
var _known_words := {}  # every word of the Korean the game knows (the menu among it): never part of a turn of phrase
const WORN_OUT := 3  # said in this many lines, a phrase is worn out: the next lines are asked to say it another way
var topics := {}  # what the game steered talk to: "owner: food", "chat: food_fight" -> how many spells
var owner_joins := 0
var customer_joins := 0
var free_turns := 0  # times the owner's voice was free (nobody to greet or settle up with)
var chat_chances := 0  # times a customer chat could have started (or carried on) when the owner was free
var chats_continued := 0  # spells that carried on a chat already going
var hints_given := {}  # hint kind (Talk.moment_kind: a menu id, "food", "pour"...) -> times given
var hints_taken := {}  # ...and how many of those lines seemed to take it up (rough: Talk.hint_taken)
var korean_words := {}  # word (Glossary: "Imo", "Soju", "Aigoo"...) -> times said
## How lines start, by what they are ("order": first orders; "owner": the owner's first proper
## word with someone) -> their first two words -> how many. To see how samey they are.
var openings := {"order": {}, "owner": {}}
var order_situations := 0  # first orders given a situation (Talk.order_moment and/or a craving)
var opener_situations := 0  # the owner's first proper words given a situation (Talk.opener_moment)
var sides_added := 0  # sides an order line asked for that the AI left out, added (Orders.add_mentioned_sides)
var unsaid_dropped := 0  # things in an order the line never asked for, taken off (Orders.drop_unsaid)
var menu_opened := 0  # times the menu board was clicked open
var rituals := {}  # drinking rituals seen: tornado, kya, turned_away (and table games, as events)
## Out in the street and coming in: who walked by (alone, in twos, in threes), on phones,
## under which umbrellas, sharing one, running for it; customers under umbrellas or running in.
var street := {}
var cravings := 0  # ...of which with a craving (Talk.craving)
var specials: Array = []  # tonight's specials (menu ids)
var sold_out: Array = []  # what's run out tonight (menu ids)

# Regulars
var regular_pulls := {}  # name -> pull, for everyone on the books
var founding_regulars := 0
var regulars_in := 0  # regulars who came in (and paid) tonight
var became_regulars := 0
var faded_regulars := 0
var verdicts := {}  # how each visit went (the AI's verdict, or the game's if it couldn't)
var memories_failed := 0
var threads := {}  # something coming up a regular mentioned: "opened", "asked", "closed", "dropped" (and "between": mentioned to another regular) -> times
var who_you_know := 0  # lines given who the speaker knows here (from their side) or what they've said about themselves
var pair_memories := {}
var closeness := {}
var groups := {}  # customers coming in together: kind (couple, colleagues...) -> pairs; "paid_" + how they paid -> pairs  # closeness paying off: "sat_by_a_friend", "waved_over", "saved_for_them", "together" -> times  # regulars remembering each other at closing: "saved", "failed" -> pairs
var facts_learned := {}  # a thing that sticks learned or changed (job, family...) -> times
var facts_heard := {}  # who heard them said: "the owner", "in a chat", "only them" -> times
var bonds := {}  # the bar's bonds by how close (bonds.gd LEVELS) -> how many, at the night's end
var friendlier_moments := 0  # two regulars on "eonni" (or oppa, hyung, nuna) terms

# TV captions
var captions := {}  # kind -> how many shown tonight
var captions_held_back := 0  # ones that would have come too soon after another
var reactions_asked := 0  # times the AI was asked "was that a big moment?"
var reactions_shown := {}  # mood -> how many shown
var moments_from := {}  # "light", "deep" or "other" talk (its topic: Talk.LIGHT_TOPICS) -> the AI's mood for each big moment it made -> how many
var reactions_none := 0  # ...answered "nothing special"
var reaction_sizes := {}  # ...how big the AI called each moment ("1" to "5"), to tune the bar for a caption
var reactions_dropped := 0  # ...answered with something that failed the checks
var reactions_put_off := 0  # ...put off, because someone was waiting for the owner (asked once she's free)
var reactions_skipped := 0  # ...of those, never asked: too late by then, or a newer one came along

# Food
var ordered := {}  # menu id -> how many ordered
var first_orders := 0
var extra_orders := 0  # orders after the first
var dishes_cooked := 0
var food_waits: Array = []  # game minutes from ordering a cooked dish to it reaching the table

# The AI
var ai_calls := 0
var ai_seconds: Array = []  # real seconds per call, retries included
var rejected := 0
var rejections := {}  # kind of problem -> how many times
## kind of problem -> the different reasons given, with what was being asked for and how
## often ("order: there's no food... (x3)"), for tuning prompts. Only in the log.
var rejection_reasons := {}
const REASONS_PER_KIND := 10
## A few of the rejected replies themselves, for each kind of problem: {kind: [{"for", "problem",
## "reply"}]}, so the logs show what the AI wrote, not just why it was turned down.
var rejected_replies := {}
const REPLIES_PER_KIND := 3
const REPLY_MOST := 600
var events: Array = []  # tonight's events (NightEvents.timeline), for the log
var pins_made := 0  # lines the PD pinned for the episode tonight...
var pins_dropped := 0  # ...a fourth dropping the oldest
var pinned: Array = []  # ...and the ones kept at the end: {"speaker", "text"}
var edits_offered := 0  # big moments the PD could edit
var edits_made := {}  # "the AI's mood→the PD's" -> how many
var edit_log: Array = []  # each edit offered: {"spins": [{"mood", "caption"}], "aired": the spin that went out (0: the AI's)}, for the log
var written: Array = []  # the PD's write-in cards: {"card", "text", "who", "what", "lines" (the replies, for the log)}
var written_tells := {}  # card -> the words that show a line took up what the PD wrote
var written_refused := 0  # write-ins the checks sent back
const WRITTEN_LINES := 4  # replies kept for each, for the log
var plant_watch := {}  # plant cards played: how many more lines (anyone's) to watch for it coming up
var plant_watch_for := {}  # ...a card played for someone: watched for as long as they're here (card -> their name)
var plant_mentions := {}  # ... and how many of them did (card: count)
const PLANT_WATCH_LINES := 12
var camera_lines := 0  # lines said tonight (the owner's conversations and the chats)...
var camera_lines_on := 0  # ...and how many of them with whoever the PD's camera was following
var gave_up_by := {}  # what the AI was being asked for -> how many times it gave up
var calls_by := {}  # what the AI was being asked for -> how many times (the bar opening's too: menu, signatures, recap)
var gave_up := 0  # calls that never got a usable reply
var stale_redone := 0  # lines asked for again because things changed while the AI wrote them

# Time (real seconds)
var real_seconds := 0.0
var seated_seconds := 0.0  # people at the counter, added up over time (for the average)
var together_seconds := 0.0  # time with two or more at the counter (so they could chat)
var owner_trips := {}  # why the owner went over to someone's stool -> times (pour, serve, carry, settle, moment, talk)
var owner_stove_seconds := 0.0  # real seconds at the stove...
var owner_front_seconds := 0.0  # ...and out along the counter
var from_the_stove := 0  # times a customer was told the owner's talking to them from the stove
var voice_busy_seconds := 0.0  # the owner's voice was busy (an AI conversation task)
var waiting_on_voice_seconds := 0.0  # ...while someone was waiting for it (to be greeted, or to pay)


## One AI call: how long it took, what was wrong with any replies it rejected, and whether
## it got a usable reply in the end.
## purpose: what was being asked for ("order", "line"...).
## Counts a night event (see night_events.gd: this listens to them). The events themselves
## are kept too (events: the night's NightEvents.timeline), and saved in the night's log.
func record_event(kind: String, facts: Dictionary, _about: Variant = null, _spot: Vector2 = Vector2.ZERO) -> void:
	event_counts[kind] = int(event_counts.get(kind, 0)) + 1
	match kind:
		"plant_played":
			var card := str(facts.get("card", ""))
			plant_watch[card] = PLANT_WATCH_LINES
			plant_watch_for.erase(card)
			if str(facts.get("name", "")) != "":
				plant_watch_for[card] = str(facts["name"])
		"left":
			for card in plant_watch_for.keys():
				if plant_watch_for[card] == str(facts.get("name", "")):
					plant_watch_for.erase(card)
					if int(plant_watch.get(card, 0)) <= 0:
						plant_watch.erase(card)
		"ordered":
			if bool(facts.get("first", false)):
				first_orders += 1
			else:
				extra_orders += 1
			for id in facts.get("items", []):
				ordered[str(id)] = int(ordered.get(str(id), 0)) + 1
		"arrived":
			arrived += 1
		"walked_on":
			walked_past += 1
		"sat_down":
			peak_seated = maxi(peak_seated, int(facts.get("seated", 0)))
			for pair in [[who, "gender"], [ages, "age_range"], [company_mix, "company"]]:
				var value := str(facts.get(pair[1], ""))
				if value != "":
					pair[0][value] = int(pair[0].get(value, 0)) + 1
		"greeted":
			if bool(facts.get("quick", false)):
				quick_greetings += 1
			else:
				proper_greetings += 1
		"dish_served":
			dishes_cooked += 1
			food_waits.append(float(facts.get("wait", 0.0)))
		"paid":
			served += 1
		"chat_started":
			chats_started += 1
			if bool(facts.get("drawn_in", false)):
				chats_drawn_in += 1
		"chat_continued":
			chats_continued += 1
		"joined_chat":
			customer_joins += 1
		"owner_joined":
			owner_joins += 1
		"became_regular":
			became_regulars += 1
		"friendlier":
			friendlier_moments += 1
		"big_moment":
			var mood := str(facts.get("mood", ""))
			reactions_shown[mood] = int(reactions_shown.get(mood, 0)) + 1
			var talk := "light" if str(facts.get("topic", "")) in Talk.LIGHT_TOPICS else ("deep" if str(facts.get("topic", "")) in Talk.DEEP_TOPICS else "other")
			var by_mood: Dictionary = moments_from.get(talk, {})
			by_mood[str(facts.get("ai_mood", mood))] = int(by_mood.get(str(facts.get("ai_mood", mood)), 0)) + 1
			moments_from[talk] = by_mood


## A line said with a hint in its direction (see Talk.moment_kind): counted, and whether
## the line seems to have taken it up (returned: whether it did).
func record_hint(kind: String, line: String, extra_tells: Array = []) -> bool:
	if kind == "":
		return false
	extra_tells = extra_tells + written_tells.get(kind.trim_prefix("plant_"), [])
	hints_given[kind] = int(hints_given.get(kind, 0)) + 1
	if Talk.hint_taken(kind, line, extra_tells) or kind == "plant_interview":  # (an interview's next line is the answer, to camera: taken up by being said)
		hints_taken[kind] = int(hints_taken.get(kind, 0)) + 1
		return true
	return false


## A line of this kind ("order" or "owner"): counts how it starts (its first two words).
func record_opening(kind: String, line: String) -> void:
	var start := " ".join(PackedStringArray(RegEx.create_from_string("[a-z']+").search_all(line.to_lower()).slice(0, 2).map(func(m): return m.get_string())))
	if start == "":
		return
	var counts: Dictionary = openings.get(kind, {})
	counts[start] = int(counts.get(start, 0)) + 1
	openings[kind] = counts


## The commonest opening of this kind, out of all of them: "\"ajumma i'll\" 12 of 19".
func opening_text(kind: String) -> String:
	var counts: Dictionary = openings.get(kind, {})
	if counts.is_empty():
		return "(none yet)"
	var total := 0
	var top := ""
	for start in counts:
		total += int(counts[start])
		if top == "" or int(counts[start]) > int(counts[top]):
			top = start
	return "\"%s\" %d of %d" % [top, int(counts[top]), total]


## Something seen in the street (or someone coming in out of the weather): see street.
func record_street(what: String) -> void:
	street[what] = int(street.get(what, 0)) + 1


## A line said (by anyone): counts its Korean words. names: people's names, which don't count.
func record_line(line: String, names: Array = []) -> void:
	for word in Glossary.words_in(line, names):
		korean_words[word] = int(korean_words.get(word, 0)) + 1
	for phrase in Text.phrases_in(line, _not_phrases(names)):
		phrases[phrase] = int(phrases.get(phrase, 0)) + 1
	# A plant card just played: does it come up, in anyone's lines (the owner's too), soon after?
	for card in plant_watch.keys():
		if Talk.hint_taken("plant_" + str(card), line, written_tells.get(card, [])):
			plant_mentions[card] = int(plant_mentions.get(card, 0)) + 1
		plant_watch[card] = int(plant_watch[card]) - 1
		if int(plant_watch[card]) <= 0 and not plant_watch_for.has(card):
			plant_watch.erase(card)


## Words that are never part of a turn of phrase: the Korean the game knows (the menu among
## it), what people call the dishes ("a bowl of rice" is an order, not a cliché), and names.
func _not_phrases(names: Array) -> Dictionary:
	if _known_words.is_empty():
		for spelling in Glossary.lookup():
			for part in Text.words(str(spelling)):
				_known_words[part] = true
		for item in Menu.items():
			for called in [str(item["name"])] + Array(item.get("aliases", [])):
				for part in Text.words(str(called)):
					_known_words[part] = true
	var skip := _known_words.duplicate()
	for person in names:
		for part in Text.words(str(person)):
			skip[part] = true
	return skip


## A worn-out phrase (said in WORN_OUT lines already tonight) that a line would say again, or "".
## (The note asking for another way was ignored now and then: night 28's "a long night", ×4.)
func worn_out_in(line: String, names: Array = []) -> String:
	for phrase in Text.phrases_in(line, _not_phrases(names)):
		if int(phrases.get(phrase, 0)) >= WORN_OUT:
			return str(phrase)
	return ""


## The phrases said in WORN_OUT lines or more tonight, most first (at most most).
func worn_out(most: int = 5) -> Array:
	var keys := phrases.keys().filter(func(k): return int(phrases[k]) >= WORN_OUT)
	keys.sort_custom(func(a, b): return int(phrases[a]) > int(phrases[b]) or (int(phrases[a]) == int(phrases[b]) and str(a) < str(b)))
	return keys.slice(0, most)


## "soju 5 · somaek 2", most first. limit: how many (0: all).
static func counts_text(counts: Dictionary, limit: int = 0) -> String:
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return int(counts[a]) > int(counts[b]) or (int(counts[a]) == int(counts[b]) and str(a) < str(b)))
	if limit > 0 and keys.size() > limit:
		keys = keys.slice(0, limit)
	return " · ".join(PackedStringArray(keys.map(func(k): return "%s %d" % [k, int(counts[k])])))


## "somaek 1/2 · pour 0/1 · food ×3": hints taken up out of given. A kind with no tell-tale
## words to look for (Talk.HINT_TELLS) can't be judged, so it just says how many were given.
## The hints given and taken up. tropes: only the pocha's own (table games, double-takes: see
## POCHA LIFE on the panel), or (false) everything else.
func hints_text(tropes := false) -> String:
	var keys := hints_given.keys().filter(func(k): return _is_trope(str(k)) == tropes)
	keys.sort()
	return " · ".join(PackedStringArray(keys.map(func(k): return ("%s %d/%d" % [k, int(hints_taken.get(k, 0)), int(hints_given[k])]) if Talk.HINT_TELLS.has(k) else ("%s ×%d" % [k, int(hints_given[k])]))))


static func _is_trope(kind: String) -> bool:
	return kind.begins_with("game_") or kind.begins_with("plant_") or kind == "stunned" or kind == "camera"  # (in their own sections)


## A write-in card played: what the PD wrote, and who for (the replies come in record_written_line).
func record_written(card: String, text: String, for_who: String, what: String, tells: Array) -> void:
	written.append({"card": card, "text": text, "who": for_who, "what": what, "lines": []})
	written_tells[card] = tells


## A line said (speaker: who; among: everyone in that conversation): kept for any write-in
## that's about one of them, until it has its replies.
func record_written_line(speaker: String, among: Array, line: String) -> void:
	for entry in written:
		if (entry["lines"] as Array).size() < WRITTEN_LINES and among.has(entry["who"]):
			entry["lines"].append("%s: %s" % [speaker, line])


## A line of the owner's conversations or the chats: whether it was on camera (the person the
## PD's camera was following was in it).
## A spell of talk steered to a topic (Talk.pick_owner_topic, pick_chat_topic). chat: customers
## chatting, rather than the owner's conversation.
## Two people coming in together, and what they are to each other.
func record_group(kind: String) -> void:
	groups[kind] = int(groups.get(kind, 0)) + 1


## How a pair who came in together paid: "one_pays", "fight" or "split".
func record_group_bill(how: String) -> void:
	groups["paid_" + how] = int(groups.get("paid_" + how, 0)) + 1


func groups_text() -> String:
	var kinds := " · ".join(PackedStringArray(groups.keys().filter(func(k): return not str(k).begins_with("paid_")).map(func(k): return "%s %d" % [k, int(groups[k])])))
	return "Came in together: %s · paid: one for both %d, a bill fight %d, split %d" % [kinds if kinds != "" else "nobody",
		int(groups.get("paid_one_pays", 0)), int(groups.get("paid_fight", 0)), int(groups.get("paid_split", 0))]


## A thing that sticks learned about a regular (key: job, family...), and who heard it said.
func record_fact(key: String, known_by: Array) -> void:
	facts_learned[key] = int(facts_learned.get(key, 0)) + 1
	var heard := "only them" if known_by.is_empty() else ("the owner" if known_by.has("owner") else "in a chat")
	facts_heard[heard] = int(facts_heard.get(heard, 0)) + 1


## What's remembered: the bonds by how close, facts learned (and who heard them), threads.
func memory_text() -> String:
	var levels := " · ".join(PackedStringArray(["acquaintance", "friendly", "close", "old friend"].filter(func(l): return bonds.has(l)).map(func(l): return "%s %d" % [l, int(bonds[l])])))
	var learned := " · ".join(PackedStringArray(facts_learned.keys().map(func(k): return "%s %d" % [k, int(facts_learned[k])])))
	var heard := " · ".join(PackedStringArray(facts_heard.keys().map(func(k): return "%s %d" % [k, int(facts_heard[k])])))
	return "Bonds: %s · lines told who they know here %d · regulars remembered each other %d%s · facts learned: %s%s · things coming up: opened %d (and %d to another regular), asked about %d, heard how it went %d, dropped %d · contradictions caught %d" % [
		levels if levels != "" else "none", who_you_know, int(pair_memories.get("saved", 0)), (" (failed %d)" % int(pair_memories["failed"])) if pair_memories.has("failed") else "",
		learned if learned != "" else "none", (" (heard by %s)" % heard) if heard != "" else "",
		int(threads.get("opened", 0)), int(threads.get("between", 0)), int(threads.get("asked", 0)), int(threads.get("closed", 0)), int(threads.get("dropped", 0)),
		int(rejections.get("contradicts what they've said", 0))]


## The owner went over to someone's stool, and why.
func record_owner_trip(why: String) -> void:
	owner_trips[why] = int(owner_trips.get(why, 0)) + 1


## Where the owner was: at the stove or out front, and their trips over.
func owner_moves_text() -> String:
	var trips := " · ".join(PackedStringArray(["pour", "serve", "carry", "settle", "moment", "talk"].filter(func(w): return owner_trips.has(w)).map(func(w): return "%s %d" % [w, int(owner_trips[w])])))
	return "The owner: at the stove %d%% · out front %d%% · trips over: %s · talked from the stove %d" % [percent(owner_stove_seconds, owner_stove_seconds + owner_front_seconds),
		percent(owner_front_seconds, owner_stove_seconds + owner_front_seconds), trips if trips != "" else "none", from_the_stove]


## Closing up early: how many were at the counter when Close the bar was pressed...
func record_closing_up(seated: int) -> void:
	closing_up = {"seated": seated}


## ...and how long (real seconds) until the tent was empty and the night ended.
func record_closed_up(seconds: float) -> void:
	closing_up["seconds"] = seconds


## The closing-up line for the panel: "" if the bar wasn't closed early.
func closing_up_text() -> String:
	if closing_up.is_empty():
		return ""
	var empty := "empty after %ds" % roundi(float(closing_up["seconds"])) if closing_up.has("seconds") else "still finishing up"
	return "Closed early: %d still in, %s" % [int(closing_up.get("seated", 0)), empty]


## The Esc menu opened.
func record_esc_menu() -> void:
	esc_menu += 1


## Quitting with the bar open: "asked" (the dialog came up), then what was chosen.
func record_quit(what: String) -> void:
	quit_asked[what] = int(quit_asked.get(what, 0)) + 1


## The menu's line for the panel: how often it was opened, and quitting asked about (if it was).
func esc_menu_text() -> String:
	var quit := ""
	if not quit_asked.is_empty():
		quit = " · quitting with the bar open: asked %d (closed up first %d, quit now %d, kept playing %d)" % [int(quit_asked.get("asked", 0)),
			int(quit_asked.get("close_up_first", 0)), int(quit_asked.get("quit_now", 0)), int(quit_asked.get("kept_playing", 0))]
	return "Esc menu opened %d%s" % [esc_menu, quit]


## Someone a card had just happened to, turned to first.
func record_card_turn() -> void:
	card_turns += 1


func record_topic(topic: String, chat: bool) -> void:
	if topic == "":
		return
	var key := "%s: %s" % ["chat" if chat else "owner", topic]
	topics[key] = int(topics.get(key, 0)) + 1


## The transcript's toolbar used (transcript_view.gd's used: what, and its detail).
func note_transcript(what: String, detail: String) -> void:
	match what:
		"search":
			transcript_use["searches"] = int(transcript_use.get("searches", 0)) + 1
		"jump":
			transcript_use["jumps"] = int(transcript_use.get("jumps", 0)) + 1
		"filter":
			transcript_use[detail] = int(transcript_use.get(detail, 0)) + 1
		"catch_up":
			transcript_use["catch_ups"] = int(transcript_use.get("catch_ups", 0)) + 1
			transcript_use["caught"] = int(transcript_use.get("caught", 0)) + int(detail)
		"size":
			transcript_use["size"] = int(detail)
		"compact":
			transcript_use["compact"] = detail == "on"


## How many spells were steered somewhere light (teasing, food fights, silly stories), and
## how many to the heavy topics (see Talk.LIGHT_TOPICS): [light, deep].
func topic_mix() -> Array:
	var light := 0
	var deep := 0
	for key in topics:
		var topic := str(key).get_slice(": ", 1)
		if topic in Talk.LIGHT_TOPICS:
			light += int(topics[key])
		elif topic in Talk.DEEP_TOPICS:
			deep += int(topics[key])
	return [light, deep]


func record_camera_line(on: bool) -> void:
	camera_lines += 1
	if on:
		camera_lines_on += 1


## The PD's camera tonight: who it followed, in order, and for how long (game minutes):
## [{"name", "minutes"}], and the noticing moments: [given, taken up].
func camera_follows() -> Array:
	var follows: Array = []
	var current := {}
	for event in events:
		var kind := str(event.get("kind", ""))
		if kind == "camera_on" or kind == "camera_off":
			if not current.is_empty():
				current["minutes"] = int(event.get("at", 0)) - int(current["from"])
				follows.append({"name": current["name"], "minutes": current["minutes"]})
				current = {}
			if kind == "camera_on":
				current = {"name": str(event.get("name", "")), "from": int(event.get("at", 0))}
	if not current.is_empty():
		follows.append({"name": current["name"], "minutes": -1})  # (still on them at the end)
	return follows


## The PD's plant cards tonight: {card: [played, lines given it, lines that took it up, lines
## (anyone's) that brought it up after it was played: the next PLANT_WATCH_LINES, or for a
## card played for someone, as long as they're here]}.
func plants() -> Dictionary:
	var found := {}
	for event in events:
		if str(event.get("kind", "")) == "plant_played":
			var card := str(event.get("card", ""))
			found[card] = [int(found.get(card, [0])[0]) + 1, int(hints_given.get("plant_" + card, 0)), int(hints_taken.get("plant_" + card, 0)),
				int(plant_mentions.get(card, 0))]
	return found


## The table games: {game: [offered, taken up]}, a chat each (a game's in the air for a few
## lines of a chat: the lines are in hints_given/hints_taken).
func table_games() -> Dictionary:
	var games := {}
	for event in events:
		var kind := str(event.get("kind", ""))
		if kind == "table_game_offered" or kind == "table_game":
			var game := str(event.get("game", ""))
			var counts: Array = games.get(game, [0, 0])
			counts[0 if kind == "table_game_offered" else 1] += 1
			games[game] = counts
	return games


func record_ai(seconds: float, problems: Array, ok: bool, purpose: String = "") -> void:
	ai_calls += 1
	ai_seconds.append(seconds)
	var what := purpose if purpose != "" else "other"
	calls_by[what] = int(calls_by.get(what, 0)) + 1
	rejected += problems.size()
	for problem in problems:
		var kind := Text.problem_kind(str(problem))
		rejections[kind] = int(rejections.get(kind, 0)) + 1
		var reasons: Dictionary = rejection_reasons.get(kind, {})
		var reason := "%s: %s" % [purpose, problem] if purpose != "" else str(problem)
		if reasons.has(reason) or reasons.size() < REASONS_PER_KIND:
			reasons[reason] = int(reasons.get(reason, 0)) + 1
		rejection_reasons[kind] = reasons
	if not ok:
		gave_up += 1
		var asked := purpose if purpose != "" else "other"
		gave_up_by[asked] = int(gave_up_by.get(asked, 0)) + 1


## A rejected reply, kept (the first few of each kind, cut short if long) for the logs.
func record_rejected(purpose: String, problem: String, reply: String) -> void:
	var kind := Text.problem_kind(problem)
	var kept: Array = rejected_replies.get(kind, [])
	if kept.size() >= REPLIES_PER_KIND:
		return
	kept.append({"for": purpose if purpose != "" else "other", "problem": problem, "reply": reply.left(REPLY_MOST)})
	rejected_replies[kind] = kept


static func average(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for v in values:
		total += float(v)
	return total / values.size()


static func longest(values: Array) -> float:
	var most := 0.0
	for v in values:
		most = maxf(most, float(v))
	return most


static func shortest(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var least := float(values[0])
	for v in values:
		least = minf(least, float(v))
	return least


static func percent(part: float, whole: float) -> int:
	return roundi(100.0 * part / whole) if whole > 0.0 else 0


## How many were at the counter, on average over the night so far.
func average_seated() -> float:
	return seated_seconds / real_seconds if real_seconds > 0.0 else 0.0


## The rejection kinds, most common first, as "same name 3, food that wasn't ordered 2".
func rejection_text() -> String:
	var kinds := rejections.keys()
	kinds.sort_custom(func(a, b): return rejections[a] > rejections[b])
	var parts := PackedStringArray()
	for kind in kinds:
		parts.append("%s %d" % [kind, rejections[kind]])
	return ", ".join(parts)


## The stats panel's text. seated and cooking are how things stand right now.
func captions_total() -> int:
	var total := 0
	for kind in captions:
		total += int(captions[kind])
	return total


## "full_house 2 · regular_back 3"
func caption_counts() -> String:
	var parts := PackedStringArray()
	for kind in captions:
		parts.append("%s %d" % [kind, int(captions[kind])])
	return " · ".join(parts)


## Tonight's special moments, in order, from the night's timeline: "9:58pm  hwaiting chorus".
## The rare things worth finding in the transcript (by their time): a cliffhanger come true,
## table games, the chorus, big moments, the cat's crimes, new regulars, the first snow...
func highlights() -> Array:
	var found: Array = []
	var full := false
	for i in events.size():
		var event: Dictionary = events[i]
		var kind := str(event.get("kind", ""))
		var what := ""
		match kind:
			"cliffhanger_answered":
				var named := str(event.get("name", ""))
				what = "CLIFFHANGER CAME TRUE (%s%s)" % [event.get("cliffhanger", ""), (", " + named) if named != "" else ""]
			"table_game_offered":
				var taken := false  # (played after this offer, before the next offer of it)
				for later in events.slice(i + 1):
					if str(later.get("game", "")) == str(event.get("game", "")):
						if str(later.get("kind", "")) == "table_game_offered":
							break
						if str(later.get("kind", "")) == "table_game":
							taken = true
							break
				what = "table game offered: %s (%s)" % [event.get("game", ""), "taken up!" if taken else "not taken up"]
			"table_game":
				what = "TABLE GAME: %s" % event.get("game", "")
			"cheered_on":
				what = "hwaiting chorus"
			"first_snow":
				what = "the first snow of winter"
			"cat_stole":
				what = "the cat stole a fish cake (from %s)" % event.get("name", "someone")
			"cat_kept":
				what = "%s couldn't leave: the cat asleep on their lap" % event.get("name", "someone")
			"cat_fed":
				what = "%s slipped the cat some %s" % [event.get("name", "someone"), event.get("dish", "food")]
			"big_moment":
				what = "big moment, %s (%s): \"%s\"" % [event.get("mood", ""), event.get("who", ""), event.get("caption", "")]
			"became_regular":
				what = "a new regular: %s" % event.get("name", "")
			"friendlier":
				what = "%s and %s got friendlier (%s)" % [event.get("a", ""), event.get("b", ""), event.get("term", "")]
			"closed_early":
				what = "closed up early"
			"menu_changed":
				what = "menu change: %s off, %s on" % [event.get("out", ""), event.get("in", "")]
			"camera_on":
				what = "the camera follows %s" % event.get("name", "")
			"plant_played":
				what = "plant: %s%s%s%s" % [event.get("card", ""), (" (%s)" % event["name"]) if str(event.get("name", "")) != "" else "",
					(": %s" % event["what"]) if str(event.get("what", "")) != "" else "", (" «%s»" % event["text"]) if str(event.get("text", "")) != "" else ""]
			"sat_down":
				if not full and int(event.get("seated", 0)) >= NightRules.SEATS:
					full = true
					what = "full house"
		if what != "":
			found.append("%s  %s" % [NightRules.clock_text(int(event.get("at", 0))), what])
	return found


## The bar's signature dishes on tonight's menu, and how many of each were ordered: {name: count}.
func signature_orders() -> Dictionary:
	var found := {}
	for item in Menu.items():
		if bool(item.get("signature", false)):
			found[str(item["name"])] = int(ordered.get(str(item["id"]), 0))
	return found


## The panel's tabs: each section's short name (the panel shows one section at a time).
const TAB_NAMES := {"HIGHLIGHTS": "Highlights", "TONIGHT": "Tonight", "PEOPLE": "People", "TALK": "Talk",
	"POCHA LIFE": "Pocha life", "THE PD": "PD", "REGULARS": "Regulars", "THE STORY": "Story", "RATINGS": "Ratings", "TV CAPTIONS": "TV",
	"FOOD AND THE MENU": "Menu", "AI": "AI", "EVERYTHING THAT HAPPENED": "Everything"}


## The panel's text cut into its sections, in order: [{"title", "tab", "text"}], for the tabs.
## (Highlights' tab shows how many there are: "Highlights 5".)
func sections(seated: int, cooking: int) -> Array:
	var found: Array = []
	for line in panel_text(seated, cooking).split("\n"):
		if line.begins_with("[b]") and line.ends_with("[/b]") and TAB_NAMES.has(line.trim_prefix("[b]").trim_suffix("[/b]")):
			var title := line.trim_prefix("[b]").trim_suffix("[/b]")
			found.append({"title": title, "tab": str(TAB_NAMES[title]), "text": ""})
		elif not found.is_empty():
			found[-1]["text"] += line + "\n"
	for section in found:
		section["text"] = str(section["text"]).strip_edges()
		if section["title"] == "HIGHLIGHTS":
			var count := highlights().size()
			section["tab"] = "Highlights %d" % count if count > 0 else "Highlights"
	return found


## The RATINGS section (시청률): tonight's (final at 3am, or so far), where it comes from, the
## last nights', and how much busier that makes tonight.
func ratings_lines() -> PackedStringArray:
	var lines := PackedStringArray(["[b]RATINGS[/b]"])
	if story.has("ratings_text"):
		lines.append("Tonight: %s%s" % [str(story["ratings_text"]), (" · " + str(story["ratings_banner"])) if story.has("ratings_banner") else ""])
		if story.has("ratings_shown"):  # (in its rung's units: rules/ladder.gd)
			lines.append("Shown as: %s" % story["ratings_shown"])
	elif not ratings_so_far.is_empty():
		lines.append("So far: %.1f%% (%s), before luck: the final rating's at 3am" % [float(ratings_so_far["rating"]), ratings_so_far.get("band", "")])
		for part in ratings_so_far.get("parts", []):
			if not is_zero_approx(float(part[1])):
				lines.append("  %s%.1f %s" % ["+" if float(part[1]) >= 0.0 else "", float(part[1]), part[0]])
	else:
		lines.append("Tonight: at 3am")
	if not ratings_before.is_empty():
		var best := 0.0
		for each in ratings_before:
			best = maxf(best, float(each))
		lines.append("Last nights: %s · best %.1f%%" % [", ".join(PackedStringArray(ratings_before.slice(-5).map(func(r): return "%.1f%%" % float(r)))), best])
	var busier := float(story.get("busier", 1.0))
	lines.append("Tonight %s from the last nights' ratings" % ("as busy as usual" if is_equal_approx(busier, 1.0) else "%d%% %s" % [roundi(absf(busier - 1.0) * 100.0), "busier" if busier > 1.0 else "quieter"]))
	return lines


func panel_text(seated: int, cooking: int) -> String:
	var lines := PackedStringArray()
	lines.append("[b]HIGHLIGHTS[/b]")
	var moments := highlights()
	lines.append_array(PackedStringArray(moments) if not moments.is_empty() else PackedStringArray(["(nothing special yet)"]))
	lines.append("")
	if story.has("date"):
		lines.append("[b]TONIGHT[/b]")
		lines.append("%s, %s · %s" % [story["date"], story.get("season", ""), story.get("weather", "")])
		lines.append("")
	lines.append("[b]PEOPLE[/b]")
	lines.append("Arrived %d · served %d · walked past %d" % [arrived, served, walked_past])
	if closing_up_text() != "":
		lines.append(closing_up_text())
	lines.append("At the counter %d (most tonight %d, avg %.1f)" % [seated, peak_seated, average_seated()])
	lines.append("Two or more in: %d%% of the night" % percent(together_seconds, real_seconds))
	if not who.is_empty():
		lines.append("Who: %s · ages %s" % [counts_text(who), counts_text(ages)])
		lines.append("Company: %s · tipsy %d" % [counts_text(company_mix), tipsy])
	if not street.is_empty():
		lines.append("Street: %s" % counts_text(street))
	lines.append("Greetings: %d proper, %d quick" % [proper_greetings, quick_greetings])
	lines.append("Invented ahead: %d (%d came in, %d too old or name taken)" % [prepared, prepared_used, prepared_stale])
	lines.append("Wait for the owner: avg %d min, longest %d" % [roundi(average(greet_waits)), roundi(longest(greet_waits))])
	lines.append("Wait for first drinks: avg %d min, longest %d" % [roundi(average(serve_waits)), roundi(longest(serve_waits))])
	if owner_lines_each.is_empty():
		lines.append("Lines with the owner each: (nobody's left yet)")
	else:
		lines.append("Lines with the owner each: avg %.1f (%d to %d)" % [average(owner_lines_each), roundi(shortest(owner_lines_each)), roundi(longest(owner_lines_each))])
	lines.append("")
	lines.append("[b]TALK[/b]")
	lines.append("Owner conversations: %d lines" % owner_lines)
	lines.append("Customer chats: %d started (%d drawing in someone quiet), %d lines (%d%% of all lines)" % [chats_started, chats_drawn_in, chat_lines, percent(chat_lines, owner_lines + chat_lines)])
	lines.append("Joined in: owner %d, another customer %d" % [owner_joins, customer_joins])
	lines.append("Chat chances: %d · taken %d (%d new, %d carried on)" % [chat_chances, chats_started + chats_continued, chats_started, chats_continued])
	lines.append("Owner free: %d times (a chat possible in %d)" % [free_turns, chat_chances])
	var mix := topic_mix()
	lines.append("Talk turned to: light %d · deep %d%s" % [mix[0], mix[1], (" · " + counts_text(topics, 8)) if not topics.is_empty() else ""])
	lines.append("Teasing that crossed the line (dropped): %d" % int(rejections.get("teasing that crossed the line", 0)))
	var worn := worn_out()
	lines.append("Said too often (%d+ lines, asked for another way; %d lines sent back for it, %d let through on a third try): %s" % [WORN_OUT, int(rejections.get("said too often", 0)), worn_let_through, " · ".join(PackedStringArray(worn.map(func(p): return "\"%s\" %d" % [p, int(phrases[p])]))) if not worn.is_empty() else "(nothing yet)"])
	var ordinary := hints_text()
	lines.append("Hints taken up: %s" % (ordinary if ordinary != "" else "(none given yet)"))
	lines.append("Korean words said: %s" % (counts_text(korean_words, 10) if not korean_words.is_empty() else "(none yet)"))
	lines.append("Commonest start: orders %s · owner's openers %s · situations given: orders %d, openers %d" % [opening_text("order"), opening_text("owner"), order_situations, opener_situations])
	lines.append("")
	lines.append("[b]POCHA LIFE[/b]")
	lines.append("Rituals: %s" % (counts_text(rituals) if not rituals.is_empty() else "none yet"))
	var games := table_games()
	var offered := 0
	var taken := 0
	for game in games:
		offered += int(games[game][0])
		taken += int(games[game][1])
	lines.append("Table games: offered %d, taken up %d%s" % [offered, taken, (" · " + " · ".join(PackedStringArray(games.keys().map(func(g): return "%s %d/%d" % [g, int(games[g][1]), int(games[g][0])])))) if not games.is_empty() else ""])
	lines.append("Double-takes: offered %d, taken up %d · hwaiting chorus %d · first snow %s" % [int(hints_given.get("stunned", 0)), int(hints_taken.get("stunned", 0)),
		int(event_counts.get("cheered_on", 0)), "yes" if int(event_counts.get("first_snow", 0)) > 0 else "no"])
	if event_counts.keys().any(func(kind): return str(kind).begins_with("cat_")):
		lines.append("The cat: moved %d · kept someone on their lap %d · fed from a plate %d · answered to its name %d, ignored it %d · stole %d" % [int(event_counts.get("cat_moved", 0)),
			int(event_counts.get("cat_kept", 0)), int(event_counts.get("cat_fed", 0)), int(event_counts.get("cat_answered", 0)), int(event_counts.get("cat_ignored", 0)), int(event_counts.get("cat_stole", 0))])
	lines.append("")
	lines.append("[b]THE PD[/b]")
	lines.append(esc_menu_text())
	if transcript_use.has("size"):
		var t := transcript_use
		lines.append("Transcript: searched %d (went through matches %d) · showed Talk %d, Events %d, All %d · caught up %d (%d new lines) · text %d%s" % [int(t.get("searches", 0)), int(t.get("jumps", 0)),
			int(t.get("talk", 0)), int(t.get("events", 0)), int(t.get("all", 0)), int(t.get("catch_ups", 0)), int(t.get("caught", 0)), int(t["size"]), " · compact" if bool(t.get("compact", false)) else ""])
	if not crew_run.is_empty():
		lines.append("The crew ran it (from %s): %s%s%s%s" % [str(crew_run.get("from", "?")), str(crew_run.get("night", "")),
			(" · took over at %s" % crew_run["took_over"]) if crew_run.has("took_over") else "",
			(" · stopped: %s" % crew_run["stopped"]) if crew_run.has("stopped") else "",
			(" · handed back %s" % (("at " + str(crew_run["handed_back"])) if not str(crew_run["handed_back"]).begins_with("after") else str(crew_run["handed_back"]))) if crew_run.has("handed_back") else ""])
	if not autopilot.is_empty():
		lines.append("Autopilot PD (an autoplay batch): cards played %d · camera moves %d · pinned %d · spins picked %d · stepped in: %s" % [int(autopilot.get("cards", 0)),
			int(autopilot.get("camera", 0)), int(autopilot.get("pins", 0)), int(autopilot.get("spins", 0)), str(autopilot.get("stepped_in", "")) if str(autopilot.get("stepped_in", "")) != "" else "no"])
	var follows := camera_follows()
	lines.append("Camera: %s" % ("followed %d · %s" % [follows.size(), " · ".join(PackedStringArray(follows.map(func(f): return "%s %s" % [f["name"], ("%d min" % int(f["minutes"])) if int(f["minutes"]) >= 0 else "(still on)"])))] if not follows.is_empty() else "not used tonight"))
	lines.append("Lines on camera %d of %d (%d%%) · noticed the camera %d/%d" % [camera_lines_on, camera_lines, percent(camera_lines_on, camera_lines),
		int(hints_taken.get("camera", 0)), int(hints_given.get("camera", 0))])
	if events.any(func(e): return str(e.get("kind", "")) == "camera_on" and bool(e.get("owner", false))):
		lines.append("On the owner: noticed %s · showed a little more of themselves %d · customers' chats half as often" % [
			"yes" if int(event_counts.get("owner_noticed_camera", 0)) > 0 else "not yet", int(event_counts.get("owner_on_camera", 0))])
	var played := plants()
	for entry in written:
		lines.append("Written (%s, for %s): «%s» · replies kept %d" % [entry["card"], entry["who"], entry["text"], (entry["lines"] as Array).size()])
	var cut: Dictionary = story.get("edit", {})
	lines.append("Last night's episode: %s" % (("cut by the PD (stepped in %s) · title %s · cliffhanger %s%s · \"%s\"" % [
		{"loading": "while loading", "recap": "mid-recap", "night": "early in the night"}.get(str(cut.get("stepped_in", "")), "?"),
		"the PD's" if str(cut.get("title_by", "")) == "pd" else "the writers'", "the PD's" if str(cut.get("cliffhanger_by", "")) == "pd" else "the writers'",
		" (their own words)" if bool(cut.get("own_teaser", false)) else "", cut.get("title", "")]) + ((" · scenes the PD's (%d, rewritten in %ss, kept %s%s)" % [
		int(cut["rewrite"].get("scenes", 0)), cut["rewrite"].get("seconds", 0), cut["rewrite"].get("kept", "?"),
		(", online: %s" % cut["rewrite"]["online"]) if str(cut["rewrite"].get("online", "")) != "" else ""]) if not cut.get("rewrite", {}).is_empty() else " · scenes the writers'")
		+ ((" · scenes with faces %d/%d" % [int(cut["scene_faces"][0]), int(cut["scene_faces"][1])]) if cut.has("scene_faces") else "")
		if not cut.is_empty() and not bool(cut.get("left_to_writers", false))
		else ("stepped in, then left it to the writers" if not cut.is_empty() else "the writers' cut")))
	lines.append("Pinned: %d%s · kept %d%s%s" % [pins_made, (" (%d dropped, a fourth pushing out the oldest)" % pins_dropped) if pins_dropped > 0 else "", pinned.size(),
		(": " + " · ".join(PackedStringArray(pinned.map(func(p): return "%s «%s»" % [p["speaker"], Text.shorten(str(p["text"]), 40)])))) if not pinned.is_empty() else "",
		(" · last time's in the recap: %s" % story["recap_pins"]) if story.has("recap_pins") else ""])
	var edited := 0
	for change in edits_made:
		edited += int(edits_made[change])
	lines.append("The edit: offered %d · you picked a spin %d%s" % [edits_offered, edited, (" (" + counts_text(edits_made) + ")") if edited > 0 else ""])
	if written_refused > 0:
		lines.append("Write-ins sent back by the checks: %d" % written_refused)
	lines.append("Plants: %s" % (("played %d · turned to first %d · " % [played.size(), card_turns]) + " · ".join(PackedStringArray(played.keys().map(func(c): return "%s taken up %d/%d, came up in %d lines after" % [c, int(played[c][2]), int(played[c][1]), int(played[c][3])]))) if not played.is_empty() else "none played tonight"))
	lines.append("")
	lines.append("[b]REGULARS[/b]")
	lines.append("On the books %d (%d founding) · average pull %.2f" % [regular_pulls.size(), founding_regulars, average(regular_pulls.values())])
	lines.append("In tonight %d (%d%% of those served) · new regulars %d · faded away %d" % [regulars_in, percent(regulars_in, served), became_regulars, faded_regulars])
	lines.append("Friendlier terms tonight: %d" % friendlier_moments)
	lines.append(memory_text())
	lines.append(groups_text())
	lines.append("Closeness: sat by a friend %d · waved over %d · the owner saved them something %d · close friends coming in together %d" % [int(closeness.get("sat_by_a_friend", 0)),
		int(closeness.get("waved_over", 0)), int(closeness.get("saved_for_them", 0)), int(closeness.get("together", 0))])
	lines.append("Visits: loved %d · enjoyed %d · fine %d · didn't enjoy %d%s" % [int(verdicts.get("loved", 0)), int(verdicts.get("enjoyed", 0)), int(verdicts.get("fine", 0)), int(verdicts.get("didnt", 0)), (" · memories failed %d" % memories_failed) if memories_failed > 0 else ""])
	lines.append("")
	lines.append("[b]THE STORY[/b]")
	lines.append("Opening: %s · recap %s" % [("loading %ds%s" % [int(story["loading_seconds"]), (" (tent: %s)" % story["loading_tent"]) if story.has("loading_tent") else ""]) if story.has("loading_seconds") else "no loading screen",
		("%s (%s)" % [story["recap_style"], story.get("recap_by", "?")]) if story.has("recap_style") else "none"]
		+ ((" · faces beside the beats %d, on the card %d (of %d kept)" % [story["recap_faces"].get("beats", []).size(), story["recap_faces"].get("card", []).size(), int(story["recap_faces"].get("kept", 0))]) + (" (the owner's own face)" if bool(story["recap_faces"].get("own", false)) else "") if story.has("recap_faces") else "")
		+ ((" · cut to the internet: %s" % story["recap_online"]) if str(story.get("recap_online", "")) != "" else "")
		+ ((" · model warmed up at the title: %s" % warm_up_text(story["warm_up"])) if story.get("warm_up", {}) is Dictionary and not story.get("warm_up", {}).is_empty() else ""))
	if story.get("opening_steps", {}) is Dictionary and not (story.get("opening_steps", {}) as Dictionary).is_empty():  # (a new bar: how long each step of making it took, visit.gd _step_done)
		lines.append("Making the bar: %s · %s" % [span_text(total_seconds(story["opening_steps"])), opening_steps_text(story["opening_steps"])])
	if not art.is_empty():
		lines.append("Art: images %d · drawn in code %d · lit by the hour %d%s · words in pixels %d · poses %d · glasses raised %d · mouthfuls %d · the owner: poured %d, carried %d, stirred %d, waved %d%s" % [art.get("images", []).size(), art.get("drawn", []).size(), int(art.get("lit", 0)),
			(" (a bulb's pool +%.1f steps over the counter's end)" % float(art["pools"])) if art.has("pools") else "", int(art.get("pixel_words", 0)), poses, int(gestures.get("drink", 0)), int(gestures.get("eat", 0)),
			int(gestures.get("pour", 0)), int(gestures.get("carry", 0)), int(gestures.get("cook", 0)), int(gestures.get("wave", 0)),
			(" · BROKEN %s" % ", ".join(PackedStringArray(art["broken"]))) if not art.get("broken", []).is_empty() else ""])
	if not portraits.is_empty():
		lines.append(portraits_text())
	if not stings.is_empty():
		lines.append(stings_text())
	if not clipart.is_empty():
		lines.append(clipart_text())
	if not keepsakes.is_empty():
		lines.append(keepsakes_text())
	if not socials.is_empty():
		lines.append(socials_text())
	if art.get("street", {}) is Dictionary and not art.get("street", {}).is_empty():
		var tonights: Dictionary = art["street"]
		lines.append("Street: lamps %d · stars %d · moon %s · road %s" % [int(tonights.get("lamps", 0)), int(tonights.get("stars", 0)), str(tonights.get("moon", "?")), str(tonights.get("road", "?"))])
	lines.append("Diary: %s" % (("stamp %s (%s)" % [story.get("diary_stamp", "?"), story.get("diary_by", "?")]) if story.has("diary_by") else "not yet"))
	if story.get("titles", {}) is Dictionary and not story.get("titles", {}).is_empty():  # (next time's titles to choose from, drafted at 3am)
		var drafted: Dictionary = story["titles"]
		lines.append("Titles: %s (by the %s)%s" % [" | ".join(PackedStringArray(drafted.get("titles", []))), drafted.get("by", "?"),
			(" · Korean dropped, not words the game knows: %s" % ", ".join(PackedStringArray(drafted["dropped_hangul"]))) if not drafted.get("dropped_hangul", []).is_empty() else ""])
	if story.get("show", {}) is Dictionary and not story.get("show", {}).is_empty():  # the show's seasons (rules/show_seasons.gd)
		var on_air: Dictionary = story["show"]
		lines.append("Season: %s%s%s%s%s" % [on_air.get("place", "?"), (" · on " + str(on_air["rung"])) if on_air.has("rung") else "", (" · " + str(on_air["moved"])) if on_air.has("moved") else "", (" · the season before tonight: %s" % on_air["so_far"]) if str(on_air.get("so_far", "")) != "" else "",
			(" · %s%s" % [on_air["verdict"], (", looked back on (%d episodes)" % int(on_air["looked_back"])) if on_air.has("looked_back") else ""]) if on_air.has("verdict") else (" · the verdict at 3am" if bool(on_air.get("finale", false)) else "")])
	if story.get("show", {}) is Dictionary and story.get("show", {}).has("on_air"):  # (where it goes out, and who films it: rules/channels.gd)
		var crew := str(story["show"].get("crew", "?"))
		if crew.begins_with("The "):  # (mid-sentence: "filmed by the channel's camera")
			crew = "the " + crew.substr(4)
		lines.append("On air: %s · filmed by %s%s%s" % [story["show"]["on_air"], crew,
			(" · cast tonight: %s, the owner's %s (@%s, by the %s)" % [story["relative"]["name"], story["relative"]["relation"], story["relative"]["handle"], story["relative"]["by"]]) if story.get("relative", {}) is Dictionary and not story.get("relative", {}).is_empty() else "",
			(" · booked tonight: %s (by the %s)" % [story["booked"]["channel"], story["booked"]["by"]]) if story.get("booked", {}) is Dictionary and not story.get("booked", {}).is_empty() else ""])
	if story.get("setup", {}) is Dictionary and not story.get("setup", {}).is_empty():  # (a new bar: the PD set the show up)
		lines.append("Setup: the show starts on %s (the PD's)" % story["setup"].get("rung", "?"))
	if story.get("faces", {}) is Dictionary and not story.get("faces", {}).is_empty():  # (a new bar: faces of their own, ai/portrait_maker.gd)
		lines.append(faces_text(story["faces"]))
	if story.get("faces_recast", {}) is Dictionary and not story.get("faces_recast", {}).is_empty():  # (the PD, before tonight)
		lines.append(recast_text(story["faces_recast"]))
	if story.get("faces_after", {}) is Dictionary and not story.get("faces_after", {}).is_empty():  # (after closing: the regulars without one)
		lines.append("Faces of their own after closing: " + after_closing_text(story["faces_after"]) + comfy_text(story["faces_after"]))
	if story.has("cliffhanger"):
		lines.append("Cliffhanger: %s · %s" % [story["cliffhanger"], "came true!" if bool(story.get("cliffhanger_answered", false)) else "not yet"])
	lines.append("")
	lines.append_array(ratings_lines())
	lines.append("")
	lines.append("[b]TV CAPTIONS[/b]")
	lines.append("Shown %d%s%s" % [captions_total(), (" · " + caption_counts()) if not captions.is_empty() else "", (" · held back %d" % captions_held_back) if captions_held_back > 0 else ""])
	var shown_reactions := 0
	for mood in reactions_shown:
		shown_reactions += int(reactions_shown[mood])
	lines.append("Reactions: asked %d · shown %d%s · none %d · dropped %d · put off (busy) %d, never asked %d" % [reactions_asked, shown_reactions,
		(" (" + ", ".join(PackedStringArray(reactions_shown.keys().map(func(k): return "%s %d" % [k, int(reactions_shown[k])]))) + ")") if not reactions_shown.is_empty() else "",
		reactions_none, reactions_dropped, reactions_put_off, reactions_skipped])
	lines.append("Moment sizes (a caption at %d+): %s" % [Captions.REACTION_MIN_SIZE, " · ".join(PackedStringArray(["1", "2", "3", "4", "5"].map(func(k): return "%s: %d" % [k, int(reaction_sizes.get(k, 0))]))) if not reaction_sizes.is_empty() else "(none asked yet)"])
	lines.append("Big moments from: %s" % (" · ".join(PackedStringArray(["light", "deep", "other"].filter(func(k): return moments_from.has(k)).map(func(k): return "%s talk (%s)" % [k, counts_text(moments_from[k])]))) if not moments_from.is_empty() else "(none yet)"))
	lines.append("")
	lines.append("[b]FOOD AND THE MENU[/b]")
	if story.has("menu_by"):
		lines.append("Menu: chosen by the %s · its own: %s" % [story["menu_by"], ", ".join(PackedStringArray(story.get("menu_own", [])))])
	if story.has("menu_change"):
		var change: Dictionary = story["menu_change"]
		lines.append("Menu change: %s off, %s on (by the %s)" % [change.get("out", ""), change.get("in", ""), change.get("by", "")])
	var house := signature_orders()
	if not house.is_empty() or story.has("signatures_by"):
		lines.append("Signature dishes: %s%s" % [" · ".join(PackedStringArray(house.keys().map(func(d): return "%s %d ordered" % [d, int(house[d])]))) if not house.is_empty() else "none",
			(" (new tonight, by the %s)" % story["signatures_by"]) if story.has("signatures_by") else ""])
	lines.append("Menu board opened: %d" % menu_opened)
	lines.append("Orders %d first, %d more%s · %s" % [first_orders, extra_orders, ((" · sides added %d" % sides_added) if sides_added > 0 else "") + ((" · unsaid dropped %d" % unsaid_dropped) if unsaid_dropped > 0 else ""), counts_text(ordered) if not ordered.is_empty() else "nothing yet"])
	if not specials.is_empty():
		lines.append("Specials: %s · cravings given %d" % [" · ".join(PackedStringArray(specials.map(func(id): return "%s %d ordered" % [id, int(ordered.get(id, 0))]))), cravings])
	if not sold_out.is_empty():
		lines.append("Sold out: %s · asked for anyway %d" % [", ".join(PackedStringArray(sold_out)), int(rejections.get("sold out", 0))])
	lines.append("Dishes cooked %d · on the stove now %d" % [dishes_cooked, cooking])
	lines.append("Wait for food: avg %d min, longest %d" % [roundi(average(food_waits)), roundi(longest(food_waits))])
	lines.append(owner_moves_text())
	lines.append("")
	lines.append("[b]AI[/b]")
	lines.append("Calls %d · avg %.1fs, longest %.1fs" % [ai_calls, average(ai_seconds), longest(ai_seconds)])
	var setting_up: Array = ["menu", "signatures", "menu_change", "recap", "bar_name", "bar_look", "cat_name", "owner", "founding_regular", "hangul"].filter(func(p): return calls_by.has(p))
	if not setting_up.is_empty():
		lines.append("Getting ready: %s" % " · ".join(PackedStringArray(setting_up.map(func(p): return "%s %d" % [p, int(calls_by[p])]))))
	lines.append("Voice busy %d%% · someone waiting for it %d%%" % [percent(voice_busy_seconds, real_seconds), percent(waiting_on_voice_seconds, real_seconds)])
	lines.append("Rejected replies %d%s" % [rejected, (": " + rejection_text()) if rejected > 0 else ""])
	lines.append("Gave up %d%s · out-of-date lines redone %d" % [gave_up,
		(" (" + ", ".join(PackedStringArray(gave_up_by.keys().map(func(k): return "%s %d" % [k, int(gave_up_by[k])]))) + ")") if not gave_up_by.is_empty() else "", stale_redone])
	lines.append("")
	lines.append("[b]EVERYTHING THAT HAPPENED[/b]")
	lines.append(counts_text(event_counts) if not event_counts.is_empty() else "(nothing yet)")
	lines.append("")
	lines.append("Real time tonight: %d:%02d" % [floori(real_seconds / 60.0), int(real_seconds) % 60])
	return "\n".join(lines)


## Portraits tonight: whose were their own, the nearest there was, or none, and hovers seen.
func portraits_text() -> String:
	var cat := ""
	if portraits.has("cat_face"):
		cat = " · the cat's face, seen %d" % int(portraits.get("cat_seen", 0))
	elif portraits.has("cat_none"):
		cat = " · the cat: NO FACE"
	return "Portraits: %smatched %d · fallback %d%s · seen in a hover %d%s" % [("their own %d · " % int(portraits["own"])) if int(portraits.get("own", 0)) > 0 else "", int(portraits.get("matched", 0)), int(portraits.get("fallback", 0)),
		(" · NONE %d" % int(portraits["none"])) if int(portraits.get("none", 0)) > 0 else "", int(portraits.get("seen", 0)), cat]


## Faces of their own made as the bar opened (visit.gd _cast_owner_face): the owner's, or why they
## keep the library's; the pictures made and failed, the casting rounds, ComfyUI and how long.
## A new bar's steps and how long each took, in order: "owner 12s · sign 4s · faces 2m08s", then
## what was shown once it was made, not part of making it: "· then the series opener shown 19s".
static func opening_steps_text(steps: Dictionary) -> String:
	var parts: Array = []
	var shown: Array = []
	for step in steps:
		if SHOWN_STEPS.has(step):
			shown.append("then %s %s" % [SHOWN_STEPS[step], span_text(float(steps[step]))])
		else:
			parts.append("%s %s" % [step, span_text(float(steps[step]))])
	return " · ".join(PackedStringArray(parts + shown))


## The steps timed with the rest that are the bar being shown, not made (the loading screen's gone
## by then): left out of the total. The series opener plays for about 19s, the same every time
## (18.82s on both new bars on the 26th), and was counted as making the bar.
const SHOWN_STEPS := {"recap": "the series opener shown"}


## The steps' seconds added up: how long the bar took to make (what's shown after it left out).
static func total_seconds(steps: Dictionary) -> float:
	var total := 0.0
	for step in steps:
		if not SHOWN_STEPS.has(step):
			total += float(steps[step])
	return total


## Seconds as "45s", or "3m27s" from a minute.
static func span_text(seconds: float) -> String:
	var whole := roundi(seconds)
	if whole < 60:
		return "%ds" % whole
	@warning_ignore("integer_division")
	return "%dm%02ds" % [whole / 60, whole % 60]


## The title screen's warm-up of the model (Game.warm_up_ai), for "Opening:": "loaded in 8s",
## "still going" (the bar opened before it was done) or "failed (why)".
static func warm_up_text(warm: Dictionary) -> String:
	if bool(warm.get("going", false)):
		return "still going"
	if bool(warm.get("ok", false)):
		return "loaded in %ds" % int(warm.get("seconds", 0.0))
	return "failed (%s)" % str(warm.get("why", "?"))


static func faces_text(faces: Dictionary) -> String:
	var rounds := (" · %d rounds" % int(faces["rounds"])) if int(faces.get("rounds", 1)) > 1 else ""
	var regulars := (" · " + regulars_faces_text(faces["regulars"])) if faces.get("regulars", {}) is Dictionary and not (faces.get("regulars", {}) as Dictionary).is_empty() else ""
	if str(faces.get("owner", "")) == "own":
		return "Faces of their own: the owner's (picked by the %s, score %.3f)%s%s" % ["PD" if str(faces.get("by", "")) == "pd" else "game", float(faces.get("score", 0.0)), comfy_text(faces, rounds), regulars]
	return "Faces of their own: the owner keeps the library's (%s)%s%s" % [faces.get("why", "?"), comfy_text(faces), regulars]


## The regulars' faces made in a gap (visit.gd _cast_regulars): their own, the library's (none
## clean enough, or none made), and still to do; or why none were tried.
static func regulars_faces_text(regulars: Dictionary) -> String:
	if regulars.has("why"):
		return "the regulars keep the library's faces for now (%s, %d waiting)" % [regulars["why"], int(regulars.get("waiting", 0))]
	var left := (", %d still to do" % int(regulars["left"])) if int(regulars.get("left", 0)) > 0 else ""
	return "the regulars' own %d, the library's %d%s (%s)" % [int(regulars.get("own", 0)), int(regulars.get("library", 0)), left, ", ".join(PackedStringArray(regulars.get("names", [])))]


## After closing (visit.gd _faces_after_closing): the regulars' new faces (if any were to do), and
## the TV moods of faces of their own (_make_moods), or why neither was made.
static func after_closing_text(after: Dictionary) -> String:
	var parts: Array = []
	if after.has("why"):
		parts.append(regulars_faces_text(after))
		if int(after.get("moods_waiting", 0)) > 0:
			parts.append("%d faces of their own still the calm face in every mood" % int(after["moods_waiting"]))
		return " · ".join(PackedStringArray(parts))
	if after.has("own") or after.has("library"):
		parts.append(regulars_faces_text(after))
	if after.get("moods", {}) is Dictionary and not (after.get("moods", {}) as Dictionary).is_empty():
		parts.append(moods_text(after["moods"]))
	return " · ".join(PackedStringArray(parts))


## Faces of their own's TV moods made tonight: kept, the calm face's, who's still to do.
static func moods_text(moods: Dictionary) -> String:
	var left := (", %d still to do" % int(moods["left"])) if int(moods.get("left", 0)) > 0 else ""
	return "their moods: %d kept, %d the calm face's%s (%s)" % [int(moods.get("kept", 0)), int(moods.get("stood_in", 0)), left, ", ".join(PackedStringArray(moods.get("names", [])))]


## What the PD did recasting regulars' faces before tonight (visit.gd _open_recast).
static func recast_text(recast: Dictionary) -> String:
	var picked: Array = recast.get("picked", [])
	return "Faces recast by the PD before tonight: %d %s of photos, %s%s" % [int(recast.get("shot", 0)), "round" if int(recast.get("shot", 0)) == 1 else "rounds",
		("new faces for " + ", ".join(PackedStringArray(picked))) if not picked.is_empty() else "none picked (they kept theirs)", comfy_text(recast)]


## The pictures made and failed, ComfyUI (started and stopped by the game, or already running)
## and how long, for a gap's faces (rounds: the owner's casting rounds, after the pictures).
static func comfy_text(faces: Dictionary, rounds: String = "") -> String:
	var made := " · %d made, %d failed" % [int(faces.get("made", 0)), int(faces.get("failed", 0))] if faces.has("made") else ""
	if made != "" and int(faces.get("retries", 0)) > 0:  # (a mood's second seed, its first scoring badly: portrait_maker.gd redraw)
		made += " (%d a mood's second try)" % int(faces["retries"])
	var comfy := ""
	if bool(faces.get("fake", false)):
		comfy = " · the test's pictures"
	elif bool(faces.get("already", false)):
		comfy = " · ComfyUI was already running%s" % ("" if not faces.has("unloaded") else (" (its models unloaded after)" if bool(faces["unloaded"]) else " (its models NOT UNLOADED)"))
	elif bool(faces.get("started", false)):
		comfy = " · ComfyUI started and %s" % ("stopped" if bool(faces.get("stopped", false)) else "NOT STOPPED")
	var start := (" in %.1fs" % (int(faces["start_ms"]) / 1000.0)) if faces.has("start_ms") and comfy.begins_with(" · ComfyUI started") else ""  # (process started to answering)
	if start != "":
		comfy = comfy.replace(" · ComfyUI started", " · ComfyUI started" + start)
	if bool(faces.get("early", false)):  # (started while the bar was made: portrait_maker.gd launch)
		comfy += " · started early, %.1fs waited for it" % (int(faces.get("waited_ms", 0)) / 1000.0)
	var took := (" · %ds" % int(faces["seconds"])) if faces.has("seconds") else ""
	var gpu := (" · on the GPU %.1fs" % (int(faces["gpu_ms"]) / 1000.0)) if faces.has("gpu_ms") else ""  # (ComfyUI's own time making them)
	if gpu != "" and faces.has("first_ms"):
		gpu += " (first picture %.1fs: the model loading)" % (int(faces["first_ms"]) / 1000.0)
	var split := (" · split in %.1fs" % (int(faces["split_ms"]) / 1000.0)) if int(faces.get("split_ms", 0)) > 0 else ""  # (portrait_maker.gd: the splits' time, on the CPU, alongside the next picture)
	return made + rounds + comfy + took + gpu + split


## Faces on the captions tonight: beside them and zooms, and which faces.
func stings_text() -> String:
	return "Faces on captions: beside %d · zooms %d · in the mood %d · calm %d · calm standing in %d · the cat's %d%s" % [int(stings.get("beside", 0)), int(stings.get("zoom", 0)),
		int(stings.get("mood", 0)), int(stings.get("calm", 0)), int(stings.get("stood_in", 0)), int(stings.get("cat", 0)), (" · NONE %d" % int(stings["none"])) if int(stings.get("none", 0)) > 0 else ""]


## 3am's keepsakes: the end card (or why not), the diary's polaroids, the faces kept.
func keepsakes_text() -> String:
	return "Keepsakes: end card %s · polaroids %d · faces kept with the entry %d" % [str(keepsakes["end_card"]) if keepsakes.has("end_card") else ("NO FACE" if keepsakes.has("end_card_faceless") else "none"),
		int(keepsakes.get("polaroids", 0)), int(keepsakes.get("faces_kept", 0))]


## 3am's posts and comments: "Socials: posts 2 (words: AI 2, game 0) · pictures 1 (drawn 1) · viewer comments 3 (words: AI 2, game 1) · snapshots 3 of 4".
func socials_text() -> String:
	var snaps: Dictionary = socials.get("snapshots", {})
	var why := PackedStringArray()
	for count in [["failed", "FAILED"], ["over", "over the limit"], ["no_screen", "no screen"]]:
		if int(snaps.get(count[0], 0)) > 0:
			why.append("%s %d" % [count[1], int(snaps[count[0]])])
	return "Socials: posts %d (words: AI %d, game %d%s%s) · pictures %d (drawn %d, words alone %d) · viewer comments %s · snapshots %d of %d%s%s" % [int(socials.get("posts", 0)),
		int(socials.get("words_ai", 0)), int(socials.get("words_game", 0)), (", AI's TURNED DOWN %d" % int(socials["ai_turned_down"])) if int(socials.get("ai_turned_down", 0)) > 0 else "",
		(", hashtags out of the words %d" % int(socials["tags_from_words"])) if int(socials.get("tags_from_words", 0)) > 0 else "",
		int(socials.get("pictures", 0)), int(socials.get("drawn", 0)), int(socials.get("text", 0)), viewers_text(),
		int(snaps.get("taken", 0)), int(snaps.get("asked", 0)), (" (%s)" % ", ".join(why)) if not why.is_empty() else "",
		(" · NOT POSTED %d" % int(socials["dropped"])) if int(socials.get("dropped", 0)) > 0 else ""]


## The viewers' comments, for socials_text: "3 (words: AI 2, game 1, AI's TURNED DOWN 1, NOT SHOWN 1)", or "0".
func viewers_text() -> String:
	var shown := int(socials.get("viewer_comments", 0))
	var turned_down := int(socials.get("viewer_ai_turned_down", 0))
	var dropped := int(socials.get("viewer_dropped", 0))
	if shown == 0 and turned_down == 0 and dropped == 0:
		return "0"
	return "%d (words: AI %d, game %d%s%s)" % [shown, int(socials.get("viewer_words_ai", 0)), int(socials.get("viewer_words_game", 0)),
		(", AI's TURNED DOWN %d" % turned_down) if turned_down > 0 else "", (", NOT SHOWN %d" % dropped) if dropped > 0 else ""]


## The clipart on stage tonight, most used first.
func clipart_text() -> String:
	var shown := clipart.keys().filter(func(clip): return clip != "missing")
	shown.sort_custom(func(a, b): return int(clipart[a]) > int(clipart[b]) or (int(clipart[a]) == int(clipart[b]) and str(a) < str(b)))
	return "Clipart on stage: %s%s" % [", ".join(PackedStringArray(shown.map(func(clip): return "%s %d" % [clip, int(clipart[clip])]))) if not shown.is_empty() else "none",
		(" · MISSING %d" % int(clipart["missing"])) if int(clipart.get("missing", 0)) > 0 else ""]


## Everything, for the log file. context: which bar and night, AI settings and so on.
func summary(context: Dictionary) -> Dictionary:
	return {
		"context": context,
		"events": events.duplicate(true),  # the night's timeline, event by event
		"event_counts": event_counts.duplicate(),
		"street": street.duplicate(),
		"story": story.duplicate(),
		"art": art.duplicate(true),
		"poses": poses,
		"portraits": portraits.duplicate(),
		"stings": stings.duplicate(),
		"clipart": clipart.duplicate(),
		"keepsakes": keepsakes.duplicate(),
		"socials": socials.duplicate(true),
		"gestures": gestures.duplicate(),
		"highlights": highlights(),
		"tonight": {"date": story.get("date", ""), "season": story.get("season", ""), "weather": story.get("weather", "")},
		"pocha_life": {"rituals": rituals.duplicate(), "table_games": table_games(), "double_takes": [int(hints_given.get("stunned", 0)), int(hints_taken.get("stunned", 0))],
			"hwaiting_chorus": int(event_counts.get("cheered_on", 0)), "first_snow": int(event_counts.get("first_snow", 0)) > 0},
		"pd": {"edit": story.get("edit", {}).duplicate(), "pins": {"made": pins_made, "dropped": pins_dropped, "kept": pinned.duplicate(true)}, "edits": {"offered": edits_offered, "made": edits_made.duplicate(), "log": edit_log.duplicate(true)}, "camera": camera_follows(), "lines_on_camera": [camera_lines_on, camera_lines], "plants": plants(), "card_turns": card_turns, "written": written.duplicate(true), "written_refused": written_refused, "autopilot": autopilot.duplicate(true), "crew": crew_run.duplicate(true), "transcript": transcript_use.duplicate(), "esc_menu": {"opened": esc_menu, "quit": quit_asked.duplicate()},
			"noticed_camera": [int(hints_given.get("camera", 0)), int(hints_taken.get("camera", 0))]},
		"menu": {"chosen_by": story.get("menu_by", ""), "its_own": story.get("menu_own", []), "board_opened": menu_opened,
			"signatures": signature_orders(), "signatures_by": story.get("signatures_by", ""), "change": story.get("menu_change", {})},
		"who": {"genders": who.duplicate(), "ages": ages.duplicate(), "company": company_mix.duplicate(), "tipsy": tipsy},
		"people": {
			"arrived": arrived, "served": served, "walked_past": walked_past, "peak_seated": peak_seated, "closing_up": closing_up.duplicate(),
			"average_seated": average_seated(), "two_or_more_percent": percent(together_seconds, real_seconds),
			"quick_greetings": quick_greetings, "proper_greetings": proper_greetings,
			"invented_ahead": {"invented": prepared, "came_in": prepared_used, "thrown_away": prepared_stale},
			"greet_wait_minutes": {"average": average(greet_waits), "longest": longest(greet_waits)},
			"first_drinks_wait_minutes": {"average": average(serve_waits), "longest": longest(serve_waits)},
			"owner_lines_each": {"average": average(owner_lines_each), "fewest": shortest(owner_lines_each), "most": longest(owner_lines_each)},
		},
		"talk": {
			"owner_lines": owner_lines, "chat_lines": chat_lines, "chats_started": chats_started, "chats_drawn_in": chats_drawn_in,
			"owner_joins": owner_joins, "customer_joins": customer_joins,
			"chat_chances": chat_chances, "chats_continued": chats_continued, "free_turns": free_turns,
			"chat_percent": percent(chat_lines, owner_lines + chat_lines),
			"worn_out": worn_out(10).map(func(p): return [p, int(phrases[p])]), "worn_let_through": worn_let_through,
			"topics": topics.duplicate(), "topic_mix": topic_mix(), "crossed_the_line": int(rejections.get("teasing that crossed the line", 0)),
			"hints_given": hints_given.duplicate(), "hints_taken": hints_taken.duplicate(), "korean_words": korean_words.duplicate(),
			"openings": openings.duplicate(true), "order_situations": order_situations, "opener_situations": opener_situations,
		},
		"regulars": {
			"on_the_books": regular_pulls.size(), "founding": founding_regulars, "in_tonight": regulars_in,
			"became": became_regulars, "faded": faded_regulars, "pulls": regular_pulls.duplicate(),
			"verdicts": verdicts.duplicate(), "memories_failed": memories_failed, "friendlier_moments": friendlier_moments,
			"threads": threads.duplicate(), "pair_memories": pair_memories.duplicate(), "who_you_know": who_you_know, "closeness": closeness.duplicate(), "groups": groups.duplicate(), "facts_learned": facts_learned.duplicate(), "facts_heard": facts_heard.duplicate(), "bonds": bonds.duplicate(),
		},
		"captions": {"shown": captions.duplicate(), "held_back": captions_held_back,
			"reactions": {"asked": reactions_asked, "shown": reactions_shown.duplicate(), "from": moments_from.duplicate(true), "sizes": reaction_sizes.duplicate(), "none": reactions_none, "dropped": reactions_dropped, "put_off": reactions_put_off, "skipped": reactions_skipped}},
		"food": {
			"ordered": ordered.duplicate(), "first_orders": first_orders, "extra_orders": extra_orders,
			"specials": specials.duplicate(), "sold_out": sold_out.duplicate(), "cravings": cravings, "sides_added": sides_added, "unsaid_dropped": unsaid_dropped,
			"dishes_cooked": dishes_cooked,
			"food_wait_minutes": {"average": average(food_waits), "longest": longest(food_waits)},
		},
		"ai": {
			"calls": ai_calls, "average_seconds": average(ai_seconds), "longest_seconds": longest(ai_seconds),
			"rejected": rejected, "rejections": rejections.duplicate(), "gave_up": gave_up, "gave_up_by": gave_up_by.duplicate(),
			"rejection_reasons": rejection_reasons.duplicate(true), "rejected_replies": rejected_replies.duplicate(true), "stale_redone": stale_redone, "calls_by": calls_by.duplicate(),
		},
		"time": {
			"real_seconds": real_seconds,
			"voice_busy_percent": percent(voice_busy_seconds, real_seconds),
			"owner_at_stove_percent": percent(owner_stove_seconds, owner_stove_seconds + owner_front_seconds),
			"owner_trips": owner_trips.duplicate(), "from_the_stove": from_the_stove,
			"waiting_on_voice_percent": percent(waiting_on_voice_seconds, real_seconds),
		},
	}


## Writes the night's log: stats/<date>_<bar>_night<N>.json. Returns the file's path, or ""
## if it couldn't be written.
func save(context: Dictionary, bar_id: String, night: int) -> String:
	var where := logs_folder()
	DirAccess.make_dir_recursive_absolute(where)
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "").replace(" ", "_").left(15)
	var path := where.path_join("%s_%s_night%d.json" % [stamp, bar_id, night])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(summary(context), "\t"))
	file.close()
	return path
