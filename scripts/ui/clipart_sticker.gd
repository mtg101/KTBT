extends Control
## The edit's clipart stuck to someone on stage, the Korean variety-show way (PLAN.md,
## "Variety-show clipart"): a crow flapping across an awkward silence, a rain cloud over someone
## sad, hearts floating up, flames behind a bill fight. Which one, where it sits on them and how
## it moves are the rules' (rules/clipart.gd); its frames are drawn in code (tools/art/clipart.py).
## A child of the person, so it follows them for the caption's beat wherever they go; drawn
## behind them for "behind", over them otherwise; whole pixels, unlit (the edit's, not the
## tent's). The same goes on their face on the TV pop (ui/face_sticker.gd), sized to the face
## (stick with a close-up: the portrait's rectangle). Its Hangul, if it has any, written beside
## it and explained on hover.

const Art = preload("res://scripts/ui/art.gd")
const Clipart = preload("res://scripts/rules/clipart.gd")
const Hangul = preload("res://scripts/rules/hangul.gd")
const Ktv = preload("res://scripts/ui/ktv_style.gd")
const Layout = preload("res://scripts/bar/layout.gd")
const Text = preload("res://scripts/rules/text.gd")
const SCALE := 3  # a pixel to 3, as the people
const ACROSS := 150.0  # flying across: from this far one side of them to this far the other
const RISE := 54.0  # floating up: this far over the beat
const FADE := 0.3
const WORDS_SIZE := 22
## On a face: how wide each place's clipart is against the face (the pixels as near as whole).
const ON_FACE := {"over": 0.7, "face": 0.8, "beside": 0.45, "chest": 0.9, "behind": 1.7, "feet": 0.6}

var clip := ""
var time_scale := 1.0  # tests run it in a blink
var frame := 0
var pixel := SCALE  # its pixels, this many screen pixels each
var _frames: Array = []  # Texture2D, in order
var _picture: TextureRect
var _elapsed := 0.0


## Builds it for a clipart: false (and nothing built) if any of its frames has no image.
## pixel: how big its pixels are (on stage, as the people's).
func setup(clip_name: String, pixel_size := SCALE) -> bool:
	for key in Clipart.frame_keys(clip_name):
		var texture := Art.texture(key)
		if texture == null:
			return false
		_frames.append(texture)
	if _frames.is_empty():
		return false
	clip = clip_name
	name = "Clipart"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture = TextureRect.new()
	_picture.name = "Picture"
	_picture.texture = _frames[0]
	_picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pixel = pixel_size
	size = (_frames[0] as Texture2D).get_size() * pixel
	_picture.size = size
	add_child(_picture)
	for key in Clipart.frame_keys(clip):
		Art.used[key] = "image"
	var hangul := Clipart.hangul(clip)
	if hangul != "":
		var tip := Text.tip("%s: %s" % [hangul, Hangul.MEANINGS.get(hangul, "")])
		if Clipart.labelled(clip):
			var words := Ktv.label(hangul, WORDS_SIZE if pixel <= SCALE else WORDS_SIZE * 2, Color.WHITE, 6)
			words.name = "Words"
			words.mouse_filter = Control.MOUSE_FILTER_PASS  # (its hover: only the words take the mouse)
			words.tooltip_text = tip
			add_child(words)
			words.reset_size()
			words.position = Vector2((size.x - words.size.x) / 2, -words.size.y - 2).round()
		else:  # (the drawing is the words: ㅋㅋㅋ)
			_picture.mouse_filter = Control.MOUSE_FILTER_PASS
			_picture.tooltip_text = tip
	return true


## Its pixels' size to fit a face (on_face: the face's width) for a clipart, by where it goes.
static func pixel_for_face(clip_name: String, face_width: float) -> int:
	var keys := Clipart.frame_keys(clip_name)
	var first := Art.texture(str(keys[0])) if not keys.is_empty() else null
	if first == null:
		return SCALE
	return maxi(2, roundi(face_width * float(ON_FACE.get(Clipart.place(clip_name), 0.7)) / first.get_size().x))


## Sticks it on a person for hold seconds (after delay: a zoom's beat first): placed by the
## rules, looping its frames, drifting if it drifts, then fading and freed. close_up: on a face
## instead (the portrait's rectangle in the person's place: places go by the face).
func stick(person: Control, hold: float, delay := 0.0, close_up := Rect2()) -> void:
	var place := Clipart.place(clip)
	var on_face := close_up.size != Vector2.ZERO
	var start := (face_spot(place, size, close_up) if on_face else spot(place, size)) - size / 2
	var across := close_up.size.x * 0.6 if on_face else ACROSS
	var rise := close_up.size.y * 0.3 if on_face else RISE
	position = start.round()
	show_behind_parent = place == "behind"
	person.add_child(self)
	modulate.a = 0.0
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay * time_scale)
	tween.tween_property(self, "modulate:a", 1.0, 0.1 * time_scale)
	match Clipart.drift(clip):
		"across":
			position.x = (start.x - across)
			tween.parallel().tween_property(self, "position:x", start.x + across, hold * time_scale)
		"up":
			tween.parallel().tween_property(self, "position:y", start.y - rise, hold * time_scale).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_interval(maxf(0.0, hold - 0.1 - FADE) * time_scale if Clipart.drift(clip) == "" else 0.0)
	tween.tween_property(self, "modulate:a", 0.0, FADE * time_scale)
	tween.tween_callback(queue_free)


## Where its middle goes on a person (their own coordinates: Layout.PERSON_SIZE, feet at the
## bottom), by the rules' place: over their head, by their face, beside their head, through the
## chest, behind their head and shoulders, at their feet.
static func spot(place: String, clip_size: Vector2) -> Vector2:
	var middle := Layout.PERSON_SIZE.x / 2
	match place:
		"face":
			return Vector2(middle, 42)
		"beside":
			return Vector2(Layout.PERSON_SIZE.x + clip_size.x / 2 - 12, 20)
		"chest":
			return Vector2(middle, 100)
		"behind":
			return Vector2(middle, 54)
		"feet":
			return Vector2(middle, Layout.PERSON_SIZE.y - clip_size.y / 2)
	return Vector2(middle, -clip_size.y / 2 - 6)  # "over"


## Where its middle goes on a face (box: the portrait, head and shoulders, the head filling its
## top): over the top of the head, on the face, beside the head, the chest, behind the whole
## face (peeking round the sticker's edge), the bottom.
static func face_spot(place: String, clip_size: Vector2, box: Rect2) -> Vector2:
	var middle := box.get_center().x
	match place:
		"face":
			return Vector2(middle, box.position.y + box.size.y * 0.5)
		"beside":
			return Vector2(box.end.x - clip_size.x * 0.15, box.position.y + box.size.y * 0.22)
		"chest":
			return Vector2(middle, box.position.y + box.size.y * 0.86)
		"behind":
			return box.get_center()
		"feet":
			return Vector2(middle, box.end.y - clip_size.y / 2)
	return Vector2(middle, box.position.y + clip_size.y * 0.2)  # "over": over the top of the head, overlapping it


func _process(delta: float) -> void:
	if _frames.size() < 2:
		return
	_elapsed += delta
	var now := int(_elapsed / maxf(time_scale, 0.0001) * float(Clipart.CLIPS[clip]["fps"])) % _frames.size()
	if now != frame:
		frame = now
		_picture.texture = _frames[frame]
