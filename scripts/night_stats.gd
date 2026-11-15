extends RefCounted
## Debug stats for one night, for testing and tuning: who came, how much talking there was
## (owner and customer chats), how long people waited, and how the AI did. The visit scene
## counts things as they happen; this shows them in the stats panel and, when the night
## ends (or the bar's closed partway through), writes them to a log file in stats/ in the
## user data folder, one per night, to compare runs.

const Text = preload("res://scripts/rules/text.gd")

## Where the logs go. Tests point this at their own folder.
static var folder := "user://stats/"

# People
var arrived := 0
var served := 0  # paid and left
var walked_past := 0  # gave up waiting for a stool
var peak_seated := 0
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
var reactions_skipped := 0  # ...not asked, because someone was waiting for the owner

# Food
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
	lines.append("Greetings: %d proper, %d quick" % [proper_greetings, quick_greetings])
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
	lines.append("Reactions: asked %d · shown %d%s · none %d · dropped %d · skipped (busy) %d" % [reactions_asked, shown_reactions,
		(" (" + ", ".join(PackedStringArray(reactions_shown.keys().map(func(k): return "%s %d" % [k, int(reactions_shown[k])]))) + ")") if not reactions_shown.is_empty() else "",
		reactions_none, reactions_dropped, reactions_skipped])
	lines.append("")
	lines.append("[b]FOOD[/b]")
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
	lines.append("Real time tonight: %d:%02d" % [floori(real_seconds / 60.0), int(real_seconds) % 60])
	return "\n".join(lines)


## Everything, for the log file. context: which bar and night, AI settings and so on.
func summary(context: Dictionary) -> Dictionary:
	return {
		"context": context,
		"people": {
			"arrived": arrived, "served": served, "walked_past": walked_past, "peak_seated": peak_seated,
			"average_seated": average_seated(), "two_or_more_percent": percent(together_seconds, real_seconds),
			"quick_greetings": quick_greetings, "proper_greetings": proper_greetings,
			"greet_wait_minutes": {"average": average(greet_waits), "longest": longest(greet_waits)},
			"first_drinks_wait_minutes": {"average": average(serve_waits), "longest": longest(serve_waits)},
			"owner_lines_each": {"average": average(owner_lines_each), "fewest": shortest(owner_lines_each), "most": longest(owner_lines_each)},
		},
		"talk": {
			"owner_lines": owner_lines, "chat_lines": chat_lines, "chats_started": chats_started,
			"owner_joins": owner_joins, "customer_joins": customer_joins,
			"chat_chances": chat_chances, "chats_continued": chats_continued, "free_turns": free_turns,
			"chat_percent": percent(chat_lines, owner_lines + chat_lines),
		},
		"regulars": {
			"on_the_books": regular_pulls.size(), "founding": founding_regulars, "in_tonight": regulars_in,
			"became": became_regulars, "faded": faded_regulars, "pulls": regular_pulls.duplicate(),
			"verdicts": verdicts.duplicate(), "memories_failed": memories_failed, "friendlier_moments": friendlier_moments,
		},
		"captions": {"shown": captions.duplicate(), "held_back": captions_held_back,
			"reactions": {"asked": reactions_asked, "shown": reactions_shown.duplicate(), "none": reactions_none, "dropped": reactions_dropped, "skipped": reactions_skipped}},
		"food": {
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
