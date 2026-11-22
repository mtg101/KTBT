extends GdUnitTestSuite
## Tests for scripts/ui/face_sticker.gd: a face slapped onto a TV caption, on its own.

const FaceSticker = preload("res://scripts/ui/face_sticker.gd")
const CaptionPopup = preload("res://scripts/ui/caption.gd")


func _face(face_name: String, mood: String) -> Dictionary:
	var picture := Image.create(64, 80, false, Image.FORMAT_RGBA8)
	picture.fill(Color.WHITE)
	return {"texture": ImageTexture.create_from_image(picture), "name": face_name, "mood": mood, "how": "mood"}


func test_a_face_is_slapped_on_at_a_tilt_in_whole_pixels_with_its_name() -> void:
	var sticker: FaceSticker = auto_free(FaceSticker.new())
	sticker.setup([_face("Kim Ji-ho", "shock")], Color("ff4f6d"), 0.2)
	add_child(sticker)
	assert_int(sticker.faces_shown).is_equal(1)
	assert_str(sticker.look).is_equal("burst")  # (a shock: always the starburst)
	var face := sticker.find_child("Face", true, false) as Control
	assert_float(absf(face.rotation)).is_greater(0.05)  # (never straight)
	var picture := sticker.find_child("Picture", true, false) as TextureRect
	assert_vector(picture.size).is_equal_approx(Vector2(64, 80) * FaceSticker.SCALE, Vector2(0.01, 0.01))
	assert_int(picture.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)  # (never smoothed)
	assert_str((sticker.find_child("Name", true, false) as Label).text).is_equal("Kim Ji-ho")
	assert_vector(sticker.custom_minimum_size).is_equal(face.size)
	assert_int(sticker.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)  # (never takes a click)


func test_each_mood_has_its_looks_and_two_faces_overlap_leaning_apart() -> void:
	for mood in FaceSticker.LOOKS:
		for roll in [0.0, 0.99]:
			var sticker: FaceSticker = auto_free(FaceSticker.new())
			sticker.setup([_face("Kim Ji-ho", mood)], Color.WHITE, roll)
			assert_array(FaceSticker.LOOKS[mood]).contains([sticker.look])
	var two: FaceSticker = auto_free(FaceSticker.new())
	two.setup([_face("Kim Ji-ho", "sweet"), _face("Park Min-seo", "sweet")], Color("ff8fc0"), 0.7)
	assert_int(two.faces_shown).is_equal(2)
	var faces := two.get_node("Faces").get_children()
	assert_float((faces[1] as Control).position.x).is_less((faces[0] as Control).size.x)  # (over the first's edge)
	assert_bool(signf((faces[0] as Control).rotation) != signf((faces[1] as Control).rotation)).is_true()


func test_it_goes_with_its_caption_and_thumps_in_after_it() -> void:
	var caption := CaptionPopup.new()
	caption.time_scale = 0.01
	var sticker := FaceSticker.new()
	sticker.setup([_face("Kim Ji-ho", "warm")], Color("ffc46b"), 0.5)
	caption.setup({"hangul": "훈훈", "english": "SO KIND"}, "🥹", Color("ffc46b"), sticker, true)
	add_child(caption)
	assert_object(caption.sticker).is_same(sticker)
	assert_int(sticker.get_index()).is_equal(0)  # (left of the words)
	caption.pop(1.0)
	assert_float(sticker.get_node("Faces").scale.x).is_greater(1.0)  # (big, about to thump down)
	await await_millis(300)
	assert_bool(is_instance_valid(caption) or is_instance_valid(sticker)).is_false()  # (gone with its caption)


func test_the_edit_s_clipart_lands_on_each_face_sized_to_it() -> void:
	var two: FaceSticker = auto_free(FaceSticker.new())
	two.setup([_face("Kim Ji-ho", "sweet"), _face("Park Min-seo", "sweet")], Color("ff8fc0"), 0.7, false, "flowers", 2.6)
	add_child(two)
	two.time_scale = 0.01
	two.slam(0.14)
	var faces := two.get_node("Faces").get_children()
	for face in faces:
		var clip := (face as Control).get_node_or_null("Clipart") as Control
		assert_object(clip).is_not_null()  # (on both of them)
		assert_bool(clip.show_behind_parent).is_true()  # flowers: behind the face, peeking round its edge
		assert_float(clip.size.x).is_greater((face.get_node("Picture") as Control).size.x)
	var zoomed: FaceSticker = auto_free(FaceSticker.new())
	zoomed.setup([_face("Kim Ji-ho", "sad")], Color("6fa8ff"), 0.2, true, "rain_cloud", 3.6)
	add_child(zoomed)
	zoomed.slam(0.14)
	var cloud := zoomed.find_child("Clipart", true, false) as Control
	assert_int(cloud.pixel).is_greater(6)  # (bigger on a zoom, with the face)
	var plain: FaceSticker = auto_free(FaceSticker.new())
	plain.setup([_face("Kim Ji-ho", "calm")], Color.WHITE, 0.2)
	add_child(plain)
	plain.slam(0.14)
	assert_object(plain.find_child("Clipart", true, false)).is_null()  # (no clipart: none)
