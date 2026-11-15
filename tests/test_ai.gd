extends GdUnitTestSuite
## Tests for scripts/ai.gd: every AI reply is checked, and a rejected one is sent back with
## the reason so the AI can try again. Uses a fake Ollama (tests/support/fake_ollama.gd), so
## the real retry loop runs without a network.

const Ai = preload("res://scripts/ai.gd")
const AiSettings = preload("res://scripts/ai_settings.gd")
const FakeOllama = preload("res://tests/support/fake_ollama.gd")

const MESSAGES := [{"role": "system", "content": "You are a test."}, {"role": "user", "content": "Say 2."}]

var _answers: Array = []  # what each answered signal said


func before_test() -> void:
	AiSettings.override = {"backend": "ollama"}  # (no "are you there?" check, no fallback)
	_answers = []


func after_test() -> void:
	AiSettings.override = {}


## An Ai talking to a fake Ollama with these replies.
func _ai_with(replies: Array) -> Array:
	var ai: Ai = auto_free(Ai.new())
	add_child(ai)
	var fake: FakeOllama = FakeOllama.new()
	fake.replies = replies
	ai._client.queue_free()
	ai._client = fake
	ai.add_child(fake)
	ai.answered.connect(func(purpose, seconds, problems, ok): _answers.append([purpose, seconds, problems, ok]))
	return [ai, fake]


## Wants {"x": 2}.
func _wants_two(data: Variant) -> String:
	if typeof(data) != TYPE_DICTIONARY:
		return "it wasn't a JSON object"
	if int(data.get("x", 0)) != 2:
		return "\"x\" must be 2"
	return ""


func test_a_good_reply_is_used_straight_away() -> void:
	var made := _ai_with([[true, "{\"x\": 2}"]])
	var reply: Dictionary = await made[0].ask_json(MESSAGES, _wants_two, {}, {"purpose": "test"})
	assert_int(int(reply["x"])).is_equal(2)
	assert_int(made[1].asked.size()).is_equal(1)
	assert_str(made[0].last_error).is_empty()
	assert_array(_answers[0][2]).is_empty()
	assert_bool(_answers[0][3]).is_true()


func test_a_rejected_reply_goes_back_with_the_reason() -> void:
	var made := _ai_with([[true, "not json at all"], [true, "{\"x\": 1}"], [true, "{\"x\": 2}"]])
	var reply: Dictionary = await made[0].ask_json(MESSAGES, _wants_two, {}, {"purpose": "test"})
	assert_int(int(reply["x"])).is_equal(2)
	var asked: Array = made[1].asked
	assert_int(asked.size()).is_equal(3)
	assert_array(asked[0]).is_equal(MESSAGES)
	# Each retry: the original messages, the bad reply, and why it can't be used. Only the
	# latest mistake: they don't pile up.
	for i in [1, 2]:
		assert_int(asked[i].size()).is_equal(MESSAGES.size() + 2)
		assert_str(str(asked[i][-2]["role"])).is_equal("assistant")
	assert_str(str(asked[1][-2]["content"])).is_equal("not json at all")
	assert_str(str(asked[1][-1]["content"])).contains("it wasn't a JSON object")
	assert_str(str(asked[2][-2]["content"])).is_equal("{\"x\": 1}")
	assert_str(str(asked[2][-1]["content"])).contains("\"x\" must be 2")
	# The stats hear about both problems, and that it worked in the end.
	assert_array(_answers[0][2]).is_equal(["it wasn't a JSON object", "\"x\" must be 2"])
	assert_bool(_answers[0][3]).is_true()
	assert_str(str(_answers[0][0])).is_equal("test")


func test_it_gives_up_after_max_attempts() -> void:
	var made := _ai_with([[true, "{\"x\": 1}"], [true, "{\"x\": 3}"], [true, "{\"x\": 4}"], [true, "{\"x\": 2}"]])
	var reply: Dictionary = await made[0].ask_json(MESSAGES, _wants_two)
	assert_dict(reply).is_empty()
	assert_int(made[1].asked.size()).is_equal(made[0].max_attempts)  # (the 4th, good reply is never asked for)
	assert_str(made[0].last_error).contains("rejected 3 times")
	assert_str(made[0].last_error).contains("\"x\" must be 2")
	assert_bool(_answers[0][3]).is_false()
	assert_int(_answers[0][2].size()).is_equal(3)


func test_a_request_can_ask_for_fewer_tries() -> void:
	var made := _ai_with([[true, "{\"x\": 1}"], [true, "{\"x\": 2}"]])
	var reply: Dictionary = await made[0].ask_json(MESSAGES, _wants_two, {}, {"purpose": "reaction", "tries": 1})
	assert_dict(reply).is_empty()  # one go only (reactions: a miss just means no caption)
	assert_int(made[1].asked.size()).is_equal(1)


func test_no_answer_from_ollama_isnt_retried() -> void:
	var made := _ai_with([[false, "Can't reach Ollama"], [true, "{\"x\": 2}"]])
	var reply: Dictionary = await made[0].ask_json(MESSAGES, _wants_two)
	assert_dict(reply).is_empty()
	assert_int(made[1].asked.size()).is_equal(1)  # retrying straight away won't help
	assert_str(made[0].last_error).is_equal("Can't reach Ollama")
	assert_bool(made[0].offline).is_false()  # ("ollama" chosen: no falling back to canned)


func test_auto_mode_falls_back_to_canned_for_the_rest_of_the_session() -> void:
	var made := _ai_with([[false, "Can't reach Ollama"]])
	var ai: Ai = made[0]
	ai._auto_fallback = true  # (as "auto" sets it, without the start-up "are you there?" check)
	var reasons: Array = []
	ai.offline_started.connect(func(reason): reasons.append(reason))
	var takes_any_reply := func(data: Variant) -> String: return "" if typeof(data) == TYPE_DICTIONARY else "not an object"
	var reply: Dictionary = await ai.ask_json(MESSAGES, takes_any_reply, {}, {"purpose": "line", "owner_speaks": true, "first": true, "last": false, "title": "Imo"})
	assert_dict(reply).is_not_empty()  # the canned AI answered instead
	assert_bool(ai.offline).is_true()
	assert_array(reasons).is_equal(["Can't reach Ollama"])
	await ai.ask_json(MESSAGES, takes_any_reply, {}, {"purpose": "line", "owner_speaks": true, "first": true, "last": false, "title": "Imo"})
	assert_int(made[1].asked.size()).is_equal(1)  # Ollama isn't asked again
	assert_array(reasons).has_size(1)
