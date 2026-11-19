extends RefCounted
## The panels and buttons under the stage in the stage's pixel art (ART.md, "The panels"): a
## frame of whole pixels of the grid (3 on screen), its corners notched, lit from above (a lighter
## row inside its top edge, a darker one inside its bottom), never smoothed; and a theme for the
## bar's screen that gives every button such a frame (lit up in the accent when you're over it,
## pressed in when you click) and the pixel font (pixel_font.gd). Long text (the transcript, the
## stats) stays in the readable font; the frames, headings and buttons are pixels.

const Ktv = preload("res://scripts/ui/ktv_style.gd")
const PixelFont = preload("res://scripts/ui/pixel_font.gd")

const GRID := 3  # screen pixels to a pixel of the art
const CELLS := 8  # a frame's picture: this many pixels square (the middle stretches)
const EDGE := 2  # pixels of it that are edge (the border, and the light or shadow inside it)

## A panel's colours: [fill, edge, light, shadow].
const PANEL := [Ktv.PANEL, Color("3a3760"), Color("2c2a4a"), Color("1b1a30")]
const BUTTON := [Color("2c2a48"), Color("4a4870"), Color("3a3860"), Color("211f38")]
const BUTTON_OVER := [Color("34325a"), Ktv.ORANGE, Color("46437a"), Color("26243f")]
const BUTTON_DOWN := [Color("1f1d36"), Ktv.ORANGE, Color("1a1830"), Color("2c2a48")]  # (pressed in: the light below, the shadow above)
const BUTTON_OFF := [Color("201e34"), Color("2e2c48"), Color("24223a"), Color("1c1a2e")]

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


## The bar screen's theme: every button in a pixel frame and the pixel font; tick boxes left as
## they are (they're buttons too: without their own empty styles they'd get a frame).
static func theme() -> Theme:
	var made := Theme.new()
	var padding := Vector2(12, 6)
	made.set_stylebox("normal", "Button", style(BUTTON, padding))
	made.set_stylebox("hover", "Button", style(BUTTON_OVER, padding))
	made.set_stylebox("pressed", "Button", style(BUTTON_DOWN, padding))
	made.set_stylebox("hover_pressed", "Button", style(BUTTON_DOWN, padding))
	made.set_stylebox("disabled", "Button", style(BUTTON_OFF, padding))
	made.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	var font := PixelFont.font("galmuri14")
	if font != null:
		made.set_font("font", "Button", font)
		made.set_font_size("font_size", "Button", PixelFont.size_for("button"))
	for type in ["CheckBox", "CheckButton", "LinkButton"]:
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			made.set_stylebox(state, type, StyleBoxEmpty.new())
	return made
