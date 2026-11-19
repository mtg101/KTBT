extends GdUnitTestSuite
## Tests for scripts/ui/people_art.gd: a person built in pixel art from the layers (drawn by
## tools/art/people.py), painted onto their own colours' ramps.

const PeopleArt = preload("res://scripts/ui/people_art.gd")
const PeopleView = preload("res://scripts/bar/people_view.gd")
const PixelPerson = preload("res://scripts/ui/pixel_person.gd")
const Art = preload("res://scripts/ui/art.gd")
const Looks = preload("res://scripts/rules/looks.gd")

const OWNER := {"age_range": "60s", "hair": "perm", "hair_colour": "grey", "clothes": "cardigan", "colour": "mint", "glasses": false,
	"bag": "", "skin": 1, "apron": true, "height": "tall"}  # (tall: drawn as the layers are)
const STUDENT := {"age_range": "20s", "hair": "long", "hair_colour": "black", "clothes": "hoodie", "colour": "charcoal", "glasses": true,
	"bag": "backpack", "skin": 2, "apron": false, "height": "tall"}


func after_test() -> void:
	Art.folder = "res://art/"
	Art.reset()
	PeopleArt.reset()


func test_a_person_is_stacked_from_their_looks_layers() -> void:
	assert_array(PeopleArt.layers_for(OWNER, "front")).is_equal(["front_body_cardigan", "front_apron", "front_head_old", "front_hair_perm"])
	assert_array(PeopleArt.layers_for(STUDENT, "front")).is_equal(["front_hairback_long", "front_body_hoodie", "front_head", "front_hair_long", "front_glasses", "front_backpack"])
	assert_array(PeopleArt.layers_for(STUDENT, "back")).is_equal(["back_hairback_long", "back_body_hoodie", "back_head", "back_hair_long", "back_backpack"])  # (no glasses from behind)
	for view in ["front", "back", "side"]:  # every look the game can pick has its layers
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
	# Walking from the side whenever they move: a frame of the stride for every so far, mirrored going
	# left, standing (facing us) again once they stop.
	front._process(0.0)
	assert_int(front.walk_frame).is_equal(-1)
	for k in 5:
		person.position.x += PixelPerson.STEP / 2
		front._process(0.016)
	assert_int(front.walk_frame).is_equal(2)  # (50 gone)
	assert_bool(front.facing_left).is_false()
	var walker: TextureRect = front.get_child(2)
	assert_object(walker.texture).is_same(PeopleArt.side_frames(OWNER)[2])
	assert_bool(walker.flip_h).is_false()
	person.position.x -= PixelPerson.STEP
	front._process(0.016)
	assert_bool(front.facing_left).is_true()
	assert_bool(walker.flip_h).is_true()  # (walking left: the side view mirrored)
	view.add_phone(person)
	front = person.get_node("Look/Front")  # (redressed holding it: a new picture)
	walker = front.get_child(2)
	upper = front.get_child(1)
	front._process(0.016)
	person.position.x -= PixelPerson.STEP
	front._process(0.016)
	var phone := person.get_node("Phone") as Control
	assert_float(phone.position.x).is_less(48.0)  # (held in front of their face: walking left, on the left)
	person.position.x += PixelPerson.STEP * 2
	front._process(0.016)
	front._process(0.016)
	assert_float(phone.position.x).is_greater(48.0)  # (walking right, on the right)
	for k in 20:
		front._process(0.016)
	assert_int(front.walk_frame).is_equal(-1)
	assert_bool(walker.visible).is_false()
	assert_vector(phone.position).is_equal(phone.get_meta("front_at"))  # (stopped, facing us: held up at the chest)
	# On a phone, it's in their hand: the arm bent up to hold it (facing us and walking), not hanging.
	assert_array(PeopleArt.layers_for(OWNER, "front", 0, "phone")).contains(["front_arm_phone"])
	assert_array(PeopleArt.layers_for(OWNER, "side", 1, "phone")).contains(["side_arm_phone"])
	assert_array(PeopleArt.layers_for(OWNER, "side", 1, "phone")).not_contains(["side_arm_1"])
	var hands_down := PeopleArt.texture(OWNER, "front").get_image()
	var on_phone := PeopleArt.texture(OWNER, "front", 0, "phone").get_image()
	assert_float(hands_down.get_pixel(28, 40).a).is_equal(1.0)  # (the arm down at their side...)
	assert_float(on_phone.get_pixel(28, 40).a).is_equal(0.0)  # (...up holding the phone)
	assert_bool(person.get_node("Look/Front") is PixelPerson).is_true()  # (redressed holding it)
	var suited := OWNER.duplicate()
	suited["bag"] = "briefcase"
	assert_array(PeopleArt.layers_for(suited, "side", 2)).contains(["side_briefcase_2"])  # (in the near hand from the side)
	var stride: Array = PeopleArt.side_frames(OWNER)
	assert_int(stride.size()).is_equal(PeopleArt.WALK_FRAMES)
	assert_object(stride[0]).is_not_same(stride[1])  # (the legs and arms move)
	assert_array(PeopleArt.layers_for(STUDENT, "side", 1)).is_equal(["side_arm_far_1", "side_legs_1", "side_body_hoodie", "side_backpack", "side_head", "side_hair_long", "side_glasses", "side_arm_1"])
	var tee := STUDENT.duplicate()
	tee["clothes"] = "tshirt"
	assert_array(PeopleArt.layers_for(tee, "side", 0)).contains(["side_arm_bare_0"])  # (short sleeves: bare arms)
	# Without the side view's layers, they glide facing us with a bob.
	var up: Image = PeopleArt.walk_frames(PeopleArt.texture(OWNER, "front"))[1].get_image()
	assert_float(up.get_pixel(11, PeopleArt.SIZE.y - 1).a).is_equal(0.0)  # (up a pixel off the ground)
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


func test_seated_from_behind_an_arm_goes_up_for_a_moment() -> void:
	# The layers: a glass or chopsticks behind the head (by the mouth), a hand to the head over the hair.
	var drink := PeopleArt.layers_for(STUDENT, "back", 0, "drink")
	assert_int(drink.find("back_arm_drink")).is_less(drink.find("back_head"))
	var head := PeopleArt.layers_for(STUDENT, "back", 0, "head")
	assert_int(head.find("back_arm_head")).is_greater(head.find("back_hair_long"))
	var bare := OWNER.duplicate()
	bare["clothes"] = "tshirt"
	assert_array(PeopleArt.layers_for(bare, "back", 0, "eat")).contains(["back_arm_eat_bare"])  # (short sleeves)
	assert_array(PeopleArt.layers_for(STUDENT, "front", 0, "drink")).not_contains(["back_arm_drink"])  # (from behind only)
	# The picture: the arm resting on the counter gone, the raised one there.
	var own := PeopleArt.texture(STUDENT, "back").get_image()
	var raised := PeopleArt.texture(STUDENT, "back", 0, "drink").get_image()
	var low := PeopleArt.BACK_ARM_CLEAR.position + Vector2i(0, 15)
	assert_float(own.get_pixelv(low).a).is_greater(0.0)
	assert_float(raised.get_pixelv(low).a).is_equal(0.0)
	assert_bool(raised.get_data() != own.get_data()).is_true()
	# On someone seated: for a moment, then themselves again.
	var view := PeopleView.new(RandomNumberGenerator.new())
	var stage: Control = auto_free(Control.new())
	add_child(stage)
	var person := view.new_person(stage, Vector2.ZERO, Color.WHITE)
	view.dress(person, STUDENT)
	assert_bool(view.gesture(person, "drink")).is_false()  # (facing us: no)
	view.turn(person, false)
	assert_bool(view.gesture(person, "drink", 0.2)).is_true()
	var back = person.get_node("Look/Back")
	assert_str(back.gesture).is_equal("drink")
	await get_tree().create_timer(0.4).timeout
	assert_str(back.gesture).is_equal("")
	assert_bool(view.gesture(person, "eat")).is_true()  # two or three mouthfuls
	assert_str(back.gesture).is_equal("eat")
	view.pose(person, "sad")  # a sad moment: a hand to the head too
	assert_str(back.gesture).is_equal("head")


func test_heights_builds_hats_and_a_lanyard() -> void:
	# Shorter people come down two rows a height; their name with them.
	var tall := PeopleArt.texture(OWNER, "front").get_image()
	var average := OWNER.duplicate()
	average["height"] = "average"
	var short := OWNER.duplicate()
	short["height"] = "short"
	assert_bool(PeopleArt.texture(average, "front").get_image().get_pixel(16, 3 + 2).is_equal_approx(tall.get_pixel(16, 3))).is_true()
	assert_bool(PeopleArt.texture(short, "front").get_image().get_pixel(16, 3 + 4).is_equal_approx(tall.get_pixel(16, 3))).is_true()
	assert_int(PeopleArt.drop_rows({})).is_equal(2)  # (a look from before heights: average)
	var view := PeopleView.new(RandomNumberGenerator.new())
	var stage: Control = auto_free(Control.new())
	add_child(stage)
	var person := view.new_person(stage, Vector2.ZERO, Color.WHITE)
	view.dress(person, short)
	assert_float(person.get_node("Tag").position.y).is_equal(PeopleView.TAG_Y + 4 * PeopleArt.SCALE)
	# Broad or slight: the torso a pixel wider or narrower each side, the head as it was.
	var row := PeopleArt.BUILD_ROWS.x + 8
	var broad := OWNER.duplicate()
	broad["build"] = "broad"
	var slim := OWNER.duplicate()
	slim["build"] = "slim"
	assert_int(_width(PeopleArt.texture(broad, "front").get_image(), row)).is_equal(_width(tall, row) + 2)
	assert_int(_width(PeopleArt.texture(slim, "front").get_image(), row)).is_equal(_width(tall, row) - 2)
	assert_int(_width(PeopleArt.texture(broad, "front").get_image(), 8)).is_equal(_width(tall, 8))
	# A hat over the hair, every way round; a lanyard facing us.
	var hatted := STUDENT.duplicate()
	hatted["hat"] = "beanie"
	hatted["lanyard"] = true
	for view_name in ["front", "back"]:
		var ids := PeopleArt.layers_for(hatted, view_name)
		assert_int(ids.find("%s_hat_beanie" % view_name)).is_greater(ids.find("%s_hair_long" % view_name))
	assert_array(PeopleArt.side_layers(hatted, 0)).contains(["side_hat_beanie"])
	assert_array(PeopleArt.layers_for(hatted, "front")).contains(["front_lanyard"])
	assert_array(PeopleArt.layers_for(hatted, "back")).not_contains(["front_lanyard"])
	for hat in Looks.HATS:
		for view_name in ["front", "back", "side"]:
			assert_bool(Art.has("person/%s_hat_%s" % [view_name, hat])).is_true()


## How wide someone is on a row of their picture (its first to last drawn pixel).
func _width(picture: Image, row: int) -> int:
	var first := -1
	var last := -1
	for x in picture.get_width():
		if picture.get_pixel(x, row).a > 0.0:
			if first < 0:
				first = x
			last = x
	return last - first + 1
