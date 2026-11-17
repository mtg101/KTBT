extends RefCounted
## The PD's camera: who the show is following tonight. The player clicks a customer (or the
## cat) to follow them, and again to stop; doing nothing is fine, and the night runs as it
## always has. Following someone gives their story more airtime, since the one AI voice is
## what's scarce: the owner sees to them sooner, and the counter's chats lean their way.
## Following the cat, the airtime goes to whoever it's with, and it wanders sooner. Everyone
## knows they're on a show, so the first time the camera turns to someone tonight, they
## notice: a moment for their next line (Talk.camera_moment), never the words.
## The tent's scene handles the clicks, the viewfinder, the narration and the stats; this decides.

const Talk = preload("res://scripts/rules/talk.gd")

## The owner sees to whoever's followed as if they'd waited this many turns longer (someone
## here to talk to the owner gets 3).
const PULL := 3
## Followed, the cat stays put for this much of its usual time: more happens around it.
const CAT_RESTLESS := 0.5

var following: Variant = null  # the Guest the camera's on, or null
var on_cat := false  # ... or it's on the cat
var cat: Variant = null  # the tent's cat (bar/cat.gd), for who it's with
var noticed: Array = []  # names who've had their "the camera's on me" moment tonight (once each)


## Follow someone (whoever was followed before is dropped). Gives them their moment of
## noticing, the first time tonight. Returns who was followed before: a Guest, "cat" or null.
func follow(guest: Variant) -> Variant:
	var previous: Variant = stop()
	following = guest
	var named := str(guest.customer["name"])
	if not noticed.has(named):
		noticed.append(named)
		guest.camera_moment = Talk.camera_moment(named)
	return previous


## Follow the cat. Returns who was followed before (as follow does).
func follow_cat() -> Variant:
	var previous: Variant = stop()
	on_cat = true
	return previous


## Stop following, returning who it was: a Guest, "cat", or null.
func stop() -> Variant:
	var was: Variant = "cat" if on_cat else following
	following = null
	on_cat = false
	return was


func is_on(guest: Variant) -> bool:
	return guest != null and following == guest


## Whose story the camera's getting tonight, right now: the one followed, or whoever the cat's
## with (null: the cat's on its own, or nobody's followed).
func subject() -> Variant:
	if on_cat:
		return cat.with_guest if cat != null else null
	return following


## How soon the owner gets to someone (lower: sooner), with the camera's pull.
func neediness(guest: Variant, base: int) -> int:
	return base - (PULL if guest != null and subject() == guest else 0)


## Of the chats that could carry on, the one the camera's on (if it's in one), or the one picked.
func choose_chat(ongoing: Array, picked: Variant) -> Variant:
	var who: Variant = subject()
	if who == null:
		return picked
	for chat in ongoing:
		if chat.people.has(who):
			return chat
	return picked


## People about to start a chat: the one the camera's on first, if they're among them.
func put_first(people: Array) -> Array:
	var who: Variant = subject()
	if who == null or not people.has(who):
		return people
	var ordered := people.duplicate()
	ordered.erase(who)
	ordered.push_front(who)
	return ordered


## Whether a line (said among these people) was on camera.
func on_camera(people: Array) -> bool:
	var who: Variant = subject()
	return who != null and people.has(who)


## How long the cat stays put (game minutes): shorter while it's followed.
func cat_stay(minutes: float) -> float:
	return minutes * CAT_RESTLESS if on_cat else minutes
