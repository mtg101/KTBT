extends RefCounted
## Debug stats for one night, for testing and tuning: who came, how much talking there was
## (owner and customer chats), how long people waited, and how the AI did. The visit scene
## counts things as they happen; this shows them in the stats panel and, when the night
## ends (or the bar's closed partway through), writes them to a log file in stats/ in the
## user data folder, one per night, to compare runs.

const Text = preload("res://scripts/rules/text.gd")
const Talk = preload("res://scripts/rules/talk.gd")
const Glossary = preload("res://scripts/rules/glossary.gd")

## Where the logs go. Tests point this at their own folder.
static var folder := "user://stats/"

## Every night event, counted by kind (so a new kind of event is always counted, even
## before it has a stat of its own).
var event_counts := {}

# People
var arrived := 0
var served := 0  # paid and left
var walked_past := 0  # gave up waiting for a stool
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
## Out in the street and coming in: who walked by (alone, in twos, in threes), on phones,
## under which umbrellas, sharing one, running for it; customers under umbrellas or running in.
var street := {}
var cravings := 0  # ...of which with a craving (Talk.craving)
var specials: Array = []  # tonight's specials (menu ids)

# Regulars
var regular_pulls := {}  # name -> pull, for everyone on the books
var founding_regulars := 0
var regulars_in := 0  # regulars who came in (and paid) tonight
var became_regulars := 0
var faded_regulars := 0
var verdicts := {}  # how each visit went (the AI's verdict, or the game's if it couldn't)
var memories_failed := 0
var friendlier_moments := 0  # two regulars on "eonni" (or oppa, hyung, nuna) terms

# TV captions
var captions := {}  # kind -> how many shown tonight
var captions_held_back := 0  # ones that would have come too soon after another
var reactions_asked := 0  # times the AI was asked "was that a big moment?"
var reactions_shown := {}  # mood -> how many shown
var reactions_none := 0  # ...answered "nothing special"
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
var events: Array = []  # tonight's events (NightEvents.timeline), for the log
var gave_up_by := {}  # what the AI was being asked for -> how many times it gave up
var gave_up := 0  # calls that never got a usable reply
var stale_redone := 0  # lines asked for again because things changed while the AI wrote them

# Time (real seconds)
var real_seconds := 0.0
var seated_seconds := 0.0  # people at the counter, added up over time (for the average)
var together_seconds := 0.0  # time with two or more at the counter (so they could chat)
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


## A line said with a hint in its direction (see Talk.moment_kind): counted, and whether
## the line seems to have taken it up.
func record_hint(kind: String, line: String, extra_tells: Array = []) -> void:
	if kind == "":
		return
	hints_given[kind] = int(hints_given.get(kind, 0)) + 1
	if Talk.hint_taken(kind, line, extra_tells):
		hints_taken[kind] = int(hints_taken.get(kind, 0)) + 1


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


## "soju 5 · somaek 2", most first. limit: how many (0: all).
static func counts_text(counts: Dictionary, limit: int = 0) -> String:
	var keys := counts.keys()
	keys.sort_custom(func(a, b): return int(counts[a]) > int(counts[b]) or (int(counts[a]) == int(counts[b]) and str(a) < str(b)))
	if limit > 0 and keys.size() > limit:
		keys = keys.slice(0, limit)
	return " · ".join(PackedStringArray(keys.map(func(k): return "%s %d" % [k, int(counts[k])])))


## "somaek 1/2 · pour 0/1 · food ×3": hints taken up out of given. A kind with no tell-tale
## words to look for (Talk.HINT_TELLS) can't be judged, so it just says how many were given.
func hints_text() -> String:
	var keys := hints_given.keys()
	keys.sort()
	return " · ".join(PackedStringArray(keys.map(func(k): return ("%s %d/%d" % [k, int(hints_taken.get(k, 0)), int(hints_given[k])]) if Talk.HINT_TELLS.has(k) else ("%s ×%d" % [k, int(hints_given[k])]))))


func record_ai(seconds: float, problems: Array, ok: bool, purpose: String = "") -> void:
	ai_calls += 1
	ai_seconds.append(seconds)
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


func panel_text(seated: int, cooking: int) -> String:
	var lines := PackedStringArray()
	lines.append("[b]PEOPLE[/b]")
	lines.append("Arrived %d · served %d · walked past %d" % [arrived, served, walked_past])
	lines.append("At the counter %d (most tonight %d, avg %.1f)" % [seated, peak_seated, average_seated()])
	lines.append("Two or more in: %d%% of the night" % percent(together_seconds, real_seconds))
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
	lines.append("Customer chats: %d started, %d lines (%d%% of all lines)" % [chats_started, chat_lines, percent(chat_lines, owner_lines + chat_lines)])
	lines.append("Joined in: owner %d, another customer %d" % [owner_joins, customer_joins])
	lines.append("Chat chances: %d · taken %d (%d new, %d carried on)" % [chat_chances, chats_started + chats_continued, chats_started, chats_continued])
	lines.append("Owner free: %d times (a chat possible in %d)" % [free_turns, chat_chances])
	lines.append("Hints taken up: %s" % (hints_text() if not hints_given.is_empty() else "(none given yet)"))
	lines.append("Korean words said: %s" % (counts_text(korean_words, 10) if not korean_words.is_empty() else "(none yet)"))
	lines.append("Commonest start: orders %s · owner's openers %s · situations given: orders %d, openers %d" % [opening_text("order"), opening_text("owner"), order_situations, opener_situations])
	lines.append("")
	lines.append("[b]REGULARS[/b]")
	lines.append("On the books %d (%d founding) · average pull %.2f" % [regular_pulls.size(), founding_regulars, average(regular_pulls.values())])
	lines.append("In tonight %d (%d%% of those served) · new regulars %d · faded away %d" % [regulars_in, percent(regulars_in, served), became_regulars, faded_regulars])
	lines.append("Friendlier terms tonight: %d" % friendlier_moments)
	lines.append("Visits: loved %d · enjoyed %d · fine %d · didn't enjoy %d%s" % [int(verdicts.get("loved", 0)), int(verdicts.get("enjoyed", 0)), int(verdicts.get("fine", 0)), int(verdicts.get("didnt", 0)), (" · memories failed %d" % memories_failed) if memories_failed > 0 else ""])
	lines.append("")
	lines.append("[b]TV CAPTIONS[/b]")
	lines.append("Shown %d%s%s" % [captions_total(), (" · " + caption_counts()) if not captions.is_empty() else "", (" · held back %d" % captions_held_back) if captions_held_back > 0 else ""])
	var shown_reactions := 0
	for mood in reactions_shown:
		shown_reactions += int(reactions_shown[mood])
	lines.append("Reactions: asked %d · shown %d%s · none %d · dropped %d · put off (busy) %d, never asked %d" % [reactions_asked, shown_reactions,
		(" (" + ", ".join(PackedStringArray(reactions_shown.keys().map(func(k): return "%s %d" % [k, int(reactions_shown[k])]))) + ")") if not reactions_shown.is_empty() else "",
		reactions_none, reactions_dropped, reactions_put_off, reactions_skipped])
	lines.append("")
	lines.append("[b]FOOD[/b]")
	lines.append("Orders %d first, %d more%s · %s" % [first_orders, extra_orders, (" · sides added %d" % sides_added) if sides_added > 0 else "", counts_text(ordered) if not ordered.is_empty() else "nothing yet"])
	if not specials.is_empty():
		lines.append("Specials: %s · cravings given %d" % [" · ".join(PackedStringArray(specials.map(func(id): return "%s %d ordered" % [id, int(ordered.get(id, 0))]))), cravings])
	lines.append("Dishes cooked %d · on the stove now %d" % [dishes_cooked, cooking])
	lines.append("Wait for food: avg %d min, longest %d" % [roundi(average(food_waits)), roundi(longest(food_waits))])
	lines.append("")
	lines.append("[b]AI[/b]")
	lines.append("Calls %d · avg %.1fs, longest %.1fs" % [ai_calls, average(ai_seconds), longest(ai_seconds)])
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


## Everything, for the log file. context: which bar and night, AI settings and so on.
func summary(context: Dictionary) -> Dictionary:
	return {
		"context": context,
		"events": events.duplicate(true),  # the night's timeline, event by event
		"event_counts": event_counts.duplicate(),
		"street": street.duplicate(),
		"people": {
			"arrived": arrived, "served": served, "walked_past": walked_past, "peak_seated": peak_seated,
			"average_seated": average_seated(), "two_or_more_percent": percent(together_seconds, real_seconds),
			"quick_greetings": quick_greetings, "proper_greetings": proper_greetings,
			"invented_ahead": {"invented": prepared, "came_in": prepared_used, "thrown_away": prepared_stale},
			"greet_wait_minutes": {"average": average(greet_waits), "longest": longest(greet_waits)},
			"first_drinks_wait_minutes": {"average": average(serve_waits), "longest": longest(serve_waits)},
			"owner_lines_each": {"average": average(owner_lines_each), "fewest": shortest(owner_lines_each), "most": longest(owner_lines_each)},
		},
		"talk": {
			"owner_lines": owner_lines, "chat_lines": chat_lines, "chats_started": chats_started,
			"owner_joins": owner_joins, "customer_joins": customer_joins,
			"chat_chances": chat_chances, "chats_continued": chats_continued, "free_turns": free_turns,
			"chat_percent": percent(chat_lines, owner_lines + chat_lines),
			"hints_given": hints_given.duplicate(), "hints_taken": hints_taken.duplicate(), "korean_words": korean_words.duplicate(),
			"openings": openings.duplicate(true), "order_situations": order_situations, "opener_situations": opener_situations,
		},
		"regulars": {
			"on_the_books": regular_pulls.size(), "founding": founding_regulars, "in_tonight": regulars_in,
			"became": became_regulars, "faded": faded_regulars, "pulls": regular_pulls.duplicate(),
			"verdicts": verdicts.duplicate(), "memories_failed": memories_failed, "friendlier_moments": friendlier_moments,
		},
		"captions": {"shown": captions.duplicate(), "held_back": captions_held_back,
			"reactions": {"asked": reactions_asked, "shown": reactions_shown.duplicate(), "none": reactions_none, "dropped": reactions_dropped, "put_off": reactions_put_off, "skipped": reactions_skipped}},
		"food": {
			"ordered": ordered.duplicate(), "first_orders": first_orders, "extra_orders": extra_orders,
			"specials": specials.duplicate(), "cravings": cravings, "sides_added": sides_added,
			"dishes_cooked": dishes_cooked,
			"food_wait_minutes": {"average": average(food_waits), "longest": longest(food_waits)},
		},
		"ai": {
			"calls": ai_calls, "average_seconds": average(ai_seconds), "longest_seconds": longest(ai_seconds),
			"rejected": rejected, "rejections": rejections.duplicate(), "gave_up": gave_up, "gave_up_by": gave_up_by.duplicate(),
			"rejection_reasons": rejection_reasons.duplicate(true), "stale_redone": stale_redone,
		},
		"time": {
			"real_seconds": real_seconds,
			"voice_busy_percent": percent(voice_busy_seconds, real_seconds),
			"waiting_on_voice_percent": percent(waiting_on_voice_seconds, real_seconds),
		},
	}


## Writes the night's log: stats/<date>_<bar>_night<N>.json. Returns the file's path, or ""
## if it couldn't be written.
func save(context: Dictionary, bar_id: String, night: int) -> String:
	DirAccess.make_dir_recursive_absolute(folder)
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "").replace(" ", "_").left(15)
	var path := folder.path_join("%s_%s_night%d.json" % [stamp, bar_id, night])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(summary(context), "\t"))
	file.close()
	return path
