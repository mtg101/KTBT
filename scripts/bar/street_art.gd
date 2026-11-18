extends SubViewportContainer
## The street behind the tent, in pixel art (ART.md): the night sky and the city's pieces from
## the art folder ("street/overpass", "street/apartments"...), drawn on a grid of PIXELS, each
## pixel SCALE screen pixels, never smoothed. It sits behind the tent's stage and reaches above
## it (the stage's ROOM: the overpass and the tops of the blocks show over the roof). Without
## any street art it's just the sky, and the stage draws its own city as before.
## The first step of the real art: the tent, its light and the people move onto this grid later
## (PLAN.md, "Real art").

const Art = preload("res://scripts/ui/art.gd")

const SCALE := 3  # screen pixels to a street pixel
const PIXELS := Vector2i(624, 180)  # the grid: 1872 x 540 on screen
const GROUND := 178  # where the buildings stand (the tent's floor line on this grid)
## The street's a little dimmer and bluer than the tent, so what happens under the tarp stands
## out (until the palette's light does this properly: ART.md, "How it'll work in Godot").
const NIGHT := Color(0.72, 0.74, 0.88)

## Where each piece goes, back to front: [key, centre x, bottom y] on the grid. The tent hides
## most of the street (it's where everything happens): what shows is above its roof and at its
## sides.
const LAYOUT := [
	["street/apartments", 110, GROUND], ["street/apartments_2", 500, GROUND],
	["street/overpass", 312, 112],  # (its deck along the top, its pillars behind the tent)
	["street/corner_shop", 30, GROUND], ["street/shops", 300, GROUND], ["street/karaoke", 600, GROUND],
]

var sky: ColorRect  # the night, following the stage's sky (set_sky)
var pieces: Array = []  # the pieces drawn (TextureRects), for the tests
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
	for piece in LAYOUT:
		var drawn := Art.place(sky, str(piece[0]), Vector2(piece[1], piece[2]), "bottom", 1)
		if drawn == null:
			Art.drawn(str(piece[0]))
		else:
			drawn.modulate = NIGHT
			pieces.append(drawn)


## Whether any of the street is art (then the stage leaves its own sky and city out, so this
## shows through it).
func has_art() -> bool:
	return not pieces.is_empty()


## The sky's colour, as the stage's (by the hour and the weather: tent_view.gd update_light).
func set_sky(colour: Color) -> void:
	sky.color = colour
