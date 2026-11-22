extends RefCounted
## The night's keepsakes at 3am (PLAN.md's portraits): which big moment gets the TV-style end
## card before the diary page, and whose polaroids go on the page. Pure rules on tonight's
## events (night_events.gd timeline) and the faces kept (visit.gd _faces_kept: name -> {"key",
## "look"}); the scene shows them (captions_on_screen.gd end_card, ui/diary_page.gd).

const Names = preload("res://scripts/rules/names.gd")

const END_CARD_SECONDS := 4.5  # the end card's beat: a little longer than a reaction's
const MOST_PHOTOS := 2


## The night's biggest moment: the aired big_moment with the highest size, ties the latest
## (nearly every one's a 4); {} for none tonight.
static func biggest_moment(events: Array) -> Dictionary:
	var best := {}
	for event in events:
		if str(event.get("kind", "")) == "big_moment" and (best.is_empty() or int(event.get("size", 0)) >= int(best.get("size", 0))):
			best = event
	return best.duplicate(true)


## Whose kept face a name means: the full name, or a given name (the AI's "who" is sometimes
## just "Ji-ho"); "" for nobody.
static func whose(person_name: String, faces: Dictionary) -> String:
	if person_name == "":
		return ""
	if faces.has(person_name):
		return person_name
	for full in faces:
		if Names.given_name(str(full)) == person_name:
			return str(full)
	return ""


## How long each customer stayed tonight, in game minutes: sitting down to leaving, or to
## closing (end_at) if they never left.
static func stays(events: Array, end_at: int) -> Dictionary:
	var sat := {}
	var stayed := {}
	for event in events:
		var who := str(event.get("name", ""))
		match str(event.get("kind", "")):
			"sat_down":
				sat[who] = int(event.get("at", 0))
			"left":
				if sat.has(who):
					stayed[who] = int(stayed.get(who, 0)) + int(event.get("at", 0)) - int(sat[who])
					sat.erase(who)
	for who in sat:
		stayed[who] = int(stayed.get(who, 0)) + maxi(0, end_at - int(sat[who]))
	return stayed


## The diary page's polaroids, a polaroid or two: [{"name", "mood"}]. Whoever had the night's
## biggest moment first (the owner too); then a regular, or whoever stayed longest (the longest
## of the regulars, if there are several). Each in their biggest moment's mood if they had one,
## else "calm". Only people with a face kept; the owner never second (they're there every night).
static func polaroids(events: Array, faces: Dictionary, end_at: int, owner_name: String = "") -> Array:
	var photos: Array = []
	var moment := biggest_moment(events)
	var first := whose(str(moment.get("who", "")), faces)
	if first != "":
		photos.append({"name": first, "mood": mood_of(events, first, faces)})
	var stayed := stays(events, end_at)
	var regulars: Array = []
	for event in events:
		if str(event.get("kind", "")) == "sat_down" and str(event.get("regular", "")) != "":
			regulars.append(str(event.get("name", "")))
	var candidates: Array = stayed.keys().filter(func(who): return who != first and who != owner_name and faces.has(who))
	var picked_from: Array = candidates.filter(func(who): return who in regulars)
	if picked_from.is_empty():
		picked_from = candidates
	picked_from.sort_custom(func(a, b): return int(stayed[a]) > int(stayed[b]) or (int(stayed[a]) == int(stayed[b]) and str(a) < str(b)))
	if not picked_from.is_empty() and photos.size() < MOST_PHOTOS:
		photos.append({"name": str(picked_from[0]), "mood": mood_of(events, str(picked_from[0]), faces)})
	return photos


## Someone's kept face, for showing it after the night's gone ("Previously on…", the edit
## suite): a diary entry's faces (name -> {"key", "look"}), the person by a full or a given name,
## and the mood wanted. {"name" (their full name), "key", "look", "mood"}; {} for nobody kept
## (or an entry from before faces were kept).
static func face(faces: Dictionary, person_name: String, mood := "calm") -> Dictionary:
	var full := whose(person_name, faces)
	if full == "" or not faces[full] is Dictionary or str(faces[full].get("key", "")) == "":
		return {}
	return {"name": full, "key": str(faces[full]["key"]), "look": (faces[full].get("look", {}) as Dictionary).duplicate(true), "mood": mood if mood != "" else "calm"}


## The mood someone's face is shown in for last night: their own biggest moment's in the
## entry's moments (StoryKeeper facts: {"who", "mood"}), or "calm" (a mood with no face is drawn calm).
static func last_mood(moments: Array, person_name: String, faces: Dictionary) -> String:
	var full := whose(person_name, faces)
	for moment in moments:
		if full != "" and whose(str(moment.get("who", "")), faces) == full and str(moment.get("mood", "")) != "":
			return str(moment["mood"])
	return "calm"


## Someone's face for their polaroid: their own biggest moment's mood (as it aired), or "calm".
static func mood_of(events: Array, person_name: String, faces: Dictionary) -> String:
	var theirs: Array = events.filter(func(e): return str(e.get("kind", "")) == "big_moment" and whose(str(e.get("who", "")), faces) == person_name)
	var best := biggest_moment(theirs)
	return str(best.get("mood", "calm")) if not best.is_empty() else "calm"
