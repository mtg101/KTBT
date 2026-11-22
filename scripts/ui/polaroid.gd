extends Control
## A polaroid on the owner's diary page (ui/diary_page.gd): someone's portrait (people_art.gd
## portrait(), in a mood or calm), its whole pixels SCALE times over and never smoothed, in a
## white frame with a deeper bottom, the name written under it in the diary's ink, a strip of
## tape across the top, and a tilt. Never takes a click.

const Ktv = preload("res://scripts/ui/ktv_style.gd")
const SCALE := 2  # the portrait's 64 x 80 at 128 x 160
const BORDER := 10.0
const BOTTOM := 38.0  # the name's strip
const FRAME := Color("fbf8f0")
const TAPE := Color(0.95, 0.9, 0.7, 0.6)
const INK := Color("2b3a67")  # (the diary's)

var who := ""  # whose (their full name), for the tests and the log


## picture: their portrait; written: the name under it (their given name, as the owner writes
## it); tilt: radians.
func setup(picture: Texture2D, full_name: String, written: String, tilt: float) -> void:
	name = "Polaroid"
	who = full_name
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var picture_size := Vector2(picture.get_size() * SCALE)
	size = picture_size + Vector2(BORDER * 2, BORDER + BOTTOM)
	custom_minimum_size = size
	pivot_offset = size / 2
	rotation = tilt
	var face := TextureRect.new()
	face.name = "Picture"
	face.texture = picture
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_SCALE
	face.position = Vector2(BORDER, BORDER)
	face.size = picture_size
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(face)
	var label := Ktv.label(written, 20, INK)
	label.name = "Name"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.position = Vector2(4, BORDER + picture_size.y + 4)
	label.size = Vector2(size.x - 8, BOTTOM - 8)
	label.rotation = -tilt * 0.5  # (written by hand: not quite square to the frame)
	add_child(label)


func _draw() -> void:
	draw_rect(Rect2(Vector2(4, 6), size), Color(0, 0, 0, 0.28))  # a shadow on the page
	draw_rect(Rect2(Vector2.ZERO, size), FRAME)
	draw_rect(Rect2(Vector2(BORDER - 1, BORDER - 1), size - Vector2(BORDER * 2 - 2, BORDER + BOTTOM - 2)), Color(0, 0, 0, 0.12), false, 1.0)
	var tape := Rect2(Vector2(size.x / 2 - 34, -12), Vector2(68, 24))  # stuck down across the top
	draw_set_transform(tape.get_center(), -rotation * 0.6 + 0.05, Vector2.ONE)
	draw_rect(Rect2(-tape.size / 2, tape.size), TAPE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
