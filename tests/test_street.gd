extends GdUnitTestSuite
## Tests for scripts/bar/street.gd: the street in front of the tent, on its own, without a
## night at the tent (a Night of its own, and a bare stage).

const Street = preload("res://scripts/bar/street.gd")
const Night = preload("res://scripts/bar/night.gd")
const PeopleView = preload("res://scripts/bar/people_view.gd")
const Layout = preload("res://scripts/bar/layout.gd")


func _street(weather := "") -> Street:
	var stage: Control = auto_free(Control.new())
	add_child(stage)  # (in the tree: everyone walks by on a tween)
	var night := Night.new()
	night.weather_kind = weather
	return Street.new(night, PeopleView.new(RandomNumberGenerator.new(), night), stage)


func test_people_walk_by_and_are_counted() -> void:
	var street := _street()
	street.stroll({}, 2)  # two together
	assert_int(street.strollers).is_equal(2)
	assert_object(street.stage.get_node_or_null("Stroller1")).is_not_null()
	assert_object(street.stage.get_node_or_null("Stroller2")).is_not_null()
	assert_int(int(street.night.stats.street.get("in twos", 0))).is_equal(1)
	assert_int(int(street.night.stats.street.get("walked by", 0))).is_equal(2)
	assert_float(street.stage.get_node("Stroller1").position.y).is_between(Layout.STROLL_Y - 10.0, Layout.STROLL_Y + 10.0)  # on the pavement
	# As time passes, whoever's due walks by (a few at most, however long a frame).
	street.tick(600.0, 21 * 60)
	assert_int(street.strollers).is_between(3, 2 + 3 * 3)


func test_a_passer_by_wants_in_and_walks_on() -> void:
	var street := _street()
	street.walk_past(0.0)
	assert_int(street.passers_by).is_equal(1)
	assert_object(street.stage.get_node_or_null("PasserBy1")).is_not_null()


func test_rain_gear_only_when_its_wet() -> void:
	assert_dict(_street("clear").pick_rain_gear()).is_empty()
	var wet := _street("rain")
	var gear := wet.pick_rain_gear()
	assert_bool(gear.has("umbrella")).is_true()
	var person := wet.people.new_person(wet.stage, Vector2.ZERO, Color.WHITE)
	wet.gear_up(person, {"umbrella": true, "shape": "dome", "size": 1.0, "tilt": 0.0}, true)
	assert_object(person.get_node_or_null("Umbrella")).is_not_null()
	assert_int(int(wet.night.stats.street.get("umbrella: dome", 0))).is_equal(1)
	wet.gear_up(wet.people.new_person(wet.stage, Vector2.ZERO, Color.WHITE), {"umbrella": false}, true, false)  # (going home: not counted again)
	assert_int(int(wet.night.stats.street.get("ran for it", 0))).is_equal(0)
