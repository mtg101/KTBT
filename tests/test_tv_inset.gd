extends GdUnitTestSuite
## Tests for scripts/ui/tv_inset.gd: the TV box (a caption's picture-in-picture), on its own.

const TvInset = preload("res://scripts/ui/tv_inset.gd")


func _face(face_name: String) -> Dictionary:
	var picture := Image.create(64, 80, false, Image.FORMAT_RGBA8)
	picture.fill(Color.WHITE)
	return {"texture": ImageTexture.create_from_image(picture), "name": face_name, "how": "mood"}


func test_an_inset_goes_in_the_corner_away_from_them_in_whole_pixels() -> void:
	var box: TvInset = auto_free(TvInset.new())
	box.setup([_face("Kim Ji-ho")], Color("ff4f6d"), false)
	add_child(box)
	box.place_inset(1872.0, 300.0)  # (they're on the left: it goes right)
	assert_int(box.faces_shown).is_equal(1)
	assert_float(box.position.x + box.size.x).is_equal_approx(1872.0 - TvInset.MARGIN, 0.5)
	var picture := box.find_child("Picture", true, false) as TextureRect
	assert_vector(picture.custom_minimum_size).is_equal(Vector2(64, 80) * TvInset.INSET_SCALE)
	assert_int(picture.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)  # (never smoothed)
	assert_str((box.find_child("Name", true, false) as Label).text).is_equal("Kim Ji-ho")
	box.place_inset(1872.0, 1500.0)  # (on the right: it goes left)
	assert_float(box.position.x).is_equal(TvInset.MARGIN)
	assert_int(box.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)  # (never takes a click)


func test_two_faces_side_by_side() -> void:
	var box: TvInset = auto_free(TvInset.new())
	box.setup([_face("Kim Ji-ho"), _face("Park Min-seo")], Color("ff8fc0"), false)
	add_child(box)
	box.place_inset(1872.0, 300.0)
	assert_int(box.faces_shown).is_equal(2)
	assert_float(box.size.x).is_greater(2 * 64 * TvInset.INSET_SCALE)


func test_a_zoom_dims_the_window_with_the_face_big_and_room_for_the_caption() -> void:
	var box: TvInset = auto_free(TvInset.new())
	box.setup([_face("Kim Ji-ho")], Color("ff4f6d"), true)
	add_child(box)
	box.place_zoom(Vector2(1920, 1080))
	assert_bool(box.zoomed).is_true()
	assert_object(box.get_node_or_null("Dim")).is_not_null()
	assert_vector(box.size).is_equal(Vector2(1920, 1080))
	assert_vector((box.find_child("Picture", true, false) as TextureRect).custom_minimum_size).is_equal(Vector2(64, 80) * TvInset.ZOOM_SCALE)
	assert_float(box.box.position.x + box.box.size.x / 2).is_equal_approx(960.0, 0.5)  # (in the middle)
	var spot := box.zoom_caption_spot()
	assert_float(spot.y).is_greater(box.box.position.y + box.box.size.y)  # (under the face)
	assert_float(spot.y).is_less(1080.0)


func test_it_goes_by_itself() -> void:
	var box := TvInset.new()
	box.time_scale = 0.01
	box.setup([_face("Kim Ji-ho")], Color("ff4f6d"), false)
	add_child(box)
	box.place_inset(1872.0, 300.0)
	box.pop(1.0)
	await await_millis(200)
	assert_bool(is_instance_valid(box)).is_false()
