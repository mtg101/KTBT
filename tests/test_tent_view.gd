extends GdUnitTestSuite
## Tests for scripts/bar/tent_view.gd: the tent's look on its own, without a night.

const TentView = preload("res://scripts/bar/tent_view.gd")
const Draw = preload("res://scripts/bar/draw.gd")
const BarLook = preload("res://scripts/rules/bar_look.gd")
const NightRules = preload("res://scripts/rules/night_rules.gd")
const PixelLight = preload("res://scripts/ui/pixel_light.gd")
const PixelFont = preload("res://scripts/ui/pixel_font.gd")
const Art = preload("res://scripts/ui/art.gd")

const STAGE := Vector2(1872, 380)


## A stage with the tent's changing pieces, as the tent's scene builds them.
func _tent() -> TentView:
	var stage: Control = auto_free(Control.new())
	add_child(stage)  # (in the tree: the bulbs' swing and the fog's drift are tweens)
	var view := TentView.new(STAGE)
	view.sky = Draw.rect(stage, Vector2.ZERO, STAGE, Color.BLACK)
	view.glow = Draw.rect(stage, Vector2.ZERO, STAGE, Color.BLACK)
	view.weather_back = Draw.rect(stage, Vector2.ZERO, STAGE, Color(0, 0, 0, 0))
	view.weather_front = Draw.rect(stage, Vector2.ZERO, STAGE, Color(0, 0, 0, 0))
	for layer in ["decor_back", "decor_counter", "decor_roof", "roof_stripes"]:
		view.set(layer, Draw.rect(stage, Vector2.ZERO, STAGE, Color(0, 0, 0, 0)))
	view.roof = Polygon2D.new()
	stage.add_child(view.roof)
	view.roof_edge = Draw.rect(stage, Vector2.ZERO, Vector2(10, 10), Color.BLACK)
	var bulb := Control.new()
	stage.add_child(bulb)
	view.bulbs.append(bulb)
	view.bulb_lights.append(Draw.rect(bulb, Vector2.ZERO, Vector2(16, 16), Color.WHITE))
	view.build_sign(stage)
	return view


func test_the_tent_shows_the_bars_look() -> void:
	var view := _tent()
	var look := BarLook.default_bar_look()
	look["touches"] = ["lanterns", "radio"]
	view.show_look({"name": "Golmok Pocha", "name_meaning": "alley tent", "look": look})
	assert_str(view.sign_english.text).is_equal("GOLMOK POCHA")
	assert_str(view.sign_hangul.text).is_equal(str(look["hangul"]))
	assert_int(view.sign_hangul.get_theme_font_size("font_size")).is_equal(PixelFont.size_for("sign_hangul"))  # in the pixel font
	assert_object(view.sign_english.get_theme_font("font")).is_same(PixelFont.font("galmuri7"))
	assert_bool(view.sign_node.visible).is_true()
	assert_int(view.decor_roof.get_child_count()).is_greater(0)  # the lanterns
	assert_int(view.decor_counter.get_child_count()).is_greater(0)  # the radio
	for shape in BarLook.TENT_SHAPES:
		assert_int(view.tent_shape(str(shape)).size()).is_greater_equal(4)


func test_the_light_follows_the_hour_the_weather_and_closing_up() -> void:
	var view := _tent()
	view.update_light(NightRules.OPEN_MINUTES, "", false)
	var dusk := view.sky.color
	view.update_light(NightRules.OPEN_MINUTES, "fog", false)
	assert_bool(view.sky.color.is_equal_approx(dusk)).is_false()  # fog greys it
	view.update_light(23 * 60, "", false)
	var full := view.glow.color.a
	view.update_light(23 * 60, "", true)
	assert_float(view.glow.color.a).is_less(full)  # closing up: dimmer...
	assert_bool(TentView.bulb_colour(view.bulb_lights[-1]).is_equal_approx(TentView.BULB_OFF)).is_true()  # ...and the far bulb's off
	assert_float(PixelLight.bulbs[-1].z).is_equal(0.0)  # (its light off the pixels too)


func test_the_pixels_light_comes_from_the_hour_and_the_bulbs() -> void:
	var view := _tent()
	view.bulbs[0].position = Vector2(621, 111)
	view.update_light(23 * 60, "", false)
	assert_float(PixelLight.ambient_steps).is_equal_approx(PixelLight.ambient(23 * 60), 0.001)
	assert_array(view.bulb_spots()).is_equal([Vector2(621, 111) + TentView.BULB_GLASS])
	assert_float(PixelLight.bulbs[0].z).is_equal(PixelLight.BULB_STEPS)
	var under := PixelLight.light_at(Vector2(621, 200))
	view.lights_out(true)  # (a plant card: the lights go out)
	assert_float(PixelLight.bulbs[0].z).is_equal(0.0)
	assert_float(PixelLight.light_at(Vector2(621, 200))).is_less(under)
	view.update_light(23 * 60, "", false)  # (and back on)
	assert_float(PixelLight.light_at(Vector2(621, 200))).is_equal_approx(under, 0.001)


func test_the_weather_falls_and_the_bulbs_swing() -> void:
	var view := _tent()
	view.show_weather("rain")
	assert_object(view.weather_back.get_node_or_null("Rain")).is_not_null()
	assert_object(view.weather_front.get_node_or_null("Drips")).is_not_null()
	assert_int(view.sways.size()).is_equal(1)
	view.show_weather("snow")
	assert_object(view.weather_back.get_node_or_null("Rain")).is_null()  # (last night's gone)
	assert_object(view.weather_back.get_node_or_null("Snow")).is_not_null()
	view.show_weather("fog")
	assert_object(view.weather_front.get_node_or_null("Fog0")).is_not_null()
	assert_int(view.sways.size()).is_equal(1)  # (the old swing stopped, a new one started)
	# The bulb swings by whole pixels, never turned (turned pixels shimmer).
	var glass: Control = view.bulb_lights[0]
	var rest: float = glass.position.x
	view.swing_bulb(7.0, view.bulbs[0], glass)
	assert_float(view.bulbs[0].rotation).is_equal(0.0)
	assert_float(glass.position.x - rest).is_equal(TentView.GRID * roundi(sin(deg_to_rad(7.0)) * TentView.WIRE_LENGTH / TentView.GRID))
	assert_float(fposmod(glass.position.x - rest, TentView.GRID)).is_equal(0.0)


func test_the_tents_art_is_in_clean_steps_with_the_light_left_to_the_game() -> void:
	# 20 Nov: the tent's art had a 4x4 dither between its light's steps (the C64 look), clashing
	# with the people's clean steps; and the bulbs' glow drawn into the tarp and the counter. Now
	# clean steps (no lone pixel between two the same, as a dither leaves), and the glow's the
	# light's (pixel_light.gd's pool round each bulb), so the counter's top is the same all along.
	for key in ["tent/counter", "tarp/orange_classic", "tarp/blue_stripes_awning", "tarp/red_stripes_peaked"]:
		var image: Image = Art.texture(key).get_image()
		if image.is_compressed():
			image.decompress()
		var lone := 0
		for y in image.get_height():
			for x in range(1, image.get_width() - 1):
				var here := image.get_pixel(x, y)
				var left := image.get_pixel(x - 1, y)
				var right := image.get_pixel(x + 1, y)
				if here.a > 0.5 and left.a > 0.5 and right.a > 0.5 and left.is_equal_approx(right) and not here.is_equal_approx(left):
					lone += 1
		assert_int(lone).override_failure_message("%s: %d dithered pixels" % [key, lone]).is_less(5)
	var counter: Image = Art.texture("tent/counter").get_image()
	if counter.is_compressed():
		counter.decompress()
	var row := 3  # (the counter's top)
	assert_bool(counter.get_pixel(20, row).is_equal_approx(counter.get_pixel(384, row))).is_true()  # no glow drawn under the far bulb (at 1251 on the stage: the counter starts at 99, a pixel to 3)
