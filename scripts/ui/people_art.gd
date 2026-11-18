extends RefCounted
## People in pixel art (ART.md, "People"): a person's picture, facing us or from behind, built
## from the layers in the art folder ("person/front_body_suit", "person/back_hair_bob"...: drawn
## in code by tools/art/people.py) in the order they stack, each pixel painted onto the light
## ramp of what it's made of: their skin, their hair's colour, their clothes' colour, or one of
## the FIXED colours (a white shirt, a red tie, the apron...). So one haircut serves every hair
## colour, and a regular looks the same every visit (it's all from their look: rules/looks.gd).
## Without the layers it needs (no body or head for this look), null: people_view.gd draws the
## shapes as before.

const Art = preload("res://scripts/ui/art.gd")
const Looks = preload("res://scripts/rules/looks.gd")

const SIZE := Vector2i(32, 72)  # a person on the grid (96 x 216 on the stage, a pixel to 3: Layout.PERSON_SIZE)
const SEATED_DOWN := 2  # seated, from behind, they're drawn this many rows lower (tools/art/people.py: no taller than standing)
const BREATHE_FROM := 28  # standing: the rows above this (head and shoulders) rise as they breathe
const NECK_ROWS := 21  # the head and neck, to the shoulders' line (tools/art/people.py TOP)
const STOOP := 2  # the oldest: their head this many rows lower, sunk a little into their shoulders
const SCALE := 3

## What a layer's pixel is made of (its green, over 36), and, for FIXED, which (its blue, over 8).
const FIXED_SLOT := 0
const SKIN := 1
const HAIR := 2
const CLOTH := 3
## Colours that are always the same (tools/art/people.py names them, in this order): trousers,
## ink (eyes, shoes, glasses), a white shirt, a blue shirt, a tie, a cream top, gold buttons, the
## apron, a strap, a tote, a backpack, a hair tie, a briefcase.
const FIXED := ["2a2a33", "1a1a20", "eef0f2", "9cc4e4", "8a2a35", "efe6d2", "f2c14a", "f5f2ea", "8a5a33", "cdb894",
	"3a3946", "c8443a", "5a3a2a"]

## The light ramp's steps (tools/art/palette.py: LEVELS, the same sums): deep shadow to highlight.
const LEVELS := [0.22, 0.36, 0.52, 0.72, 1.0, 1.22, 1.42]
const BASE_STEP := 4

static var _cache := {}  # (look, view) -> ImageTexture or null
static var _ramps := {}  # colour -> its 7 steps


## The layer ids a person is built from, back to front.
static func layers_for(look: Dictionary, view: String, frame: int = 0, holding: String = "") -> Array:
	var hair := str(look.get("hair", "short"))
	var ids: Array = []
	if view == "side":
		return side_layers(look, frame, holding)
	if hair == "long":
		ids.append("%s_hairback_long" % view)
	ids.append("%s_body_%s" % [view, str(look.get("clothes", "knit"))])
	if bool(look.get("apron", false)):
		ids.append("%s_apron" % view)
	var bag := str(look.get("bag", ""))
	if view == "front" and bag in ["tote", "briefcase"]:
		ids.append("front_" + bag)
	var old: bool = str(look.get("age_range", "")) in ["60s", "70s"]
	ids.append("front_head_old" if view == "front" and old else "%s_head" % view)
	ids.append("%s_hair_%s" % [view, hair])
	if view == "front" and bool(look.get("glasses", false)):
		ids.append("front_glasses")
	if bag == "backpack":
		ids.append("%s_backpack" % view)
	if view == "front" and holding == "phone":
		ids.append("front_arm_phone_bare" if str(look.get("clothes", "")) in ["tshirt", "scrubs"] else "front_arm_phone")
	return ids


## From the side, walking (facing right; mirrored to walk left), frame 0 to 3 of a stride: the far
## arm, the legs, the body, what's carried, the head and hair, glasses, the near arm.
const WALK_FRAMES := 4

static func side_layers(look: Dictionary, frame: int, holding: String = "") -> Array:
	var clothes := str(look.get("clothes", "knit"))
	var arm := "side_arm_bare" if clothes in ["tshirt", "scrubs"] else "side_arm"  # (short sleeves)
	var ids: Array = ["%s_far_%d" % [arm, frame], "side_legs_%d" % frame, "side_body_" + clothes]
	if bool(look.get("apron", false)):
		ids.append("side_apron")
	var bag := str(look.get("bag", ""))
	if bag in ["tote", "backpack"]:
		ids.append("side_" + bag)
	ids.append("side_head_old" if str(look.get("age_range", "")) in ["60s", "70s"] else "side_head")
	ids.append("side_hair_" + str(look.get("hair", "short")))
	if bool(look.get("glasses", false)):
		ids.append("side_glasses")
	if holding == "phone":  # (the near arm up, holding the phone in front of their face)
		ids.append("side_arm_phone_bare" if arm == "side_arm_bare" else "side_arm_phone")
	else:
		ids.append("%s_%d" % [arm, frame])
	if bag == "briefcase":
		ids.append("side_briefcase_%d" % frame)  # (in the near hand, swinging with it)
	return ids


## The person's picture (SIZE, its pixels a grid's), or null if a layer it needs isn't there.
## view: "front", "back" or "side" (with frame, of the stride).
## holding: "phone" for someone on their phone (the arm it's in bent up to hold it).
static func texture(look: Dictionary, view: String, frame: int = 0, holding: String = "") -> ImageTexture:
	var key := "%s%d%s|%s" % [view, frame, holding, JSON.stringify(look, "", true)]
	if _cache.has(key):
		return _cache[key]
	var picture := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	var colours := {
		SKIN: Color(Looks.SKIN_TONES[clampi(int(look.get("skin", 0)), 0, Looks.SKIN_TONES.size() - 1)]),
		HAIR: Color(str(Looks.HAIR_COLOURS.get(look.get("hair_colour", "black"), Looks.HAIR_COLOURS["black"])[0])),
		CLOTH: Color(str(Looks.CLOTHES_COLOURS.get(look.get("colour", "black"), Looks.CLOTHES_COLOURS["black"])[0])),
	}
	var made: ImageTexture = null
	var complete := true
	for id in layers_for(look, view, frame, holding):
		var layer := Art.texture("person/" + str(id))
		if str(id).begins_with("front_arm_phone"):
			_clear(picture, ARM_CLEAR)  # (the arm hanging at their side goes: it's up holding the phone)
		if layer == null:
			if str(id).contains("_body_") or str(id).ends_with("_head") or str(id).ends_with("_head_old") or str(id).contains("_legs_"):
				complete = false  # (a body and a head it can't do without; a missing extra it can)
			continue
		_paint(picture, _pixels_of(str(id), layer), colours)
	if complete:
		if str(look.get("age_range", "")) == "70s":
			_stoop(picture, NECK_ROWS + (SEATED_DOWN if view == "back" else 0))
		made = ImageTexture.create_from_image(picture)
	_cache[key] = made
	return made


## Moving, facing us, without the side view's layers: they glide with a gentle bob (two
## frames: standing, and all of them a pixel up), not stepping on the spot (which looked like
## marching sideways).
static var _walks := {}


## Walking from the side: the stride's frames for this look, or [] if its layers aren't there.
static func side_frames(look: Dictionary, holding: String = "") -> Array:
	var frames: Array = []
	for frame in WALK_FRAMES:
		var picture := texture(look, "side", frame, holding)
		if picture == null:
			return []
		frames.append(picture)
	return frames


static func walk_frames(picture: Texture2D) -> Array:
	if _walks.has(picture):
		return _walks[picture]
	var still := picture.get_image()
	var up := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	up.blit_rect(still, Rect2i(0, 1, SIZE.x, SIZE.y - 1), Vector2i(0, 0))
	var frames: Array = [picture, ImageTexture.create_from_image(up)]
	_walks[picture] = frames
	return frames


## Forget the pictures made (after the art changes).
static func reset() -> void:
	_cache = {}
	_layers = {}
	_walks = {}


## Facing us, the arm that holds a phone, hanging (tools/art/people.py: its columns outside the
## torso, from the shoulder down; its hand, which reaches over the torso's edge, ARM_HAND).
const ARM_CLEAR := Rect2i(27, 21, 2, 26)
const ARM_HAND := Rect2i(25, 42, 2, 5)


static func _clear(picture: Image, area: Rect2i) -> void:
	picture.fill_rect(area, Color(0, 0, 0, 0))
	for y in range(ARM_HAND.position.y, ARM_HAND.end.y):  # (where the hand was over the torso: the torso again, from beside it)
		for x in range(ARM_HAND.position.x, ARM_HAND.end.x):
			picture.set_pixel(x, y, picture.get_pixel(ARM_HAND.position.x - 1, y))


## The oldest stoop: their head and neck come down a little into their shoulders.
static func _stoop(picture: Image, to_row: int) -> void:
	var old := picture.duplicate() as Image
	for y in range(to_row + STOOP, -1, -1):
		for x in SIZE.x:
			var from := y - STOOP
			var pixel := old.get_pixel(x, from) if from >= 0 else Color(0, 0, 0, 0)
			if pixel.a > 0.5 or y < to_row:  # (the head's rows move down whole; below them, onto the shoulders, only the head itself)
				picture.set_pixel(x, y, pixel)


## A layer onto the picture: each pixel on its colour's ramp, at its step.
static func _paint(picture: Image, pixels: PackedInt32Array, colours: Dictionary) -> void:
	for k in range(0, pixels.size(), 5):
		var colour: Color = colours.get(pixels[k + 3], Color(FIXED[pixels[k + 4]]))
		picture.set_pixel(pixels[k], pixels[k + 1], ramp(colour)[pixels[k + 2]])


static var _layers := {}  # a layer's drawn pixels, read once: [x, y, step, slot, fixed colour] each


static func _pixels_of(id: String, layer: Texture2D) -> PackedInt32Array:
	if _layers.has(id):
		return _layers[id]
	var image := layer.get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var pixels := PackedInt32Array()
	for y in mini(image.get_height(), SIZE.y):
		for x in mini(image.get_width(), SIZE.x):
			var pixel := image.get_pixel(x, y)
			if pixel.a8 < 128:
				continue
			pixels.append_array([x, y, clampi(roundi(pixel.r8 / 36.0), 0, 6), roundi(pixel.g8 / 36.0),
				clampi(roundi(pixel.b8 / 8.0), 0, FIXED.size() - 1)])
	_layers[id] = pixels
	return pixels


## A colour's light ramp: 7 steps, shadows cooler (bluer, a little more saturated), light warmer
## (tools/art/palette.py ramp(), the same sums, so the game's people match the drawn art).
static func ramp(colour: Color) -> Array:
	if _ramps.has(colour):
		return _ramps[colour]
	var steps: Array = []
	var h := colour.h
	var s := colour.s
	var v := colour.v
	for k in LEVELS.size():
		var f: float = LEVELS[k]
		var t := (k - BASE_STEP) / 4.0
		var hh := h
		if t < 0:
			hh = h + (fposmod(0.64 - h + 0.5, 1.0) - 0.5) * 0.12 * -t
		else:
			hh = h + (fposmod(0.11 - h + 0.5, 1.0) - 0.5) * 0.10 * t
		var ss := minf(1.0, s * (1 + 0.15 * -t)) if t < 0 else s * (1 - 0.25 * t)
		var vv := minf(1.0, v * f) if f <= 1 else minf(1.0, v + (1 - v) * (f - 1) * 1.4)
		steps.append(Color.from_hsv(fposmod(hh, 1.0), ss, vv))
	_ramps[colour] = steps
	return steps
