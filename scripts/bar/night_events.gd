extends RefCounted
## The night's events: everything noteworthy that happens is announced here once (someone
## walks on, sits down, pays, a dish is served, a chat starts, the cat moves, a big moment...),
## and whatever cares listens: the stats count them (NightStats.record_event), the TV captions
## pick theirs (Captions.for_event), and tonight's list of them becomes the diary's facts
## (Story.diary_facts) and goes in the night's log. A new feature that wants to know what
## happened (commentary, a season recap, the trope book) is just another listener.
##
## Each event: its kind and its facts, as plain data (names, not nodes, so the list can be
## saved); where on screen it happened is passed alongside, for the captions.

## kind, facts, and (for the captions) who it's about on screen and where.
signal happened(kind: String, facts: Dictionary, about: Variant, spot: Vector2)

const KINDS := ["arrived", "walked_on", "sat_down", "greeted", "ordered", "drinks_poured", "stove_backed", "dish_served",
	"paid", "left", "chat_started", "chat_continued", "joined_chat", "owner_joined", "cat_moved",
	"became_regular", "friendlier", "big_moment", "dawn", "last_orders", "cat_stole", "closed_early", "first_snow", "cheered_on", "table_game", "table_game_offered", "cliffhanger_answered", "menu_changed",
	"camera_on", "camera_off", "plant_played"]

var timeline: Array = []  # tonight's events, in order: {"kind", "at" (the clock), and their facts}


## Announces something that happened, at this time (game minutes).
func emit_event(kind: String, minutes: float, facts: Dictionary = {}, about: Variant = null, spot: Vector2 = Vector2(-1, -1)) -> void:
	assert(KINDS.has(kind), "unknown night event: %s" % kind)
	var entry := facts.duplicate(true)
	entry["kind"] = kind
	entry["at"] = int(minutes)
	timeline.append(entry)
	happened.emit(kind, facts, about, spot)


## Tonight's events of a kind.
func of_kind(kind: String) -> Array:
	return timeline.filter(func(e): return str(e["kind"]) == kind)
