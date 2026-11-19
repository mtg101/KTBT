extends GdUnitTestSuite
## Tests for scripts/bar/friendliness.gd: who calls whom, and regulars getting friendlier, on
## their own (stand-ins for the tent's guests).

const Friendliness = preload("res://scripts/bar/friendliness.gd")

const OWNER := {"name": "Park Mi-sook", "gender": "woman", "age": 61}


## Just what friendliness looks at.
class Someone:
	extends RefCounted
	var customer := {}

	func _init(details: Dictionary) -> void:
		customer = details


func _two_regulars() -> Array:
	var older := Someone.new({"name": "Choi Hye-rin", "gender": "woman", "age": 38, "regular_id": "choi-hye-rin-1"})
	var younger := Someone.new({"name": "Kang Da-eun", "gender": "woman", "age": 27, "regular_id": "kang-da-eun-1"})
	var bar := {"regulars": [{"id": "choi-hye-rin-1", "name": "Choi Hye-rin"}, {"id": "kang-da-eun-1", "name": "Kang Da-eun"}]}
	return [bar, older, younger]


func test_how_the_owner_and_a_customer_address_each_other() -> void:
	var guest := Someone.new({"name": "Kim Ji-ho", "gender": "woman", "age": 34})
	assert_bool(bool(Friendliness.person(OWNER, null)["owner"])).is_true()
	assert_str(Friendliness.name_of(OWNER, guest)).is_equal("Kim Ji-ho")
	assert_str(str(Friendliness.address_for(OWNER, guest, null)["listener_name"])).is_equal("Park Mi-sook")
	assert_str(Friendliness.address_note(OWNER, guest)).starts_with("HOW THEY ADDRESS EACH OTHER:").not_contains("given name")
	guest.customer["regular"] = {"owner_knows_name": true, "visits": 8}
	assert_str(Friendliness.address_note(OWNER, guest)).contains("calls them by their given name, Ji-ho")


func test_regulars_who_chat_get_friendlier() -> void:
	var made := _two_regulars()
	var bar: Dictionary = made[0]
	var older: Someone = made[1]
	var younger: Someone = made[2]
	assert_dict(Friendliness.friend_record(bar, younger, older)).is_empty()
	assert_bool(Friendliness.know_each_other(bar, [older, younger])).is_false()  # (strangers: no teasing)
	for night in Friendliness.FRIENDLY_AFTER:
		Friendliness.remember_chat(bar, [older, younger], [{"speaker": "Kang Da-eun", "text": "I'm Da-eun, by the way."}], "See you!", night + 1)
		Friendliness.remember_chat(bar, [older, younger], [], "Again!", night + 1)  # (once a night per pair)
	var record := Friendliness.friend_record(bar, older, younger)
	assert_int(int(record["meetings"])).is_equal(Friendliness.FRIENDLY_AFTER)
	assert_bool(Friendliness.know_each_other(bar, [older, younger])).is_true()  # (chatted before: they can tease)
	assert_bool(Friendliness.know_each_other(bar, [older])).is_false()
	assert_bool(Friendliness.knows_name(bar, older, younger)).is_true()  # (her name was said)
	assert_bool(Friendliness.knows_name(bar, younger, older)).is_false()  # (hers wasn't)
	assert_bool(Friendliness.friend_record(bar, younger, older) == record).is_true()  # (one bond, whichever way round)
	assert_str(str(record["last"])).is_equal("Again!")
	# Time for "can I call you eonni?": the younger asks the older, not the other way round.
	assert_str(Friendliness.friendly_moment(bar, OWNER, younger, older)).is_equal("eonni")
	assert_str(Friendliness.friendly_moment(bar, OWNER, older, younger)).is_empty()
	Friendliness.make_close(bar, younger, older)
	assert_bool(Friendliness.are_close(bar, older, younger)).is_true()
	assert_bool(bool(Friendliness.friend_record(bar, older, younger)["casual"])).is_true()  # (and talking casually: 말 놓을까요?)
	assert_str(Friendliness.friendly_moment(bar, OWNER, younger, older)).is_empty()  # (asked once)
	assert_str(Friendliness.term_used(bar, OWNER, "Eonni, look at this!", younger, older)).is_equal("eonni")
