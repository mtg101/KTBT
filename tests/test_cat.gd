extends GdUnitTestSuite
## Tests for scripts/bar/cat.gd: the tent's cat on its own, without a night.

const Cat = preload("res://scripts/bar/cat.gd")
const Layout = preload("res://scripts/bar/layout.gd")
const PixelLight = preload("res://scripts/ui/pixel_light.gd")
const PixelCat = preload("res://scripts/ui/pixel_cat.gd")
const Art = preload("res://scripts/ui/art.gd")
const CatRules = preload("res://scripts/rules/cat_rules.gd")

const NABI := {"name": "Nabi", "coat": "calico", "personality": "lazy"}


func after_test() -> void:
	Art.folder = "res://art/"
	Art.reset()


func _cat() -> Cat:
	var stage: Control = auto_free(Control.new())
	add_child(stage)  # (in the tree: it moves on tweens)
	var cat := Cat.new(RandomNumberGenerator.new(), 1872.0)
	cat.build(stage)
	cat.info = NABI.duplicate()
	cat.paint("나비 Nabi ♀")
	return cat


func test_the_cat_is_drawn_in_its_coat_with_its_name() -> void:
	var lit := _cat()
	assert_object(lit.node.material).is_same(PixelLight.material("people"))  # lit by the hour, as the people
	assert_bool((lit.node.get_node("Body") as CanvasItem).use_parent_material).is_true()
	assert_bool(lit.picture.use_parent_material).is_true()
	assert_bool((lit.node.get_node("Tag") as CanvasItem).use_parent_material).is_false()  # (its name isn't)
	# Without art for its coat: its shapes.
	Art.folder = "res://tests/support/art/"
	Art.reset()
	var cat := _cat()
	assert_str((cat.node.get_node("Tag") as Label).text).is_equal("나비 Nabi ♀")
	assert_bool(cat.node.get_node("Patch").visible).is_true()  # (calico: patches)
	assert_bool(cat.node.get_node("Body").visible).is_true()
	assert_bool(cat.picture.visible).is_false()
	assert_array(Art.summary()["drawn"]).contains(["cat/calico_sit"])
	cat.place()
	assert_bool(cat.node.visible).is_true()


func test_the_cat_in_pixel_art_sleeps_sits_and_walks() -> void:
	for coat in CatRules.CAT_COATS:  # every coat has its pictures
		for pose in Art.CAT_POSES:
			assert_bool(Art.has("cat/%s_%s" % [coat, pose])).override_failure_message("no cat/%s_%s" % [coat, pose]).is_true()
	var cat := _cat()
	assert_bool(cat.picture.visible).is_true()
	assert_bool(cat.node.get_node("Body").visible).is_false()  # (its shapes not drawn)
	assert_bool(cat.node.get_node("Patch").visible).is_false()
	assert_str(cat.picture.pose).is_equal("sleep")  # by the stove: curled up asleep
	assert_object(cat.picture.texture).is_same(Art.texture("cat/calico_sleep"))
	assert_vector(cat.picture.size).is_equal(PixelCat.PIXELS * PixelCat.GRID)
	cat.spot = "counter"
	cat.place()
	assert_str(cat.picture.rest).is_equal("sit")
	# Moving, it walks: a frame of its stride every so far.
	cat.tween.kill()
	cat.node.position = Vector2(400, 348)
	await get_tree().process_frame
	cat.node.position.x += 2.0
	await get_tree().process_frame
	assert_str(cat.picture.pose).is_equal("walk_0")
	cat.node.position.x += PixelCat.STEP + 1.0
	await get_tree().process_frame
	assert_str(cat.picture.pose).is_equal("walk_1")
	# On the grid's lines, either way it faces.
	cat.node.position.x += 1.0
	await get_tree().process_frame
	var drawn_left: float = cat.node.position.x + PixelCat.BASE.x + (cat.picture.position.x - PixelCat.BASE.x) * signf(cat.node.scale.x)
	assert_float(fposmod(drawn_left + 0.001, PixelCat.GRID)).is_less(0.01)
	# Still again: sitting up.
	await get_tree().create_timer(PixelCat.STILL_AFTER + 0.1).timeout
	assert_str(cat.picture.pose).is_equal("sit")


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
