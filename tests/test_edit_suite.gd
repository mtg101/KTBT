extends GdUnitTestSuite
## Tests for scripts/ui/edit_suite.gd: the PD's edit suite on its own, without a night.

const EditSuite = preload("res://scripts/ui/edit_suite.gd")

const TITLES := [{"hangul": "짠한 밤", "english": "A Bittersweet Night"}, {"hangul": "", "english": "Ji-ho Walks Out"}, {"hangul": "", "english": "Nabi Strikes Again"}]
const OPTIONS := [{"kind": "stays_away", "who": ["Hwang Tae-oh"], "teaser": "Will Tae-oh stay away again?"}, {"kind": "cat_strikes", "who": [], "teaser": "Will Nabi strike again?"}]

var _cuts: Array = []


func before_test() -> void:
	_cuts = []


func _suite() -> EditSuite:
	var suite := EditSuite.new()
	add_child(suite)
	suite.open(28, TITLES, "What will Ji-ho do now?", OPTIONS)
	suite.finished.connect(func(cut): _cuts.append(cut))
	return suite


func test_the_writers_cut_is_picked_to_start_with() -> void:
	var suite := _suite()
	assert_object(suite.find_child("CutIt", true, false)).is_not_null()
	suite.cut()
	assert_dict(_cuts[0]).is_equal({"title": TITLES[0], "title_by": "writers", "cliffhanger_by": "writers", "own_teaser": false})


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
