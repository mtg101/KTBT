extends GdUnitTestSuite
## Tests for scripts/ui/edit_suite.gd: the PD's edit suite on its own, without a night.

const EditSuite = preload("res://scripts/ui/edit_suite.gd")

const TITLES := [{"hangul": "짠한 밤", "english": "A Bittersweet Night"}, {"hangul": "", "english": "Ji-ho Walks Out"}, {"hangul": "", "english": "Nabi Strikes Again"}]
const OPTIONS := [{"kind": "stays_away", "who": ["Hwang Tae-oh"], "teaser": "Will Tae-oh stay away again?"}, {"kind": "cat_strikes", "who": [], "teaser": "Will Nabi strike again?"}]

var _cuts: Array = []


func before_test() -> void:
	_cuts = []


const SCENES := [
	{"kind": "pin", "at": 1260, "text": "Kim Ji-ho: «I quit.»", "who": ["Kim Ji-ho"], "quote": {"speaker": "Kim Ji-ho", "text": "I quit."}},
	{"kind": "moment", "at": 1262, "text": "Kim Ji-ho: SHE QUIT?! (shock)", "who": ["Kim Ji-ho"], "caption": "SHE QUIT?!", "mood": "shock"},
	{"kind": "pin", "at": 1300, "text": "Lee Da-eun: «Me too.»", "who": ["Lee Da-eun"], "quote": {"speaker": "Lee Da-eun", "text": "Me too."}},
	{"kind": "happened", "at": 1380, "text": "Every stool was taken.", "who": []},
	{"kind": "happened", "at": -1, "text": "Hwang Tae-oh, a regular, didn't come in.", "who": ["Hwang Tae-oh"]},
]


func _suite() -> EditSuite:
	var suite := EditSuite.new()
	add_child(suite)
	suite.open("season 2, episode 4", TITLES, "What will Ji-ho do now?", OPTIONS, SCENES)
	suite.finished.connect(func(cut): _cuts.append(cut))
	return suite


func test_the_writers_cut_is_picked_to_start_with() -> void:
	var suite := _suite()
	assert_object(suite.find_child("CutIt", true, false)).is_not_null()
	suite.cut()
	assert_dict(_cuts[0]).is_equal({"title": TITLES[0], "title_by": "writers", "cliffhanger_by": "writers", "own_teaser": false})
	assert_bool(suite.find_children("*", "Label", true, false).any(func(l): return (l as Label).text.ends_with("THE EDIT SUITE · SEASON 2, EPISODE 4"))).is_true()  # (its season and episode)


func test_the_pd_picks_a_title_and_a_cliffhanger() -> void:
	var suite := _suite()
	suite.pick_title(1)
	suite.pick_cliffhanger(2)  # (0 is the writers': this is the second of the game's)
	suite.cut()
	assert_dict(_cuts[0]).is_equal({"title": TITLES[1], "title_by": "pd", "cliffhanger": OPTIONS[1], "cliffhanger_by": "pd", "own_teaser": false})


func test_the_pd_writes_their_own() -> void:
	var suite := _suite()
	suite.own_title.text = "Hi"
	suite.pick_title(3)
	suite.cut()
	assert_array(_cuts).is_empty()  # (too short: not cut yet)
	assert_str(suite.problem.text).contains("The title").contains("a few words")
	suite.own_title.text = "Salt and Overtime"
	suite.own_teaser.text = "will she ever tell him"
	suite.pick_cliffhanger(3)  # (your own)
	suite.cut()
	assert_dict(_cuts[0]).is_equal({"title": {"hangul": "", "english": "Salt and Overtime"}, "title_by": "pd",
		"cliffhanger": {"kind": "other", "who": [], "teaser": "will she ever tell him?"}, "cliffhanger_by": "pd", "own_teaser": true})


func test_typing_picks_your_own_and_esc_leaves_it_to_the_writers() -> void:
	var suite := _suite()
	suite.own_title.text_changed.emit("Salt")
	assert_bool((suite.find_child("Pick3", true, false) as CheckBox).button_pressed).is_true()  # (typing ticks "your own")
	suite.leave_it()
	assert_array(_cuts).is_equal([{}])
	suite.cut()  # (it's gone: once only)
	assert_int(_cuts.size()).is_equal(1)


func test_the_scenes_the_pins_ticked_and_three_at_most() -> void:
	var suite := _suite()
	assert_array(suite.ticked_scenes().map(func(s): return s["at"])).is_equal([1260, 1300])  # (the pins, ticked to start with)
	suite.tick_scene(3)
	suite.tick_scene(4)  # (a fourth: the oldest tick, the first pin, drops)
	assert_array(suite.ticked_scenes().map(func(s): return s["at"])).is_equal([1300, 1380, -1])  # (in the order they happened)
	suite.cut()
	assert_str(str(_cuts[0]["scenes_by"])).is_equal("pd")
	assert_int(_cuts[0]["scenes"].size()).is_equal(3)


func test_the_pins_as_they_were_need_no_rewrite() -> void:
	var suite := _suite()
	suite.cut()
	assert_bool(_cuts[0].has("scenes")).is_false()  # (unchanged: the writers already had the pins)
	var again := _suite()
	again.tick_scene(0, false)
	again.tick_scene(2, false)  # (nothing ticked: the writers choose)
	again.cut()
	assert_bool(_cuts[1].has("scenes")).is_false()


const LOOK := {"age_range": "20s", "hair": "long", "hair_colour": "black", "clothes": "hoodie", "colour": "charcoal", "glasses": true, "skin": 2}


func test_each_scene_has_the_faces_of_who_it_s_about() -> void:
	var suite := EditSuite.new()
	add_child(suite)
	var face := {"key": "w_20s_long_glasses", "look": LOOK}
	suite.open("season 2, episode 4", TITLES, "What will Ji-ho do now?", OPTIONS, SCENES, {"Kim Ji-ho": face, "Lee Da-eun": face})
	assert_int(suite.scenes_with_faces).is_equal(3)  # (Ji-ho's pin and moment, Da-eun's pin: the stools and Tae-oh have no face kept)
	var row := suite.find_child("SceneRow1", true, false) as HBoxContainer
	var pictured := row.find_children("SceneFace", "TextureRect", false, false)
	assert_int(pictured.size()).is_equal(1)
	assert_str(str(pictured[0].get_meta("who"))).is_equal("Kim Ji-ho")
	assert_str((pictured[0] as TextureRect).tooltip_text).contains("Kim Ji-ho")  # (who it is, on hover)
	assert_int(suite.find_child("SceneRow3", true, false).find_children("SceneFace", "TextureRect", false, false).size()).is_equal(0)
	# Still ticked and cut as ever.
	assert_array(suite.ticked_scenes().map(func(s): return s["at"])).is_equal([1260, 1300])
	suite.queue_free()


func test_an_entry_from_before_faces_were_kept_has_none() -> void:
	var suite := _suite()  # (no faces passed: as from before 22 Nov)
	assert_int(suite.scenes_with_faces).is_equal(0)
	assert_array(suite.find_children("SceneFace", "TextureRect", true, false)).is_empty()
