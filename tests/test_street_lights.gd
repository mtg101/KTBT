extends GdUnitTestSuite
## Tests for scripts/bar/street_lights.gd: the street's finish, drawn in code on its grid: the
## sodium lamps and cables, the stars and the moon, the wet road's reflections, and the
## street's own light.

const StreetLights = preload("res://scripts/bar/street_lights.gd")
const StreetArt = preload("res://scripts/bar/street_art.gd")
const PixelLight = preload("res://scripts/ui/pixel_light.gd")


func _street() -> Array:
	var holder: Control = auto_free(Control.new())
	add_child(holder)
	var street := StreetArt.new()
	holder.add_child(street)
	street.show_street("bar-1")
	var road := Control.new()
	road.size = Vector2(1872, 8)
	holder.add_child(road)
	var lights: StreetLights = auto_free(StreetLights.new())
	holder.add_child(lights)
	lights.build(street, road, "bar-1")
	return [street, road, lights]


func after_test() -> void:
	PixelLight.set_lamps([])


func test_the_moon_in_its_phase() -> void:
	assert_float(StreetLights.phase(StreetLights.NEW_MOON_DAY)).is_equal_approx(0.0, 0.001)  # new
	assert_float(StreetLights.phase(StreetLights.NEW_MOON_DAY + 15)).is_equal_approx(0.508, 0.01)  # full, a fortnight on
	assert_str(StreetLights.phase_name(0.5)).is_equal("full")
	assert_str(StreetLights.phase_name(0.27)).is_equal("first quarter")
	assert_str(StreetLights.phase_name(0.98)).is_equal("new")


func test_the_stars_come_out_through_the_night_and_not_through_cloud() -> void:
	assert_float(StreetLights.stars_out(18 * 60, "")).is_less(StreetLights.stars_out(22 * 60, ""))
	for cloud in StreetLights.CLOUDY:
		assert_float(StreetLights.stars_out(23 * 60, cloud)).is_equal(0.0)
	assert_float(StreetLights.stars_out(23 * 60, "cold")).is_greater(StreetLights.stars_out(23 * 60, "muggy"))  # (a clear cold night, a hazy muggy one)


func test_the_lamps_cables_stars_and_moon_on_the_streets_grid() -> void:
	var made := _street()
	var street: StreetArt = made[0]
	var lights: StreetLights = made[2]
	assert_int(lights.lamps.size()).is_equal(StreetLights.LAMP_XS.size())
	var overpass: Control = street.pieces.filter(func(p): return str(p.name).contains("overpass"))[0]
	for lamp in lights.lamps:
		assert_int(lamp.get_index()).is_greater(overpass.get_index())  # (hung from it, in front of it)
		assert_float(lamp.position.y).is_equal(float(StreetLights.DECK))
	assert_int(street.sky.get_node("Stars").get_index()).is_equal(0)  # behind every building
	assert_int(street.sky.get_node("Cables").get_index()).is_equal(street.sky.get_child_count() - 1)  # in front of them
	assert_int(PixelLight.lamps.size()).is_equal(StreetLights.LAMP_XS.size() + 1)  # (lighting the street round them, and the neon)
	PixelLight.set_night(24 * 60, "", [], [])  # (midnight, the tent's bulbs aside)
	assert_float(PixelLight.light_at(Vector2(StreetLights.LAMP_XS[0] * 3.0, 42.0), "street")).is_greater(PixelLight.light_at(Vector2(StreetLights.LAMP_XS[0] * 3.0 + 600.0, -60.0), "street"))
	# A clear night: stars and the moon (crossing from right to left).
	lights.tonight(StreetLights.NEW_MOON_DAY + 10, "")
	lights.set_minutes(22 * 60)
	assert_int(lights.stars_shown).is_greater(0)
	assert_bool(lights.moon_shown).is_true()
	var early: float = lights._moon.position.x
	lights.set_minutes(26 * 60)
	assert_float(lights._moon.position.x).is_less(early)
	# Rain: no stars or moon, and the road reflects what's bright.
	lights.tonight(StreetLights.NEW_MOON_DAY + 10, "rain")
	assert_int(lights.stars_shown).is_equal(0)
	assert_bool(lights.moon_shown).is_false()
	assert_bool(lights.reflecting).is_true()
	await get_tree().process_frame
	assert_bool(lights._reflections.visible).is_true()
	assert_object(lights._reflections.texture).is_not_null()
	# A new moon: none to see.
	lights.tonight(StreetLights.NEW_MOON_DAY, "")
	assert_bool(lights.moon_shown).is_false()
	assert_bool(lights.reflecting).is_false()
	await get_tree().process_frame
	assert_bool(lights._reflections.visible).is_false()
