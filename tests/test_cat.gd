extends GdUnitTestSuite
## Tests for scripts/bar/cat.gd: the tent's cat on its own, without a night.

const Cat = preload("res://scripts/bar/cat.gd")
const Layout = preload("res://scripts/bar/layout.gd")

const NABI := {"name": "Nabi", "coat": "calico", "personality": "lazy"}


func _cat() -> Cat:
	var stage: Control = auto_free(Control.new())
	add_child(stage)  # (in the tree: it moves on tweens)
	var cat := Cat.new(RandomNumberGenerator.new(), 1872.0)
	cat.build(stage)
	cat.info = NABI.duplicate()
	cat.paint("나비 Nabi ♀")
	return cat


func test_the_cat_is_drawn_in_its_coat_with_its_name() -> void:
	var cat := _cat()
	assert_str((cat.node.get_node("Tag") as Label).text).is_equal("나비 Nabi ♀")
	assert_bool(cat.node.get_node("Patch").visible).is_true()  # (calico: patches)
	cat.place()
	assert_bool(cat.node.visible).is_true()


func test_where_the_cat_is_for_the_ai_and_the_checks() -> void:
	var cat := _cat()
	assert_dict(cat.fact()).is_equal({"name": "Nabi", "spot": "stove", "with": ""})
	assert_array(cat.tells()).is_equal(["nabi"])
	cat.spot = "lap"
	cat.with_guest = {"seat": 2, "customer": {"name": "Kim Ji-ho"}}
	assert_str(cat.with_name()).is_equal("Kim Ji-ho")
	assert_str(cat.prompt()).contains("Kim Ji-ho's lap")
	cat.place()  # (onto their lap, at their stool)
	assert_object(cat.tween).is_not_null()
	# No cat (a bar from before cats): nothing to tell or check.
	cat.info = {}
	assert_str(cat.prompt()).is_empty()
	assert_dict(cat.fact()).is_empty()
	assert_array(cat.tells()).is_empty()


func test_a_cat_faces_the_way_its_going() -> void:
	var cat := _cat()
	cat.node.position = Vector2(500, 222)
	cat.face_towards(100.0)
	assert_float(cat.node.scale.x).is_equal(-1.0)  # left
	assert_float(cat.node.get_node("Tag").scale.x).is_equal(-1.0)  # (its name turned back to read)
	cat.face_towards(900.0)
	assert_float(cat.node.scale.x).is_equal(1.0)
