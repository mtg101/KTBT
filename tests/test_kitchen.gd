extends GdUnitTestSuite
## Tests for scripts/bar/kitchen.gd: the stove on its own, without a night.

const DishView = preload("res://scripts/ui/dish_view.gd")
const PixelLight = preload("res://scripts/ui/pixel_light.gd")
const Kitchen = preload("res://scripts/bar/kitchen.gd")
const Menu = preload("res://scripts/rules/menu.gd")

const JI_HO := {"customer": {"name": "Kim Ji-ho"}}
const DA_EUN := {"customer": {"name": "Park Da-eun"}}


func _kitchen() -> Kitchen:
	var kitchen := Kitchen.new()
	kitchen.stove_row = auto_free(HBoxContainer.new())
	return kitchen


func test_one_cook_so_dishes_queue() -> void:
	var kitchen := _kitchen()
	kitchen.put_on(JI_HO, ["tteokbokki"], 1200.0)
	kitchen.put_on(DA_EUN, ["dakgalbi"], 1201.0)
	assert_int(kitchen.stove_row.get_child_count()).is_equal(2)  # cooking, and waiting
	assert_array(kitchen.food_coming(DA_EUN)).is_equal(["dakgalbi"])
	assert_bool(kitchen.cook(Menu.cook_minutes("tteokbokki") - 1.0)).is_false()  # not yet
	assert_bool(kitchen.cook(2.0)).is_true()  # done: and the spare minute goes to the next one
	assert_int(kitchen.ready.size()).is_equal(1)
	assert_float(float(kitchen.queue[0]["left"])).is_equal(float(Menu.cook_minutes("dakgalbi")) - 1.0)
	var dish := kitchen.take_ready()
	assert_str(str(dish["id"])).is_equal("tteokbokki")
	assert_float(float(dish["ordered"])).is_equal(1200.0)
	assert_array(kitchen.food_coming(JI_HO)).is_empty()  # (carried over)
	assert_int(kitchen.stove_row.get_child_count()).is_equal(1)
	# A long frame can finish more than one.
	kitchen.put_on(JI_HO, ["pajeon"], 1210.0)
	kitchen.cook(100.0)
	assert_int(kitchen.queue.size()).is_equal(0)
	assert_int(kitchen.ready.size()).is_equal(2)


func test_dishes_and_banchan_are_drawn_with_their_names() -> void:
	var kitchen := _kitchen()
	var dish: Control = auto_free(kitchen.dish_shape("pajeon"))
	assert_str(dish.tooltip_text).is_equal("Pajeon")
	assert_vector(dish.custom_minimum_size).is_not_equal(Vector2.ZERO)
	var banchan: Control = auto_free(kitchen.banchan_shape())
	assert_str(banchan.tooltip_text).contains("Banchan").contains(Kitchen.BANCHAN)
	assert_int(banchan.shapes.filter(func(sh): return sh["kind"] == "ellipse").size()).is_equal(3)  # three little dishes
	# In pixel art: painted on their colours' ramps, a darker edge round them, the same picture each time.
	var picture: ImageTexture = DishView.paint(dish.shapes)
	assert_object(picture).is_same(DishView.paint(dish.shapes))
	assert_vector(Vector2(picture.get_size())).is_equal((dish.custom_minimum_size / DishView.PIXEL).ceil())
	assert_object(dish.material).is_same(PixelLight.material("tent"))  # (lit by the hour)
	assert_object(DishView.paint([])).is_null()
