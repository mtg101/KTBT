extends GdUnitTestSuite
## Tests for scripts/rules/portraits.gd (a look to its portrait), people_art.gd's portrait() (the
## face painted onto their own colours) and scripts/ui/portrait_hover.gd (the face in the hover).

const PortraitRules = preload("res://scripts/rules/portraits.gd")
const PortraitHover = preload("res://scripts/ui/portrait_hover.gd")
const PeopleArt = preload("res://scripts/ui/people_art.gd")
const Art = preload("res://scripts/ui/art.gd")
const Looks = preload("res://scripts/rules/looks.gd")
const Captions = preload("res://scripts/rules/captions.gd")

const TEAR := 14  # people_art.gd FIXED: the reaction faces' tears (tools/art/portraits.py FIXED_OF)
const STUDENT := {"age_range": "20s", "hair": "long", "hair_colour": "black", "clothes": "hoodie", "colour": "charcoal", "glasses": true, "skin": 2}


func after_test() -> void:
	Art.folder = "res://art/"
	Art.reset()
	PeopleArt.reset()


func _library() -> Array:
	return Art.ids("portrait").filter(func(id): return Art.has("portrait/" + str(id)))


func test_every_look_the_game_can_pick_has_its_own_portrait() -> void:
	var have := _library()
	assert_int(have.size()).is_equal(126)
	seed(7)
	for k in 300:
		var gender: String = ["woman", "man", "non-binary"][k % 3]
		var look := Looks.pick_look(gender, Looks.pick_age_range(randf()), ["clear", "cold", "muggy"][k % 3])
		var picked := PortraitRules.pick(gender, look, have)
		assert_str(str(picked["how"])).override_failure_message("%s %s" % [gender, look]).is_equal("matched")
		assert_bool(str(picked["key"]).ends_with("_glasses")).is_equal(bool(look["glasses"]))


func test_the_same_look_gets_the_same_face_whatever_its_colours() -> void:
	var have := _library()
	var first := PortraitRules.pick("woman", STUDENT, have)
	assert_dict(first).is_equal({"key": "w_20s_long_glasses", "how": "matched"})
	var recoloured := STUDENT.duplicate()
	recoloured.merge({"hair_colour": "pink", "colour": "mint", "skin": 0, "clothes": "padded"}, true)
	assert_dict(PortraitRules.pick("woman", recoloured, have)).is_equal(first)  # (a regular keeps their face, in tonight's clothes)
	assert_dict(PortraitRules.pick("woman", STUDENT, have)).is_equal(first)


func test_non_binary_customers_get_the_portrait_drawn_for_their_hairstyle() -> void:
	var have := _library()
	assert_str(str(PortraitRules.pick("non-binary", {"age_range": "30s", "hair": "pixie"}, have)["key"])).is_equal("w_30s_pixie")
	assert_str(str(PortraitRules.pick("non-binary", {"age_range": "30s", "hair": "two_block", "glasses": true}, have)["key"])).is_equal("m_30s_two_block_glasses")


func test_without_their_own_the_nearest_there_is() -> void:
	# Glasses wanted and none drawn: the same face without.
	assert_dict(PortraitRules.pick("man", {"age_range": "50s", "hair": "short", "glasses": true}, ["m_50s_short"])).is_equal({"key": "m_50s_short", "how": "fallback"})
	# No such hairstyle: the nearest (balding young, from an old save, gets short).
	assert_dict(PortraitRules.pick("man", {"age_range": "20s", "hair": "balding"}, ["m_20s_buzz", "m_20s_short"])).is_equal({"key": "m_20s_short", "how": "fallback"})
	# Not at their age: the nearest age range.
	assert_dict(PortraitRules.pick("woman", {"age_range": "60s", "hair": "perm"}, ["w_20s_perm", "w_70s_perm"])).is_equal({"key": "w_70s_perm", "how": "fallback"})
	# No age range (a look from before them): from their age.
	assert_str(PortraitRules.ideal("woman", {"hair": "bob"}, 44)).is_equal("w_40s_bob")
	# Nothing of theirs at all: none.
	assert_dict(PortraitRules.pick("woman", STUDENT, ["m_20s_short"])).is_equal({"key": "", "how": "none"})
	assert_dict(PortraitRules.pick("woman", STUDENT, [])).is_equal({"key": "", "how": "none"})


func test_a_portrait_is_painted_onto_their_own_colours() -> void:
	var face := PeopleArt.portrait(STUDENT, "w_20s_long_glasses")
	assert_object(face).is_not_null()
	assert_vector(Vector2(face.get_size())).is_equal(Vector2(PeopleArt.PORTRAIT_SIZE))
	assert_object(PeopleArt.portrait(STUDENT, "w_20s_long_glasses")).is_same(face)  # (made once)
	# Every hair pixel is on their hair colour's ramp; dyed pink, the same pixels on pink's.
	var pixels: PackedInt32Array = PeopleArt._pixels_of("portrait/w_20s_long_glasses", Art.texture("portrait/w_20s_long_glasses"), PeopleArt.PORTRAIT_SIZE)
	var pink := STUDENT.duplicate()
	pink["hair_colour"] = "pink"
	var pink_face := PeopleArt.portrait(pink, "w_20s_long_glasses").get_image()
	var black_ramp: Array = PeopleArt.ramp(Color(Looks.HAIR_COLOURS["black"][0]))
	var pink_ramp: Array = PeopleArt.ramp(Color(Looks.HAIR_COLOURS["pink"][0]))
	var black_image := face.get_image()
	var hair_pixels := 0
	for k in range(0, pixels.size(), 5):
		if pixels[k + 3] == PeopleArt.HAIR:
			hair_pixels += 1
			assert_bool(_same(black_image.get_pixel(pixels[k], pixels[k + 1]), black_ramp[pixels[k + 2]])).is_true()
			assert_bool(_same(pink_face.get_pixel(pixels[k], pixels[k + 1]), pink_ramp[pixels[k + 2]])).is_true()
	assert_int(hair_pixels).is_greater(500)  # (long hair: a good share of the picture)
	# Its outlines the ink itself (as portraits.py previews them), not the ink's deepest shadow.
	for k in range(0, pixels.size(), 5):
		if pixels[k + 3] == PeopleArt.FIXED_SLOT:
			assert_bool(_same(black_image.get_pixel(pixels[k], pixels[k + 1]), PeopleArt.ramp(Color(PeopleArt.FIXED[pixels[k + 4]]))[PeopleArt.BASE_STEP])).is_true()
			break
	assert_object(PeopleArt.portrait(STUDENT, "")).is_null()
	assert_object(PeopleArt.portrait(STUDENT, "w_20s_mohawk")).is_null()  # (not in the library)


func test_every_portrait_has_a_reaction_face_for_every_tv_mood() -> void:
	var checked := 0
	for id in _library():
		var moods: Array = Captions.REACTIONS.keys().filter(func(mood): return Art.has("reaction/%s_%s" % [id, mood]))
		assert_array(moods).override_failure_message("%s has only %s" % [id, moods]).has_size(Captions.REACTIONS.size())
		checked += 1
	assert_int(checked).is_equal(126)


func test_a_reaction_face_is_painted_onto_their_own_colours_with_its_own_tears() -> void:
	var calm := PeopleArt.portrait(STUDENT, "w_20s_long_glasses")
	var sad := PeopleArt.portrait(STUDENT, "w_20s_long_glasses", "sad")
	assert_object(sad).is_not_null()
	assert_vector(Vector2(sad.get_size())).is_equal(Vector2(PeopleArt.PORTRAIT_SIZE))
	assert_object(sad).is_not_same(calm)
	assert_object(PeopleArt.portrait(STUDENT, "w_20s_long_glasses", "sad")).is_same(sad)  # (made once)
	var pixels: PackedInt32Array = PeopleArt._pixels_of("reaction/w_20s_long_glasses_sad", Art.texture("reaction/w_20s_long_glasses_sad"), PeopleArt.PORTRAIT_SIZE)
	var image := sad.get_image()
	var hair_ramp: Array = PeopleArt.ramp(Color(Looks.HAIR_COLOURS["black"][0]))
	var tears := 0
	for k in range(0, pixels.size(), 5):
		if pixels[k + 3] == PeopleArt.HAIR:
			assert_bool(_same(image.get_pixel(pixels[k], pixels[k + 1]), hair_ramp[pixels[k + 2]])).is_true()
		elif pixels[k + 3] == PeopleArt.FIXED_SLOT and pixels[k + 4] == TEAR:
			tears += 1
			assert_bool(_same(image.get_pixel(pixels[k], pixels[k + 1]), PeopleArt.ramp(Color(PeopleArt.FIXED[TEAR]))[PeopleArt.BASE_STEP])).is_true()  # (its own blue, whatever their skin)
	assert_int(tears).is_greater(0)
	assert_object(PeopleArt.portrait(STUDENT, "w_20s_mohawk", "sad")).is_null()  # (no such face: the caller shows the calm one)


func test_the_hover_shows_their_face_beside_the_words() -> void:
	var hover: PortraitHover = auto_free(PortraitHover.new())
	assert_object(hover._make_custom_tooltip("Min-ji, 24")).is_null()  # (no portrait: the plain tooltip)
	hover.portrait = PeopleArt.portrait(STUDENT, "w_20s_long_glasses")
	var shown := [0]
	hover.shown.connect(func(): shown[0] += 1)
	var tip: Control = auto_free(hover._make_custom_tooltip("Min-ji, 24"))
	assert_object(tip).is_not_null()
	var face := tip.get_node("Portrait") as TextureRect
	assert_vector(face.custom_minimum_size).is_equal(Vector2(PeopleArt.PORTRAIT_SIZE * PortraitHover.SCALE))
	assert_int(face.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)  # (pixels, never smoothed)
	assert_str((tip.get_node("Words") as Label).text).is_equal("Min-ji, 24")
	assert_int(shown[0]).is_equal(1)


## Whether two colours are the same at 8 bits a channel (a pixel against a ramp's step).
func _same(pixel: Color, step: Color) -> bool:
	return absi(step.r8 - pixel.r8) <= 1 and absi(step.g8 - pixel.g8) <= 1 and absi(step.b8 - pixel.b8) <= 1


# --- Faces of their own ---------------------------------------------------------------------------

func test_a_face_of_their_own_is_asked_for_in_the_librarys_style_and_colours() -> void:
	var prompt := PortraitRules.prompt_for("woman", {"age_range": "60s", "hair": "perm", "hair_colour": "grey", "glasses": true}, 63,
		"A small, quick woman in a padded vest, grey curls under a headscarf, always wiping the counter.")
	assert_str(prompt).starts_with("Head and shoulders portrait of a Korean woman in her sixties with very curly, tightly permed short black hair")
	assert_str(prompt).contains("lines and wrinkles on her face, and thin-framed glasses")
	assert_str(prompt).contains("Who they are: A small, quick woman in a padded vest, grey curls under a headscarf, always wiping the counter.")
	assert_str(prompt).contains("Whatever the description says, black hair and a plain bright red top.")  # (said again after the description's own colours)
	assert_str(prompt).ends_with("Plain flat green background, no text.")
	var plain := PortraitRules.prompt_for("man", {"age_range": "30s", "hair": "two_block"})
	assert_str(plain).contains("man in his thirties with black hair in a two-block cut").contains("and no glasses").not_contains("Who they are")


func test_a_long_description_is_cut_to_a_line() -> void:
	var about := "word ".repeat(100)
	var prompt := PortraitRules.prompt_for("man", {"age_range": "40s", "hair": "short"}, 0, about)
	var line := prompt.get_slice("Who they are: ", 1).get_slice("...", 0)
	assert_int(line.length()).is_less_equal(PortraitRules.ABOUT_MOST)
	assert_str(prompt).contains("word...")


func test_a_face_of_their_own_has_an_id_of_its_own_and_is_painted_like_the_librarys() -> void:
	assert_str(PortraitRules.own_key("ggwa-pocha-1794600000", "owner", 81230)).is_equal("own_ggwa-pocha-1794600000_owner_81230")
	assert_bool(PortraitRules.is_own("own_x_owner_1")).is_true()
	assert_bool(PortraitRules.is_own("w_20s_long")).is_false()
	var key: String = _library()[0]
	var layer := Art.texture("portrait/" + key).get_image()
	var from_art := PeopleArt.portrait(STUDENT, key).get_image()
	var from_layer := PeopleArt.paint_portrait(STUDENT, layer).get_image()  # (a casting photo's split, not art yet)
	assert_bool(from_layer.get_data() == from_art.get_data()).override_failure_message("a layer painted another way").is_true()
	Art.own["portrait/own_test_owner_1"] = ImageTexture.create_from_image(layer)  # (one of their own: drawn as the library's are)
	assert_bool(PeopleArt.portrait(STUDENT, "own_test_owner_1").get_image().get_data() == from_art.get_data()).is_true()
	Art.own.erase("portrait/own_test_owner_1")
