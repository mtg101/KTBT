extends GdUnitTestSuite
## Tests for scripts/ui/art.gd: the art arriving a piece at a time (the manifest, an image drawn
## in pixels, anything without one drawn in code), and the art folder itself kept honest.

const Art = preload("res://scripts/ui/art.gd")
const TentView = preload("res://scripts/bar/tent_view.gd")
const StreetArt = preload("res://scripts/bar/street_art.gd")
const PixelLight = preload("res://scripts/ui/pixel_light.gd")
const BarLook = preload("res://scripts/rules/bar_look.gd")
const Looks = preload("res://scripts/rules/looks.gd")

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
	assert_vector(cat.position + Vector2(cat.size.x / 2, cat.size.y)).is_equal_approx(Vector2(100, 250), Vector2(2, 2))  # (standing on the spot...)
	assert_vector(cat.position.posmodv(Vector2(Art.SCALE, Art.SCALE))).is_equal(Vector2.ZERO)  # (...on the grid's lines)
	var hanging := Art.place(parent, "touch/lucky_cat", Vector2(100, 120), "top")
	assert_vector(hanging.position + Vector2(hanging.size.x / 2, 0)).is_equal_approx(Vector2(100, 120), Vector2(2, 2))
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


func test_the_street_draws_its_pieces_on_its_own_pixel_grid_or_is_just_the_sky() -> void:
	Art.folder = FIXTURES
	Art.reset()
	var street: StreetArt = auto_free(StreetArt.new())
	assert_vector(street.size).is_equal(Vector2(StreetArt.PIXELS * StreetArt.SCALE))
	assert_int(street.stretch_shrink).is_equal(StreetArt.SCALE)  # (each street pixel SCALE screen pixels)
	assert_bool(street.has_art()).is_true()
	street.show_street("bar-1")
	assert_array(street.chosen).is_equal(["", "", "", "", "street/shops", ""])  # (only the shops have art here)
	var shops: TextureRect = street.pieces[0]
	assert_vector(shops.size).is_equal(shops.texture.get_size())  # (one image pixel to a grid pixel)
	assert_vector(shops.position + Vector2(shops.size.x / 2, shops.size.y)).is_equal(Vector2(300, StreetArt.GROUND))
	assert_that(shops.material).is_same(PixelLight.material("street"))  # (lit by the hour: the street's kind)
	street.set_sky(Color.RED)
	assert_that(street.sky.color).is_equal(Color.RED)
	assert_array(Art.summary()["drawn"]).contains(["street/overpass", "street/apartments"])  # (the rest, still the stage's own city)
	street.show_street("bar-2")  # (another bar: the street's redrawn, not added to)
	assert_int(street.pieces.size()).is_equal(1)
	Art.folder = "res://tests/support/no_art_here/"
	Art.reset()
	var bare: StreetArt = auto_free(StreetArt.new())
	assert_bool(bare.has_art()).is_false()


func test_each_bar_has_its_own_street_the_same_every_night() -> void:
	Art.reset()  # (the game's own art folder: a few of each piece)
	var street: StreetArt = auto_free(StreetArt.new())
	street.show_street("bar-1")
	var first: Array = street.chosen.duplicate()
	assert_array(first).not_contains([""])
	assert_str(first[0]).is_not_equal(first[1])  # (two blocks, never the same one twice)
	street.show_street("bar-1")
	assert_array(street.chosen).is_equal(first)  # (the same bar, the same street)
	var streets := {}
	for k in 12:
		street.show_street("bar-%d" % k)
		streets[str(street.chosen)] = true
	assert_int(streets.size()).is_greater(6)  # (bars differ)


func test_a_manifest_only_has_what_the_game_draws_with_its_sources_and_licences() -> void:
	Art.folder = FIXTURES
	var problems := Art.check_manifest({
		"touch/lucky_cat": {"file": "touches/lucky_cat.png", "source": "drawn for the tests", "licence": "CC BY-SA 4.0"},
		"touch/disco_ball": {"file": "touches/lucky_cat.png", "source": "x", "licence": "x"},
		"street/moon": {"file": "touches/lucky_cat.png", "source": "x", "licence": "x"},
		"hat/fedora": {"file": "x.png", "source": "x", "licence": "x"},
		"touch/radio": {"file": "touches/radio.png", "source": "", "licence": "CC0"},
	}, "art/touches/lucky_cat.png: drawn for the tests")
	assert_array(problems).contains_exactly_in_any_order([
		"touch/disco_ball: no touch called \"disco_ball\"",
		"street/moon: no street called \"moon\"",
		"hat/fedora: no such kind of art (\"kind/id\", the kinds in art.gd's ids())",
		"touch/radio: its file \"touches/radio.png\" isn't in %s" % FIXTURES,
		"touch/radio: no source",
		"touch/radio: touches/radio.png isn't listed in LICENSE-ASSETS.md",
	])


func test_portraits_are_by_gender_age_hairstyle_and_glasses() -> void:
	var ids := Art.ids("portrait")
	assert_array(ids).contains(["w_20s_long", "w_60s_perm_glasses", "m_70s_balding", "m_30s_two_block_glasses"])
	assert_array(ids).not_contains(["x_20s_long", "w_90s_long", "w_20s_mohawk"])
	assert_int(ids.size()).is_equal(2 * Looks.AGE_RANGES.size() * Looks.HAIR_STYLES.size() * 2)


func test_the_games_art_folder_passes() -> void:
	Art.reset()
	var licences := FileAccess.get_file_as_string("res://LICENSE-ASSETS.md")
	assert_array(Art.check_manifest(Art.manifest(), licences)).is_empty()

