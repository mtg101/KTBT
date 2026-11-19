extends RefCounted
## The panels under the stage in the stage's pixel art (ART.md, "The panels"): a frame of whole
## pixels of the grid (3 on screen), its corners notched, lit from above (a lighter row inside its
## top edge, a darker one inside its bottom), never smoothed. The words in them stay in the
## ordinary font (pixel_font.gd is only for the words in the bar's art), and the buttons are
## ordinary buttons (framed in pixels for a day: it felt odd).

const Ktv = preload("res://scripts/ui/ktv_style.gd")

const GRID := 3  # screen pixels to a pixel of the art
const CELLS := 8  # a frame's picture: this many pixels square (the middle stretches)
const EDGE := 2  # pixels of it that are edge (the border, and the light or shadow inside it)

## A panel's colours: [fill, edge, light, shadow].
const PANEL := [Ktv.PANEL, Color("3a3760"), Color("2c2a4a"), Color("1b1a30")]

static var _styles := {}


## A frame's picture: CELLS pixels square, each GRID on screen.
static func frame_texture(colours: Array) -> ImageTexture:
	var image := Image.create(CELLS * GRID, CELLS * GRID, false, Image.FORMAT_RGBA8)
	for y in CELLS:
		for x in CELLS:
			var corner := (x == 0 or x == CELLS - 1) and (y == 0 or y == CELLS - 1)
			if corner:
				continue  # (notched: a pixel-art corner, not a rounded one)
			var colour: Color = colours[0]
			if x == 0 or y == 0 or x == CELLS - 1 or y == CELLS - 1:
				colour = colours[1]
			elif y == 1:
				colour = colours[2]  # lit from above...
			elif y == CELLS - 2:
				colour = colours[3]  # ...in shadow below
			image.fill_rect(Rect2i(x * GRID, y * GRID, GRID, GRID), colour)
	return ImageTexture.create_from_image(image)


## A frame as a style: its edges kept whole (EDGE pixels), the middle stretched; padding inside.
static func style(colours: Array, padding: Vector2 = Vector2(16, 16)) -> StyleBoxTexture:
	var key := str(colours) + str(padding)
	if _styles.has(key):
		return _styles[key]
	var made := StyleBoxTexture.new()
	made.texture = frame_texture(colours)
	made.set_texture_margin_all(EDGE * GRID)
	made.content_margin_left = padding.x
	made.content_margin_right = padding.x
	made.content_margin_top = padding.y
	made.content_margin_bottom = padding.y
	_styles[key] = made
	return made
