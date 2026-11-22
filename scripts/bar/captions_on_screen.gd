extends RefCounted
## TV captions on screen: popping one up over whoever it's about (or a spot, or the middle of
## the tent), replacing the last, with its sound sting and a line in the transcript; pacing
## them so they stay a treat (and routine ones wait while a reaction's up); and the red light
## for an emergency. The tent's scene decides what deserves one (events, the AI's reaction
## check) and fills in the blanks; this paces and shows them, and counts them in the stats.
## (Part 6 of splitting visit.gd: see DEVLOG.md, 16 November 2026.)

const Captions = preload("res://scripts/rules/captions.gd")
const CaptionPopup = preload("res://scripts/ui/caption.gd")
const Draw = preload("res://scripts/bar/draw.gd")
const Night = preload("res://scripts/bar/night.gd")
const Hooks = preload("res://scripts/test_hooks.gd")
const FaceSticker = preload("res://scripts/ui/face_sticker.gd")
const ClipartSticker = preload("res://scripts/ui/clipart_sticker.gd")
const Clipart = preload("res://scripts/rules/clipart.gd")
const Art = preload("res://scripts/ui/art.gd")
const ZOOM_DIM := Color(0.04, 0.03, 0.1, 0.72)  # the zoom's window, behind the caption
const DebugLog = preload("res://scripts/debug_log.gd")

var night: Night  # tonight (its stats)
var layer: Control  # TV captions, over everything
var red_frame: Panel  # flashes round the tent for an emergency
var shown: Control  # the one up now (a new one replaces it)
var shown_zoom: Control  # its zoom's dimmed window, if it's a zoom
var stuck: Array = []  # its clipart on people on stage (a new caption takes them off)
var zoom_layer: Control  # the whole window, for a zoom (the tent's scene)
var screen := Vector2(1920, 1080)
var bubble_layer: Control  # the speech bubbles, cleared for a zoom's beat
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
## (untyped: they may have walked off and been freed); spot: where instead; faces: slapped on
## (see pop).
func show_caption(kind: String, fill: Dictionary, about: Variant = null, spot: Vector2 = Vector2(-1, -1), faces: Array = []) -> void:
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
	pop(Captions.caption_words(kind, fill, roll), str(data["icon"]), str(data["colour"]), str(data["sound"]), bool(data["emergency"]), about, spot, Captions.CAPTION_SECONDS, faces, false, kind)


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
## sting, and the red light for an emergency. faces: [{"texture", "name", "mood", "how"}] slapped
## onto it (ui/face_sticker.gd; how: "mood" its own face, "calm" the plain one asked for,
## "stood_in" the plain one for a missing mood face), [] for none; zoom: the caption and its
## faces big over the whole window instead, dimmed behind. Whoever's face is on it gets the
## edit's clipart stuck to them on stage too (_stick_clipart); kind: the caption's ("" for an AI
## reaction, which has only its mood).
func pop(words: Dictionary, icon: String, colour: String, sound: String, emergency: bool, about: Variant, spot: Vector2, hold: float, faces: Array = [], zoom := false, kind := "") -> void:
	transcript.call("[center][b][color=#%s]%s[/color][/b][/center]\n\n" % [colour, ("[TV] %s %s" % [words["hangul"], words["english"]]).replace("[", "[lb]")])
	if is_instance_valid(shown):
		shown.name = "OldCaption"  # (so it's never mistaken for the new one while it goes)
		shown.queue_free()
	if is_instance_valid(shown_zoom):
		shown_zoom.name = "OldZoom"
		shown_zoom.queue_free()
	shown_zoom = null
	zoom = zoom and not faces.is_empty() and is_instance_valid(zoom_layer)
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
	var roll := randf()  # (the face's look and lean: scenery, not the night's own dice)
	var clip := _clipart_for(faces, kind, emergency)
	var face: FaceSticker = null
	if not faces.is_empty():
		face = FaceSticker.new()
		face.setup(faces, Color(colour), roll, zoom, clip, hold)
	if zoom:
		caption.stage_width = screen.x
		caption.at = Vector2(screen.x / 2, screen.y * 0.78)
		shown_zoom = _zoom_behind(hold)
	caption.setup(words, icon, Color(colour), face, caption.at.x >= (screen.x if zoom else stage_width) / 2)  # (the face on the side nearer the middle)
	(shown_zoom if zoom else layer).add_child(caption)
	caption.pop(hold)
	shown = caption
	if face != null:
		_count_faces(faces, zoom, words)
	_stick_clipart(faces, clip, hold, zoom)
	sting.call(sound)
	if emergency:
		flash_red()


## The edit's clipart for a caption with faces (rules/clipart.gd: the caption kind's own, the
## siren for an emergency, else its face's mood's), "" for none; one whose art isn't there is
## counted "missing" and noted, and none goes up. Counted and noted once a caption.
func _clipart_for(faces: Array, kind: String, emergency: bool) -> String:
	if faces.is_empty():
		return ""
	var clip := Clipart.pick(kind, str(faces[0].get("mood", "calm")), emergency, randf())  # (scenery's roll, as the face's look)
	if clip == "":
		return ""
	var clips: Dictionary = night.stats.clipart
	for key in Clipart.frame_keys(clip):
		if not Art.has(str(key)):
			clips["missing"] = int(clips.get("missing", 0)) + 1
			DebugLog.say("Clipart", "no art for the %s clipart (draw it: tools/art/clipart.py, then import in Godot)" % clip)
			return ""
	clips[clip] = int(clips.get(clip, 0)) + 1
	DebugLog.say("Clipart", "%s on %s's face%s (%s)" % [clip, " and ".join(PackedStringArray(faces.map(func(f): return str(f.get("name", "?"))))),
		"s" if faces.size() > 1 else "", kind if kind != "" else "a big moment"])
	return clip


## The caption's clipart stuck to each person whose face is on it, on stage too, for its beat
## (after a zoom: once the zoom's gone, so it's seen). The last caption's comes off first.
func _stick_clipart(faces: Array, clip: String, hold: float, zoom: bool) -> void:
	for old in stuck:
		if is_instance_valid(old):
			old.name = "OldClipart"
			old.queue_free()
	stuck = []
	if clip == "":
		return
	for person in faces.filter(func(f): return f.get("node") is Control and is_instance_valid(f.get("node"))):
		var sticker := ClipartSticker.new()
		if not sticker.setup(clip):
			sticker.free()
			return
		sticker.time_scale = Draw.scaled(1.0)
		sticker.stick(person["node"], hold, hold if zoom else 0.0)
		stuck.append(sticker)


## A zoom's window: dimmed behind the caption (freed with it), the speech bubbles faded for its beat.
func _zoom_behind(hold: float) -> Control:
	var zoom := Control.new()
	zoom.name = "TvZoom"
	zoom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom.size = screen
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = ZOOM_DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.size = screen
	zoom.add_child(dim)
	zoom_layer.add_child(zoom)
	zoom.modulate.a = 0.0
	var tween := zoom.create_tween()
	tween.tween_property(zoom, "modulate:a", 1.0, Draw.scaled(0.15))
	tween.tween_interval(Draw.scaled(maxf(0.0, hold - 0.55)))
	tween.tween_property(zoom, "modulate:a", 0.0, Draw.scaled(0.4))
	tween.tween_callback(zoom.queue_free)
	_clear_bubbles(hold)
	return zoom


## Faces on a caption, counted and noted.
func _count_faces(faces: Array, zoom: bool, words: Dictionary) -> void:
	var stings: Dictionary = night.stats.stings
	stings["zoom" if zoom else "beside"] = int(stings.get("zoom" if zoom else "beside", 0)) + 1
	for face in faces:
		stings[str(face.get("how", "mood"))] = int(stings.get(str(face.get("how", "mood")), 0)) + 1
	DebugLog.say("Sting", "%s «%s»: %s" % ["a zoom for" if zoom else "faces on", words.get("english", ""),
		", ".join(PackedStringArray(faces.map(func(f): return "%s (%s, %s)" % [f.get("name", "?"), f.get("mood", "?"), f.get("how", "mood")])))])


## A zoom's beat: the speech bubbles faded out while it's up, and back after.
func _clear_bubbles(hold: float) -> void:
	if not is_instance_valid(bubble_layer):
		return
	var tween := bubble_layer.create_tween()
	tween.tween_property(bubble_layer, "modulate:a", 0.0, Draw.scaled(0.2))
	tween.tween_interval(Draw.scaled(maxf(0.0, hold - 0.4)))
	tween.tween_property(bubble_layer, "modulate:a", 1.0, Draw.scaled(0.3))


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
