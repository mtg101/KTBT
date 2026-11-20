extends RefCounted
## The game's look in one place: the K-TV palette (the cream, pink, mint and yellow of the
## captions, title cards and recaps; the night's navy; the tarp's orange), and the pieces every
## screen builds from: outlined labels, chunky pills with a hard shadow, and title-card text.
## Captions, bubbles, the diary, the recap, the loading and title screens and the bar all use
## these, so a new look (when the real art comes) is changed here once.

# --- The palette ------------------------------------------------------------------------------
const CREAM := Color("fff4e0")  # title-card text
const PINK := Color("ff7eb6")  # the K-TV accent: ribbons, title outlines, EP. tags
const MINT := Color("7ee8c8")
const YELLOW := Color("ffd27f")  # teasers, the owner's lines, bulbs
const ORANGE := Color("e8833a")  # the tarp, and headings
const INK := Color("1a1840")  # outlines and borders: the night's deep navy
const NIGHT_TOP := Color("1a1840")
const NIGHT_BOTTOM := Color("3c2a5c")
const BACKGROUND := Color("14132a")  # behind everything
const PANEL := Color("22203a")  # the bar's panels
const MUTED := Color("a9a6c2")  # quieter text
const LIGHT := Color("d8d5ee")  # light text on the dark
const PAPER := Color("f6ecd6")  # the diary's page and the speech bubbles
## Drop shadows: light and close, so text stands off the screen without blurring into it (a
## dark, wide one, the outline's size, made the title hard to read).
const SHADOW := Color(0, 0, 0, 0.3)


## A tick box that shows up on a dark background (Godot's own are dark, and an empty one
## disappears): a light outline, filled with the accent colour and a tick when on.
static func tick_box(on: bool) -> ImageTexture:
	var side := 18
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	for i in side:
		for j in [0, 1, side - 2, side - 1]:
			image.set_pixel(i, j, LIGHT)
			image.set_pixel(j, i, LIGHT)
	if on:
		image.fill_rect(Rect2i(3, 3, side - 6, side - 6), ORANGE)
		# The tick: a short stroke down, then a long one up.
		for k in 4:
			image.fill_rect(Rect2i(5 + k, 8 + k, 2, 2), Color.WHITE)
		for k in 6:
			image.fill_rect(Rect2i(8 + k, 11 - k, 2, 2), Color.WHITE)
	return ImageTexture.create_from_image(image)


## Gives a tick box (CheckBox) the light tick boxes.
static func light_ticks(toggle: CheckBox) -> void:
	toggle.add_theme_icon_override("unchecked", tick_box(false))
	toggle.add_theme_icon_override("checked", tick_box(true))


## Gives a choice in a group (a CheckBox in a ButtonGroup, drawn as a radio button) the light
## tick boxes, so an unticked one shows on the dark.
static func light_radios(toggle: CheckBox) -> void:
	toggle.add_theme_icon_override("radio_unchecked", tick_box(false))
	toggle.add_theme_icon_override("radio_checked", tick_box(true))


## A label: text in a size and colour, ignoring the mouse, with an outline if asked (in INK
## unless told otherwise).
static func label(text: String, font_size: int, colour: Color, outline: int = 0, outline_colour: Color = INK) -> Label:
	var made := Label.new()
	made.text = text
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	made.add_theme_font_size_override("font_size", font_size)
	made.add_theme_color_override("font_color", colour)
	if outline > 0:
		made.add_theme_constant_override("outline_size", outline)
		made.add_theme_color_override("font_outline_color", outline_colour)
	return made


## A chunky pill (the K-TV caption shape): a colour, rounded ends, a thick INK border and a
## hard shadow. margin: left and right padding (top and bottom are small).
static func pill(colour: Color, radius: int, border: int = 5, margin: int = 26, shadow: bool = true) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.border_color = INK
	style.set_border_width_all(border)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin
	style.content_margin_right = margin
	style.content_margin_bottom = 6
	if shadow:
		style.shadow_color = Color(0, 0, 0, 0.4)
		style.shadow_offset = Vector2(6, 6)
	return style


## Title-card text: a thick outline and a light drop shadow (the loading and title screens' name).
static func title_card(text_label: Label, outline: int, outline_colour: Color, shadow_offset: Vector2) -> void:
	text_label.add_theme_constant_override("outline_size", outline)
	text_label.add_theme_color_override("font_outline_color", outline_colour)
	soft_shadow(text_label, shadow_offset * 0.5)


## A light, close drop shadow on a label (the shadow follows the letters, not their outline,
## so the outline stays crisp).
static func soft_shadow(text_label: Label, offset: Vector2) -> void:
	text_label.add_theme_color_override("font_shadow_color", SHADOW)
	text_label.add_theme_constant_override("shadow_offset_x", int(offset.x))
	text_label.add_theme_constant_override("shadow_offset_y", int(offset.y))
	text_label.add_theme_constant_override("shadow_outline_size", 0)
