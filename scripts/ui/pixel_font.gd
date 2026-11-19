extends RefCounted
## Words on the stage in a pixel Korean font (ART.md, "Text on the stage"): Galmuri, by Lee
## Minseo (fonts/galmuri, under the SIL Open Font Licence: LICENSE-ASSETS.md), Hangul and Latin
## drawn as pixels, at whole multiples of each size's own pixel height so they stay crisp
## (never smoothed). The words that are part of the scene (the sign, the neon, the CLOSED
## board) at three times, so a pixel of the word is a pixel of the art's grid; the name tags
## and the speech bubbles at the font's own size, smaller but still crisp. Anything a size
## hasn't got (a symbol or two) comes from the game's ordinary font. Without the font files,
## the ordinary font, as before.
## On the stage; and under it, the panels' headings, buttons and the bar's name (pixel_frame.gd).
## The transcript, the stats' and the desk's long text and the TV captions keep their own fonts.

const FOLDER := "res://fonts/galmuri/"
## Each size: its file and its own pixel height (a whole multiple of that stays crisp).
const SIZES := {
	"galmuri14": {"file": "Galmuri14.ttf", "pixels": 15},
	"galmuri11": {"file": "Galmuri11.ttf", "pixels": 12},
	"galmuri9": {"file": "Galmuri9.ttf", "pixels": 10},
	"galmuri7": {"file": "Galmuri7.ttf", "pixels": 8},
}
## Each piece of text on the stage: [size, times its own pixel height].
const USES := {
	"sign_hangul": ["galmuri9", 3],  # the sign's Hangul (포장마차): on the art's grid
	"sign_english": ["galmuri7", 2],  # the bar's name under it (a long name has to fit the board)
	"neon": ["galmuri7", 3],  # 노래방, down the pillar: on the grid
	"closed_hangul": ["galmuri7", 3],  # 마감, on the CLOSED board: on the grid
	"closed_english": ["galmuri7", 2],
	"name_tag": ["galmuri14", 1],  # over people's heads
	"cat_tag": ["galmuri11", 1],
	"bubble_header": ["galmuri11", 1],  # who's speaking to whom
	"bubble": ["galmuri14", 1],  # what they say
	# Under the stage (pixel_frame.gd): the headings, the buttons and the bar's name; long text stays smooth.
	"heading": ["galmuri14", 1],  # the panels' headings (their bold: PD CONTROLS, HERE NOW, THE OWNER...)
	"button": ["galmuri14", 1],
	"title": ["galmuri11", 2],  # the bar's name, top left
	"panel_title": ["galmuri9", 2],  # a panel's own title (Options)
	"badge": ["galmuri11", 1],  # OFFLINE MODE
}

static var _fonts := {}  # size -> FontFile (or null: not there)


## A size's font, set up for pixels (no smoothing, no hinting, on whole pixels), the ordinary
## font behind it for anything it hasn't got; null without the file.
static func font(size_name: String) -> FontFile:
	if _fonts.has(size_name):
		return _fonts[size_name]
	var made: FontFile = null
	var path := FOLDER + str(SIZES.get(size_name, {}).get("file", ""))
	if SIZES.has(size_name) and ResourceLoader.exists(path):
		made = load(path) as FontFile
		if made != null:
			made.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			made.hinting = TextServer.HINTING_NONE
			made.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			made.generate_mipmaps = false
			made.fallbacks = [ThemeDB.fallback_font]
	elif SIZES.has(size_name):
		push_error("Pixel font: %s isn't there (or isn't imported yet: open the project in the Godot editor once): the ordinary font instead" % path)
	_fonts[size_name] = made
	return made


## The font size for a use: its size's pixel height, times its multiple.
static func size_for(use: String) -> int:
	var spec: Array = USES[use]
	return int(SIZES[spec[0]]["pixels"]) * int(spec[1])


## A label (or rich text) on the stage, in the pixel font for what it is (USES); left as it is
## without the font.
static func apply(control: Control, use: String) -> void:
	var made := font(str(USES[use][0]))
	if made == null:
		return
	if control is RichTextLabel:
		for kind in ["normal", "bold", "italics"]:
			control.add_theme_font_override(kind + "_font", made)
			control.add_theme_font_size_override(kind + "_font_size", size_for(use))
	else:
		control.add_theme_font_override("font", made)
		control.add_theme_font_size_override("font_size", size_for(use))


## Lines of a label (in the pixel font) exactly this far apart, top to top: the font's own line
## height, with its gap above and below, can be taller than a board has room for (the neon's
## three syllables, one under another).
static func space_lines(label: Label, use: String, line_height: int) -> void:
	var made := font(str(USES[use][0]))
	if made == null:
		return
	label.add_theme_constant_override("line_spacing", line_height - int(made.get_height(size_for(use))))


## A rich text's headings (its bold) in the pixel font; the rest of it as it is.
static func apply_headings(rich: RichTextLabel, use: String = "heading") -> void:
	var made := font(str(USES[use][0]))
	if made == null:
		return
	rich.add_theme_font_override("bold_font", made)
	rich.add_theme_font_size_override("bold_font_size", size_for(use))


## How many pieces of text under this node are in the pixel font (for the night's stats).
static func count_in(node: Node) -> int:
	var count := 0
	if node is Control:
		var own := (node as Control).get_theme_font("normal_font" if node is RichTextLabel else "font")
		count = 1 if own != null and own in _fonts.values() else 0
	for child in node.get_children(true):
		count += count_in(child)
	return count


## Forget the fonts read (for the tests).
static func reset() -> void:
	_fonts = {}
