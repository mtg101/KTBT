extends Control
## The invisible area over a person on stage (visit.gd: a customer's or the owner's "Hover"),
## whose tooltip shows their portrait beside the words (PLAN.md, "Portraits"): the face from the
## library, repainted onto their own colours (people_art.gd portrait()), its pixels SCALE times
## over, never smoothed. Without a portrait, the plain tooltip as before.

signal shown  # (each time the tooltip with their face opens: counted in the night's stats)

const SCALE := 2  # the portrait's 64 x 80 pixels at 128 x 160: bigger than the people on stage

var portrait: Texture2D = null
var picked_for := {}  # the look visit.gd picked it for (once a look: picked again only if it changes, a new owner on "Try again")
var picked_how := ""  # how it was picked ("matched", "fallback", "none"): visit.gd counts it again in a new night's stats
var picked_key := ""  # which portrait it is ("w_20s_long"), for the TV box's mood faces ("" for none)


func _make_custom_tooltip(for_text: String) -> Object:
	if portrait == null or for_text == "":
		return null  # (the plain tooltip)
	var row := HBoxContainer.new()
	row.name = "PortraitTip"
	row.add_theme_constant_override("separation", 10)
	var face := TextureRect.new()
	face.name = "Portrait"
	face.texture = portrait
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.custom_minimum_size = Vector2(portrait.get_size() * SCALE)
	face.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(face)
	var words := Label.new()
	words.name = "Words"
	words.theme_type_variation = "TooltipLabel"  # (looking like every other tooltip)
	words.text = for_text
	row.add_child(words)
	shown.emit()
	return row
