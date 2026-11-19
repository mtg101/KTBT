extends GdUnitTestSuite
## Tests for scripts/bar/tent_view.gd: the tent's look on its own, without a night.

const TentView = preload("res://scripts/bar/tent_view.gd")
const Draw = preload("res://scripts/bar/draw.gd")
const BarLook = preload("res://scripts/rules/bar_look.gd")
const NightRules = preload("res://scripts/rules/night_rules.gd")
const PixelLight = preload("res://scripts/ui/pixel_light.gd")
const PixelFont = preload("res://scripts/ui/pixel_font.gd")

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
