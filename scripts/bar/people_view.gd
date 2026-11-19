extends RefCounted
## Drawing people: a plain person (a head, a body, a name tag), dressed in their look (hair,
## clothes, glasses, a bag, the owner's apron) in two views, facing us or seated from behind;
## a phone held up; an umbrella (its shape, the snow settling on it, the rain running off,
## shaken off under the tarp and folded), or a bag held over their head, running for it.
## The tent's scene says who and when; this only draws.
## (Part 2 of splitting visit.gd: see DEVLOG.md, 16 November 2026.)

const Draw = preload("res://scripts/bar/draw.gd")
const Looks = preload("res://scripts/rules/looks.gd")
const PeopleArt = preload("res://scripts/ui/people_art.gd")
const PixelPerson = preload("res://scripts/ui/pixel_person.gd")
const PixelShape = preload("res://scripts/ui/pixel_shape.gd")
const Art = preload("res://scripts/ui/art.gd")
const PixelFont = preload("res://scripts/ui/pixel_font.gd")
const Night = preload("res://scripts/bar/night.gd")

## The colours people are drawn in before they're dressed (and the bags held over heads).
const CUSTOMER_COLORS := [Color("6fa8c7"), Color("8fc79a"), Color("c78fb5"), Color("c7b06f"), Color("9a8fc7"), Color("c7836f")]

## An umbrella held over someone's head: a canopy on a shaft (lots of Seoul's are clear), in
## the shape, size and tilt Looks.rain_gear picked. It's held at the hand, so it tilts and
## scales from there.
const UMBRELLA_COLOURS := [Color(0.85, 0.9, 1.0, 0.35), Color("26252e"), Color("2c3a5c"), Color("7a2a2a"), Color("8a7a2a")]
const TAG_Y := -30.0  # a person's name, above their head
const UMBRELLA_CLEAR := Color(0.85, 0.9, 1.0, 0.3)
const UMBRELLA_HAND := Vector2(48, 6)
## Each shape's canopy: half-width, height, how far the rim hangs below its middle, how many ribs.
const UMBRELLA_CANOPIES := {
	"dome": {"across": 64.0, "high": 30.0, "rim": 6.0, "ribs": 4, "middle": -18.0},
	"wide": {"across": 78.0, "high": 22.0, "rim": 5.0, "ribs": 5, "middle": -20.0},
	"bubble": {"across": 50.0, "high": 46.0, "rim": 14.0, "ribs": 4, "middle": -6.0},
	"compact": {"across": 54.0, "high": 26.0, "rim": 6.0, "ribs": 3, "middle": -16.0},
}

## Its own dice for scenery that comes and goes by itself (the tent's: it never shifts the
## game's own rolls).
var dice: RandomNumberGenerator
## Tonight (its weather: snow settles on umbrellas, rain runs off them).
var night: Night
## Tonight's weather, as NightRules.weather_kind says it (the night's).
var weather_kind: String:
	get:
		return night.weather_kind
	set(value):
		night.weather_kind = value


func _init(scenery_dice: RandomNumberGenerator, tonight: Night = null) -> void:
	dice = scenery_dice
	night = tonight if tonight != null else Night.new()  # (on its own, in a test: a night of its own)


## A grey-box person: a head, a body and a name tag, grouped so they move together.
## A plain person: a head and a body (dressed in their look by _dress), and a name tag.
func new_person(parent: Control, pos: Vector2, colour: Color) -> Control:
	var root := Control.new()
	root.position = pos
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(root)
	var head := Draw.rect(root, Vector2(17, 0), Vector2(46, 44), colour.lightened(0.25))
	head.name = "Head"
	var body := Draw.rect(root, Vector2(0, 44), Vector2(80, 106), colour)
	body.name = "Body"
	var tag := Label.new()
	tag.name = "Tag"
	tag.position = Vector2(-110, TAG_Y)
	tag.size = Vector2(300, 24)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 15)
	PixelFont.apply(tag, "name_tag")  # (in pixels: pixel_font.gd)
	tag.add_theme_constant_override("outline_size", 6)
	tag.add_theme_color_override("font_outline_color", Color.BLACK)
	root.add_child(tag)
	return root


## Dresses a person (from _person) in their look: hair, clothes and their colour, glasses,
## a bag, and the owner's apron. Still simple shapes, layered back to front, in two views:
## "Front" (facing us: walking along the street, coming in, leaving, and the owner behind the
## counter) and "Back" (sitting at the counter, facing their food and the owner). _face
## switches between them.
func dress(person: Control, look: Dictionary) -> void:
	for part in ["Head", "Body", "Look"]:
		var old := person.get_node_or_null(part)
		if old != null:
			person.remove_child(old)
			old.queue_free()
	var tag := person.get_node_or_null("Tag")
	if _dress_in_pixels(person, look):
		if tag != null:
			person.move_child(tag, -1)  # the name stays on top
		return
	var outfit := _layer_in(person, "Look")
	var skin := Color(Looks.SKIN_TONES[clampi(int(look.get("skin", 0)), 0, Looks.SKIN_TONES.size() - 1)])
	var hair_colour := Color(str(Looks.HAIR_COLOURS.get(look.get("hair_colour", "black"), Looks.HAIR_COLOURS["black"])[0]))
	var cloth := Color(str(Looks.CLOTHES_COLOURS.get(look.get("colour", "black"), Looks.CLOTHES_COLOURS["black"])[0]))
	var dark := cloth.darkened(0.25)
	var light := cloth.lightened(0.2)
	var hair := str(look.get("hair", "short"))
	var clothes := str(look.get("clothes", "knit"))
	var bag := str(look.get("bag", ""))
	var front := _layer_in(outfit, "Front")
	var back := _layer_in(outfit, "Back")
	back.visible = false

	# --- Facing us ---
	match hair:  # hair behind the head
		"long":
			Draw.rect(front, Vector2(12, 4), Vector2(56, 66), hair_colour)
		"ponytail":
			Draw.rect(front, Vector2(60, 10), Vector2(12, 36), hair_colour)
		"bun":
			_blob(front, Vector2(40, -8), 12.0, hair_colour)
	if clothes == "hoodie":
		Draw.rect(front, Vector2(10, 22), Vector2(60, 30), dark)  # the hood, behind the head
	if bag == "backpack":
		Draw.rect(front, Vector2(-6, 52), Vector2(12, 60), Color("3a3946"))
	var body := Draw.rect(front, Vector2(0, 44), Vector2(80, 106), cloth)
	body.name = "Body"
	match clothes:
		"suit", "blazer":
			_poly(front, [Vector2(28, 44), Vector2(52, 44), Vector2(40, 80)], Color("eef0f2") if clothes == "suit" else Color("cfe0ee"))
			_poly(front, [Vector2(24, 44), Vector2(30, 44), Vector2(40, 86), Vector2(36, 92)], dark)  # lapels
			_poly(front, [Vector2(50, 44), Vector2(56, 44), Vector2(44, 92), Vector2(40, 86)], dark)
			if clothes == "suit":
				_poly(front, [Vector2(38, 48), Vector2(42, 48), Vector2(44, 76), Vector2(40, 82), Vector2(36, 76)], Color("8a2a35"))  # the tie
		"trench":
			_poly(front, [Vector2(20, 44), Vector2(40, 44), Vector2(30, 66)], light)  # collar
			_poly(front, [Vector2(40, 44), Vector2(60, 44), Vector2(50, 66)], light)
			Draw.rect(front, Vector2(0, 98), Vector2(80, 6), dark)  # belt
			for y in [60, 76, 112]:
				Draw.rect(front, Vector2(30, y), Vector2(4, 4), dark)
				Draw.rect(front, Vector2(46, y), Vector2(4, 4), dark)
		"padded":
			Draw.rect(front, Vector2(14, 40), Vector2(52, 10), cloth)  # a high collar
			for y in range(58, 150, 16):
				Draw.rect(front, Vector2(0, y), Vector2(80, 2), dark)  # quilting
			Draw.rect(front, Vector2(39, 50), Vector2(2, 100), dark)  # zip
		"hoodie":
			Draw.rect(front, Vector2(16, 104), Vector2(48, 22), dark)  # pocket
			Draw.rect(front, Vector2(32, 46), Vector2(2, 20), light)  # drawstrings
			Draw.rect(front, Vector2(46, 46), Vector2(2, 20), light)
		"cardigan":
			Draw.rect(front, Vector2(30, 44), Vector2(20, 106), Color("e8e4da") if look.get("colour", "") != "white" else Color("9a9aa4"))
			for y in [62, 82, 102, 122]:
				Draw.rect(front, Vector2(26, y), Vector2(3, 3), dark)
		"scrubs":
			_poly(front, [Vector2(28, 44), Vector2(52, 44), Vector2(40, 64)], skin.darkened(0.05))
			Draw.rect(front, Vector2(48, 74), Vector2(16, 14), dark)  # chest pocket
		"work_jacket":
			Draw.rect(front, Vector2(0, 100), Vector2(80, 5), Color("e8e8e8", 0.85))  # reflective stripes
			Draw.rect(front, Vector2(0, 116), Vector2(80, 5), Color("e8e8e8", 0.85))
			Draw.rect(front, Vector2(16, 44), Vector2(48, 8), dark)  # collar
		"tshirt":
			_poly(front, [Vector2(30, 44), Vector2(50, 44), Vector2(40, 52)], skin)
		"knit":
			Draw.rect(front, Vector2(26, 44), Vector2(28, 6), dark)  # ribbed neck
			for x in range(4, 80, 8):
				Draw.rect(front, Vector2(x, 140), Vector2(3, 10), dark)  # ribbed hem
	if bool(look.get("apron", false)):  # the owner's apron
		Draw.rect(front, Vector2(26, 44), Vector2(4, 22), Color("f0e8d8"))
		Draw.rect(front, Vector2(50, 44), Vector2(4, 22), Color("f0e8d8"))
		Draw.rect(front, Vector2(18, 64), Vector2(44, 86), Color("f0e8d8"))
		Draw.rect(front, Vector2(24, 104), Vector2(32, 16), Color("e2d8c4"))  # its pocket
	var face := Draw.rect(front, Vector2(17, 0), Vector2(46, 44), skin)
	face.name = "Head"
	match hair:  # hair on the head, and the fringe
		"long", "bob":
			Draw.rect(front, Vector2(14, -6), Vector2(52, 16), hair_colour)
			Draw.rect(front, Vector2(12, 0), Vector2(9, 60 if hair == "long" else 34), hair_colour)
			Draw.rect(front, Vector2(59, 0), Vector2(9, 60 if hair == "long" else 34), hair_colour)
			Draw.rect(front, Vector2(20, 8), Vector2(26, 6), hair_colour)
		"ponytail", "bun":
			Draw.rect(front, Vector2(15, -5), Vector2(50, 13), hair_colour)
			Draw.rect(front, Vector2(15, 4), Vector2(5, 12), hair_colour)
			Draw.rect(front, Vector2(60, 4), Vector2(5, 12), hair_colour)
		"pixie":
			Draw.rect(front, Vector2(15, -4), Vector2(50, 13), hair_colour)
			Draw.rect(front, Vector2(15, 4), Vector2(7, 16), hair_colour)
			Draw.rect(front, Vector2(58, 4), Vector2(7, 10), hair_colour)
		"perm":
			for x in range(18, 66, 9):
				_blob(front, Vector2(x, -2 + (x % 2) * 3), 7.0, hair_colour)
			_blob(front, Vector2(16, 10), 6.0, hair_colour)
			_blob(front, Vector2(64, 10), 6.0, hair_colour)
		"short":
			Draw.rect(front, Vector2(15, -4), Vector2(50, 12), hair_colour)
			Draw.rect(front, Vector2(15, 4), Vector2(5, 10), hair_colour)
			Draw.rect(front, Vector2(60, 4), Vector2(5, 10), hair_colour)
		"side_part":
			Draw.rect(front, Vector2(15, -5), Vector2(50, 13), hair_colour)
			_poly(front, [Vector2(30, 8), Vector2(64, 8), Vector2(64, 14)], hair_colour)
			Draw.rect(front, Vector2(28, -5), Vector2(2, 9), hair_colour.lightened(0.25))  # the parting
		"buzz":
			Draw.rect(front, Vector2(17, -2), Vector2(46, 7), Color(hair_colour, 0.8))
		"two_block":
			Draw.rect(front, Vector2(14, -7), Vector2(52, 14), hair_colour)
			Draw.rect(front, Vector2(22, 6), Vector2(30, 9), hair_colour)  # the long fringe
			Draw.rect(front, Vector2(17, 6), Vector2(4, 10), Color(hair_colour, 0.6))  # shaved sides
			Draw.rect(front, Vector2(59, 6), Vector2(4, 10), Color(hair_colour, 0.6))
		"balding":
			Draw.rect(front, Vector2(15, 8), Vector2(6, 14), hair_colour)
			Draw.rect(front, Vector2(59, 8), Vector2(6, 14), hair_colour)
	if bool(look.get("glasses", false)):
		_frame(front, Vector2(23, 17), Vector2(14, 9), Color("1a1a20"))
		_frame(front, Vector2(43, 17), Vector2(14, 9), Color("1a1a20"))
		Draw.rect(front, Vector2(37, 20), Vector2(6, 2), Color("1a1a20"))
	if bag == "backpack":  # its straps over the shoulders
		Draw.rect(front, Vector2(14, 44), Vector2(6, 46), Color("3a3946"))
		Draw.rect(front, Vector2(60, 44), Vector2(6, 46), Color("3a3946"))

	# --- From behind ---
	Draw.rect(back, Vector2(0, 44), Vector2(80, 106), cloth)
	match clothes:
		"trench":
			Draw.rect(back, Vector2(0, 98), Vector2(80, 6), dark)  # belt
			Draw.rect(back, Vector2(38, 104), Vector2(4, 46), dark)  # the back vent
		"padded":
			Draw.rect(back, Vector2(14, 40), Vector2(52, 10), cloth)
			for y in range(58, 150, 16):
				Draw.rect(back, Vector2(0, y), Vector2(80, 2), dark)
		"suit", "blazer":
			Draw.rect(back, Vector2(38, 110), Vector2(4, 40), dark)  # the back seam
			Draw.rect(back, Vector2(28, 40), Vector2(24, 6), Color("eef0f2"))  # shirt collar
		"work_jacket":
			Draw.rect(back, Vector2(0, 100), Vector2(80, 5), Color("e8e8e8", 0.85))
			Draw.rect(back, Vector2(0, 116), Vector2(80, 5), Color("e8e8e8", 0.85))
		"knit":
			for x in range(4, 80, 8):
				Draw.rect(back, Vector2(x, 140), Vector2(3, 10), dark)
	if bool(look.get("apron", false)):
		Draw.rect(back, Vector2(0, 96), Vector2(80, 4), Color("f0e8d8"))  # apron strings, tied behind
	var neck := Draw.rect(back, Vector2(17, 0), Vector2(46, 44), skin)
	neck.name = "Head"
	match hair:  # the back of the head
		"long":
			Draw.rect(back, Vector2(14, -6), Vector2(52, 50), hair_colour)
			Draw.rect(back, Vector2(12, 40), Vector2(56, 34), hair_colour)  # down the back
		"bob":
			Draw.rect(back, Vector2(13, -6), Vector2(54, 46), hair_colour)
		"ponytail":
			Draw.rect(back, Vector2(15, -5), Vector2(50, 40), hair_colour)
			Draw.rect(back, Vector2(35, 26), Vector2(10, 36), hair_colour)  # the ponytail
		"bun":
			Draw.rect(back, Vector2(15, -5), Vector2(50, 40), hair_colour)
			_blob(back, Vector2(40, 12), 11.0, hair_colour.darkened(0.15))
		"perm":
			for x in range(18, 66, 9):
				for y in [0, 12, 24]:
					_blob(back, Vector2(x, y + (x % 2) * 3), 7.0, hair_colour)
		"balding":
			Draw.rect(back, Vector2(15, 16), Vector2(50, 18), hair_colour)  # a fringe of hair round the back
		"buzz":
			Draw.rect(back, Vector2(17, -2), Vector2(46, 34), Color(hair_colour, 0.8))
		_:  # short, side-parted, two-block, pixie: hair down to the nape
			Draw.rect(back, Vector2(15, -5), Vector2(50, 36), hair_colour)
	if clothes == "hoodie":
		Draw.rect(back, Vector2(14, 40), Vector2(52, 24), dark)  # the hood, hanging down the back
	match bag:
		"backpack":
			Draw.rect(back, Vector2(14, 56), Vector2(52, 56), Color("3a3946"))
		"tote":
			Draw.rect(back, Vector2(8, 50), Vector2(3, 46), Color("cdb894").darkened(0.2))
			Draw.rect(back, Vector2(-10, 92), Vector2(24, 30), Color("e6dcc6"))
	if bag in ["tote", "briefcase"]:  # carried at their side, either way
		if bag == "tote":
			Draw.rect(front, Vector2(70, 50), Vector2(3, 50), Color("cdb894").darkened(0.2))
			Draw.rect(front, Vector2(66, 96), Vector2(24, 30), Color("e6dcc6"))
		else:
			Draw.rect(front, Vector2(70, 120), Vector2(30, 22), Color("4a3020"))
			_frame(front, Vector2(79, 114), Vector2(12, 7), Color("4a3020"))
			Draw.rect(back, Vector2(-20, 120), Vector2(30, 22), Color("4a3020"))
	if tag != null:
		person.move_child(tag, -1)  # the name stays on top


## The person in pixel art, both ways round, if there's art for their look (people_art.gd):
## whether they were.
func _dress_in_pixels(person: Control, look: Dictionary, holding: String = "") -> bool:
	person.set_meta("look", look)
	var front_art := PeopleArt.texture(look, "front", 0, holding)
	var back_art := PeopleArt.texture(look, "back")
	if front_art == null or back_art == null:
		Art.drawn("person/front_body_%s" % str(look.get("clothes", "knit")))
		return false
	var outfit := _layer_in(person, "Look")
	for view in [["Front", front_art, PeopleArt.BREATHE_FROM], ["Back", back_art, PeopleArt.BREATHE_FROM + PeopleArt.SEATED_DOWN]]:
		var picture := PixelPerson.new(view[1], view[2], view[0] == "Front", PeopleArt.side_frames(look, holding) if view[0] == "Front" else [])  # (on the grid's lines, breathing, walking from the side)
		picture.name = view[0]
		outfit.add_child(picture)
	outfit.get_node("Back").visible = false
	return true


## Someone's big moment's mood, in their pose (pixel_person.gd POSES: a laugh, a slump, a jolt, a
## nod, a fidget), whichever way round they are; people drawn in shapes have none.
func pose(person: Control, mood: String) -> void:
	for view in ["Look/Front", "Look/Back"]:
		var picture := person.get_node_or_null(view)
		if picture is PixelPerson and picture.visible:
			picture.pose(mood)


## Which way someone's facing: toward us (walking, coming in, leaving, the owner), or away
## (sitting at the counter, facing their food and the owner).
func turn(person: Control, toward_us: bool) -> void:
	var front := person.get_node_or_null("Look/Front") as Control
	var back := person.get_node_or_null("Look/Back") as Control
	if front != null and back != null:
		front.visible = toward_us
		back.visible = not toward_us
		var tag := person.get_node_or_null("Tag") as Control
		if tag != null and back is PixelPerson:  # (seated in pixels, their head's lower: their name with it)
			tag.position.y = TAG_Y + (0.0 if toward_us else PeopleArt.SEATED_DOWN * PeopleArt.SCALE)


func _layer_in(parent: Control, layer_name: String) -> Control:
	var layer := Control.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(layer)
	return layer


func _poly(parent: Control, points: Array, colour: Color) -> Polygon2D:
	var shape := Polygon2D.new()
	shape.polygon = PackedVector2Array(points)
	shape.color = colour
	parent.add_child(shape)
	return shape


func _blob(parent: Control, centre: Vector2, radius: float, colour: Color) -> Polygon2D:
	var points: Array = []
	for k in 12:
		points.append(centre + Vector2.from_angle(TAU * k / 12.0) * radius)
	return _poly(parent, points, colour)


## A rectangle's outline (glasses, a handle).
func _frame(parent: Control, pos: Vector2, rect_size: Vector2, colour: Color) -> void:
	Draw.rect(parent, pos, Vector2(rect_size.x, 2), colour)
	Draw.rect(parent, pos + Vector2(0, rect_size.y - 2), Vector2(rect_size.x, 2), colour)
	Draw.rect(parent, pos, Vector2(2, rect_size.y), colour)
	Draw.rect(parent, pos + Vector2(rect_size.x - 2, 0), Vector2(2, rect_size.y), colour)


## A phone held up in front of them, its screen lighting their face, glancing up now and then.
func add_phone(person: Control) -> void:
	person.set_meta("on_phone", true)
	if person.has_meta("look") and person.get_node_or_null("Look/Front") is PixelPerson:  # (in pixels: redressed holding it)
		var old := person.get_node("Look")
		person.remove_child(old)
		old.queue_free()
		_dress_in_pixels(person, person.get_meta("look"), "phone")
		var tag := person.get_node_or_null("Tag")
		if tag != null:
			person.move_child(tag, -1)
	var glow := Draw.rect(person, Vector2(33, 18), Vector2(30, 30), Color(0.55, 0.75, 1.0, 0.18))  # the screen's light on their face
	glow.name = "PhoneGlow"
	var phone := Draw.rect(person, Vector2(57, 78), Vector2(12, 21), Color("1c1c24"))  # (in whole pixels of the grid's size, in the hand at the chest: people.py PHONE_HAND_FRONT)
	phone.name = "Phone"
	var screen := Draw.rect(phone, Vector2(3, 3), Vector2(6, 15), Color(0.7, 0.85, 1.0))
	screen.name = "Screen"
	var flicker := screen.create_tween().set_loops()  # scrolling: the light changes a little
	flicker.tween_property(screen, "color", Color(0.85, 0.9, 1.0), Draw.scaled(randf_range(0.6, 1.4)))
	flicker.tween_property(screen, "color", Color(0.65, 0.8, 1.0), Draw.scaled(randf_range(0.6, 1.4)))


func add_umbrella(person: Control, gear: Dictionary = {"umbrella": true, "shape": "dome", "size": 1.0, "tilt": 0.0}) -> void:
	var holder := Node2D.new()
	holder.name = "Umbrella"
	holder.position = UMBRELLA_HAND + Vector2(float(gear.get("reach", 0.0)), 0)  # (reach: held out over a friend too)
	holder.rotation = float(gear.get("tilt", 0.0))
	holder.scale = Vector2.ONE * float(gear.get("size", 1.0))
	holder.set_meta("shape", str(gear.get("shape", "dome")))
	person.add_child(holder)
	var shape: Dictionary = UMBRELLA_CANOPIES.get(str(gear.get("shape", "dome")), UMBRELLA_CANOPIES["dome"])
	var middle := Vector2(0, float(shape["middle"]) - UMBRELLA_HAND.y)  # (from the hand)
	var across := float(shape["across"])
	var high := float(shape["high"])
	var metal := Color("55536b")
	holder.add_child(_bar(Vector2(-1, middle.y - high + 8), Vector2(2, high - 8 - middle.y), metal, holder.scale.x))  # the shaft, down to the hand
	var points := PackedVector2Array()
	for step in 13:
		var angle: float = PI + PI * step / 12.0
		points.append(middle + Vector2(cos(angle) * across, sin(angle) * high))
	var ribs := int(shape["ribs"])
	for rib in range(ribs - 1, -1, -1):  # back along a scalloped rim, dipping between the ribs
		points.append(middle + Vector2(-across + 2.0 * across * (rib + 0.5) / ribs, float(shape["rim"])))
		if rib > 0:
			points.append(middle + Vector2(-across + 2.0 * across * rib / ribs, 0))
	var canopy := PixelShape.sprite(points, UMBRELLA_CLEAR if str(gear.get("shape", "")) == "bubble" else UMBRELLA_COLOURS.pick_random(), holder.scale.x)  # (in pixels: the grid's size)
	canopy.name = "Canopy"
	holder.add_child(canopy)
	holder.add_child(_bar(Vector2(-2, middle.y - high - 4), Vector2(4, 6), metal, holder.scale.x))  # the tip
	# The weather lands on it (unlike some K-drama umbrellas): snow builds up on top, and
	# rain runs off the rim in drops.
	holder.set_meta("middle", middle)
	holder.set_meta("across", across)
	if weather_kind == "snow":
		_snow_cap(holder, middle, across, high)
	elif weather_kind in ["rain", "drizzle"]:
		for k in (5 if weather_kind == "rain" else 3):
			_drip(holder, middle + Vector2(dice.randf_range(-across, across) * 0.95, float(shape["rim"])))


## Snow settling on an umbrella: a white cap over the top, building up while they walk.
func _snow_cap(holder: Node2D, middle: Vector2, across: float, high: float) -> void:
	var points := PackedVector2Array()
	for step in 11:  # along the top, a little above the canopy...
		var angle: float = PI * 1.12 + PI * 0.76 * step / 10.0
		points.append(middle + Vector2(cos(angle) * across * 0.98, sin(angle) * (high + 4.0)))
	for step in range(10, -1, -1):  # ...and back along it, lower in the middle: thicker on top
		var angle: float = PI * 1.12 + PI * 0.76 * step / 10.0
		points.append(middle + Vector2(cos(angle) * across * 0.95, sin(angle) * high * 0.82))
	var cap := PixelShape.sprite(points, Color(0.95, 0.96, 1.0, 0.95), holder.scale.x, false)  # (in pixels, as the canopy)
	cap.name = "SnowCap"
	cap.modulate.a = 0.0
	holder.add_child(cap)
	cap.create_tween().tween_property(cap, "modulate:a", 1.0, Draw.scaled(5.0))  # building up


## A raindrop running off the umbrella's rim, again and again.
func _drip(holder: Node2D, from: Vector2) -> void:
	var drop := _bar(Vector2(-1, 0), Vector2(2, 5), Color(0.7, 0.82, 1.0, 0.85))
	drop.name = "Drip"
	drop.position = from
	drop.modulate.a = 0.0
	holder.add_child(drop)
	var fall := drop.create_tween().set_loops()
	fall.tween_interval(Draw.scaled(dice.randf_range(0.2, 1.4)))
	fall.tween_property(drop, "modulate:a", 1.0, 0.01).from(0.0)
	fall.tween_property(drop, "position", from + Vector2(0, 34), Draw.scaled(0.35)).from(from).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	fall.parallel().tween_property(drop, "modulate:a", 0.0, Draw.scaled(0.35))


## Under the tarp, the umbrella gets a shake before it's folded: the snow (or the rain) flies off.
func _shake_off(person: Control, holder: Node2D) -> void:
	var snowy := holder.get_node_or_null("SnowCap") != null
	var wet := holder.get_node_or_null("Drip") != null
	if not snowy and not wet:
		return
	var middle: Vector2 = holder.get_meta("middle", Vector2.ZERO)
	var across := float(holder.get_meta("across", 50.0))
	var start := holder.position + middle * holder.scale
	for k in 7:
		var bit := _bar(Vector2(-2, -2), Vector2(4, 4) if snowy else Vector2(2, 5), Color(1, 1, 1, 0.9) if snowy else Color(0.7, 0.82, 1.0, 0.8))
		bit.name = "ShakenOff"
		bit.position = start + Vector2(dice.randf_range(-across, across), dice.randf_range(-10.0, 4.0))
		person.add_child(bit)
		var fly := bit.create_tween()
		fly.tween_property(bit, "position", bit.position + Vector2(dice.randf_range(-40.0, 40.0), dice.randf_range(40.0, 90.0)), Draw.scaled(0.5)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fly.parallel().tween_property(bit, "modulate:a", 0.0, Draw.scaled(0.5))
		fly.tween_callback(bit.queue_free)


## A rectangle for something that isn't a Control (the umbrella's shaft and tip).
## A straight little piece (a shaft, a tip, a drop) in the grid's pixels: at least one, never
## a sliver thinner than a pixel. scale: its holder's (so its pixels stay the grid's size).
func _bar(pos: Vector2, bar_size: Vector2, colour: Color, scale: float = 1.0) -> Sprite2D:
	var cell := 3.0 / maxf(scale, 0.01)
	var cells := Vector2i(maxi(1, roundi(bar_size.x / cell)), maxi(1, roundi(bar_size.y / cell)))
	var image := Image.create(cells.x, cells.y, false, Image.FORMAT_RGBA8)
	image.fill(colour)
	var bar := Sprite2D.new()
	bar.texture = ImageTexture.create_from_image(image)
	bar.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	bar.centered = false
	bar.position = ((pos + bar_size / 2.0) / cell - Vector2(cells) / 2.0).round() * cell
	bar.scale = Vector2.ONE * cell
	return bar


## No umbrella: a bag (or a jacket) held over their head, leaning into it, bobbing as they run.
func run_for_it(person: Control, going_right: bool) -> void:
	var ground := person.position.y
	person.set_meta("running", true)
	person.set_meta("ground", ground)
	var cover := PixelShape.sprite(PackedVector2Array([Vector2(8, -4), Vector2(72, -8), Vector2(70, 4), Vector2(10, 6)]),
		CUSTOMER_COLORS.pick_random().darkened(0.4))  # (a jacket or a bag, in pixels as the umbrellas are)
	cover.name = "OverHead"
	person.add_child(cover)
	person.pivot_offset = Vector2(48, 216)  # leaning from the feet (Layout.PERSON_SIZE)
	lean(person, 0.1 if going_right else -0.1)
	var bob := person.create_tween().set_loops()
	bob.tween_property(person, "position:y", ground - 6, Draw.scaled(0.14)).set_trans(Tween.TRANS_SINE)
	bob.tween_property(person, "position:y", ground, Draw.scaled(0.14)).set_trans(Tween.TRANS_SINE)
	person.set_meta("bob", bob)


## In out of the weather: the umbrella folds down and goes, and anyone running stops.
func gear_down(person: Control) -> void:
	if not is_instance_valid(person):
		return
	var umbrella := person.get_node_or_null("Umbrella") as Node2D
	if umbrella != null:
		umbrella.name = "UmbrellaDown"  # (so it's gone straight away, as far as anyone looking is concerned)
		_shake_off(person, umbrella)
		var fold := umbrella.create_tween()
		var tilt := umbrella.rotation
		fold.tween_property(umbrella, "rotation", tilt + 0.3, Draw.scaled(0.06))  # a shake...
		fold.tween_property(umbrella, "rotation", tilt - 0.3, Draw.scaled(0.08))
		fold.tween_property(umbrella, "rotation", tilt, Draw.scaled(0.06))
		fold.tween_property(umbrella, "scale:x", umbrella.scale.x * 0.15, Draw.scaled(0.2)).set_trans(Tween.TRANS_SINE)  # ...and folded
		fold.parallel().tween_property(umbrella, "modulate:a", 0.0, Draw.scaled(0.25))
		fold.tween_callback(umbrella.queue_free)
	var cover := person.get_node_or_null("OverHead")
	if cover != null:
		person.remove_child(cover)  # (gone now, not at the end of the frame)
		cover.queue_free()
	if is_running(person):
		var bob: Tween = person.get_meta("bob")
		if bob != null and bob.is_valid():
			bob.kill()
		lean(person, 0.0)
		person.position.y = float(person.get_meta("ground"))
		person.remove_meta("running")


## Someone leaning (radians, + to the right: a tipsy sway, running for it, turning away to
## drink). In pixel art they're never turned (turned pixels shimmer, and their name over them
## would too): their head and shoulders lean over a pixel or two (pixel_person.gd lean). Drawn
## in shapes, they tilt as before.
func lean(person: Control, amount: float) -> void:
	if not is_instance_valid(person):
		return
	person.set_meta("lean", amount)
	var pictures: Array = ["Look/Front", "Look/Back"].map(func(path): return person.get_node_or_null(path)).filter(func(p): return p is PixelPerson)
	if pictures.is_empty():
		person.rotation = amount
		return
	person.rotation = 0.0
	for picture in pictures:
		picture.lean = amount


## How far someone's leaning (lean).
func leaning(person: Control) -> float:
	return float(person.get_meta("lean", 0.0))


## A lean from one amount to another, as a step of a tween.
func lean_step(tween: Tween, person: Control, from: float, to: float, seconds: float) -> MethodTweener:
	return tween.tween_method(func(amount: float): lean(person, amount), from, to, seconds)


func is_running(person: Control) -> bool:
	return is_instance_valid(person) and bool(person.get_meta("running", false))
