extends SubViewportContainer
## The street behind the tent, in pixel art (ART.md): the night sky and the city's pieces from
## the art folder ("street/overpass", "street/apartments_3"...), drawn on a grid of PIXELS, each
## pixel SCALE screen pixels, never smoothed. It sits behind the tent's stage and reaches above
## it (the stage's ROOM: the overpass and the tops of the blocks show over the roof). Each bar
## has its own street: a piece for each of the SLOTS, picked from those there's art for by the
## bar's id (its own dice, as the skyline's are). Without any street art it's just the sky, and
## the stage draws its own city as before.
## The first step of the real art: the tent, its light and the people move onto this grid later
## (PLAN.md, "Real art").

const Art = preload("res://scripts/ui/art.gd")

const SCALE := 3  # screen pixels to a street pixel
const PIXELS := Vector2i(624, 154)  # the grid: 1872 x 462 on screen
const GROUND := 152  # where the buildings stand (the tent's floor line on this grid)

## Where the street's pieces go, back to front: the pieces that can stand there, its centre x
## and bottom y on the grid. The tent hides most of the street (it's where everything happens):
## what shows is above its roof, through its open back, and at its sides.
const SLOTS := [
	{"keys": ["apartments", "apartments_2", "apartments_3", "apartments_4", "apartments_5", "apartments_6"], "at": Vector2(110, GROUND)},
	{"keys": ["apartments", "apartments_2", "apartments_3", "apartments_4", "apartments_5", "apartments_6"], "at": Vector2(500, GROUND)},
	{"keys": ["overpass", "overpass_2"], "at": Vector2(312, 112)},  # (its deck along the top, its pillars behind the tent)
	{"keys": ["corner_shop", "corner_shop_2", "corner_shop_3", "corner_shop_4"], "at": Vector2(30, GROUND)},
	{"keys": ["shops", "shops_2", "shops_3", "shops_4"], "at": Vector2(300, GROUND)},
	{"keys": ["karaoke", "karaoke_2", "karaoke_3", "karaoke_4"], "at": Vector2(600, GROUND)},
]

var sky: ColorRect  # the night, following the stage's sky (set_sky)
var pieces: Array = []  # the pieces drawn (TextureRects)
var chosen: Array = []  # tonight's street: the key drawn in each slot ("" for none)
var _grid: SubViewport


func _init() -> void:
	name = "StreetArt"
	stretch = true
	stretch_shrink = SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(PIXELS * SCALE)
	_grid = SubViewport.new()
	_grid.name = "Grid"
	_grid.size = PIXELS
	_grid.transparent_bg = false
	_grid.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_grid.snap_2d_transforms_to_pixel = true
	add_child(_grid)
	sky = ColorRect.new()
	sky.name = "Sky"
	sky.size = Vector2(PIXELS)
	sky.color = Color("3c3a72")
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.add_child(sky)


## Whether there's any street art (then the stage leaves its own sky and city out, so this
## shows through it).
static func has_art() -> bool:
	for slot in SLOTS:
		for key in slot["keys"]:
			if Art.has("street/" + str(key)):
				return true
	return false


## This bar's street: a piece in each slot, from those there's art for, picked by its id (the
## same street every night; two slots never the same building).
func show_street(bar_id: String) -> void:
	for piece in pieces:
		piece.queue_free()
	pieces = []
	chosen = []
	var dice := RandomNumberGenerator.new()
	dice.seed = hash("street " + bar_id)
	for slot in SLOTS:
		var choices: Array = slot["keys"].filter(func(id): return Art.has("street/" + str(id)) and not chosen.has("street/" + str(id)))
		if choices.is_empty():
			for id in slot["keys"]:
				Art.drawn("street/" + str(id))
			chosen.append("")
			continue
		var picked := "street/" + str(choices[dice.randi_range(0, choices.size() - 1)])
		var drawn := Art.place(sky, picked, slot["at"], "bottom", 1)  # (lit by the hour: pixel_light.gd, the "street" kind)
		pieces.append(drawn)
		chosen.append(picked)


## The sky's colour, as the stage's (by the hour and the weather: tent_view.gd update_light).
func set_sky(colour: Color) -> void:
	sky.color = colour
