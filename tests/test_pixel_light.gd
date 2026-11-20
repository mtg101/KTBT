extends GdUnitTestSuite
## Tests for scripts/ui/pixel_light.gd: the light by the hour on the pixels, the night's own and
## the bulbs', each pixel moved along its colour's ramp, smoothly (no dither).

const PixelLight = preload("res://scripts/ui/pixel_light.gd")

const BULBS := [Vector2(621, 155), Vector2(1251, 155)]


func after_test() -> void:
	PixelLight.set_night(23 * 60, "", BULBS, [PixelLight.BULB_STEPS, PixelLight.BULB_STEPS])


func test_the_night_darkens_by_the_hour() -> void:
	var dusk := PixelLight.ambient(18 * 60)
	var nine := PixelLight.ambient(21 * 60)
	var late := PixelLight.ambient(26 * 60)
	var dawn := PixelLight.ambient(27 * 60)
	assert_float(dusk).is_less(0.0)  # (darker than drawn, even at six)
	assert_float(nine).is_less(dusk)
	assert_float(late).is_less(nine)  # darkest after midnight...
	assert_float(dawn).is_greater(late)  # ...a little less towards dawn
	assert_float(PixelLight.ambient(17 * 60)).is_equal(dusk)  # (before opening, as at six)
	assert_float(PixelLight.ambient(30 * 60)).is_equal(dawn)
	assert_float(PixelLight.ambient(21 * 60, "fog")).is_greater(nine)  # fog throws the light about
	assert_float(PixelLight.ambient(21 * 60, "rain")).is_less(nine)


func test_the_bulbs_light_the_tent_and_hardly_the_street() -> void:
	PixelLight.set_lamps([])  # (the street's own lamps aside: test_street_lights.gd)
	PixelLight.set_night(24 * 60, "", BULBS, [PixelLight.BULB_STEPS, PixelLight.BULB_STEPS])
	var counter := PixelLight.light_at(Vector2(936, 250))
	var far_end := PixelLight.light_at(Vector2(40, 250))
	assert_float(counter).is_greater(-0.5)  # under the bulbs, much as drawn
	assert_float(counter).is_less_equal(PixelLight.BRIGHTEST)
	assert_float(far_end).is_less(counter)  # out at the ends, darker
	assert_float(PixelLight.light_at(Vector2(936, -40), "street")).is_less(PixelLight.light_at(Vector2(936, -40), "tent"))  # (the tarp holds it in)
	assert_float(PixelLight.light_at(Vector2(936, 250), "people")).is_equal(counter)  # people as the tent
	assert_float(PixelLight.light_at(Vector2(936, 60), "tarp")).is_less(PixelLight.light_at(Vector2(936, 60), "tent"))  # the tarp glows dim...
	assert_float(float(PixelLight.material("tarp").get_shader_parameter("self_lit"))).is_equal(0.0)  # ...its orange isn't a light of its own
	assert_float(float(PixelLight.material("tent").get_shader_parameter("self_lit"))).is_equal(1.0)
	PixelLight.set_lamps([Vector4(100, 300, 0.9, 300)])  # a street lamp lights what's round it, whatever it is
	assert_float(PixelLight.light_at(Vector2(100, 300), "street")).is_greater(PixelLight.light_at(Vector2(1000, 300), "street"))
	PixelLight.set_lamps([])
	PixelLight.set_night(24 * 60, "", BULBS, [PixelLight.BULB_STEPS, 0.0])  # closing up: the far bulb off
	assert_float(PixelLight.light_at(Vector2(1251, 250))).is_less(counter)
	PixelLight.bulbs_off()  # the lights go out
	assert_float(PixelLight.light_at(Vector2(936, 250))).is_equal_approx(PixelLight.ambient(24 * 60), 0.001)


func test_a_step_down_the_ramp_is_darker_and_bluer_up_lighter_and_warmer() -> void:
	var red := Color("c8443a")
	var down := PixelLight.shifted(red, -1)
	var up := PixelLight.shifted(red, 1)
	assert_float(down.v).is_less(red.v)
	assert_float(up.v).is_greater(red.v)
	assert_float(down.h).is_greater(red.h)  # (red to blue the short way: up through the hues' end)
	assert_float(up.h).is_greater(red.h)  # (and to warm yellow)
	assert_float(up.h).is_less(PixelLight.WARM_HUE)
	assert_bool(PixelLight.shifted(red, 0).is_equal_approx(red)).is_true()
	assert_float(PixelLight.shifted(red, -2).v).is_less(down.v)
	assert_float(PixelLight.shifted(red, -1).a).is_equal(red.a)


func test_the_light_fades_smoothly_between_steps_with_no_dither() -> void:
	var red := Color("c8443a")
	# Whole steps are the ramp's own; between them, a blend, so the light fades evenly.
	assert_bool(PixelLight.lit(red, -1.0).is_equal_approx(PixelLight.shifted(red, -1))).is_true()
	assert_bool(PixelLight.lit(red, 0.0).is_equal_approx(red)).is_true()
	var halfway := PixelLight.lit(red, -0.5)
	assert_float(halfway.v).is_greater(PixelLight.shifted(red, -1).v).is_less(red.v)
	var last := PixelLight.lit(red, -1.9)
	for k in range(1, 20):  # no jumps: a little more light, a little lighter
		var now := PixelLight.lit(red, -1.9 + k * 0.1)
		assert_float(now.v).is_greater(last.v)
		assert_float(now.v - last.v).is_less(0.05)
		last = now
	# Regression (20 Nov): a dither fixed to the grid slid across people as they walked.
	assert_str(PixelLight.SHADER).not_contains("BAYER").not_contains("stage_at / 3.0")


func test_each_kind_shares_one_material() -> void:
	assert_object(PixelLight.material("tent")).is_same(PixelLight.material("tent"))
	assert_object(PixelLight.material("street")).is_not_same(PixelLight.material("tent"))
	assert_float(float(PixelLight.material("street").get_shader_parameter("lit_by_bulbs"))).is_equal(PixelLight.KINDS["street"])
	PixelLight.place_kind("street", 3.0, Vector2(0, -81))
	assert_that(PixelLight.material("street").get_shader_parameter("to_stage_offset")).is_equal(Vector2(0, -81))
	var holder: Control = auto_free(Control.new())
	var piece := TextureRect.new()
	holder.add_child(piece)
	PixelLight.light(piece, "tent")
	holder.add_child(Control.new())
	assert_int(PixelLight.count_lit(holder)).is_equal(1)
	assert_str(PixelLight.material("tent").shader.code).contains("shader_type canvas_item")


func test_each_bulb_lights_a_pool_close_round_it() -> void:
	# (20 Nov: the glow round a bulb was drawn into the tarp and the counter; now it's the
	# light's, so it lights whoever's under it too, and goes when the bulb does.)
	PixelLight.set_lamps([])
	PixelLight.set_night(24 * 60, "", BULBS, [PixelLight.BULB_STEPS, PixelLight.BULB_STEPS])
	var bulb := Vector4(621, 155, PixelLight.BULB_STEPS, PixelLight.BULB_REACH)
	var under := PixelLight.bulb_light(bulb, Vector2(621, 250))
	var reach_only := PixelLight.BULB_STEPS * (1.0 - 95.0 / PixelLight.BULB_REACH)
	assert_float(under).is_greater(reach_only + 0.4)  # brighter close by than the long reach alone
	assert_float(PixelLight.bulb_light(bulb, Vector2(621 + PixelLight.POOL_REACH + 200, 155))).is_equal_approx(
		PixelLight.BULB_STEPS * (1.0 - (PixelLight.POOL_REACH + 200) / PixelLight.BULB_REACH), 0.001)  # (past the pool, just the reach)
	assert_float(PixelLight.bulb_light(Vector4(621, 155, 0.0, PixelLight.BULB_REACH), Vector2(621, 250))).is_equal(0.0)  # off: no pool
	assert_float(PixelLight.light_at(Vector2(621, 60), "tarp")).is_greater(PixelLight.light_at(Vector2(936, 60), "tarp"))  # the tarp glows round the bulb
	assert_str(PixelLight.SHADER).contains("pool_steps")
