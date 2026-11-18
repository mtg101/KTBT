extends GdUnitTestSuite
## Tests for scripts/ui/people_art.gd: a person built in pixel art from the layers (drawn by
## tools/art/people.py), painted onto their own colours' ramps.

const PeopleArt = preload("res://scripts/ui/people_art.gd")
const PeopleView = preload("res://scripts/bar/people_view.gd")
const PixelPerson = preload("res://scripts/ui/pixel_person.gd")
const Art = preload("res://scripts/ui/art.gd")
const Looks = preload("res://scripts/rules/looks.gd")

const OWNER := {"age_range": "60s", "hair": "perm", "hair_colour": "grey", "clothes": "cardigan", "colour": "mint", "glasses": false,
	"bag": "", "skin": 1, "apron": true}
const STUDENT := {"age_range": "20s", "hair": "long", "hair_colour": "black", "clothes": "hoodie", "colour": "charcoal", "glasses": true,
	"bag": "backpack", "skin": 2, "apron": false}


func after_test() -> void:
	Art.folder = "res://art/"
	Art.reset()
	PeopleArt.reset()


func test_a_person_is_stacked_from_their_looks_layers() -> void:
	assert_array(PeopleArt.layers_for(OWNER, "front")).is_equal(["front_body_cardigan", "front_apron", "front_head_old", "front_hair_perm"])
	assert_array(PeopleArt.layers_for(STUDENT, "front")).is_equal(["front_hairback_long", "front_body_hoodie", "front_head", "front_hair_long", "front_glasses", "front_backpack"])
	assert_array(PeopleArt.layers_for(STUDENT, "back")).is_equal(["back_hairback_long", "back_body_hoodie", "back_head", "back_hair_long", "back_backpack"])  # (no glasses from behind)
	for view in ["front", "back"]:  # every look the game can pick has its layers
		for k in 30:
			var look := Looks.pick_look(["woman", "man", "non-binary"][k % 3], Looks.pick_age_range(k / 30.0), "")
			for id in PeopleArt.layers_for(look, view):
				assert_bool(Art.has("person/" + str(id))).override_failure_message(str(id)).is_true()


func test_their_picture_is_painted_in_their_own_colours() -> void:
	var made := PeopleArt.texture(OWNER, "front")
	assert_vector(Vector2(made.get_size())).is_equal(Vector2(PeopleArt.SIZE))
	assert_object(PeopleArt.texture(OWNER, "front")).is_same(made)  # (made once)
	var picture := made.get_image()
	var hair: Array = PeopleArt.ramp(Color(Looks.HAIR_COLOURS["grey"][0]))
	var crown := picture.get_pixel(16, 3)  # the top of the head: the perm, on grey's ramp
	assert_bool(_on(hair, crown)).override_failure_message(str(crown)).is_true()
	var apron := picture.get_pixel(16, 45)  # the apron's a fixed colour, whatever they wear
	assert_bool(_on(PeopleArt.ramp(Color(PeopleArt.FIXED[7])), apron)).is_true()
	assert_float(picture.get_pixel(0, 0).a).is_equal(0.0)  # (round them, see-through)
	var greyer := OWNER.duplicate()
	greyer["hair_colour"] = "black"
	assert_bool(PeopleArt.texture(greyer, "front").get_image().get_pixel(16, 3).is_equal_approx(crown)).is_false()  # (the same perm, black)


## Whether a pixel (8 bits a channel) is one of a ramp's steps.
func _on(ramp: Array, pixel: Color) -> bool:
	return ramp.any(func(step: Color): return absi(step.r8 - pixel.r8) <= 1 and absi(step.g8 - pixel.g8) <= 1 and absi(step.b8 - pixel.b8) <= 1)


func test_the_oldest_stoop() -> void:
	var young := OWNER.duplicate()
	young["age_range"] = "40s"
	var old := OWNER.duplicate()
	old["age_range"] = "70s"
	var standing := PeopleArt.texture(young, "front").get_image()
	var stooped := PeopleArt.texture(old, "front").get_image()
	var top := func(image: Image) -> int:
		for y in PeopleArt.SIZE.y:
			if image.get_pixel(16, y).a > 0.5:
				return y
		return -1
	assert_int(top.call(stooped)).is_equal(top.call(standing) + PeopleArt.STOOP)  # (their head lower)
	assert_bool(stooped.get_pixel(16, 60).is_equal_approx(standing.get_pixel(16, 60))).is_true()  # (the rest as it was)


func test_the_ramp_is_the_drawn_arts() -> void:
	# (tools/art/palette.py ramp("e8833a"), the same sums: the people match the tent)
	var expected := [[51, 12, 7], [84, 27, 14], [121, 49, 23], [167, 82, 37], [232, 131, 58], [239, 143, 71], [246, 154, 84]]
	var ramp: Array = PeopleArt.ramp(Color("e8833a"))
	for k in 7:
		var step: Color = ramp[k]
		for c in 3:
			assert_int(roundi([step.r, step.g, step.b][c] * 255)).override_failure_message("step %d" % k).is_between(expected[k][c] - 2, expected[k][c] + 2)


func test_without_the_layers_people_are_drawn_as_shapes() -> void:
	Art.folder = "res://tests/support/no_art_here/"
	Art.reset()
	assert_object(PeopleArt.texture(OWNER, "front")).is_null()
	var view := PeopleView.new(RandomNumberGenerator.new())
	var stage: Control = auto_free(Control.new())
	add_child(stage)
	var person := view.new_person(stage, Vector2.ZERO, Color.WHITE)
	view.dress(person, OWNER)
	assert_bool(person.get_node("Look/Front") is PixelPerson).is_false()  # (shapes)
	Art.folder = "res://art/"
	Art.reset()
	PeopleArt.reset()
	view.dress(person, OWNER)
	var front = person.get_node("Look/Front")
	assert_bool(front is PixelPerson).is_true()  # (pixels)
	assert_vector(front.size).is_equal(Vector2(PeopleArt.SIZE * PeopleArt.SCALE))
	# On the grid's lines wherever they are, and breathing: the head and shoulders rise, the rest stays.
	person.position = Vector2(100.4, 157.0)
	front.snap()
	assert_vector(person.position + front.position).is_equal(Vector2(99, 156))
	var upper: TextureRect = front.get_child(1)
	var lower: TextureRect = front.get_child(0)
	front.breathing = 1.0
	front._next_breath = 999.0
	front._process(0.0)
	assert_float(upper.position.y).is_equal(-PixelPerson.GRID)
	assert_float(lower.position.y).is_equal((PeopleArt.BREATHE_FROM - 1) * PixelPerson.GRID)
	# Bobbing whenever they move (facing us): up a pixel and down again every so far, standing again once they stop.
	front._process(0.0)
	assert_int(front.walk_frame).is_equal(-1)
	for k in 5:
		person.position.x += PixelPerson.STEP / 2
		front._process(0.016)
	assert_int(front.walk_frame).is_equal(0)  # (40 gone: two bobs, down again)
	person.position.x += PixelPerson.STEP
	front._process(0.016)
	assert_int(front.walk_frame).is_equal(1)
	for k in 20:
		front._process(0.016)
	assert_int(front.walk_frame).is_equal(-1)
	var frames: Array = PeopleArt.walk_frames(PeopleArt.texture(OWNER, "front"))
	assert_int(frames.size()).is_equal(2)  # (a glide and a bob, not steps on the spot)
	var up: Image = frames[1].get_image()
	assert_float(up.get_pixel(11, PeopleArt.SIZE.y - 1).a).is_equal(0.0)  # (up a pixel off the ground)
	assert_float(up.get_pixel(11, PeopleArt.SIZE.y - 2).a).is_equal(1.0)
	# A big moment's mood in their pose: a slump, then back to themselves.
	view.pose(person, "sad")
	assert_str(front.pose_mood).is_equal("sad")
	front._process(0.1)
	assert_float(upper.position.y).is_equal(PixelPerson.GRID * 2)  # (head down)
	front._process(PixelPerson.POSES["sad"])
	assert_str(front.pose_mood).is_empty()
	view.pose(person, "baffled")  # (a mood with no pose: nothing)
	assert_str(front.pose_mood).is_empty()
	view.turn(person, false)  # seated: their name comes down with their head
	assert_float(person.get_node("Tag").position.y).is_equal(PeopleView.TAG_Y + PeopleArt.SEATED_DOWN * PeopleArt.SCALE)
	view.turn(person, true)
	assert_float(person.get_node("Tag").position.y).is_equal(PeopleView.TAG_Y)
