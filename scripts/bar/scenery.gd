extends RefCounted
## The tent's fixtures, drawn: the drinks fridge, the odeng pot simmering on the stove, the
## karaoke neon across the street (flickering now and then), and steam off a hot dish just set
## down. The tent's scene places them as it builds the stage.
## (Part 11 of splitting visit.gd: see DEVLOG.md, 16 November 2026.)

const Catalogue = preload("res://scripts/rules/catalogue.gd")
const Text = preload("res://scripts/rules/text.gd")
const Ktv = preload("res://scripts/ui/ktv_style.gd")
const Draw = preload("res://scripts/bar/draw.gd")
const Art = preload("res://scripts/ui/art.gd")
const PixelFont = preload("res://scripts/ui/pixel_font.gd")
const PeopleArt = preload("res://scripts/ui/people_art.gd")

## Dishes that steam when they're set down (and any stew, pancake, grill or fried dish).
const NEON_BOARD_IN := 42.0  # the neon's board, its left edge this far in from the stage's right (39 wide)
const NEON_TOP := 126.0  # the neon's first syllable, on its board (the board: 117 to 216, a pixel to 3)
const NEON_LINE := 27  # a syllable every 27 (9 of the grid's pixels: 8 for the letter, 1 between)
const HOT_DISHES := ["tteokbokki", "odeng", "sundae", "dakgalbi", "pajeon", "ramyeon", "gonggibap", "bokkeumbap"]

var dice: RandomNumberGenerator  # the scenery's (it never shifts the game's own rolls)
var neon: Label  # the karaoke sign on the pillar
var stage_width := 0.0


func _init(scenery_dice: RandomNumberGenerator, width: float) -> void:
	dice = scenery_dice
	stage_width = width


## The drinks fridge at the back, by the stove (the owner's station), behind the owner: a
## glass door lit from inside, with shelves of soju, beer and makgeolli (only what's on the
## menu). Its shelves sit high, so the odeng pot in front doesn't hide them.
func build_fridge(stage: Control) -> void:
	var fridge := Control.new()
	fridge.name = "Fridge"
	fridge.position = Vector2(186, 116)  # just right of the odeng pot
	fridge.size = Vector2(92, 134)
	fridge.mouse_filter = Control.MOUSE_FILTER_STOP
	fridge.tooltip_text = Text.tip("The drinks fridge: soju, beer and makgeolli, ice cold.")
	stage.add_child(fridge)
	if Art.place(fridge, "tent/fridge", Vector2(0, 1), "topleft", 3) != null:  # (in pixel art: art/tents, its top on a row of the grid)
		return
	Art.drawn("tent/fridge")
	Draw.rect(fridge, Vector2.ZERO, Vector2(92, 134), Color("d8dce4"))  # the cabinet
	Draw.rect(fridge, Vector2.ZERO, Vector2(92, 14), Color("c8443a"))  # the header strip
	Draw.rect(fridge, Vector2(6, 18), Vector2(80, 112), Color("23344a"))  # inside
	Draw.rect(fridge, Vector2(6, 18), Vector2(80, 112), Color(0.9, 0.96, 1.0, 0.18))  # its light
	var shelves := [
		["soju", Vector2(7, 20), 6],  # green bottles
		["beer", Vector2(10, 16), 5],  # gold cans
		["makgeolli", Vector2(9, 20), 5],  # white bottles
	]
	for row in shelves.size():
		var drink: String = shelves[row][0]
		var shape: Vector2 = shelves[row][1]
		var count: int = shelves[row][2]
		var floor_y := 18.0 + (row + 1) * 26.0
		var colour := Color(str(Catalogue.find(drink)["color"]))  # (the catalogue's: not every bar's menu has makgeolli)
		var gap := (80.0 - count * shape.x) / (count + 1)
		for k in count:
			var x := 6.0 + gap + k * (shape.x + gap)
			Draw.rect(fridge, Vector2(x, floor_y - shape.y), shape, colour)
			if drink != "beer":  # a neck and a cap on the bottles
				Draw.rect(fridge, Vector2(x + shape.x / 2 - 2, floor_y - shape.y - 6), Vector2(4, 6), colour)
				Draw.rect(fridge, Vector2(x + shape.x / 2 - 2, floor_y - shape.y - 8), Vector2(4, 2), Color("2e7a44") if drink == "makgeolli" else Color("d8dce4"))
		Draw.rect(fridge, Vector2(6, floor_y), Vector2(80, 2), Color("9aa6b4"))  # the shelf
	var sheen := Polygon2D.new()  # light catching the glass
	sheen.polygon = PackedVector2Array([Vector2(14, 18), Vector2(34, 18), Vector2(16, 130), Vector2(6, 130), Vector2(6, 60)])
	sheen.color = Color(1, 1, 1, 0.1)
	fridge.add_child(sheen)
	Draw.rect(fridge, Vector2(80, 40), Vector2(3, 40), Color("8a8c96"))  # the handle


## The odeng pot, simmering on the stove all night: fish cake skewers poking out of the
## broth, and steam curling up off it.
func build_odeng_pot(stage: Control) -> void:
	var pot := Control.new()
	pot.name = "OdengPot"
	pot.position = Vector2(108, 212)
	pot.mouse_filter = Control.MOUSE_FILTER_STOP
	pot.size = Vector2(60, 32)
	pot.tooltip_text = Text.tip("Odeng: %s" % Catalogue.find("odeng")["desc"])  # (every tent's pot, on the menu or not)
	stage.add_child(pot)
	if Art.place(pot, "tent/odeng_pot", Vector2(-3, -14), "topleft", 3) == null:  # (in pixel art: art/tents, on the grid's lines)
		Art.drawn("tent/odeng_pot")
		for k in 4:  # skewers, at a slant
			var skewer := Draw.rect(pot, Vector2(10 + k * 12, -14 + (k % 2) * 4), Vector2(2, 22), Color("d8c49a"))
			skewer.rotation = -0.2 + k * 0.12
			Draw.rect(pot, Vector2(7 + k * 12, -2 + (k % 2) * 4), Vector2(9, 8), Color("c9a26b"))  # a folded fish cake
		Draw.rect(pot, Vector2(0, 6), Vector2(60, 26), Color("8a8c96"))  # the pot (a square metal one)
		Draw.rect(pot, Vector2(-3, 4), Vector2(66, 4), Color("b0b2bc"))  # its rim
		Draw.rect(pot, Vector2(2, 8), Vector2(56, 3), Color("c9a26b", 0.8))  # the broth
	for k in 3:  # steam, rising and fading, one puff after another
		puff(pot, Vector2(20 + k * 10, 0), Vector2(14 + k * 12, -46), 3, 2.7, 0.3, 0, k * 0.9)


## A neon sign on the pillar across from the tent: 노래방, karaoke (a kind of place, not a
## name: see CONCEPT.md, "Real people, brands and shows"), flickering now and then.
func build_neon(stage: Control) -> void:
	if Art.place(stage, "tent/neon_board", Vector2(stage_width - NEON_BOARD_IN, 117), "topleft", 3) == null:  # its board, in pixel art (the word stays text over it, to hover)
		Art.drawn("tent/neon_board")
	neon = Ktv.label("노\n래\n방", 22, Color("ff5fa2"), 6, Color("ff5fa2", 0.35))
	neon.name = "Neon"
	PixelFont.apply(neon, "neon")  # (in pixels, on the grid: pixel_font.gd)
	PixelFont.space_lines(neon, "neon", NEON_LINE)  # (all three on its board)
	neon.mouse_filter = Control.MOUSE_FILTER_STOP  # (Korean on screen explains itself)
	neon.tooltip_text = Text.tip("노래방 noraebang: a karaoke room across the street, where the night carries on after the pocha.")
	neon.position = Vector2(stage_width - NEON_BOARD_IN + 9, NEON_TOP)  # (3 of the grid's pixels in: a pixel clear inside the tube)
	neon.size = Vector2(24, 0)  # (a syllable's width: 8 of the grid's pixels, its last one the gap after it)
	neon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stage.add_child(neon)
	dice.randomize()
	_flicker_neon()


## Now and then the neon stutters, the way old signs do, then comes back.
func _flicker_neon() -> void:
	if not is_instance_valid(neon):
		return
	var stutter := neon.create_tween()
	stutter.tween_interval(dice.randf_range(4.0, 14.0))
	for k in dice.randi_range(2, 4):
		stutter.tween_property(neon, "modulate:a", dice.randf_range(0.15, 0.5), 0.05)
		stutter.tween_property(neon, "modulate:a", 1.0, dice.randf_range(0.04, 0.12))
	stutter.tween_callback(_flicker_neon)


## A little steam off a hot dish just set down, for a while.
func steam(shape: Control) -> void:
	for k in 2:
		puff(shape, Vector2(9 + k * 7, 12), Vector2(6 + k * 9, -18), 2, 2.2, 0.28, 4, k * 0.8 + dice.randf_range(0.0, 0.4))  # (4 puffs: it cools down)


## A puff of steam in pixel art (a little cloud cells of the grid across, each pixel 3 on
## screen): rising from from to to (on its holder) a pixel at a time, kept on the grid's lines,
## and fading in steps, over and over (loops: 0 for ever), after a wait.
func puff(holder: Control, from: Vector2, to: Vector2, cells: int, seconds: float, alpha: float, loops: int, wait: float) -> TextureRect:
	var cloud := TextureRect.new()
	cloud.name = "Steam"
	cloud.texture = _puff_texture(cells)
	cloud.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cloud.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cloud.stretch_mode = TextureRect.STRETCH_SCALE
	cloud.size = Vector2(cells, cells) * PUFF_PIXEL
	cloud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cloud.modulate.a = 0.0
	holder.add_child(cloud, true)
	var rise := cloud.create_tween().set_loops(loops)
	rise.tween_interval(wait)
	rise.tween_method(_rise.bind(cloud, from, to, alpha), 0.0, 1.0, seconds)
	return cloud


const PUFF_PIXEL := 3.0
static var _puffs := {}


func _rise(t: float, cloud: TextureRect, from: Vector2, to: Vector2, alpha: float) -> void:
	if not is_instance_valid(cloud) or not cloud.is_inside_tree():
		return
	var holder_at := (cloud.get_parent() as CanvasItem).get_global_transform().origin
	var at := holder_at + from.lerp(to, t)
	cloud.position = Vector2(snappedf(at.x, PUFF_PIXEL), snappedf(at.y, PUFF_PIXEL)) - holder_at
	cloud.modulate.a = alpha * ceilf((1.0 - t) * 4.0) / 4.0  # (fading in four steps)


## A puff: a round little cloud, its middle a little thicker.
static func _puff_texture(cells: int) -> ImageTexture:
	if _puffs.has(cells):
		return _puffs[cells]
	var image := Image.create(cells, cells, false, Image.FORMAT_RGBA8)
	for y in cells:
		for x in cells:
			var corner := (x == 0 or x == cells - 1) and (y == 0 or y == cells - 1)
			if cells > 2 and corner:
				continue
			var middle := cells > 2 and x > 0 and x < cells - 1 and y > 0 and y < cells - 1
			image.set_pixel(x, y, Color(1, 1, 1, 1.0 if middle or cells <= 2 else 0.7))
	_puffs[cells] = ImageTexture.create_from_image(image)
	return _puffs[cells]


## The CLOSED board out front, in pixel art (28 by 27 of the grid's pixels, 84 by 81 on the
## stage): a little chalkboard in a wooden frame, lit from above, chalk dust on it, on its
## A-frame's legs. Its words stay text over it (the pixel font), to hover.
static func closed_board() -> ImageTexture:
	var image := Image.create(28, 27, false, Image.FORMAT_RGBA8)
	var wood: Array = PeopleArt.ramp(Color("6b4a2e"))
	var legs: Array = PeopleArt.ramp(Color("4a3524"))
	var slate: Array = PeopleArt.ramp(Color("3d4a3f"))
	for leg in [4, 21]:
		for y in range(17, 27):
			image.set_pixel(leg, y, legs[5])
			image.set_pixel(leg + 1, y, legs[3])
	for y in 19:
		for x in 28:
			var frame := x == 0 or y == 0 or x == 27 or y == 18
			if frame:
				image.set_pixel(x, y, wood[5] if y == 0 else (wood[2] if y == 18 or x == 27 else wood[4]))
			else:
				image.set_pixel(x, y, slate[4] if y > 1 else slate[5])
	var dust := RandomNumberGenerator.new()
	dust.seed = 7  # (the same smudges every time)
	for k in 14:
		var spot := Vector2i(dust.randi_range(2, 25), dust.randi_range(2, 16))
		image.set_pixelv(spot, slate[5].lerp(Color.WHITE, 0.25))
	return ImageTexture.create_from_image(image)
