extends Control
## A face slapped onto a TV caption, the Korean variety-show way (PLAN.md, "Using portraits"):
## whoever the caption's about (or two, overlapping), their portrait in the caption's mood
## (people_art.gd portrait()), whole pixels scaled up and never smoothed, thumped in just after
## the caption at a tilt against its own, in one of the shows' looks: a starburst (a shock, a
## roast, now and then a laugh), a white sticker's edge (sweet, sad, warm, and most others), or
## a dark TV frame; their name on a tag across the bottom. Part of the caption (caption.gd
## setup): it pops in, holds and fades with it, over whoever it's about. The zoom is the same,
## bigger, in the middle of the dimmed window (captions_on_screen.gd). Never takes a click.
## The edit's clipart, if the caption has any, on each face too (ui/clipart_sticker.gd, sized
## to the face), landing with it.

const Ktv = preload("res://scripts/ui/ktv_style.gd")
const ClipartSticker = preload("res://scripts/ui/clipart_sticker.gd")
const SCALE := 2  # beside a caption: the portrait's 64 x 80 at 128 x 160
const ZOOM_SCALE := 5  # the zoom's: 320 x 400
## Each mood's looks, picked from by the caption's roll.
const LOOKS := {"shock": ["burst"], "roast": ["burst"], "funny": ["burst", "sticker"], "sweet": ["sticker"], "sad": ["sticker", "frame"],
	"warm": ["sticker", "frame"], "awkward": ["sticker", "frame"], "calm": ["sticker", "frame"]}
const BURST_POINTS := 18
const OVERLAP := 0.1  # a second face over the first's edge, by this much of its width (its name tag still clear)
const NAME_SIZE := 20

var time_scale := 1.0  # tests run it in a blink
var look := "sticker"
var faces_shown := 0
var _colour := Color.WHITE
var _mood := ""
var _inner: Control  # the faces, free to tilt and thump (a container would straighten them)
var clip := ""  # the edit's clipart on each face ("": none)
var clip_hold := 2.6  # for how long (the caption's beat)
var _clip_spots: Array = []  # [the face's holder, its picture's rectangle], one a face


## faces: [{"texture", "name", "mood"}], one or two; colour: the caption's; roll: the caption's
## dice (which look, which way it leans); zoomed: the zoom's size; clip: the edit's clipart on
## each face ("" for none), for hold seconds.
func setup(faces: Array, colour: Color, roll: float, zoomed := false, clip_name := "", hold := 2.6) -> void:
	clip = clip_name
	clip_hold = hold
	name = "FaceSticker"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colour = colour
	_mood = str(faces[0].get("mood", "calm")) if not faces.is_empty() else "calm"
	var looks: Array = LOOKS.get(_mood, ["sticker"])
	look = str(looks[clampi(floori(roll * looks.size()), 0, looks.size() - 1)])
	_inner = Control.new()
	_inner.name = "Faces"
	_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_inner)
	var lean := -1.0 if roll < 0.5 else 1.0
	var scale_by := ZOOM_SCALE if zoomed else SCALE
	var x := 0.0
	var extent := Vector2.ZERO
	for i in faces.size():
		var face := _face(faces[i], scale_by, zoomed)
		face.position = Vector2(x, 34.0 * i)
		face.rotation = lean * (0.1 + 0.08 * i) * (1.0 if i % 2 == 0 else -1.0)
		face.pivot_offset = face.size / 2
		_inner.add_child(face)
		x += face.size.x * (1.0 - OVERLAP)
		extent = extent.max(face.position + face.size)
		faces_shown += 1
	custom_minimum_size = extent
	size = custom_minimum_size
	_inner.size = custom_minimum_size
	_inner.pivot_offset = custom_minimum_size / 2


## One face: the picture, its look drawn round it, the name tag across its bottom.
func _face(face: Dictionary, scale_by: int, zoomed: bool) -> Control:
	var texture: Texture2D = face["texture"]
	var picture_size := Vector2(texture.get_size() * scale_by)
	var pad := picture_size.x * (0.32 if look == "burst" else 0.08)
	var holder := Control.new()
	holder.name = "Face"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.size = picture_size + Vector2(pad, pad) * 2 + Vector2(0, 16)
	var picture := TextureRect.new()
	picture.name = "Picture"
	picture.texture = texture
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_SCALE
	picture.position = Vector2(pad, pad)
	picture.size = picture_size
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(picture)
	holder.draw.connect(_draw_look.bind(holder, Rect2(picture.position, picture_size)))
	_clip_spots.append([holder, Rect2(picture.position, picture_size)])
	var tag := PanelContainer.new()
	tag.name = "Tag"
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := Ktv.pill(_colour.darkened(0.25), 8, 3, 8, false)
	style.content_margin_top = 0
	style.content_margin_bottom = 1
	tag.add_theme_stylebox_override("panel", style)
	var label := Ktv.label(str(face.get("name", "")), NAME_SIZE * (2 if zoomed else 1), Color.WHITE, 5)
	label.name = "Name"
	tag.add_child(label)
	holder.add_child(tag)
	var tag_size := tag.get_combined_minimum_size()
	tag.size = tag_size
	tag.position = Vector2((holder.size.x - tag_size.x) / 2, pad + picture_size.y - tag_size.y * 0.45)
	tag.rotation = -0.04
	return holder


## The look round a face: a starburst, a sticker's white edge with its shadow, or a TV frame.
func _draw_look(holder: Control, picture: Rect2) -> void:
	match look:
		"burst":
			var middle := picture.get_center()
			var outer := picture.size.x * 0.5 + picture.size.x * 0.3
			var points := PackedVector2Array()
			for k in BURST_POINTS * 2:
				var reach := outer if k % 2 == 0 else outer * 0.74
				var angle := TAU * k / (BURST_POINTS * 2)
				points.append(middle + Vector2(cos(angle), sin(angle) * 1.12) * reach)
			holder.draw_colored_polygon(points, _colour)
			var ring := points.duplicate()
			ring.append(points[0])
			holder.draw_polyline(ring, Ktv.INK, 4.0)
			holder.draw_rect(picture.grow(5), Color.WHITE)
			holder.draw_rect(picture.grow(5), Ktv.INK, false, 3.0)
		"frame":
			holder.draw_rect(Rect2(picture.position + Vector2(5, 6), picture.size).grow(9), Ktv.SHADOW)
			holder.draw_rect(picture.grow(9), _colour)
			holder.draw_rect(picture.grow(3), Ktv.INK)
		_:  # a sticker
			holder.draw_rect(Rect2(picture.position + Vector2(6, 8), picture.size).grow(8), _colour.darkened(0.35))
			holder.draw_rect(picture.grow(8), Color.WHITE)


## Thumped in just after the caption: big, then down onto it with a bounce (a shock shakes).
func slam(delay: float) -> void:
	_inner.scale = Vector2(1.7, 1.7)
	_inner.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_interval(delay * time_scale)
	tween.tween_property(_inner, "modulate:a", 1.0, 0.05 * time_scale)
	tween.parallel().tween_property(_inner, "scale", Vector2.ONE, 0.22 * time_scale).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_stick_clipart(delay)
	if _mood == "shock":
		for shake in [7.0, -6.0, 4.0, 0.0]:
			tween.tween_property(_inner, "position:x", shake, 0.04 * time_scale)


## The edit's clipart on each face, sized to it, landing with the faces (after delay).
func _stick_clipart(delay: float) -> void:
	if clip == "":
		return
	for spot in _clip_spots:
		var holder: Control = spot[0]
		var picture: Rect2 = spot[1]
		var sticker := ClipartSticker.new()
		if not sticker.setup(clip, ClipartSticker.pixel_for_face(clip, picture.size.x)):
			sticker.free()
			return
		sticker.time_scale = time_scale
		sticker.stick(holder, clip_hold, delay, picture)
