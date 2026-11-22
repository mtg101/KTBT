extends GdUnitTestSuite
## Tests for scripts/rules/channels.gd: the owner's niece or nephew who films the show, and the
## channels it's booked on, checked (made up, never real, never the same again), the game's own
## names, and the show's booking history.

const Channels = preload("res://scripts/rules/channels.gd")
const Talk = preload("res://scripts/rules/talk.gd")


func test_the_niece_or_nephew_is_checked() -> void:
	var good := {"name": "Ji-woo Kim", "hangul": "김지우", "handle": "@JiWoo_Pocha.Live"}
	assert_str(Channels.validate_relative(good)).is_empty()
	assert_str(str(good["name"])).is_equal("Kim Ji-woo")  # (family name first)
	assert_str(str(good["handle"])).is_equal("jiwoo_pocha.live")  # (lowercase, the @ dropped)
	assert_str(str(good["hangul"])).is_equal("김지우")
	assert_str(Channels.validate_relative({"name": "Jiwoo", "handle": "jiwoo_live"})).contains("family name")
	assert_str(Channels.validate_relative({"name": "Kim Ji-woo", "handle": "ji woo!"})).contains("lowercase letters")
	assert_str(Channels.validate_relative({"name": "Kim Ji-woo", "handle": "9lives"})).contains("start with a letter")
	assert_str(Channels.validate_relative({"name": "Kim Ji-woo", "handle": "jiwoo_youtube"})).contains("real platform")
	assert_str(Channels.validate_relative({"name": "Kim Ji-woo"})).is_not_empty()  # (no handle)
	assert_str(Channels.relation(0.2)).is_equal("niece")
	assert_str(Channels.relation(0.8)).is_equal("nephew")
	assert_str(Channels.gender_of("nephew")).is_equal("man")


func test_a_channel_is_made_up_and_never_the_same_again() -> void:
	var good := {"hangul": "달빛 TV", "english": "Moonlight TV", "meaning": "moonlight"}
	assert_str(Channels.validate_channel(good)).is_empty()
	assert_str(str(good["hangul"])).is_equal("달빛TV")
	assert_str(Channels.validate_channel({"hangul": "한빛방송", "english": "Hanbit Broadcasting", "meaning": "a great light"})).is_empty()
	# Never real (whole words, any case; in Hangul too), however it's dressed.
	assert_str(Channels.validate_channel({"hangul": "달빛TV", "english": "SBS Plus", "meaning": "something"})).contains("SBS")
	assert_str(Channels.validate_channel({"hangul": "유튜브방송", "english": "Tube Broadcasting", "meaning": "something"})).contains("real")
	assert_str(Channels.validate_channel({"hangul": "달빛TV", "english": "tvN Night", "meaning": "something"})).contains("tvN")
	assert_str(Channels.names_real("Kenai Broadcasting")).is_empty()  # (ENA only as a word of its own)
	assert_str(Channels.names_real("ENA Drama")).is_equal("ENA")
	# Hangul, with TV or + if you like; English letters for the English.
	assert_str(Channels.validate_channel({"hangul": "Moon TV", "english": "Moon TV", "meaning": "the moon"})).contains("Hangul")
	assert_str(Channels.validate_channel({"hangul": "달빛TV", "english": "달빛방송국", "meaning": "moonlight"})).contains("English letters")
	# Never one of the show's earlier channels.
	assert_str(Channels.validate_channel({"hangul": "달빛TV", "english": "Moonlight TV", "meaning": "moonlight"}, ["Pocha Log", "Moonlight TV"])).contains("been on")


func test_the_games_own_names_pass_the_checks() -> void:
	for relation in Channels.RELATIVES:
		for k in Channels.RELATIVES[relation].size():
			var picked := Channels.fallback_relative(relation, (k + 0.5) / Channels.RELATIVES[relation].size())
			assert_str(Channels.validate_relative(picked)).override_failure_message(str(picked)).is_empty()
	for rung in Channels.FALLBACK_CHANNELS:
		for each in Channels.FALLBACK_CHANNELS[rung]:
			assert_str(Channels.validate_channel(each.duplicate())).override_failure_message(str(each)).is_empty()
	assert_str(str(Channels.fallback_channel("network", ["Moonlight TV"])["english"])).is_not_equal("Moonlight TV")  # (the first not taken)
	var all_taken: Array = Channels.FALLBACK_CHANNELS["video"].map(func(c): return str(c["english"]))
	assert_str(Channels.validate_channel(Channels.fallback_channel("video", all_taken), all_taken)).is_empty()  # (every one taken: still a new one)


func test_the_show_books_channels_and_keeps_them() -> void:
	var show := {"season": 1, "rung": "phone"}
	assert_bool(Channels.needs_booking(show)).is_true()
	var relative := {"name": "Kim Ji-woo", "handle": "jiwoo_pocha_live", "relation": "niece"}
	show["pd"] = relative
	var stream := Channels.stream_channel(relative)
	assert_str(str(stream["english"])).is_equal("@jiwoo_pocha_live")
	Channels.book(show, "phone", stream, 1)
	assert_bool(Channels.needs_booking(show)).is_false()
	show["rung"] = "video"  # (moved up)
	assert_bool(Channels.needs_booking(show)).is_true()
	Channels.book(show, "video", {"hangul": "포차로그", "english": "Pocha Log", "meaning": "a pocha's video diary"}, 3)
	assert_int(int(show["channel"]["from_season"])).is_equal(3)
	assert_array(show["channels"].map(func(c): return str(c["rung"]))).is_equal(["phone", "video"])
	assert_array(Channels.taken_names(show)).is_equal(["@jiwoo_pocha_live", "포차로그", "Pocha Log"])
	assert_str(Channels.full_name(show["channel"])).is_equal("포차로그 (Pocha Log)")
	assert_str(Channels.hover(show["channel"])).contains("a pocha's video diary").contains("Online video channel")


func test_whos_filming_is_in_the_prompts() -> void:
	var show := {"rung": "phone", "pd": {"name": "Kim Ji-woo", "relation": "niece"}}
	var crew := Channels.camera_crew(show)
	assert_str(crew).is_equal("Ji-woo, the owner's niece, filming on her phone,")
	assert_str(Talk.camera_moment("Lee Min-jun", crew)).is_equal("Ji-woo, the owner's niece, filming on her phone, has just turned it on Min-jun, and they've noticed.")
	assert_str(Talk.camera_happened("Lee Min-jun", crew)).is_equal("Ji-woo, the owner's niece, filming on her phone, turns it on Lee Min-jun.")
	show["rung"] = "network"
	assert_str(Talk.camera_moment("Lee Min-jun", Channels.camera_crew(show))).is_equal("The show's camera crew have just turned their camera on Min-jun, and they've noticed.")
	show["rung"] = "video"
	assert_str(Channels.camera_crew(show)).is_equal("The channel's camera")


func test_the_loading_screen_shows_the_channel() -> void:
	var on_tv := {"show": {"channel": {"hangul": "달빛TV", "english": "Moonlight TV", "meaning": "moonlight", "rung": "network"}}}
	assert_str(LoadingScreen.channel_text(on_tv)).is_equal("on 달빛TV")
	assert_str(LoadingScreen.channel_text({"show": {"channel": {"hangul": "", "english": "@jiwoo_pocha_live"}}})).is_equal("on @jiwoo_pocha_live")
	assert_str(LoadingScreen.channel_text({})).is_empty()  # (a new bar: not booked anywhere yet)
	var screen: LoadingScreen = auto_free(LoadingScreen.new())
	screen.bar = on_tv
	add_child(screen)
	var label: Label = screen.get_node("Channel")
	assert_str(label.text).is_equal("on 달빛TV")
	assert_str(label.tooltip_text).contains("Moonlight TV")  # (the Hangul explains itself)
