extends GdUnitTestSuite
## Tests for scripts/bar/conversation.gd: what each line is given, on its own (stand-ins for
## the tent's guests).

const Conversation = preload("res://scripts/bar/conversation.gd")
const CounterChats = preload("res://scripts/bar/counter_chats.gd")
const Night = preload("res://scripts/bar/night.gd")
const Talk = preload("res://scripts/rules/talk.gd")
const Plants = preload("res://scripts/rules/plants.gd")


## Just what the conversations look at.
class Someone:
	extends RefCounted
	var customer := {"name": "Kim Ji-ho", "gender": "woman", "age": 34}
	var quick_greeting := false
	var stay_left := 60.0
	var topic := ""
	var stunned := ""
	var food_moment := ""
	var cat_moment := ""
	var camera_moment := ""
	var plant_moment := ""
	var thread_moment := ""
	var plant_card := ""
	var pd_topic := ""
	var pd_topic_lines := 0


func test_a_quiet_one_drawn_into_a_chat_keeps_it_short() -> void:
	assert_str(Talk.QUIET_IN_A_CHAT % "Oh Seong-jun").contains("Oh Seong-jun keeps to themselves").contains("briefly")


func test_lines_are_asked_to_say_worn_out_phrases_another_way() -> void:
	var night := Night.new()
	var guest := Someone.new()
	assert_str(str(Conversation.owner_line(night, guest, 2, false, false)["direction"])).not_contains("Already said a lot")
	for _k in 3:
		night.stats.record_line("Just drowning my sorrows, you know.")
	assert_str(str(Conversation.owner_line(night, guest, 2, false, false)["direction"])).contains("«drown my sorrow»")


func test_the_owners_line_is_given_its_moments_once() -> void:
	var night := Night.new()
	var guest := Someone.new()
	guest.quick_greeting = true
	assert_str(str(Conversation.owner_line(night, guest, 0, false, false)["direction"])).contains("busy")
	guest.food_moment = "The tteokbokki has just arrived."
	var given := Conversation.owner_line(night, guest, 1, false, false)
	assert_str(str(given["direction"])).starts_with("The tteokbokki has just arrived.")
	assert_str(guest.food_moment).is_empty()  # (used up)
	night.owner_stunned = "They've just said they quit their job."
	given = Conversation.owner_line(night, guest, 2, false, false)
	assert_str(str(given["hint"])).is_equal("stunned")
	assert_str(night.owner_stunned).is_empty()
	night.owner_cat_moment = "The cat's on the counter."
	assert_str(str(Conversation.owner_line(night, guest, 4, false, false)["hint"])).is_equal("cat")
	guest.stay_left = 5.0
	assert_str(str(Conversation.owner_line(night, guest, 6, false, false)["direction"])).contains("nearly ready to leave")


func test_a_chat_line_is_given_its_moments() -> void:
	var night := Night.new()
	var chat := CounterChats.Chat.new()
	var speaking := Someone.new()
	var dice := RandomNumberGenerator.new()
	var opening := Conversation.chat_line(night, chat, "Kim Ji-ho", "Lee Min-jun", true, speaking, false, false, "", true, [0, 0, false], 0, false, dice)
	assert_str(str(opening["direction"])).contains("met here before")
	var asking := Conversation.chat_line(night, chat, "Kang Da-eun", "Choi Hye-rin", false, speaking, false, true, "eonni", false, [0, 0, false], 0, false, dice)
	assert_str(str(asking["direction"])).contains("can they call them Eonni, and talk to each other casually")
	speaking.stunned = "Mwo?!"
	assert_str(str(Conversation.chat_line(night, chat, "Kim Ji-ho", "Lee Min-jun", false, speaking, false, false, "", false, [0, 0, false], 0, false, dice)["hint"])).is_equal("stunned")
	# Late on, a few drinks in: now and then a table game, once a chat.
	chat.people = [speaking, Someone.new()]  # (a game needs company)
	chat.topic = "work"
	var offered := ""
	var late := {}
	for k in 60:
		dice.seed = k
		late = Conversation.chat_line(night, chat, "Kim Ji-ho", "Lee Min-jun", false, speaking, false, false, "", false, [0, 0, false], 3, true, dice)
		if str(late["game"]) != "":
			offered = str(late["game"])
			break
	assert_str(offered).is_not_empty()
	assert_str(chat.game).is_equal(offered)
	assert_bool(Talk.TABLE_GAMES.has(offered)).is_true()
	# It's what's going on at the table, in place of the topic (not one more thing beside it) ...
	var situation := str(Talk.TABLE_GAMES[offered]["situation"])
	assert_str(str(late["direction"])).contains(situation)
	assert_str(str(late["direction"])).not_contains(Talk.CHAT_TOPICS["work"])
	# ... for a few lines, offered just the once (for the stats) ...
	for i in Talk.TABLE_GAME_LINES - 1:
		var still := Conversation.chat_line(night, chat, "Lee Min-jun", "Kim Ji-ho", false, speaking, false, false, "", false, [0, 0, false], 3, true, dice)
		assert_str(str(still["game"])).is_empty()
		assert_str(str(still["hint"])).is_equal("game_" + offered)
		assert_str(str(still["direction"])).contains(situation)
	# ... then the chat moves on (and it isn't offered again).
	var moved_on := Conversation.chat_line(night, chat, "Kim Ji-ho", "Lee Min-jun", false, speaking, false, false, "", false, [0, 0, false], 3, true, dice)
	assert_str(str(moved_on["hint"])).is_empty()
	assert_str(str(moved_on["direction"])).contains(Talk.CHAT_TOPICS["work"])
	# Taken up, it isn't steered any more: the AI plays it out.
	chat.game_lines = 2
	chat.game_on = true
	assert_str(str(Conversation.chat_line(night, chat, "Kim Ji-ho", "Lee Min-jun", false, speaking, false, false, "", false, [0, 0, false], 3, true, dice)["hint"])).is_empty()


func test_the_camera_turning_to_someone_is_their_next_lines_moment_once() -> void:
	var night := Night.new()
	var guest := Someone.new()
	guest.camera_moment = Talk.camera_moment("Kim Ji-ho")
	# Not the owner's line (it's the customer who notices the camera) ...
	assert_str(str(Conversation.owner_line(night, guest, 2, false, false)["hint"])).is_not_equal("camera")
	# ... theirs.
	var theirs := Conversation.owner_line(night, guest, 3, false, false)
	assert_str(str(theirs["hint"])).is_equal("camera")
	assert_str(str(theirs["direction"])).contains("camera")
	assert_str(guest.camera_moment).is_empty()
	assert_str(str(Conversation.owner_line(night, guest, 5, false, false)["hint"])).is_not_equal("camera")
	# In a chat at the counter too.
	var chat := CounterChats.Chat.new()
	var dice := RandomNumberGenerator.new()
	guest.camera_moment = Talk.camera_moment("Kim Ji-ho")
	var said := Conversation.chat_line(night, chat, "Kim Ji-ho", "Lee Min-jun", false, guest, false, false, "", false, [0, 0, false], 0, false, dice)
	assert_str(str(said["hint"])).is_equal("camera")
	assert_str(guest.camera_moment).is_empty()


func test_a_plant_card_is_the_next_lines_moment_once() -> void:
	var night := Night.new()
	var guest := Someone.new()
	guest.plant_moment = Plants.moment("phone", "Kim Ji-ho")
	guest.plant_card = "phone"
	var theirs := Conversation.owner_line(night, guest, 3, false, false)
	assert_str(str(theirs["hint"])).is_equal("plant_phone")
	assert_str(str(theirs["direction"])).contains("phone has just started ringing")
	assert_str(guest.plant_moment).is_empty()
	# In a chat too.
	guest.plant_moment = Plants.moment("rain")
	guest.plant_card = "rain"
	var said := Conversation.chat_line(night, CounterChats.Chat.new(), "Kim Ji-ho", "Lee Min-jun", false, guest, false, false, "", false, [0, 0, false], 0, false, RandomNumberGenerator.new())
	assert_str(str(said["hint"])).is_equal("plant_rain")
	assert_str(guest.plant_moment).is_empty()


func test_the_pds_cue_card_is_the_topic_for_a_few_lines() -> void:
	var night := Night.new()
	var guest := Someone.new()
	guest.topic = "work"
	guest.pd_topic = Talk.cue_hint("her first love")
	guest.pd_topic_lines = 2
	for i in 2:
		assert_str(str(Conversation.owner_line(night, guest, 2 + i, false, false)["direction"])).contains("«her first love»")
	assert_str(str(Conversation.owner_line(night, guest, 4, false, false)["direction"])).not_contains("cue card")
	var chat := CounterChats.Chat.new()
	chat.pd_topic = Talk.cue_hint("the worst date they've been on")
	chat.pd_topic_lines = 1
	var dice := RandomNumberGenerator.new()
	assert_str(str(Conversation.chat_line(night, chat, "Kim Ji-ho", "Lee Min-jun", false, guest, false, false, "", false, [0, 0, false], 0, false, dice)["direction"])).contains("«the worst date")
	assert_int(chat.pd_topic_lines).is_equal(0)


func test_strangers_are_known_by_how_they_look_until_a_names_said() -> void:
	var guest := Someone.new()
	guest.customer["look"] = {}
	var chat := CounterChats.Chat.new()
	chat.people = [guest]
	assert_str(Conversation.known_as(guest, chat)).is_not_equal("Kim Ji-ho")
	chat.transcript.append({"speaker": "Kim Ji-ho", "text": "I'm Ji-ho, by the way."})
	assert_str(Conversation.known_as(guest, chat)).is_equal("Kim Ji-ho")
	assert_str(Conversation.last_speaker(chat.transcript)).is_equal("Kim Ji-ho")
	assert_str(Conversation.last_speaker([{"action": "Someone comes in."}])).is_empty()


func test_a_big_moment_stays_on_their_minds_for_a_few_lines() -> void:
	# 17 Nov: the ex walked past, and two lines on they were arguing about ramyeon.
	assert_int(Plants.lingers("ex_walks_past")).is_equal(3)
	assert_int(Plants.lingers("ppl")).is_equal(0)  # (a plug for the sponsor: said, and on to other things)
	assert_int(Plants.lingers("power_goes")).is_equal(2)  # (the whole tent's, 18 Nov)
	var steer := Talk.aftermath_hint(Plants.happened("ex_walks_past", "Jang Yeon-mi", "", "arm in arm with someone new", "female"))
	assert_str(steer).contains("A little while ago").contains("arm in arm with someone new").contains("needn't be every line")
	var night := Night.new()
	var chat := CounterChats.Chat.new()
	chat.pd_topic = steer
	chat.pd_topic_lines = 3
	var guest := Someone.new()
	var dice := RandomNumberGenerator.new()
	for i in 3:
		assert_str(str(Conversation.chat_line(night, chat, "Jang Yeon-mi", "Park Joon-hyung", false, guest, false, false, "", false, [0, 0, false], 0, false, dice)["direction"])).contains("arm in arm")
	assert_str(str(Conversation.chat_line(night, chat, "Jang Yeon-mi", "Park Joon-hyung", false, guest, false, false, "", false, [0, 0, false], 0, false, dice)["direction"])).not_contains("arm in arm")


func test_the_owner_reacts_to_a_card_for_the_whole_tent() -> void:
	# 18 Nov: the song and the power cut, and the owner talked on about the kimchi.
	var night := Night.new()
	night.owner_plant_moment = "The tent's power has just cut out for a moment, then come back on."
	night.owner_plant_card = "power_goes"
	var guest := Someone.new()
	var given := Conversation.owner_line(night, guest, 2, true, false)
	assert_str(str(given["direction"])).contains("power has just cut out")
	assert_str(str(given["hint"])).is_equal("plant_power_goes")
	assert_str(night.owner_plant_moment).is_empty()  # (once)
	assert_str(str(Conversation.owner_line(night, guest, 4, true, false)["direction"])).not_contains("power")


func test_a_card_that_starts_a_chat_is_its_first_line() -> void:
	# 18 Nov: Small world got Sora and Yu-mi talking, and their first line was about mapping hospitals.
	var night := Night.new()
	var chat := CounterChats.Chat.new()
	var speaking := Someone.new()
	speaking.plant_moment = "Jung Sora and Choi Yu-mi have just worked out that they went to the same school."
	speaking.plant_card = "small_world"
	var dice := RandomNumberGenerator.new()
	var given := Conversation.chat_line(night, chat, "Jung Sora", "Choi Yu-mi", true, speaking, false, false, "", false, [0, 0, false], 0, false, dice)
	assert_str(str(given["direction"])).contains("same school").contains("first thing they've ever said")
	assert_str(str(given["hint"])).is_equal("plant_small_world")


func test_the_line_reacting_to_a_card_is_given_only_that() -> void:
	# 18 Nov: the power went, and the next line, told that and the chat's topic and "a little while
	# ago…", carried on about gochujang.
	var night := Night.new()
	var chat := CounterChats.Chat.new()
	chat.topic = "food_fight"
	chat.pd_topic = Talk.aftermath_hint("The tent's lights go out.")
	chat.pd_topic_lines = 2
	var speaking := Someone.new()
	speaking.plant_moment = "The tent's power has just cut out for a moment, then come back on."
	speaking.plant_card = "power_goes"
	var dice := RandomNumberGenerator.new()
	var given := Conversation.chat_line(night, chat, "Moon Jae-yeon", "Kang Eun-bi", false, speaking, false, false, "", false, [0, 0, false], 0, false, dice)
	assert_str(str(given["direction"])).contains("power has just cut out").contains(Talk.JUST_HAPPENED).not_contains("A little while ago")
	assert_int(chat.pd_topic_lines).is_equal(2)  # (what lingers starts on the next line)
	var next_line := Conversation.chat_line(night, chat, "Kang Eun-bi", "Moon Jae-yeon", false, Someone.new(), false, false, "", false, [0, 0, false], 0, false, dice)
	assert_str(str(next_line["direction"])).contains("A little while ago")
	# The same with the owner: the line with the moment is given only that.
	var guest := Someone.new()
	guest.pd_topic = Talk.aftermath_hint("The tent's lights go out.")
	guest.pd_topic_lines = 2
	guest.plant_moment = "The tent's power has just cut out for a moment."
	guest.plant_card = "power_goes"
	var owner_given := Conversation.owner_line(night, guest, 3, false, false)
	assert_str(str(owner_given["direction"])).contains("power has just cut out").not_contains("A little while ago")
	assert_int(guest.pd_topic_lines).is_equal(2)


func test_something_they_mentioned_last_time_is_asked_about_once() -> void:
	var night := Night.new()
	var guest := Someone.new()
	guest.thread_moment = "Last time they were in (3 nights ago), they mentioned a job interview on Monday. The owner remembers, and asks how it went (or is going)."
	assert_str(str(Conversation.owner_line(night, guest, 3, false, false)["direction"])).not_contains("job interview")  # (the owner's to ask: not the customer's line)
	var given: Dictionary = Conversation.owner_line(night, guest, 2, false, false)
	assert_str(str(given["direction"])).contains("job interview")
	assert_str(str(given["hint"])).is_equal("thread")
	assert_str(guest.thread_moment).is_empty()  # (once)
	assert_bool(Talk.hint_taken("thread", "So, how did the interview go?")).is_true()
	# On the owner's first line, if it's still on their mind (19 Nov: a regular went off chatting, and was never asked).
	guest.thread_moment = "Last time they were in, they mentioned an exam."
	var first: Dictionary = Conversation.owner_line(night, guest, 0, false, false)
	assert_str(str(first["direction"])).contains("an exam")
	assert_str(guest.thread_moment).is_empty()
