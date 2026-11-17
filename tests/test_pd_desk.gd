extends GdUnitTestSuite
## Tests for scripts/bar/pd_desk.gd: the PD's desk on its own, without a night (stand-ins for
## the tent's guests, and the tent's side of a card played or a spin aired recorded here).

const PdDesk = preload("res://scripts/bar/pd_desk.gd")
const PdCamera = preload("res://scripts/bar/camera.gd")
const Night = preload("res://scripts/bar/night.gd")
const Plants = preload("res://scripts/rules/plants.gd")


## Just what the desk (and the camera) look at.
class Someone:
	extends RefCounted
	var customer := {"name": "Kim Ji-ho", "gender": "female"}
	var camera_moment := ""
	var stay_left := 60.0


var _seated: Array = []
var _online := true
var _happened: Array = []  # [card, text, aimed, what] for each card the tent was told to make happen
var _aired: Array = []  # k for each spin that went out


func before_test() -> void:
	_seated = []
	_online = true
	_happened = []
	_aired = []


func _someone(named: String, stay := 60.0) -> Someone:
	var made := Someone.new()
	made.customer = {"name": named, "gender": "female"}
	made.stay_left = stay
	return made


## A desk built into a panel in the test's scene, wired to this test's stand-ins.
func _desk() -> PdDesk:
	var desk := PdDesk.new(Night.new())
	desk.now = func(): return {"open": true, "online": _online, "seated": _seated.size(), "pairable": _seated.size() >= 2, "regulars_away": 1, "weather_kind": "clear"}
	desk.guests = func(): return _seated
	desk.pair_partner = func(g): return _seated.filter(func(o): return o != g).front() if _seated.size() >= 2 else null
	desk.cat = func(): return {"name": "Nabi"}
	desk.happens = func(card, text, aimed, what): _happened.append([card, text, aimed, what])
	desk.airs = func(k, _spins, _reply, _lines, _names, _roll): _aired.append(k)
	desk.camera = PdCamera.new()
	var panel: PanelContainer = auto_free(PanelContainer.new())
	add_child(panel)
	desk.build(panel)
	var stage: Control = auto_free(Control.new())
	add_child(stage)
	desk.build_rec(stage)
	return desk


func test_a_hand_is_dealt_the_same_for_the_same_night() -> void:
	var desk := _desk()
	var hand := desk.deal("bar-1 night 3", {}, [])
	assert_int(hand.size()).is_equal(Plants.HAND)
	assert_array(_desk().deal("bar-1 night 3", {}, [])).is_equal(hand)  # (its own dice: the same night, the same hand)
	assert_array(desk.played).is_empty()
	for card in hand:
		assert_bool(desk.card_what.has(card)).is_true()  # (each card's variant, picked as it's dealt)
	assert_bool(hand.any(func(card): return Plants.is_write(card))).is_true()


func test_a_card_is_aimed_at_whoever_the_camera_is_on() -> void:
	var desk := _desk()
	var ji_ho := _someone("Kim Ji-ho")
	var min_jun := _someone("Lee Min-jun")
	_seated = [ji_ho, min_jun]
	desk.camera.follow(min_jun)
	assert_array(desk.target("phone")).is_equal([min_jun])
	assert_str(desk.aim_text("phone")).contains("Lee Min-jun").contains("the camera's on them")
	desk.camera.stop()
	var picked: Array = desk.target("phone")
	assert_array(desk.target("phone")).is_equal(picked)  # (with nobody followed, the game picks someone, and keeps to them)
	assert_str(desk.aim_text("phone")).contains("picked")
	assert_array(desk.target("rain")).is_empty()  # (the tent's: for everyone)
	assert_int(desk.target("small_world").size()).is_equal(2)  # (a pair: them and who they'd chat with)
	ji_ho.stay_left = 5.0
	min_jun.stay_left = 5.0
	assert_array(desk.target("phone")).is_empty()  # (nobody with time left for it)


func test_playing_a_card_tells_the_tent_once() -> void:
	var desk := _desk()
	desk.deal("bar-1 night 1", {}, [])
	desk.hand = ["phone", "rain", "cue_card"]
	desk.refresh()
	_seated = [_someone("Kim Ji-ho")]
	desk.refresh()
	assert_int(desk.cards.get_child_count()).is_equal(3)
	assert_str((desk.cards.get_node("Plant_cue_card").get_node("Kind") as Label).text).is_equal("WRITE-IN")
	(desk.cards.get_node("Plant_phone") as Button).pressed.emit()
	assert_int(_happened.size()).is_equal(1)
	assert_str(str(_happened[0][0])).is_equal("phone")
	assert_array(_happened[0][2]).is_equal([_seated[0]])
	desk.press("phone")  # (played: not again)
	assert_int(_happened.size()).is_equal(1)
	assert_bool((desk.cards.get_node("Plant_phone") as Button).disabled).is_true()


func test_a_write_in_is_typed_on_the_desk_and_checked() -> void:
	var desk := _desk()
	desk.deal("bar-1 night 1", {}, [])
	desk.hand = ["cue_card", "phone", "rain"]
	_seated = [_someone("Kim Ji-ho")]
	desk.press("cue_card")
	assert_bool(desk.writing_box.visible).is_true()
	assert_object(desk.scroll).is_not_null()  # (the desk scrolls: it never grows past the screen)
	assert_str(desk.writing_label.text).contains("The conversation turns to").contains("Kim Ji-ho")
	assert_array(_happened).is_empty()  # (nothing yet: it's being written)
	desk.written("hi")
	assert_str(desk.writing_problem.text).contains("a few words")
	assert_int(desk.night.stats.written_refused).is_equal(1)
	desk.written("her first love")
	assert_bool(desk.writing_box.visible).is_false()
	assert_array(_happened[0].slice(0, 2)).is_equal(["cue_card", "her first love"])
	# Offline, a write-in can't be played (the canned lines can't answer it).
	_online = false
	desk.hand = ["interview", "phone", "rain"]
	desk.refresh()
	assert_bool((desk.cards.get_node("Plant_interview") as Button).disabled).is_true()


func test_the_edit_airs_the_spin_picked_or_the_ais() -> void:
	var desk := _desk()
	var spins := [{"mood": "sad", "caption": "A LONG DAY"}, {"mood": "warm", "caption": "SHE'S GOT THIS"}, {"mood": "roast", "caption": "THE CONFIDENCE, THOUGH"}]
	desk.offer_edit(spins, {"who": "Kim Ji-ho"}, [], ["Kim Ji-ho"], 0.0)
	assert_bool(desk.edit_up()).is_true()
	assert_bool(desk.edit_box.visible).is_true()
	assert_int(desk.edit_buttons.get_child_count()).is_equal(3)
	(desk.edit_buttons.get_node("Edit_3") as Button).pressed.emit()
	assert_array(_aired).is_equal([2])
	assert_bool(desk.edit_up()).is_false()
	assert_dict(desk.night.stats.edits_made).is_equal({"sad→roast": 1})
	# A second one while one's up: the first goes out as the AI had it.
	desk.offer_edit(spins, {"who": "Kim Ji-ho"}, [], ["Kim Ji-ho"], 0.0)
	desk.offer_edit(spins, {"who": "Kim Ji-ho"}, [], ["Kim Ji-ho"], 0.0)
	assert_array(_aired).is_equal([2, 0])
	assert_int(desk.night.stats.edits_offered).is_equal(3)


func test_the_rec_corner_and_the_viewfinder() -> void:
	var desk := _desk()
	desk.show_rec("Kim Ji-ho", "")
	assert_bool(desk.rec.visible).is_true()
	assert_str(desk.rec.text).contains("REC").contains("Kim Ji-ho")
	desk.show_rec("", "")
	assert_bool(desk.rec.visible).is_false()
	var person: Control = auto_free(Control.new())
	PdDesk.viewfinder(person, Rect2(0, 0, 80, 160))
	PdDesk.viewfinder(person, Rect2(0, 0, 80, 160))  # (once only)
	assert_int(person.get_children().filter(func(n): return n.name == "CameraBadge").size()).is_equal(1)
	PdDesk.viewfinder_off(person)
	await get_tree().process_frame
	assert_object(person.get_node_or_null("CameraBadge")).is_null()


func test_the_desk_says_who_the_camera_is_on() -> void:
	var desk := _desk()
	desk.refresh()
	assert_str(desk.text.text).contains("PD CONTROLS").contains("not on anyone")
	var ji_ho := _someone("Kim Ji-ho")
	_seated = [ji_ho]
	desk.camera.follow(ji_ho)
	desk.refresh()
	assert_str(desk.text.text).contains("Kim Ji-ho")


func test_three_lines_pinned_a_fourth_drops_the_oldest() -> void:
	var desk := _desk()
	var lines: Array = []
	for k in 4:
		lines.append({"id": k, "speaker": "Kim Ji-ho", "text": "Line %d." % k, "at": 1200 + k})
	assert_dict(desk.pin(lines[0])).is_equal({"pinned": lines[0]})
	desk.pin(lines[1])
	desk.pin(lines[2])
	assert_str(desk.text.get_parsed_text()).contains("Pinned 3/3").contains("Line 2.")
	assert_str(desk.text.text).contains("[url=pin:2]")  # (a pinned line on the desk: click to let it go)
	var clicked: Array = []
	desk.link = func(meta): clicked.append(meta)
	desk.text.meta_clicked.emit("pin:2")
	assert_array(clicked).is_equal(["pin:2"])
	var fourth := desk.pin(lines[3])
	assert_int(int(fourth["dropped"]["id"])).is_equal(0)  # (three a night: the oldest goes)
	assert_array(desk.pins.map(func(p): return int(p["id"]))).is_equal([1, 2, 3])
	assert_dict(desk.pin(lines[2])).contains_keys(["unpinned"])  # (clicked again: let go)
	assert_array(desk.pins.map(func(p): return int(p["id"]))).is_equal([1, 3])
	assert_int(desk.night.stats.pins_made).is_equal(4)
	assert_int(desk.night.stats.pins_dropped).is_equal(1)
	assert_array(desk.night.stats.pinned).is_equal([{"speaker": "Kim Ji-ho", "text": "Line 1."}, {"speaker": "Kim Ji-ho", "text": "Line 3."}])
	assert_str(desk.night.stats.panel_text(0, 0)).contains("Pinned: 4 (1 dropped").contains("kept 2")
	desk.deal("bar-1 night 2", {}, [])
	assert_array(desk.pins).is_empty()  # (a new night, new pins)
