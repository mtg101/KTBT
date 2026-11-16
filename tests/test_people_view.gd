extends GdUnitTestSuite
## Tests for scripts/bar/people_view.gd: drawing people on their own, without a night.

const PeopleView = preload("res://scripts/bar/people_view.gd")
const Looks = preload("res://scripts/rules/looks.gd")


func _view(weather := "") -> PeopleView:
	var view := PeopleView.new(RandomNumberGenerator.new())
	view.weather_kind = weather
	return view


func _stage() -> Control:
	var stage: Control = auto_free(Control.new())
	add_child(stage)  # (in the tree: the drips, the snow building up and the bobbing are tweens)
	return stage


func test_a_person_is_dressed_in_their_look_both_ways_round() -> void:
	var view := _view()
	var person := view.new_person(_stage(), Vector2.ZERO, Color.WHITE)
	for part in ["Head", "Body", "Tag"]:
		assert_object(person.get_node_or_null(part)).is_not_null()
	view.dress(person, Looks.pick_look("woman", Looks.pick_age_range(0.5), ""))
	var front := person.get_node_or_null("Look/Front") as Control
	var back := person.get_node_or_null("Look/Back") as Control
	assert_object(front).is_not_null()
	assert_object(back).is_not_null()
	view.turn(person, false)  # sat at the counter: from behind
	assert_bool(front.visible).is_false()
	assert_bool(back.visible).is_true()
	view.turn(person, true)
	assert_bool(front.visible).is_true()
	assert_int(person.get_child_count() - 1).is_equal(person.get_node("Tag").get_index())  # (the name stays on top)


func test_a_phone_and_an_umbrella() -> void:
	var view := _view("snow")
	var person := view.new_person(_stage(), Vector2.ZERO, Color.WHITE)
	view.add_phone(person)
	assert_object(person.get_node_or_null("Phone")).is_not_null()
	assert_bool(bool(person.get_meta("on_phone", false))).is_true()
	view.add_umbrella(person, {"umbrella": true, "shape": "bubble", "size": 1.0, "tilt": 0.1})
	var umbrella := person.get_node_or_null("Umbrella") as Node2D
	assert_object(umbrella).is_not_null()
	assert_object(umbrella.get_node_or_null("Canopy")).is_not_null()
	assert_object(umbrella.get_node_or_null("SnowCap")).is_not_null()  # snow settles on it
	view.gear_down(person)  # under the tarp: shaken off and folded
	assert_object(person.get_node_or_null("Umbrella")).is_null()
	var rainy := _view("rain")
	var wet := rainy.new_person(_stage(), Vector2.ZERO, Color.WHITE)
	rainy.add_umbrella(wet)
	assert_object(wet.get_node("Umbrella").get_node_or_null("Drip")).is_not_null()  # and rain runs off it


func test_running_for_it_and_stopping() -> void:
	var view := _view("rain")
	var person := view.new_person(_stage(), Vector2(0, 200), Color.WHITE)
	view.run_for_it(person, true)
	assert_bool(view.is_running(person)).is_true()
	assert_object(person.get_node_or_null("OverHead")).is_not_null()  # a bag held over their head
	view.gear_down(person)
	assert_bool(view.is_running(person)).is_false()
	assert_object(person.get_node_or_null("OverHead")).is_null()
	assert_float(person.position.y).is_equal(200.0)  # back on the ground
