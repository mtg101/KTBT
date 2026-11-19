extends GdUnitTestSuite
## Tests for scripts/bar/regulars_tonight.gd: the bar's regulars tonight, on their own.

const RegularsTonight = preload("res://scripts/bar/regulars_tonight.gd")
const Regulars = preload("res://scripts/rules/regulars.gd")
const Bonds = preload("res://scripts/rules/bonds.gd")
const Memories = preload("res://scripts/rules/memories.gd")


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
	assert_int(int(RegularsTonight.facts(bar, bar["regulars"][0], 9)["nights_ago"])).is_equal(4)


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


func test_tonights_chats_as_pairs_of_regulars_remembered_at_closing() -> void:
	var bar := {"regulars": [{"id": "ji-ho", "name": "Kim Ji-ho"}, {"id": "da-eun", "name": "Kang Da-eun"}, {"id": "min-su", "name": "Park Min-su"}]}
	var chats := [
		{"names": ["Kim Ji-ho", "Kang Da-eun", "Someone New"], "owner_in": false,
			"lines": [{"speaker": "Kim Ji-ho", "text": "I've just started at the bakery."}, {"speaker": "Kang Da-eun", "text": "My dog Bori loves bread."}, {"speaker": "Someone New", "text": "Hi."}]},
		{"names": ["Kim Ji-ho", "Park Min-su"], "owner_in": true, "lines": [{"speaker": "Park Min-su", "text": "Cheers."}]},
	]
	var pairs := RegularsTonight.chat_pairs(bar, chats)
	assert_int(pairs.size()).is_equal(2)  # (someone who isn't a regular isn't remembered)
	assert_str(str(pairs[0]["b"]["name"])).is_equal("Kang Da-eun")  # (the most said first)
	assert_str(RegularsTonight.said_by(pairs[0], bar["regulars"][0])).is_equal("i've just started at the bakery.")
	assert_array(pairs[1]["heard"][0]["by"]).contains(["owner"])  # (the owner had joined that one)
	var changed := RegularsTonight.remember_pair(bar, pairs[0], 7, {"first_remembers": "Da-eun has a dog.", "second_remembers": "Ji-ho bakes now.",
		"first_fact_kind": "job", "first_fact": "just started at the bakery", "second_fact_kind": "pet", "second_fact": "a dog called Bori",
		"first_coming_up": "", "second_coming_up": "a trip"})
	var bond := Bonds.find(bar, "ji-ho", "da-eun")
	assert_int(int(bond["meetings"])).is_equal(1)
	assert_str(str(Bonds.memories_by(bond, "ji-ho")[0]["text"])).is_equal("Da-eun has a dog.")
	assert_array(bar["regulars"][0]["facts"]["job"]["known_by"]).is_equal(["da-eun"])  # (not the owner: she wasn't in that chat)
	assert_int(changed["facts"].size()).is_equal(2)
	assert_int(changed["threads"].size()).is_equal(1)
	assert_dict(Memories.open_thread(bar["regulars"][1])).is_empty()  # (the owner never heard about it)


func test_who_you_know_here_from_your_own_side() -> void:
	var bar := {"regulars": [{"id": "ji-ho", "name": "Kim Ji-ho", "job": "baker"}, {"id": "da-eun", "name": "Kang Da-eun", "job": "teacher"}]}
	var ji_ho: Dictionary = bar["regulars"][0]
	var da_eun: Dictionary = bar["regulars"][1]
	assert_str(RegularsTonight.known_of(bar, "ji-ho", da_eun)).is_empty()  # (never met)
	var bond := Bonds.between(bar, "ji-ho", "da-eun")
	Bonds.meet(bond, 1)
	assert_str(RegularsTonight.known_of(bar, "ji-ho", da_eun)).is_equal("the teacher (name not known): acquaintance")
	Bonds.learn_name(bond, "ji-ho")
	Bonds.remember(bond, 1, {"ji-ho": "Da-eun's dog would eat the cake.", "da-eun": "Ji-ho bakes."})
	Memories.learn_fact(da_eun, "pet", "a dog called Bori", 1, ["ji-ho"])
	Memories.learn_fact(da_eun, "home", "Daegu", 1, ["owner"])  # (Ji-ho never heard this one)
	Memories.add_thread(da_eun, "a trip to Jeju", 1, ["ji-ho"])
	var known := RegularsTonight.known_of(bar, "ji-ho", da_eun)
	assert_str(known).starts_with("Kang Da-eun: acquaintance").contains("pet: a dog called Bori").contains("Da-eun's dog would eat the cake").contains("a trip to Jeju")
	assert_str(known).not_contains("Daegu")
	assert_str(RegularsTonight.known_of(bar, "da-eun", ji_ho)).is_equal("the baker (name not known): acquaintance, remembers \"Ji-ho bakes.\"")  # (her side: not his)
	assert_str(RegularsTonight.own_facts_text(da_eun)).is_equal("from: Daegu; pet: a dog called Bori")  # (hers, whoever heard them)
	assert_str(RegularsTonight.carried_in(bar, da_eun)).contains("with the owner stranger").contains("knows Kim Ji-ho (acquaintance)").contains("2 things said about themselves")


func test_close_friends_drift_in_around_the_same_time() -> void:
	var bar := {"regulars": [{"id": "ji-ho", "name": "Kim Ji-ho"}, {"id": "da-eun", "name": "Kang Da-eun"}, {"id": "min-su", "name": "Park Min-su"}]}
	Bonds.between(bar, "ji-ho", "da-eun")["close"] = true
	var due := [{"time": 1200.0, "id": "ji-ho"}, {"time": 1380.0, "id": "da-eun"}, {"time": 1300.0, "id": "min-su"}]
	RegularsTonight.together(bar, due, RandomNumberGenerator.new())
	var da_eun: Dictionary = due.filter(func(d): return d["id"] == "da-eun")[0]
	assert_float(float(da_eun["time"])).is_between(1200.0, 1200.0 + RegularsTonight.TOGETHER_MINUTES)  # (just after her friend)
	assert_str(str(da_eun["with"])).is_equal("ji-ho")
	assert_float(float(due.filter(func(d): return d["id"] == "min-su")[0]["time"])).is_equal(1300.0)  # (not close to anyone: as he was)
	# One who wasn't coming in might tag along (now and then).
	var tagged := 0
	for seed_value in 40:
		var dice := RandomNumberGenerator.new()
		dice.seed = seed_value
		var alone := [{"time": 1200.0, "id": "ji-ho"}]
		RegularsTonight.together(bar, alone, dice)
		tagged += alone.size() - 1
		assert_bool(alone.any(func(d): return d["id"] == "min-su")).is_false()
	assert_int(tagged).is_between(4, 24)  # (about TAG_ALONG of the time)
