extends GdUnitTestSuite
## Tests for scripts/bar/counter_chats.gd: customers chatting, on their own (with stand-ins for
## the tent's guests).

const CounterChats = preload("res://scripts/bar/counter_chats.gd")


## Just what the chats look at.
class Someone:
	extends RefCounted
	var company := "chatty"
	var customer := {"name": "Kim Ji-ho"}
	var stay_left := 60.0
	var order: Array = ["soju"]
	var version := 0


func test_who_can_chat() -> void:
	var counter := CounterChats.new()
	var chatty := Someone.new()
	var quiet := Someone.new()
	quiet.company = "quiet"
	var leaving := Someone.new()
	leaving.stay_left = CounterChats.CHAT_MIN_STAY_LEFT - 1.0
	var waiting := Someone.new()
	waiting.order = []
	assert_bool(counter.can_chat(chatty)).is_true()
	assert_bool(counter.can_chat(quiet)).is_false()  # (keeping to themselves)
	assert_bool(counter.can_chat(leaving)).is_false()  # (about to go)
	assert_bool(counter.can_chat(waiting)).is_false()  # (not settled in)
	assert_bool(counter.possible([chatty], false)).is_false()  # (one's not enough)
	assert_bool(counter.possible([quiet, Someone.new()], false)).is_true()  # (a chatty one can turn to a quiet one: see below)
	var also_quiet := Someone.new()
	also_quiet.company = "quiet"
	assert_bool(counter.possible([quiet, also_quiet], false)).is_false()  # (quiet ones never start one)
	assert_bool(counter.possible([chatty, Someone.new()], false)).is_true()
	assert_bool(counter.possible([chatty, Someone.new()], true)).is_false()  # (not after last orders)


func test_a_quiet_one_is_drawn_in_now_and_then() -> void:
	var counter := CounterChats.new()
	var chatty := Someone.new()
	var quiet := Someone.new()
	quiet.company = "quiet"
	quiet.customer = {"name": "Oh Seong-jun"}
	var spell := counter.choose_spell([chatty, quiet])
	assert_bool(bool(spell.get("drawn_in", false))).is_true()
	assert_array(spell["chat"].people).is_equal([chatty, quiet])
	assert_int(counter.voices(spell["chat"]).size()).is_equal(2)  # (drawn in, they can carry on talking)
	counter.leave(chatty)
	assert_bool(counter.possible([Someone.new(), quiet], false)).is_false()  # (once a night: they'd rather be left alone)
	# Someone chatty to talk to comes first.
	var other := CounterChats.new()
	var friend := Someone.new()
	assert_bool(bool(other.choose_spell([chatty, quiet, friend]).get("drawn_in", false))).is_false()


func test_a_spell_starts_carries_on_and_ends() -> void:
	var counter := CounterChats.new()
	var a := Someone.new()
	var b := Someone.new()
	var spell := counter.choose_spell([a, b])
	assert_bool(bool(spell["started"])).is_true()
	var chat: CounterChats.Chat = spell["chat"]
	assert_array(chat.people).contains_exactly_in_any_order([a, b])
	assert_object(counter.chat_of(a)).is_same(chat)
	assert_array(counter.free_to_chat([a, b])).is_empty()
	# Someone new: next time it carries on (and they may join in).
	var c := Someone.new()
	var again := counter.choose_spell([a, b, c])
	assert_object(again["chat"]).is_same(chat)
	assert_bool(bool(again["started"])).is_false()
	a.version = 2
	assert_int(counter.version(chat)).is_greater_equal(2)
	# Leaving: a chat with one left is over.
	counter.leave(a)
	if not chat.people.has(c):
		assert_array(counter.chats).is_empty()
	assert_object(counter.chat_of(a)).is_null()
	assert_dict(CounterChats.new().choose_spell([])).contains_key_value("chat", null)  # (nobody to chat)
