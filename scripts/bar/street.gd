extends RefCounted
## The street in front of the tent: people walking by (alone, in twos and threes, on their
## phones, under umbrellas or running for it), and passers-by who wanted in, look at the full
## stools and walk on; and rain gear, for anyone out in tonight's weather (customers coming
## in and going home too). The tent's scene says when; this draws them and counts them.
## (Part 3 of splitting visit.gd: see PLAN.md, "A proper refactor".)

const Draw = preload("res://scripts/bar/draw.gd")
const Layout = preload("res://scripts/bar/layout.gd")
const Night = preload("res://scripts/bar/night.gd")
const PeopleView = preload("res://scripts/bar/people_view.gd")
const Looks = preload("res://scripts/rules/looks.gd")
const NightRules = preload("res://scripts/rules/night_rules.gd")
const Hooks = preload("res://scripts/test_hooks.gd")

var night: Night  # tonight: its weather, and its stats
var people: PeopleView  # who draws the people
var stage: Control  # where they walk
var strollers := 0  # people walking along the street, not coming in (also names their nodes)
var passers_by := 0  # how many have walked past tonight, wanting in (also names their nodes)
var stroll_next := 0.0  # game minutes until the next one


func _init(tonight: Night, drawing: PeopleView, on: Control) -> void:
	night = tonight
	people = drawing
	stage = on


## Time passes (game minutes, at this hour): whoever's due walks by. Catches up on everyone
## due (a slow frame, or time running fast, can cover several), so how many walk by doesn't
## depend on the frame rate; a few at most, so no crowd.
func tick(minutes: float, clock: float) -> void:
	stroll_next -= minutes
	var due := 0
	while stroll_next <= 0.0 and due < 3:
		stroll()
		stroll_next += NightRules.stroll_gap(int(clock), randf())
		due += 1
	stroll_next = maxf(stroll_next, 0.0)


## Someone walking along the street, not coming in: a dark figure on the pavement in front
## of the tent, at their own pace. Some are in twos or threes, walking together; plenty are on
## their phones. If it's raining or snowing they have an umbrella (of their own shape and
## size), or now and then none, and run for it (see Looks.rain_gear); a pair sometimes
## shares one. gear and company: instead of the dice (for tests; company 0: the dice).
func stroll(gear: Dictionary = {}, company: int = 0) -> void:
	var from_left := randi() % 2 == 0
	var count := company if company > 0 else Looks.street_company(randf())
	var shared := count == 2 and gear.is_empty() and Looks.wet(night.weather_kind) and randf() < Looks.SHARED_UMBRELLA_CHANCE
	var seconds := randf_range(6.0, 10.0)
	var gap := 46.0 if shared else 62.0  # (closer under one umbrella)
	night.stats.record_street({1: "alone", 2: "in twos", 3: "in threes"}.get(count, "in a group"))
	if shared:
		night.stats.record_street("sharing an umbrella")
	for i in count:
		var own := gear
		if shared:
			# One big umbrella, held by the first, out over the space between them.
			own = {"umbrella": true, "shape": "wide", "size": 1.12, "tilt": 0.0, "reach": gap / 2.0 * (-1.0 if from_left else 1.0)} if i == 0 else {"none": true}
		elif own.is_empty():
			own = Looks.rain_gear(night.weather_kind, randf(), randf(), randf())
		if count > 1 and not own.is_empty() and not own.has("none") and not bool(own["umbrella"]):
			own = Looks.rain_gear(night.weather_kind, 1.0, randf(), randf())  # (friends don't run off and leave each other)
		# Following on behind (from where they're walking from), a little up or down the pavement.
		var behind := gap * i * (-1.0 if from_left else 1.0)
		_stroller(from_left, behind, (-6.0 if i % 2 == 1 else 4.0) * signf(i), own, count == 1, seconds)


func _stroller(from_left: bool, behind: float, up: float, gear: Dictionary, alone: bool, seconds: float) -> void:
	strollers += 1
	var shade: Color = PeopleView.CUSTOMER_COLORS.pick_random().darkened(0.55)
	var start_x := (Layout.OFFSCREEN_LEFT_X if from_left else Layout.OFFSCREEN_RIGHT_X) + behind
	var person := people.new_person(stage, Vector2(start_x, Layout.STROLL_Y + up), shade)
	person.name = "Stroller%d" % strollers
	people.dress(person, street_look())
	person.z_index = 1  # in front of the counter and stools
	person.modulate = Color(0.42, 0.42, 0.5, 0.92)  # darker: out in the street, in front of the light
	if not gear.has("none"):
		gear_up(person, gear, from_left)
	var running := people.is_running(person)
	night.stats.record_street("walked by")
	if Looks.on_phone(alone, running, randf()):
		people.add_phone(person)
		night.stats.record_street("on a phone")
	var tween := person.create_tween()
	tween.tween_property(person, "position:x", (Layout.OFFSCREEN_RIGHT_X if from_left else Layout.OFFSCREEN_LEFT_X) + behind,
		Draw.scaled(randf_range(2.4, 3.4) if running else seconds))
	tween.tween_callback(person.queue_free)


## A passer-by in the street: they slow down at the tent, look in, and carry on. Runs by
## itself; the owner doesn't stop for it.
func walk_past(delay: float) -> void:
	passers_by += 1
	var from_left := randi() % 2 == 0
	var person := people.new_person(stage, Vector2(Layout.OFFSCREEN_LEFT_X if from_left else Layout.OFFSCREEN_RIGHT_X, Layout.CUSTOMER_Y), PeopleView.CUSTOMER_COLORS.pick_random().darkened(0.35))
	person.name = "PasserBy%d" % passers_by
	people.dress(person, street_look())
	person.modulate = Color(0.7, 0.7, 0.78)
	gear_up(person, pick_rain_gear(), from_left)  # (they wanted in, so they're dressed for the weather like anyone)
	var tween := stage.create_tween()
	tween.tween_interval(Draw.scaled(delay))
	tween.tween_property(person, "position:x", Layout.PEEK_X, Draw.scaled(2.2)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_interval(Draw.scaled(0.9))  # a look at the full stools...
	tween.tween_property(person, "position:x", Layout.OFFSCREEN_RIGHT_X if from_left else Layout.OFFSCREEN_LEFT_X, Draw.scaled(2.2)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(person.queue_free)


## Rain gear for someone out in tonight's weather (Looks.rain_gear; {} when it's dry).
func pick_rain_gear() -> Dictionary:
	if not Looks.wet(night.weather_kind):
		return {}
	if not Hooks.rain_gear.is_empty():
		return Hooks.rain_gear.duplicate()
	return Looks.rain_gear(night.weather_kind, randf(), randf(), randf())


## Out into the weather with this gear: the umbrella up, or running for it ({}: nothing).
## counted: in the street stats (not when a customer puts theirs back up to go).
func gear_up(person: Control, gear: Dictionary, going_right: bool, counted: bool = true) -> void:
	if gear.is_empty():
		return
	if bool(gear["umbrella"]):
		people.add_umbrella(person, gear)
	else:
		people.run_for_it(person, going_right)
	if counted:
		night.stats.record_street(("umbrella: %s" % str(gear.get("shape", "dome"))) if bool(gear["umbrella"]) else "ran for it")


## A look for someone the AI never hears about (passers-by): the game picks it all.
func street_look() -> Dictionary:
	var gender := "woman" if randf() < 0.5 else "man"
	return Looks.pick_look(gender, Looks.pick_age_range(randf()), night.weather_kind)
