extends GdUnitTestSuite
## Tests for scripts/bar/card_slots.gd: a PD's card waits its turn behind one still to come,
## rather than wiping it out (26 Nov: the interview never asked, the chaebol card on top of it).

const CardSlots = preload("res://scripts/bar/card_slots.gd")
const CounterChats = preload("res://scripts/bar/counter_chats.gd")
const Night = preload("res://scripts/bar/night.gd")


## Just what the slots look at.
class Someone:
	extends RefCounted
	var plant_moment := ""
	var plant_card := ""
	var plant_happened := ""
	var card_turn := false
	var plant_queue: Array = []
	var pd_topic := ""
	var pd_topic_lines := 0
	var pd_topic_card := ""
	var pd_topic_personal := false
	var pd_topic_queue: Array = []


func test_a_second_card_waits_behind_the_first() -> void:
	var guest := Someone.new()
	assert_str(str(CardSlots.plant(guest, "interview", "The PD asks them a question.", "")["behind"])).is_empty()
	guest.card_turn = true  # (the owner's turned to them for it)
	var slot := CardSlots.plant(guest, "chaebol", "A man in a suit says their mother's looking for them.", "A man in a suit comes in.")
	assert_str(str(slot["behind"])).is_equal("interview")
	assert_str(guest.plant_card).is_equal("interview")  # (not wiped out)
	assert_array(CardSlots.unsaid(guest)).is_equal(["interview", "chaebol"])
	assert_str(CardSlots.use_plant(guest)).is_equal("chaebol")
	assert_str(guest.plant_moment).contains("mother's looking")
	assert_str(guest.plant_happened).is_equal("A man in a suit comes in.")
	assert_bool(guest.card_turn).is_false()  # (a new card: the owner turns to them again)
	assert_str(CardSlots.use_plant(guest)).is_empty()
	assert_str(guest.plant_moment).is_empty()
	assert_array(CardSlots.unsaid(guest)).is_empty()


func test_only_so_many_cards_wait() -> void:
	var guest := Someone.new()
	CardSlots.plant(guest, "phone", "Their phone rings.", "")
	for i in CardSlots.MAX_WAITING:
		assert_str(str(CardSlots.plant(guest, "card%d" % i, "Something.", "")["dropped"])).is_empty()
	assert_str(str(CardSlots.plant(guest, "late", "Something more.", "")["dropped"])).is_equal("card0")  # (the oldest waiting)
	assert_int(guest.plant_queue.size()).is_equal(CardSlots.MAX_WAITING)


func test_the_whole_tents_card_waits_behind_their_own() -> void:
	# 26 Nov: a song from across the street wiped out the ex walking past.
	var guest := Someone.new()
	CardSlots.steer(guest, "The ex walked past.", 3, "ex_walks_past", true)
	var slot := CardSlots.steer(guest, "A song from across the street.", 2, "noraebang", false)
	assert_str(str(slot["behind"])).is_equal("ex_walks_past")
	assert_str(guest.pd_topic_card).is_equal("ex_walks_past")
	for _k in 2:
		assert_str(CardSlots.use_steer(guest)).is_empty()
	assert_str(CardSlots.use_steer(guest)).is_equal("noraebang")  # (the ex's lines done: the song's turn)
	assert_str(guest.pd_topic).contains("song")
	assert_int(guest.pd_topic_lines).is_equal(2)
	CardSlots.use_steer(guest)
	CardSlots.use_steer(guest)
	assert_int(guest.pd_topic_lines).is_equal(0)


func test_their_own_card_goes_ahead_and_the_newest_goes_first() -> void:
	var guest := Someone.new()
	CardSlots.steer(guest, "The power went.", 2, "power_goes", false)
	assert_str(str(CardSlots.steer(guest, "The ex walked past.", 3, "ex_walks_past", true)["ahead_of"])).is_equal("power_goes")
	assert_str(guest.pd_topic_card).is_equal("ex_walks_past")
	assert_str(str(CardSlots.steer(guest, "The PD's cue: her first love.", 3, "cue_card", true)["ahead_of"])).is_equal("ex_walks_past")
	assert_array(guest.pd_topic_queue.map(func(e): return e["card"])).is_equal(["ex_walks_past", "power_goes"])  # (their own before the tent's)
	CardSlots.steer(guest, "Rain.", 2, "rain", false)
	assert_array(guest.pd_topic_queue.map(func(e): return e["card"])).is_equal(["ex_walks_past", "power_goes", "rain"])
	assert_str(str(CardSlots.steer(guest, "Wild weather.", 2, "wild_weather", false)["dropped"])).is_equal("wild_weather")  # (too many: the one furthest back)


func test_whats_on_their_mind_goes_into_a_chat_and_back_out() -> void:
	var a := Someone.new()
	var b := Someone.new()
	CardSlots.steer(a, "The ex walked past.", 3, "ex_walks_past", true)
	CardSlots.steer(a, "The power went.", 2, "power_goes", false)
	CardSlots.steer(b, "Small world.", 2, "small_world", true)
	var chat := CounterChats.Chat.new()
	assert_array(CardSlots.hand_over(a, chat)).is_empty()  # (nothing in the chat yet: it all goes over as it was)
	assert_str(chat.pd_topic_card).is_equal("ex_walks_past")
	assert_int(chat.pd_topic_queue.size()).is_equal(1)
	assert_int(a.pd_topic_lines).is_equal(0)
	assert_array(a.pd_topic_queue).is_empty()
	CardSlots.hand_over(b, chat)  # (the other one's comes too: 26 Nov, it was lost)
	var cards: Array = [chat.pd_topic_card] + chat.pd_topic_queue.map(func(e): return e["card"])
	assert_array(cards).contains_exactly_in_any_order(["ex_walks_past", "small_world", "power_goes"])
	assert_str(str(cards[-1])).is_equal("power_goes")  # (the tent's last)
	# The chat's over: what's on its mind goes back with whoever's still here.
	CardSlots.hand_over(chat, a)
	assert_int(a.pd_topic_lines).is_greater(0)
	assert_int(chat.pd_topic_lines).is_equal(0)
	assert_int(a.pd_topic_queue.size()).is_equal(2)


func test_the_owners_cards_for_the_tent_wait_their_turn() -> void:
	var night := Night.new()
	assert_str(CardSlots.owner_plant(night, "noraebang", "A song starts up across the street.")).is_empty()
	assert_str(CardSlots.owner_plant(night, "power_goes", "The power's gone.")).is_equal("noraebang")
	assert_str(night.owner_plant_card).is_equal("noraebang")
	CardSlots.use_owner_plant(night)
	assert_str(night.owner_plant_card).is_equal("power_goes")
	CardSlots.use_owner_plant(night)
	assert_str(night.owner_plant_moment).is_empty()
