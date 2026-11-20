extends GdUnitTestSuite
## Tests for scripts/bar/camera.gd: the PD's camera, on its own (with stand-ins for the tent's
## guests).

const PdCamera = preload("res://scripts/bar/camera.gd")
const CounterChats = preload("res://scripts/bar/counter_chats.gd")
const Talk = preload("res://scripts/rules/talk.gd")


## Just what the camera (and the chats) look at.
class Someone:
	extends RefCounted
	var customer := {"name": "Kim Ji-ho"}
	var camera_moment := ""
	var company := "chatty"
	var stay_left := 60.0
	var order: Array = ["soju"]
	var version := 0


func _someone(named: String) -> Someone:
	var made := Someone.new()
	made.customer = {"name": named}
	return made


func test_following_someone_and_stopping() -> void:
	var pd := PdCamera.new()
	var ji_ho := _someone("Kim Ji-ho")
	var min_jun := _someone("Lee Min-jun")
	assert_object(pd.follow(ji_ho)).is_null()
	assert_bool(pd.is_on(ji_ho)).is_true()
	assert_bool(pd.is_on(min_jun)).is_false()
	# They notice the camera (everyone knows they're on a show), the first time only.
	assert_str(ji_ho.camera_moment).is_equal(Talk.camera_moment("Kim Ji-ho"))
	assert_str(ji_ho.camera_moment).contains("Ji-ho")
	ji_ho.camera_moment = ""  # (their next line used it)
	# Switching: the one before is dropped.
	assert_object(pd.follow(min_jun)).is_same(ji_ho)
	assert_bool(pd.is_on(ji_ho)).is_false()
	pd.follow(ji_ho)
	assert_str(ji_ho.camera_moment).is_empty()  # (once a night)
	assert_object(pd.stop()).is_same(ji_ho)
	assert_object(pd.stop()).is_null()
	assert_bool(pd.is_on(null)).is_false()


func test_the_followed_get_more_airtime() -> void:
	var pd := PdCamera.new()
	var ji_ho := _someone("Kim Ji-ho")
	var min_jun := _someone("Lee Min-jun")
	assert_int(pd.neediness(ji_ho, 10)).is_equal(10)  # (nobody followed: as ever)
	pd.follow(ji_ho)
	assert_int(pd.neediness(ji_ho, 10)).is_equal(10 - PdCamera.PULL)  # the owner gets to them sooner
	assert_int(pd.neediness(min_jun, 10)).is_equal(10)
	assert_bool(pd.on_camera([min_jun, ji_ho])).is_true()
	assert_bool(pd.on_camera([min_jun])).is_false()
	assert_array(pd.put_first([min_jun, ji_ho])).is_equal([ji_ho, min_jun])
	assert_array(pd.put_first([min_jun])).is_equal([min_jun])


## Just what the camera looks at in the cat.
class StandInCat:
	extends RefCounted
	var with_guest: Variant = null


func test_following_the_cat_follows_whoever_its_with() -> void:
	var pd := PdCamera.new()
	var tabby := StandInCat.new()
	pd.cat = tabby
	var ji_ho := _someone("Kim Ji-ho")
	pd.follow(ji_ho)
	ji_ho.camera_moment = ""
	assert_object(pd.follow_cat()).is_same(ji_ho)  # (switching from someone to the cat)
	assert_bool(pd.on_cat).is_true()
	assert_bool(pd.is_on(ji_ho)).is_false()
	assert_object(pd.subject()).is_null()  # (on its own by the stove: nobody's story)
	assert_int(pd.neediness(ji_ho, 10)).is_equal(10)
	tabby.with_guest = ji_ho  # (it's gone to sit with them)
	assert_object(pd.subject()).is_same(ji_ho)
	assert_int(pd.neediness(ji_ho, 10)).is_equal(10 - PdCamera.PULL)
	assert_bool(pd.on_camera([ji_ho])).is_true()
	# It wanders sooner while it's followed.
	assert_float(pd.cat_stay(40.0)).is_equal(40.0 * PdCamera.CAT_RESTLESS)
	assert_str(str(pd.stop())).is_equal("cat")
	assert_float(pd.cat_stay(40.0)).is_equal(40.0)
	assert_object(pd.subject()).is_null()


func test_the_counters_chats_lean_towards_the_camera() -> void:
	var counter := CounterChats.new()
	var people: Array = []
	for named in ["A", "B", "C", "D"]:
		people.append(_someone(named))
	# Two chats going: with the camera on C, it's always C's that carries on.
	var first := CounterChats.Chat.new()
	first.people = [people[0], people[1]]
	var second := CounterChats.Chat.new()
	second.people = [people[2], people[3]]
	counter.chats = [first, second]
	var pd := PdCamera.new()
	pd.follow(people[2])
	for _k in 20:
		var spell := counter.choose_spell(people, pd)
		assert_object(spell["chat"]).is_same(second)
	# Starting a chat: the followed person's in it.
	var others: Array = [_someone("E"), _someone("F"), _someone("G")]
	pd.follow(others[2])
	for _k in 10:
		var started := CounterChats.new().choose_spell(others, pd)
		assert_array(started["chat"].people).contains([others[2]])
	assert_object(CounterChats.new().choose_spell([], pd)["chat"]).is_null()


func test_following_the_owner() -> void:
	var camera := PdCamera.new()
	var ji_ho := _someone("Kim Ji-ho")
	assert_float(camera.chat_share()).is_equal(1.0)
	assert_object(camera.follow_owner()).is_null()
	assert_bool(camera.on_owner).is_true()
	assert_object(camera.subject()).is_null()  # (no customer pulled to the front: the owner's the story)
	assert_float(camera.chat_share()).is_equal(PdCamera.OWNER_CHATS)  # customers chat among themselves less
	assert_bool(camera.on_camera([ji_ho], true)).is_true()  # the owner's conversations are on camera...
	assert_bool(camera.on_camera([ji_ho], false)).is_false()  # ...customers' chats without them aren't
	assert_bool(camera.owner_notices()).is_true()  # (the first time tonight: their moment)
	assert_bool(camera.owner_notices()).is_false()  # (once)
	assert_str(str(camera.follow(ji_ho))).is_equal("owner")  # (turning to someone else: it was on the owner)
	assert_bool(camera.on_owner).is_false()
	assert_bool(camera.on_camera([ji_ho], true)).is_true()  # (Ji-ho's on camera now, the owner or not)
	camera.follow_owner()
	assert_str(str(camera.stop())).is_equal("owner")
	assert_float(camera.chat_share()).is_equal(1.0)
	assert_str(Talk.OWNER_ON_CAMERA).contains("only ever hinting at your secret")
