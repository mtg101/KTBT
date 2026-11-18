extends GdUnitTestSuite
## Tests for scripts/ui/art.gd: the art arriving a piece at a time (the manifest, an image drawn
## in pixels, anything without one drawn in code), and the art folder itself kept honest.

const Art = preload("res://scripts/ui/art.gd")
const TentView = preload("res://scripts/bar/tent_view.gd")
const BarLook = preload("res://scripts/rules/bar_look.gd")

const FIXTURES := "res://tests/support/art/"  # a lucky cat, and an entry whose file's missing


func after_test() -> void:
	Art.folder = "res://art/"
	Art.reset()


func test_an_image_is_drawn_in_pixels_where_the_game_puts_it() -> void:
	Art.folder = FIXTURES
	Art.reset()
	var parent: Control = auto_free(Control.new())
	var cat := Art.place(parent, "touch/lucky_cat", Vector2(100, 250))
	assert_object(cat).is_not_null()
	assert_str(cat.name).is_equal("Art_touch_lucky_cat")
	assert_int(cat.texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_NEAREST)  # (pixels, never smoothed)
	assert_vector(cat.size).is_equal(cat.texture.get_size() * Art.SCALE)
	assert_vector(cat.position + Vector2(cat.size.x / 2, cat.size.y)).is_equal(Vector2(100, 250))  # (standing on the spot)
	var hanging := Art.place(parent, "touch/lucky_cat", Vector2(100, 120), "top")
	assert_vector(hanging.position + Vector2(hanging.size.x / 2, 0)).is_equal(Vector2(100, 120))
	assert_array(Art.summary()["images"]).is_equal(["touch/lucky_cat"])


func test_without_an_image_its_drawn_in_code_and_a_broken_one_says_so() -> void:
	Art.folder = FIXTURES
	Art.reset()
	var parent: Control = auto_free(Control.new())
	assert_object(Art.place(parent, "touch/plants", Vector2.ZERO)).is_null()  # (none in the manifest)
	Art.drawn("touch/plants")
	assert_object(Art.place(parent, "touch/radio", Vector2.ZERO)).is_null()  # (its file's missing: an error, then code)
	Art.drawn("touch/radio")
	assert_int(parent.get_child_count()).is_equal(0)
	assert_dict(Art.summary()).is_equal({"images": [], "drawn": ["touch/plants"], "broken": ["touch/radio"]})
	# No manifest at all: no art, nothing breaks.
	Art.folder = "res://tests/support/no_art_here/"
	Art.reset()
	assert_bool(Art.has("touch/lucky_cat")).is_false()


func test_the_tent_uses_a_touchs_image_and_draws_the_rest() -> void:
	Art.folder = FIXTURES
	Art.reset()
	var tent := TentView.new(Vector2(1872, 380))
	for layer in ["decor_back", "decor_counter", "decor_roof"]:
		tent.set(layer, auto_free(Control.new()))
	tent.add_touch("lucky_cat")
	assert_int(tent.decor_counter.get_child_count()).is_equal(1)
	assert_object(tent.decor_counter.get_child(0) as TextureRect).is_not_null()
	tent.add_touch("radio")  # (its image is broken: drawn in code)
	assert_int(tent.decor_counter.get_child_count()).is_greater(1)
	tent.add_touch("lanterns")  # (no image: drawn in code)
	assert_int(tent.decor_roof.get_child_count()).is_greater(0)
	assert_dict(Art.summary()).is_equal({"images": ["touch/lucky_cat"], "drawn": ["touch/lanterns"], "broken": ["touch/radio"]})
	for id in BarLook.BAR_TOUCHES:  # every touch has somewhere to put an image
		assert_array(tent.touch_spots(id)).override_failure_message(id).is_not_empty()


func test_a_manifest_only_has_what_the_game_draws_with_its_sources_and_licences() -> void:
	Art.folder = FIXTURES
	var problems := Art.check_manifest({
		"touch/lucky_cat": {"file": "touches/lucky_cat.png", "source": "drawn for the tests", "licence": "CC BY-SA 4.0"},
		"touch/disco_ball": {"file": "touches/lucky_cat.png", "source": "x", "licence": "x"},
		"hat/fedora": {"file": "x.png", "source": "x", "licence": "x"},
		"touch/radio": {"file": "touches/radio.png", "source": "", "licence": "CC0"},
	}, "art/touches/lucky_cat.png: drawn for the tests")
	assert_array(problems).contains_exactly_in_any_order([
		"touch/disco_ball: no touch called \"disco_ball\"",
		"hat/fedora: no such kind of art (\"kind/id\", the kinds in art.gd's ids())",
		"touch/radio: its file \"touches/radio.png\" isn't in %s" % FIXTURES,
		"touch/radio: no source",
		"touch/radio: touches/radio.png isn't listed in LICENSE-ASSETS.md",
	])


func test_the_games_art_folder_passes() -> void:
	Art.reset()
	var licences := FileAccess.get_file_as_string("res://LICENSE-ASSETS.md")
	assert_array(Art.check_manifest(Art.manifest(), licences)).is_empty()

