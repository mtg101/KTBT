extends RefCounted
## TV captions on screen: popping one up over whoever it's about (or a spot, or the middle of
## the tent), replacing the last, with its sound sting and a line in the transcript; pacing
## them so they stay a treat (and routine ones wait while a reaction's up); and the red light
## for an emergency. The tent's scene decides what deserves one (events, the AI's reaction
## check) and fills in the blanks; this paces and shows them, and counts them in the stats.
## (Part 6 of splitting visit.gd: see PLAN.md, "A proper refactor".)

const Captions = preload("res://scripts/rules/captions.gd")
const CaptionPopup = preload("res://scripts/ui/caption.gd")
const Draw = preload("res://scripts/bar/draw.gd")
const Night = preload("res://scripts/bar/night.gd")
const Hooks = preload("res://scripts/test_hooks.gd")

var night: Night  # tonight (its stats)
var layer: Control  # TV captions, over everything
var red_frame: Panel  # flashes round the tent for an emergency
var shown: Control  # the one up now (a new one replaces it)
var stage_width := 0.0
var last := -1.0  # real seconds when the last caption showed (-1: none yet)
var last_kind := {}  # kind -> real seconds when one of those last showed
var red_flashes := 0  # emergencies flashed (for tests)
var reaction_last := -1.0  # real seconds when the last reaction showed
var reaction_until := -1.0  # ...and until when it's up
var transcript: Callable  # shows a line (BBCode) in the transcript
var sting: Callable  # plays a caption's sound sting


func _init(tonight: Night, width: float, show_line: Callable, play_sting: Callable) -> void:
	night = tonight
	stage_width = width
	transcript = show_line
	sting = play_sting


## A TV caption (Captions.CAPTIONS) for something noteworthy, its blanks filled: paced so they
## stay a treat (Captions.caption_allowed; a kind that comes up all night only now and then;
## while a reaction's up, routine ones wait), then shown and counted. about: who it's over
## (untyped: they may have walked off and been freed); spot: where instead.
func show_caption(kind: String, fill: Dictionary, about: Variant = null, spot: Vector2 = Vector2(-1, -1)) -> void:
	var data: Dictionary = Captions.CAPTIONS[kind]
	var always := bool(data.get("always", false))  # (closing early: never held back)
	if Hooks.caption_pacing and not always and randf() >= float(data.get("chance", 1.0)):
		return  # a kind that comes up all night: only now and then
	var now := Time.get_ticks_msec() / 1000.0
	var reaction_up := now < reaction_until and not bool(data["emergency"])  # a reaction's up: routine ones wait
	if Hooks.caption_pacing and not always and (reaction_up or not Captions.caption_allowed(kind, now, last, float(last_kind.get(kind, -1.0)), Draw.scaled(Captions.CAPTION_GAP), Draw.scaled(Captions.CAPTION_SAME_GAP))):
		night.stats.captions_held_back += 1
		return
	last = now
	last_kind[kind] = now
	night.stats.captions[kind] = int(night.stats.captions.get(kind, 0)) + 1
	var roll := randf()  # which of its words, for a kind with several
	pop(Captions.caption_words(kind, fill, roll), str(data["icon"]), str(data["colour"]), str(data["sound"]), bool(data["emergency"]), about, spot, Captions.CAPTION_SECONDS)


## Whether there's been long enough since the last reaction to ask for another.
func reaction_ready() -> bool:
	return not Hooks.caption_pacing or reaction_last < 0.0 or Time.get_ticks_msec() / 1000.0 - reaction_last >= Draw.scaled(Captions.REACTION_GAP)


## A reaction's going up: routine captions wait their usual gap after it, and while it's up.
func reaction_shown() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	reaction_last = now
	reaction_until = now + Draw.scaled(Captions.REACTION_SECONDS)
	last = now


## Puts a caption up: in the transcript, popped up on the stage (replacing the last), with its
## sting, and the red light for an emergency.
func pop(words: Dictionary, icon: String, colour: String, sound: String, emergency: bool, about: Variant, spot: Vector2, hold: float) -> void:
	transcript.call("[center][b][color=#%s]%s[/color][/b][/center]\n\n" % [colour, ("[TV] %s %s" % [words["hangul"], words["english"]]).replace("[", "[lb]")])
	if is_instance_valid(shown):
		shown.name = "OldCaption"  # (so it's never mistaken for the new one while it goes)
		shown.queue_free()
	var caption := CaptionPopup.new()
	caption.name = "Caption"
	caption.time_scale = Draw.scaled(1.0)
	caption.stage_width = stage_width
	if spot.x >= 0.0:
		caption.at = spot
	elif is_instance_valid(about):
		caption.at = (about as Control).position + Vector2(40, -60)
	else:
		caption.at = Vector2(stage_width / 2, 150)
	caption.setup(words, icon, Color(colour))
	layer.add_child(caption)
	caption.pop(hold)
	shown = caption
	sting.call(sound)
	if emergency:
		flash_red()


## The emergency light: the red border flashing three times round the tent.
func flash_red() -> void:
	red_flashes += 1
	red_frame.visible = true
	red_frame.modulate.a = 0.0
	var tween := red_frame.create_tween()
	for _flash in 3:
		tween.tween_property(red_frame, "modulate:a", 1.0, Draw.scaled(0.18))
		tween.tween_property(red_frame, "modulate:a", 0.0, Draw.scaled(0.3))
	tween.tween_callback(func(): red_frame.visible = false)
