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
	var plant_card := ""


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
	assert_str(str(asking["direction"])).contains("can they call them Eonni?")
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
