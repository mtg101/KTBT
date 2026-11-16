extends GdUnitTestSuite
## Tests for scripts/bar/regulars_tonight.gd: the bar's regulars tonight, on their own.

const RegularsTonight = preload("res://scripts/bar/regulars_tonight.gd")
const Regulars = preload("res://scripts/rules/regulars.gd")


func _bar() -> Dictionary:
	return {"regulars": [
		{"id": "kim-ji-ho-1", "name": "Kim Ji-ho", "gender": "woman", "pull": 0.6, "visits": 3, "last_night": 5, "usual_hour": 21 * 60, "favourite_days": []},
		{"id": "choi-young-ja-founding", "name": "Choi Young-ja", "gender": "woman", "founding": true, "introduced": false, "pull": Regulars.FOUNDING_PULL,
			"role": Regulars.ROLES.keys()[0], "since": "for 6 years", "habit": "most Fridays", "history": "Was here the night the tarp went up.", "usual_hour": 20 * 60},
	]}


func test_who_comes_in_tonight() -> void:
	var bar := _bar()
	var due := RegularsTonight.plan(bar, 9, 4, {}, RandomNumberGenerator.new())
	assert_bool(due.any(func(d): return d["id"] == "choi-young-ja-founding")).is_true()  # (a founding regular's first night: always)
	for i in due.size() - 1:
		assert_float(float(due[i]["time"])).is_less_equal(float(due[i + 1]["time"]))  # soonest first
	assert_dict(RegularsTonight.find(bar, "kim-ji-ho-1")).is_not_empty()
	assert_dict(RegularsTonight.find(bar, "")).is_empty()
	assert_array(RegularsTonight.all({})).is_empty()


func test_how_a_regular_is_announced() -> void:
	var bar := _bar()
	assert_str(RegularsTonight.back_text(bar["regulars"][0], 9)).is_equal("Kim Ji-ho is back, for her %s visit (last time: %s)." % [Regulars.ordinal(4), Regulars.nights_ago_text(4)])
	var founding: Dictionary = bar["regulars"][1]
	var first := RegularsTonight.back_text(founding, 9)
	assert_str(first).contains("ducks in and takes her usual stool: she's been coming for 6 years, most Fridays.").contains("She's ")
	assert_bool(bool(founding["introduced"])).is_true()  # (only the first time: who they are to the tent)
	assert_str(RegularsTonight.back_text(founding, 10)).not_contains("She's ")
	assert_int(int(RegularsTonight.facts(bar["regulars"][0], 9)["nights_ago"])).is_equal(4)


func test_the_nights_end_and_what_the_owner_remembers() -> void:
	var bar := _bar()
	bar["regulars"][0]["pull"] = Regulars.DROP_BELOW * 1.01  # (one more night away and they're gone)
	assert_array(RegularsTonight.fade(bar, 9)).is_equal(["Kim Ji-ho"])
	assert_int(bar["regulars"].size()).is_equal(1)
	var counted := RegularsTonight.pulls(bar)
	assert_int(int(counted["founding"])).is_equal(1)
	assert_bool(counted["pulls"].has("Choi Young-ja")).is_true()
	assert_str(RegularsTonight.remembered_text({"impression": "Quiet, kind.", "memories": [{"owner": "Talked about her mum."}], "facts": {"job": "nurse"}})) \
		.is_equal("Quiet, kind. · Talked about her mum. · Job: nurse")
	assert_bool(RegularsTonight.name_said("Kim Ji-ho", "thanks, ji-ho!")).is_true()
	assert_bool(RegularsTonight.name_said("Kim Ji-ho", "thanks, imo!")).is_false()
