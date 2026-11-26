extends GdUnitTestSuite
## Tests for scripts/rules/portrait_split.gd: the portrait split in Godot giving the same answer as
## tools/art/portraits.py's, on the library's own pictures (tests/support/portraits: three
## candidates of one face and a woman's pick, with the Python's layers and scores from
## `portraits.py --expect`), and on drawn ones.

const PortraitSplit = preload("res://scripts/rules/portrait_split.gd")

const FIXTURES := "res://tests/support/portraits/"
const RAW := "res://art/raw/"  # (the image model's pictures: on the PC that made the library, not in git)
const SWEEP := ["w_20s_bob", "w_50s_perm_glasses", "w_70s_bun", "m_30s_two_block_glasses", "m_60s_short", "m_70s_balding"]


static var _splits := {}  # (each fixture split once for the suite: about 2.5 seconds each)


## A fixture's split, as the game's.
func _split(file: String, id: String) -> Dictionary:
	if not _splits.has(file + "|" + id):
		_splits[file + "|" + id] = PortraitSplit.split(_picture(FIXTURES + file), id)
	return _splits[file + "|" + id]


func _picture(path: String) -> Image:
	return Image.load_from_file(ProjectSettings.globalize_path(path))


func _expected() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "expected.json"))


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


func test_the_split_matches_the_pythons_on_library_pictures() -> void:
	var expected: Dictionary = _expected()["pictures"]
	assert_int(expected.size()).is_equal(4)
	for file in expected:
		var want: Dictionary = expected[file]
		var made := _split(file, want["id"])
		var layer: Image = made["layer"]
		assert_vector(Vector2(layer.get_size())).is_equal(Vector2(PortraitSplit.W, PortraitSplit.H))
		assert_bool(made["resized"]).is_false()
		assert_int(_differing(layer, _picture(FIXTURES + file.replace(".png", "_layer.png")))).override_failure_message(
			"%s: game pixels differing from the Python's" % file).is_equal(0)
		assert_float(made["score"]).is_equal_approx(want["score"], 0.000001)
		for part in ["hair", "skin", "cloth", "lines"]:
			assert_float(made["shares"][part]).is_equal_approx(want["shares"][part], 0.000001)
	# (the woman's pick is the library's own face, byte for byte)
	var kept := _split("portrait_w_20s_long_8000.png", "w_20s_long")
	assert_int(_differing(kept["layer"], _picture("res://art/portraits/w_20s_long.png"))).is_equal(0)


func test_the_pre_pick_is_the_pythons_and_a_tie_goes_to_the_lower_seed() -> void:
	var want: Dictionary = _expected()
	var candidates: Array = []
	for file in want["pictures"]:
		var about: Dictionary = want["pictures"][file]
		if about["id"] == "m_50s_balding_glasses":
			var made := _split(file, about["id"])
			candidates.append({"score": made["score"], "seed": int(about["seed"])})
	assert_int(candidates.size()).is_equal(3)
	assert_int(candidates[PortraitSplit.best(candidates)]["seed"]).is_equal(int(want["pre_picks"]["m_50s_balding_glasses"]))
	assert_int(PortraitSplit.best([{"score": 0.2, "seed": 12}, {"score": 0.1, "seed": 11}, {"score": 0.1, "seed": 10}])).is_equal(2)
	assert_int(PortraitSplit.best([])).is_equal(-1)
	# (the score: glasses asked for and not there, or balding with a full head, score worse)
	var part: PackedInt32Array = _split("portrait_w_20s_long_8000.png", "w_20s_long")["part"]
	assert_float(PortraitSplit.score(part, "w_20s_long_glasses")).is_greater(PortraitSplit.score(part, "w_20s_long"))
	assert_float(PortraitSplit.score(part, "m_50s_balding")).is_greater(PortraitSplit.score(part, "w_20s_long"))


## A made-up portrait, as portraits.py's self-test: black hair, a skin face with thin dark eyes, a
## red top with a dark neckline, on green (or on nothing, its own transparency).
func _drawn(width: int, height: int, transparent: bool) -> Image:
	var data := PackedByteArray()
	data.resize(width * height * 4)
	var k := width / 768.0
	for y in height:
		for x in width:
			var px := x / k
			var py := y / k
			var colour := Color8(120, 180, 110, 0 if transparent else 255)
			if pow((px - 384) / 230.0, 2) + pow((py - 330) / 280.0, 2) < 1:
				colour = Color8(20, 20, 24)
			if pow((px - 384) / 170.0, 2) + pow((py - 380) / 210.0, 2) < 1:
				colour = Color8(245, 222, 200)
			for ex in [320, 448]:
				if pow((px - ex) / 18.0, 2) + pow((py - 370) / 6.0, 2) < 1:
					colour = Color8(15, 15, 18)
			if py > 620:
				colour = Color8(225, 45, 45)
			if py > 616 and py < 626:
				colour = Color8(15, 15, 18)
			var i := (y * width + x) * 4
			data[i] = colour.r8
			data[i + 1] = colour.g8
			data[i + 2] = colour.b8
			data[i + 3] = colour.a8
	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)


func _check_drawn(made: Dictionary) -> void:
	var part: PackedInt32Array = made["part"]
	var w := PortraitSplit.W
	assert_int(part[70 * w + 32]).override_failure_message("the top isn't cloth").is_equal(PortraitSplit.CLOTH)
	assert_int(part[32 * w + 32]).override_failure_message("the middle of the face isn't skin").is_equal(PortraitSplit.SKIN)
	assert_int(part[10 * w + 32]).override_failure_message("the top of the head isn't hair").is_equal(PortraitSplit.HAIR)
	assert_int(part[2 * w + 2]).override_failure_message("the background's still there").is_equal(PortraitSplit.EMPTY)
	var eyes: Array = []
	for y in range(30, 33):
		for x in range(25, 29):
			eyes.append(part[y * w + x])
	assert_array(eyes).contains([PortraitSplit.LINE]).not_contains([PortraitSplit.HAIR])  # (thin and dark: lines, not hair)
	var layer: Image = made["layer"]
	var skin := layer.get_pixel(32, 32)
	@warning_ignore("integer_division")  # (whole numbers meant)
	assert_int(skin.g8 / 36).is_equal(PortraitSplit.SKIN)  # (people.py's encoding: the slot in green...)
	assert_int(skin.a8).is_equal(255)
	@warning_ignore("integer_division")  # (whole numbers meant)
	var line := layer.get_pixel(eyes.find(PortraitSplit.LINE) % 4 + 25, eyes.find(PortraitSplit.LINE) / 4 + 30)
	assert_int(line.g8).is_equal(PortraitSplit.FIXED_SLOT * 36)  # (...lines the fixed ink, in blue)
	assert_int(line.b8).is_equal(int(PortraitSplit.FIXED_OF[PortraitSplit.LINE]) * 8)
	assert_int(layer.get_pixel(2, 2).a8).is_equal(0)


func test_a_drawn_portrait_splits_into_hair_skin_cloth_and_lines() -> void:
	var made := PortraitSplit.split(_drawn(768, 960, false), "w_20s_long")
	assert_bool(made["resized"]).is_false()
	_check_drawn(made)


## The split's big passes are shared out over the CPU's cores (_in_pieces): however many pieces,
## the same split, pixel for pixel (5: pieces that don't divide the picture evenly), and the
## reaction split's too. ("pieces" in the split says how many it was in, for the notes.)
func test_a_split_is_the_same_in_one_piece_or_many() -> void:
	var picture := _drawn(768, 960, false)
	var close_up := _picture("res://tests/support/reactions/portrait_m_40s_side_part_8902.png")
	var made := {}
	for pieces in [1, 5]:
		PortraitSplit.pieces_override = pieces
		made[pieces] = [PortraitSplit.split(picture, "w_20s_long"), PortraitSplit.react_split(close_up)]
	PortraitSplit.pieces_override = 0
	assert_int(int(made[5][0]["pieces"])).is_equal(5)
	for k in 2:
		var one: Dictionary = made[1][k]
		var many: Dictionary = made[5][k]
		assert_bool(one["part"] == many["part"] and one["step"] == many["step"]).override_failure_message(
			"%s: the grid isn't the same in 5 pieces" % ["split", "react_split"][k]).is_true()
		assert_bool((one["layer"] as Image).get_data() == (many["layer"] as Image).get_data()).override_failure_message(
			"%s: the layer isn't the same in 5 pieces" % ["split", "react_split"][k]).is_true()
	assert_float(float(made[5][0]["score"])).is_equal(float(made[1][0]["score"]))
	assert_dict(made[5][0]["shares"]).is_equal(made[1][0]["shares"])


func test_a_picture_with_its_own_transparency_and_another_size_still_splits() -> void:
	var made := PortraitSplit.split(_drawn(384, 480, true), "w_20s_long")
	assert_bool(made["resized"]).is_true()  # (Godot's Lanczos isn't PIL's: near the Python's, not the same)
	_check_drawn(made)


## On the PC that made the library (its raw pictures in art/raw, not in git): a spread of the
## library's picks, each split the same as the face that's in the game.
func test_the_library_picks_split_into_the_faces_in_the_game() -> void:
	if not FileAccess.file_exists(RAW + "portrait_picks.json"):
		return  # (GitHub and the VM: no raw pictures; the fixtures above stand in)
	var picks: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RAW + "portrait_picks.json"))
	for id in SWEEP:
		var chosen = picks.get("portrait_" + id)  # (a seed, or null for none)
		if chosen == null or not FileAccess.file_exists("%sportrait_%s_%d.png" % [RAW, id, int(chosen)]):
			continue
		var made := PortraitSplit.split(_picture("%sportrait_%s_%d.png" % [RAW, id, int(chosen)]), id)
		assert_int(_differing(made["layer"], _picture("res://art/portraits/%s.png" % id))).override_failure_message(
			"%s: game pixels differing from the library's face" % id).is_equal(0)
