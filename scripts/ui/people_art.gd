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
static func layers_for(look: Dictionary, view: String) -> Array:
	var hair := str(look.get("hair", "short"))
	var ids: Array = []
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
	return ids


## The person's picture (SIZE, its pixels a grid's), or null if a layer it needs isn't there.
static func texture(look: Dictionary, view: String) -> ImageTexture:
	var key := "%s|%s" % [view, JSON.stringify(look, "", true)]
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
	for id in layers_for(look, view):
		var layer := Art.texture("person/" + str(id))
		if layer == null:
			if str(id).contains("_body_") or str(id).ends_with("_head") or str(id).ends_with("_head_old"):
				complete = false  # (a body and a head it can't do without; a missing extra it can)
			continue
		_paint(picture, layer.get_image(), colours)
	if complete:
		made = ImageTexture.create_from_image(picture)
	_cache[key] = made
	return made


## Forget the pictures made (after the art changes).
static func reset() -> void:
	_cache = {}


## A layer onto the picture: each pixel on its colour's ramp, at its step.
static func _paint(picture: Image, layer: Image, colours: Dictionary) -> void:
	if layer.is_compressed():
		layer.decompress()
	layer.convert(Image.FORMAT_RGBA8)
	for y in mini(layer.get_height(), SIZE.y):
		for x in mini(layer.get_width(), SIZE.x):
			var pixel := layer.get_pixel(x, y)
			if pixel.a8 < 128:
				continue
			var step := clampi(roundi(pixel.r8 / 36.0), 0, 6)
			var slot := roundi(pixel.g8 / 36.0)
			var colour: Color = colours.get(slot, Color(FIXED[clampi(roundi(pixel.b8 / 8.0), 0, FIXED.size() - 1)]))
			picture.set_pixel(x, y, ramp(colour)[step])


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
