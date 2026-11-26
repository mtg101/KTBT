extends GdUnitTestSuite
## Tests for the reaction split in scripts/rules/portrait_split.gd (react_split, react_face, close_up,
## react_parts, react_score and best()'s pick): the same answer as tools/art/portraits.py's, on the
## library's own pictures (tests/support/reactions: one man's calm picture and both seeds of his sad,
## sweet and shock faces, by Klein as the library's, with the Python's close-ups, layers, scores and
## picks from `portraits.py --expect`), and on a drawn close-up.

const PortraitSplit = preload("res://scripts/rules/portrait_split.gd")

const FIXTURES := "res://tests/support/reactions/"
const NEAR := 25  # game pixels (of 5,120) a whole split may differ from the Python's by: Godot's Lanczos isn't PIL's (14 at most on 22 Nov)
const NEAR_SCORE := 0.005  # and its score (0.001 at most; the closest pick, shock's, is 0.007 apart)


static var _grids := {}  # (each fixture split once for the suite)
static var _drawn_face: Image  # (and the drawn close-up made once: about 10 seconds)


func _picture(path: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(path))


func _expected() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "expected.json"))


## A fixture's split: from the Python's own close-up (whole: false), or the whole picture, as the game's.
func _split(file: String, whole: bool) -> Dictionary:
	var key := "%s|%s" % [file, whole]
	if not _grids.has(key):
		_grids[key] = PortraitSplit.react_split(_picture(FIXTURES + file)) if whole else \
			PortraitSplit.react_grid(_picture(FIXTURES + file.replace(".png", "_face.png")))
	return _grids[key]


## How many of two layers' game pixels differ.
func _differing(made: Image, want: Image) -> int:
	want.convert(Image.FORMAT_RGBA8)
	var a := made.get_data()
	var b := want.get_data()
	var count := 0
	@warning_ignore("integer_division")  # (whole numbers meant)
	for i in a.size() / 4:
		for c in 4:
			if a[i * 4 + c] != b[i * 4 + c]:
				count += 1
				break
	return count


## Each mood's pick from these splits, as the game would make it: {mood: seed}.
func _picks(whole: bool) -> Dictionary:
	var want := _expected()
	var calm: PackedInt32Array = _split(want["calm"], whole)["part"]
	var by_mood := {}
	for file in want["pictures"]:
		var about: Dictionary = want["pictures"][file]
		var score := PortraitSplit.react_score(_split(file, whole)["part"], calm, about["mood"])
		if not by_mood.has(about["mood"]):
			by_mood[about["mood"]] = []
		by_mood[about["mood"]].append({"score": score, "seed": int(about["seed"])})
	var picks := {}
	for mood in by_mood:
		picks[mood] = int(by_mood[mood][PortraitSplit.best(by_mood[mood])]["seed"])
	return picks


func test_the_reaction_split_of_the_pythons_close_ups_is_the_pythons() -> void:
	var want := _expected()
	assert_int(want["pictures"].size()).is_equal(6)
	var calm: Dictionary = _split(want["calm"], false)
	assert_int(_differing(calm["layer"], _picture(FIXTURES + want["calm"].replace(".png", "_layer.png")))).override_failure_message(
		"the calm close-up: game pixels differing from the Python's").is_equal(0)
	for file in want["pictures"]:
		var about: Dictionary = want["pictures"][file]
		var made := _split(file, false)
		assert_int(_differing(made["layer"], _picture(FIXTURES + file.replace(".png", "_layer.png")))).override_failure_message(
			"%s: game pixels differing from the Python's" % file).is_equal(0)
		var colours := PortraitSplit.colours(made["part"])
		for kind in ["white", "tear", "blush"]:  # (JSON's numbers come back as floats)
			assert_int(colours[kind]).override_failure_message("%s: its %s" % [file, kind]).is_equal(int(about["colours"][kind]))
		assert_float(PortraitSplit.react_score(made["part"], calm["part"], about["mood"])).is_equal_approx(about["score"], 0.000001)
	assert_dict(_picks(false)).is_equal({"sad": int(want["picks"]["sad"]), "sweet": int(want["picks"]["sweet"]),
		"shock": int(want["picks"]["shock"])})


func test_the_whole_reaction_split_is_near_the_pythons_and_picks_the_same() -> void:
	var want := _expected()
	var calm: Dictionary = _split(want["calm"], true)
	var face: Image = calm["face"]
	assert_vector(Vector2(face.get_size())).is_equal(Vector2(PortraitSplit.W * PortraitSplit.CLOSE_SCALE, PortraitSplit.H * PortraitSplit.CLOSE_SCALE))
	assert_int(_differing(calm["layer"], _picture(FIXTURES + want["calm"].replace(".png", "_layer.png")))).is_less_equal(NEAR)
	for file in want["pictures"]:
		var about: Dictionary = want["pictures"][file]
		var made := _split(file, true)
		var off := _differing(made["layer"], _picture(FIXTURES + file.replace(".png", "_layer.png")))
		assert_int(off).override_failure_message("%s: %d game pixels differing from the Python's" % [file, off]).is_less_equal(NEAR)
		var score := PortraitSplit.react_score(made["part"], calm["part"], about["mood"])
		assert_float(score).override_failure_message("%s: scored %f, the Python's %f" % [file, score, about["score"]]) \
			.is_between(float(about["score"]) - NEAR_SCORE, float(about["score"]) + NEAR_SCORE)
		assert_int(made["ms"]).is_greater_equal(0)
	assert_dict(_picks(true)).is_equal({"sad": int(want["picks"]["sad"]), "sweet": int(want["picks"]["sweet"]),
		"shock": int(want["picks"]["shock"])})


func test_the_close_up_is_the_middle_of_the_face_at_four_to_five() -> void:
	var calm := PortraitSplit.close_up(Image.create(768, 960, false, Image.FORMAT_RGBA8))
	assert_vector(Vector2(calm.get_size())).is_equal(Vector2(430, 538))  # (as PIL's crop: round half to even)
	var redrawn := PortraitSplit.close_up(Image.create(912, 1136, false, Image.FORMAT_RGBA8))  # (Klein's edits come back this size)
	assert_vector(Vector2(redrawn.get_size())).is_equal(Vector2(511, 639))
	assert_float(float(redrawn.get_height()) / redrawn.get_width()).is_equal_approx(5.0 / 4.0, 0.01)


## A made-up close-up, as portraits.py's react_self_test: black hair, a skin face, white eyes with
## dark pupils, a blue tear, a pink cheek, on green.
func _drawn() -> Image:
	if _drawn_face == null:
		_drawn_face = _draw()
	return _drawn_face


func _draw() -> Image:
	var w := PortraitSplit.W * PortraitSplit.CLOSE_SCALE
	var h := PortraitSplit.H * PortraitSplit.CLOSE_SCALE
	var cx := w / 2.0
	var data := PackedByteArray()
	data.resize(w * h * 4)
	for y in h:
		for x in w:
			var colour := Color8(120, 180, 110)
			if pow((x - cx) / 200.0, 2) + pow((y - 230) / 260.0, 2) < 1:
				colour = Color8(20, 20, 24)
			if pow((x - cx) / 170.0, 2) + pow((y - 300) / 220.0, 2) < 1:
				colour = Color8(250, 228, 212)
			for ex in [cx - 70, cx + 70]:
				if pow((x - ex) / 34.0, 2) + pow((y - 260) / 20.0, 2) < 1:
					colour = Color8(252, 252, 252)
				if pow((x - ex) / 9.0, 2) + pow((y - 260) / 12.0, 2) < 1:
					colour = Color8(15, 15, 18)
			if absf(x - (cx - 70)) < 9 and y > 300 and y < 380:
				colour = Color8(150, 205, 245)
			if pow((x - (cx + 90)) / 40.0, 2) + pow((y - 330) / 22.0, 2) < 1:
				colour = Color8(245, 140, 160)
			var i := (y * w + x) * 4
			data[i] = colour.r8
			data[i + 1] = colour.g8
			data[i + 2] = colour.b8
			data[i + 3] = 255
	var image := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)
	# (the background cut as portraits.py's self-test does: by the whole picture's own cut)
	var found := PortraitSplit.parts_of(image)
	var part: PackedInt32Array = found["part"]
	for i in w * h:
		if part[i] == PortraitSplit.EMPTY:
			data[i * 4 + 3] = 0
	return Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, data)


func test_a_drawn_close_up_keeps_its_eye_whites_tear_and_blush_as_fixed_colours() -> void:
	var made := PortraitSplit.react_grid(_drawn())
	var part: PackedInt32Array = made["part"]
	var found := PortraitSplit.colours(part)
	assert_int(found["white"]).override_failure_message("no eye whites").is_greater(0)
	assert_int(found["tear"]).override_failure_message("no tear").is_greater(0)
	assert_int(found["blush"]).override_failure_message("no blush").is_greater(0)
	assert_bool(part.has(PortraitSplit.HAIR) and part.has(PortraitSplit.SKIN)).override_failure_message(
		"no hair or no skin").is_true()  # (not assert_array().contains(): on a grid it took 11 seconds)
	var layer: Image = made["layer"]
	var at := part.find(PortraitSplit.BLUSH)
	@warning_ignore("integer_division")  # (whole numbers meant)
	var blush := layer.get_pixel(at % PortraitSplit.W, at / PortraitSplit.W)
	assert_int(blush.g8).is_equal(PortraitSplit.FIXED_SLOT * 36)  # (people.py's encoding: a fixed colour, the blush's)
	assert_int(blush.b8).is_equal(int(PortraitSplit.FIXED_OF[PortraitSplit.BLUSH]) * 8)
	at = part.find(PortraitSplit.TEAR)
	@warning_ignore("integer_division")  # (whole numbers meant)
	assert_int(layer.get_pixel(at % PortraitSplit.W, at / PortraitSplit.W).b8).is_equal(int(PortraitSplit.FIXED_OF[PortraitSplit.TEAR]) * 8)


func test_a_candidate_without_its_moods_colour_or_unlike_the_calm_face_scores_worse() -> void:
	var calm: PackedInt32Array = PortraitSplit.react_grid(_drawn())["part"]
	assert_float(PortraitSplit.react_score(calm, calm, "warm")).is_equal_approx(0.0, 0.000001)  # (itself: the same hair and outline)
	assert_float(PortraitSplit.react_score(calm, calm, "sad")).is_equal_approx(0.0, 0.000001)  # (its tear is there)
	var dry := calm.duplicate()
	for i in dry.size():
		if dry[i] == PortraitSplit.TEAR:
			dry[i] = PortraitSplit.SKIN
	assert_float(PortraitSplit.react_score(dry, calm, "sad")).is_equal_approx(PortraitSplit.NO_MOOD, 0.000001)
	var bald := calm.duplicate()
	for i in bald.size():
		if bald[i] == PortraitSplit.HAIR:
			bald[i] = PortraitSplit.SKIN
	assert_float(PortraitSplit.react_score(bald, calm, "warm")).is_equal_approx(1.0, 0.000001)  # (none of the calm face's hair)
	var inked := calm.duplicate()
	for i in inked.size():
		if inked[i] >= 0 and i % 2 == 0:
			inked[i] = PortraitSplit.LINE
	assert_float(PortraitSplit.react_score(inked, calm, "awkward")).is_greater(1.0)  # (mostly lines: a bad split)
